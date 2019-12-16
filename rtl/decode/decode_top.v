`include "soc.vh"

module decode_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Stall pipeline
    input   logic                           stall_decode,

    // Exceptions. WB takes care of managing exceptions and priorities
    input   fetch_xcpt_t                    xcpt_fetch_in,
    output  fetch_xcpt_t                    xcpt_fetch_out,
    output  decode_xcpt_t                   decode_xcpt_next,

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
    input logic [`REG_FILE_ADDR_RANGE] 		rmAddr,

    // Bypasses
    input logic [`REG_FILE_DATA_RANGE]		alu_data_bypass,
    input logic [`REG_FILE_DATA_RANGE]      cache_data_bypass
);

/////////////////////////////////////////
// Control logic for signals to be sent to ALU
logic           req_to_alu_valid_next;
alu_request_t   req_to_alu_info_next;

decode_xcpt_t decode_xcpt_next;

assign req_to_alu_valid_next = ( !stall_decode & fetch_instr_valid) ? 1'b1 : 1'b0;

//  CLK    DOUT             DIN
`FF(clock, req_to_alu_info, req_to_alu_info_next)
`FF(clock, req_to_alu_pc,   fetch_instr_pc)

//      CLK    RST    DOUT                DIN                      DEF
`RST_FF(clock, reset, req_to_alu_valid, req_to_alu_valid_next, '0)
`RST_FF(clock, reset, decode_xcpt,      decode_xcpt_next,      '0)
`RST_FF(clock, reset, xcpt_fetch_out,   xcpt_fetch_in,         '0)

/////////////////////////////////////////
// Register file signals      
logic [`REG_FILE_DATA_RANGE] rf_reg1_data, rf_reg2_data; 

/////////////////////////////////////////
// Destination register FF to know when to apply bypasses

// Bypass from ALU
logic [`REG_FILE_ADDR_RANGE] rd_alu_ff;
logic [`INSTR_OPCODE_RANGE]  opcode_alu_ff; // We store the opcode to check if it was an R-type instr, so the result is computed on ALU stage

//  CLK    DOUT           DIN
`FF(clock, rd_alu_ff,     fetch_instr_data[`INSTR_DST_ADDR_RANGE]) 
`FF(clock, opcode_alu_ff, fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]) 

// Bypass from cache
logic [`REG_FILE_ADDR_RANGE] rd_alu_ff_2;
logic [`INSTR_OPCODE_RANGE]  opcode_alu_2_ff; // We store the opcode to check if it was an M-type instr, so the result is computed on cache stage

//  CLK    DOUT             DIN
`FF(clock, rd_alu_ff_2,     rd_alu_ff)    
`FF(clock, opcode_alu_2_ff, opcode_alu_ff) 


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
    req_to_alu_info_next.ra_data = (  opcode_alu_ff == `INSTR_R_TYPE   
                                    & rd_alu_ff   == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE] ) ? alu_data_bypass   : // Bypass from ALU  

                                   (  ( opcode_alu_2_ff == `INSTR_LDB_OPCODE | opcode_alu_2_ff == `INSTR_LDW_OPCODE)
                                    & rd_alu_ff_2 == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]  
                                    & dcache_rsp_valid)                                         ? cache_data_bypass : //Bypass from Cache (hit on LD req)

				    					    					                                 rf_reg1_data; // data from register file

    // Use RD to store src2
    req_to_alu_info_next.rb_data = (opcode_alu_ff == `INSTR_R_TYPE & rd_alu_ff == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]) ? alu_data_bypass : // Bypass from ALU
                                   ((  opcode_alu_2_ff == `INSTR_LDB_OPCODE | opcode_alu_2_ff == `INSTR_LDW_OPCODE )
                                     & rd_alu_ff_2 == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE] & dcache_rsp_valid)          ? cache_data_bypass : //Bypass from Cache (hit on LD req)
				   										                                                                 rf_reg2_data; // data from register file

    ////////////////////////////////////////////////
    // Decode instruction to determine RB or offset 
    
    if ( fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_M_TYPE )  
    begin
        req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH,fetch_instr_data[14:0]);

        // If it is a store request we have to take into account that RD value
        // could have been computed on ALU stage or brought from memory on cache
        // stage
	    if (fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_STB_OPCODE | 
            fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_STW_OPCODE  )//if store, we take rd value or (BP)
        begin
		    req_to_alu_info_next.rd_addr =  (  opcode_alu_ff == `INSTR_R_TYPE  
                                             & rd_alu_ff     == fetch_instr_data[`INSTR_DST_ADDR_RANGE] ) ? `ZX(`REG_FILE_ADDR_WIDTH,alu_data_bypass) : // Bypass from ALU

		       				                (  (  opcode_alu_2_ff == `INSTR_LDB_OPCODE 
                                                | opcode_alu_2_ff == `INSTR_LDW_OPCODE )
                                             & rd_alu_ff_2 == fetch_instr_data[`INSTR_DST_ADDR_RANGE]) ? `ZX(`REG_FILE_ADDR_WIDTH,cache_data_bypass) : //Bypass from Cache (hit on LD req)
										                                                                 `ZX(`REG_FILE_ADDR_WIDTH,rf_reg2_data); // data from register file
        end
    end
    else 
    begin
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
            // Raise an exception because the instruction is not supported
            decode_xcpt_next.xcpt_illegal_instr = (fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE] == `INSTR_R_TYPE)? 1'b1 : 1'b0;
        end
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

assign dest_addr = fetch_instr_data[`INSTR_DST_ADDR_RANGE];

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

endmodule

