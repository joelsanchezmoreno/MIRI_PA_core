`include "soc.vh"

module decode_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset_c,

    // Stall pipeline
    input   logic                               stall_decode,

    // Fetched instruction
    input   logic                               fetch_instr_valid,
    input   logic   [`INSTR_WIDTH-1:0]          fetch_instr_data,

    // Instruction to ALU
    output  logic                               dec_instr_valid,
    output  dec_instruction_info                dec_instr_info,

    input logic [`REG_FILE_RANGE] 		writeValRF,
    input logic 				writeEnRF,
    input logic [`REG_FILE_ADDR_RANGE] 		destRF,

    input logic 				excV,
    input logic [`PC_WIDTH-1:0] 		rmPC,
    input logic [`REG_FILE_ADDR_RANGE] 		rmAddr,

    // Bypasses
    input logic [`REG_FILE_RANGE]		aluOutBP,
    input logic [`REG_FILE_RANGE]		memOutBP

);

logic   dec_instr_update;
dec_instruction_info        dec_instr_info_next;

logic [`REG_FILE_ADDR_RANGE] rd_alu;
logic [`REG_FILE_ADDR_RANGE] rd_alu_2;

`FF(clock, reset_c, rd_alu_2, rd_alu) //2nd Bypass from ALU with dist=2
`FF(clock, reset_c, rd_alu, fetch_instr_data[24:20])

logic [`REG_FILE_RANGE] regA, regB; 

//     CLK    RST      DOUT            DIN
`EN_FF(clock, reset_c, dec_instr_info, dec_instr_info_next)

//      CLK    RST      DOUT            DIN                  DEF
`RST_FF(clock, reset_c, dec_instr_valid, dec_instr_update, 1'b0)

assign dec_instr_update = ( stall_decode || !fetch_instr_valid) ? 1'b0 : 1'b1;
        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH,fetch_instr_data[14:0]);

//TODO: Finish encoding and ask Roger the instructions really needed
always_comb	
begin
    dec_instr_info_next = '0;
    dec_instr_info_next.opcode    = fetch_instr_data[31:25];
    dec_instr_info_next.rd        = fetch_instr_data[24:20];
    dec_instr_info_next.ra        = (rd_alu   == fetch_instr_data[19:15]) ? aluOutBP : //BP ALU -> DECODE DIST = 1 
	   			    (rd_alu_2 == fetch_instr_data[19:15]) ? memOutBP : //BP ALU -> DECODE DIST = 2
				    					    regA; //TODO: CHECK CORRECT ORDER, I THINK THIS IS THE CORRECT ORDER SINCE 
								    		//ALU VALUE IS THE MOST RECENT ONE
    if ( dec_instr_info_next.opcode == 8'h0X) // R-format
    begin
        dec_instr_info_next.rb_offset = (rd_alu   == fetch_instr_data[14:10])   ? `ZX(`DEC_RB_OFF_WIDTH, aluOutBP) :
					(rd_alu_2 == fetch_instr_data[14:10])   ? `ZX(`DEC_RB_OFF_WIDTH, memOutBP) :
									          `ZX(`DEC_RB_OFF_WIDTH,regB);
    end
    else if ( dec_instr_info_next.opcode == 8'h1X ) // M-format
    begin
        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH,fetch_instr_data[14:0]);
	if (dec_instr_info_next.opcode == 8'h13 || dec_instr_info_next.opcode == 8'h12)//if store, we take rd value or (BP)
		dec_instr_info_next.rd        = (rd_alu   == fetch_instr_data[24:20]) ? aluOutBP :
		       				(rd_alu_2 == fetch_instr_data[24:20]) ? memOutBP : 
											regB;

    end
    else if ( dec_instr_info_next.opcode == 8'h3X ) // B-format
    begin
	    if (dec_instr_info_next.opcode == 8'h30) // BEQ CASE
	        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH, {fetch_instr_data[24:20], fetch_instr_data[9:0]}); 
	    else if (dec_instr_info_next.opcode == 8'h31) // JUMP CASE
	        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH, {fetch_instr_data[24:20], fetch_instr_data[14:0]}); 
    end
end

regFile 
registerFile
(
  .clock     (clock),
  .reset     (reset),
  .writeEn   (writeEnRF),

  .src1      (fetch_instr_data[19:15]),
  .src2      ((dec_instr_info_next.opcode == 8'h13 || dec_instr_info_next.opcode == 8'h12)?fetch_instr_data[24:20]:fetch_instr_data[14:10]),
  .dest	     (fetch_instr_data[24:20]),

  .writeVal  (writeValRF),
  .reg1	     (regA),
  .reg2      (regB),

  .excV	     (excV),
  .rmPC	     (rmPC),
  .rmAddr    (rmAddr)

);
endmodule

