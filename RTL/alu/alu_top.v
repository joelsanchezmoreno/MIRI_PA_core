`include "soc.vh"

module alu_top
(
  // System signals
  input   logic                               clock,
  input   logic                               reset_c,

  // Stall pipeline
  input   logic                               stall_alu,

  input  logic [`REG_FILE_RANGE]  		val1,
  input  logic [`REG_FILE_RANGE]  		val2,
  input  logic [`INSTR_OPCODE-1:0]   		instr,
  output logic [`REG_FILE_RANGE] 		aluOut,
  output logic [`PC_WIDTH-1:0]	 		pcBranch,

  output logic 			 		pcBranchVal,

  output logic					writeEn
);


logic [`REG_FILE_RANGE]  aluOut_next;
logic [`PC_WIDTH-1:0]    pcBranch_next;
logic			 pcBranchVal_next;
logic			 writeEn_next;

`RST_FF(clock, reset_c, aluOut, aluOut_next, '0)
`RST_FF(clock, reset_c, pcBranch, pcBranch_next, '0)
`RST_FF(clock, reset_c, pcBranchVal, pcBranchVal_next, 1'b0)
`RST_FF(clock, reset_c, , writeEn, writeEn_next, 1'b0)

always_comb
begin
	writeEn_next = '0;
	aluOut_next  = '0;
	pcBranchVal  = '0;
	writeEn_next = '0;

	if (instr == 8'h00)
	begin
		aluOut_next <= val1 + val2;
		writeEn_next = 0'b1;
	end
	if (instr == 8'h01)
        begin
                aluOut_next <= val1 - val2;
                writeEn_next = 0'b1;
        end
	if (instr == 8'h02)
        begin
                aluOut_next <= val1 * val2;
                writeEn_next = 0'b1;
        end
	if (instr == 8'h1X) //MEM
                aluOut_next <= val1 + val2;
	if (instr == 8'h31) //JUMP
	begin
		pcBranch_next = val1;
		pcBranchVal_next = 1'b1;
	end
	if (instr == 8'h30) //BEQ
	begin
	//TODO		
	end
	if (instr == 8'h32) //TLBWRITE
        begin
        //TODO          
        end
	if (instr == 8'h33) //iret
        begin
        //TODO
        end

end
endmodule
