`include "soc.vh"

module decode_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Stall pipeline
    input   logic                           stall_decode,
    output  logic                           decode_hazard,

    // Exceptions. WB takes care of managing exceptions and priorities
    input   fetch_xcpt_t                    xcpt_fetch_in,
    output  fetch_xcpt_t                    xcpt_fetch_out,
    output  decode_xcpt_t                   decode_xcpt,

    // Fetched instruction
    input   logic                           fetch_instr_valid,
    input   logic   [`INSTR_WIDTH-1:0]      fetch_instr_data,
    input   logic   [`PC_WIDTH_RANGE]       fetch_instr_pc, 

    // Instruction to ALU
    output  logic                           req_to_alu_valid,
    output  alu_request_t                   req_to_alu_info,
    output  logic   [`PC_WIDTH_RANGE]       req_to_alu_pc,

    // Write requests to the Register File
    input logic [`REG_FILE_DATA_RANGE] 		writeValRF,
    input logic 				            writeEnRF,
    input logic [`REG_FILE_ADDR_RANGE] 		destRF,

    // Exceptions values to be stored on the RF
    input logic 				            xcpt_valid,
    input logic [`PC_WIDTH_RANGE] 		    rmPC,
    input logic [`REG_FILE_XCPT_ADDR_RANGE] rmAddr,

    // Bypasses
    input logic [`REG_FILE_DATA_RANGE]		alu_data_bypass,
    input logic [`REG_FILE_DATA_RANGE]      cache_data_bypass,
    input logic                             cache_data_valid
);

/////////////////////////////////////////
// Control logic for signals to be sent to ALU
logic           req_to_alu_valid_next, req_to_alu_valid_ff;
alu_request_t   req_to_alu_info_next;
decode_xcpt_t decode_xcpt_next;


logic           stall_decode_ff;

//  CLK    DOUT             DIN
`FF(clock, stall_decode_ff, stall_decode)


assign req_to_alu_valid_next = ( !stall_decode & fetch_instr_valid ) ? 1'b1 : // New instruction from fetch
                               ( decode_hazard                     ) ? 1'b1 : // Was stall and we need to send same request again
                                                                       1'b0;

// If decode was stalled then we need to send the request we were processing
// again, which means that we cannot perform the request sent by the fetch
// stage and we need fetch stage to wait one extra cycle                                                                  
assign decode_hazard = ( !stall_decode & stall_decode_ff );                                                                  
assign req_to_alu_valid = !stall_decode & (req_to_alu_valid_ff | decode_hazard);

//      CLK    RST    DOUT                 DIN                      DEF
`RST_FF(clock, reset, req_to_alu_valid_ff, req_to_alu_valid_next, '0)
`RST_FF(clock, reset, decode_xcpt,         decode_xcpt_next,      '0)
`RST_FF(clock, reset, xcpt_fetch_out,      xcpt_fetch_in,         '0)

//         CLK    RST    EN                     DOUT             DIN                    DEF
`RST_EN_FF(clock, reset, req_to_alu_valid_next, req_to_alu_info, req_to_alu_info_next, '0)
`RST_EN_FF(clock, reset, req_to_alu_valid_next, req_to_alu_pc,   fetch_instr_pc, '0)

/////////////////////////////////////////
// Register file signals      
logic [`REG_FILE_DATA_RANGE] rf_reg1_data; 
logic [`REG_FILE_DATA_RANGE] rf_reg2_data; 

/////////////////////////////////////////
// Destination register FF to know when to apply bypasses

// Bypass from ALU
logic [`REG_FILE_ADDR_RANGE] rd_alu_ff;
logic [`INSTR_OPCODE_RANGE]  opcode_alu_ff; // We store the opcode to check if it was an R-type instr, so the result is computed on ALU stage

//     CLK    EN                              DOUT           DIN
`EN_FF(clock, !stall_decode & !decode_hazard, rd_alu_ff,     fetch_instr_data[`INSTR_DST_ADDR_RANGE]) 
`EN_FF(clock, !stall_decode & !decode_hazard, opcode_alu_ff, fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]) 
//`EN_FF(clock, !decode_hazard & req_to_alu_valid, rd_alu_ff,     fetch_instr_data[`INSTR_DST_ADDR_RANGE]) 
//`EN_FF(clock, !decode_hazard & req_to_alu_valid, opcode_alu_ff, fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]) 

// Bypass from cache
logic [`REG_FILE_ADDR_RANGE] rd_alu_ff_2;
logic [`INSTR_OPCODE_RANGE]  opcode_alu_2_ff; // We store the opcode to check if it was an M-type instr, so the result is computed on cache stage

//     CLK    EN                              DOUT             DIN
`EN_FF(clock, !stall_decode & !decode_hazard, rd_alu_ff_2,     rd_alu_ff)    
`EN_FF(clock, !stall_decode & !decode_hazard, opcode_alu_2_ff, opcode_alu_ff) 

always_comb	
begin
    decode_xcpt_next.xcpt_illegal_instr = 1'b0;
    decode_xcpt_next.xcpt_pc = fetch_instr_pc;

    // Opcode and destination register are always decoded from the instruction
    // provided by the fetch stage
    req_to_alu_info_next.opcode  = fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE];
    req_to_alu_info_next.rd_addr = fetch_instr_data[`INSTR_DST_ADDR_RANGE];
    req_to_alu_info_next.ra_addr = fetch_instr_data[`INSTR_SRC1_ADDR_RANGE];

    // Register A value depends on the instructions being performed at the
    // alu and cache stage at this cycle, because we may need to bypass data
    req_to_alu_info_next.ra_data = (  is_r_type_instr(opcode_alu_ff)   
                                    & rd_alu_ff   == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE] ) ? alu_data_bypass   : // Bypass from ALU  

                                   ( (is_r_type_instr(opcode_alu_2_ff) |  is_load_instr(opcode_alu_2_ff))
                                    & rd_alu_ff_2 == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]  
                                    & cache_data_valid)                                         ? cache_data_bypass : //Bypass from Cache (hit on LD req)

				    					    					                                  rf_reg1_data; // data from register file

    // Use RD to store src2
    req_to_alu_info_next.rb_data = (  is_r_type_instr(opcode_alu_ff) 
                                    & rd_alu_ff == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]) ? alu_data_bypass : // Bypass from ALU

                                   (  (is_r_type_instr(opcode_alu_2_ff) |  is_load_instr(opcode_alu_2_ff))
                                     & rd_alu_ff_2 == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE] 
                                     & cache_data_valid)                                                   ? cache_data_bypass : //Bypass from Cache (hit on LD req)
				   										                                                     rf_reg2_data; // data from register file

    // Encoding for ADDI and M-type instructions                                                                                                                     
    req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH,fetch_instr_data[14:0]);

    ////////////////////////////////////////////////
    // Decode instruction to determine RB or offset 
    
    //FIXME: [Optional] Need to add MOV, TLBWRITE and IRET decoding
    // B-format
    if (  fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]  == `INSTR_BEQ_OPCODE 
        | fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]  == `INSTR_JUMP_OPCODE)  
    begin
    
        if ( fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_BEQ_OPCODE) // BEQ CASE
        begin
            req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH, {fetch_instr_data[`INSTR_OFFSET_HI_ADDR_RANGE], 
                                                                  fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE]}); 
        end
        else // JUMP CASE
        begin
            req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH, {fetch_instr_data[`INSTR_OFFSET_HI_ADDR_RANGE], 
                                                                  fetch_instr_data[`INSTR_OFFSET_M_ADDR_RANGE], 
                                                                  fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE]}); 
        end
    end
    else
    begin
        if (  is_r_type_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]) 
            & fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]  != `INSTR_NOP_OPCODE)
            // Raise an exception because the instruction is not supported
            decode_xcpt_next.xcpt_illegal_instr = 1'b1;
    end
end


////////////////////////////////
// Register File

logic [`REG_FILE_ADDR_RANGE]   src1_addr; 
logic [`REG_FILE_ADDR_RANGE]   src2_addr;
logic [`REG_FILE_ADDR_RANGE]   dest_addr;

assign src1_addr = fetch_instr_data[`INSTR_SRC1_ADDR_RANGE];

assign src2_addr = (  fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_STB_OPCODE  
                    | fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_STW_OPCODE) ? fetch_instr_data[`INSTR_DST_ADDR_RANGE]:
                                                                                         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE];

assign dest_addr = destRF;

regFile 
registerFile
(
    // System signals
    .clock      ( clock         ),
    .reset      ( reset         ),

    // Read port
    .src1_addr  ( src1_addr     ),
    .src2_addr  ( src2_addr     ),
    .reg1_data  ( rf_reg1_data  ),
    .reg2_data  ( rf_reg2_data  ),

    // Write port
    .writeEn    ( writeEnRF     ),
    .dest_addr  ( dest_addr     ),
    .writeVal   ( writeValRF    ),

    // Exception input
    .xcpt_valid ( xcpt_valid    ),
    .rmPC	    ( rmPC          ),
    .rmAddr     ( rmAddr        )
);

`ifdef VERBOSE_DECODE
always_ff @(posedge clock)
begin
    if (req_to_alu_valid)
    begin
        $display("[DECODE] Request to ALU. PC = %h",req_to_alu_pc);
        $display("         opcode  =  %h",req_to_alu_info.opcode);
        $display("         rd addr =  %h",req_to_alu_info.rd_addr);
        $display("         ra addr =  %h",req_to_alu_info.ra_addr);
        $display("         ra data =  %h",req_to_alu_info.ra_data);
        $display("         rb data =  %h",req_to_alu_info.rb_data);
        $display("         offset  =  %h",req_to_alu_info.offset );
        $display("[RF]     src1_addr    = %h",src1_addr);
        $display("         src2_addr    = %h",src2_addr);
        $display("         rf_reg1_data = %h",rf_reg1_data);
        $display("         rf_reg2_data = %h",rf_reg2_data);
     `ifdef VERBOSE_DECODE_BYPASS
        $display("[BYPASSES SRC2]");
        $display("         is_r_type_instr(opcode_alu_ff) = %h",is_r_type_instr(opcode_alu_ff));
        $display("         rd_alu_ff   = %h",rd_alu_ff);
        $display("         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]);
        $display("         alu_data_bypass   = %h",alu_data_bypass);
        $display("         ----------------------");
        $display("         is_r_type_instr(opcode_alu_2_ff) = %h",is_r_type_instr(opcode_alu_2_ff));
        $display("         is_m_type_instr(opcode_alu_2_ff) = %h",is_m_type_instr(opcode_alu_2_ff));
        $display("         rd_alu_ff_2   = %h",rd_alu_ff_2);
        $display("         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]);
        $display("         cache_data_valid   = %h",cache_data_valid);
        $display("         cache_data_bypass  = %h",cache_data_bypass);
     `endif
    end
end
`endif

endmodule

