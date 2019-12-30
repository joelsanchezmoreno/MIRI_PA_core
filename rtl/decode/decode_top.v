`include "soc.vh"

module decode_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Stall pipeline
    input   logic                           stall_decode,
    input   logic                           flush_decode,

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
    input logic                             alu_data_valid,
    input logic [`REG_FILE_DATA_RANGE]      cache_data_bypass,
    input logic                             cache_data_valid
);

/////////////////////////////////////////
// Exceptions
decode_xcpt_t   decode_xcpt_next;
decode_xcpt_t   decode_xcpt_ff;
fetch_xcpt_t    xcpt_fetch_ff;

//         CLK    RST                    EN            DOUT            DIN               DEF
`RST_EN_FF(clock, reset | flush_decode, !stall_decode, decode_xcpt_ff, decode_xcpt_next, '0)
`RST_EN_FF(clock, reset | flush_decode, !stall_decode, xcpt_fetch_ff,  xcpt_fetch_in,    '0)

assign decode_xcpt      = (stall_decode) ? decode_xcpt    : decode_xcpt_ff;
assign xcpt_fetch_out   = (stall_decode) ? xcpt_fetch_out : xcpt_fetch_ff;

/////////////////////////////////////////
// Control logic for requests to be sent to ALU
logic                   req_to_alu_valid_next;
logic                   req_to_alu_valid_ff;
alu_request_t           req_to_alu_info_next;
alu_request_t           req_to_alu_info_ff;
logic [`PC_WIDTH-1:0]   req_to_alu_pc_ff;

//         CLK    RST    EN                            DOUT                 DIN                    DEF
`RST_EN_FF(clock, reset, !stall_decode | flush_decode, req_to_alu_valid_ff, req_to_alu_valid_next, '0)

//     CLK    EN            DOUT                DIN                  
`EN_FF(clock, !stall_decode, req_to_alu_info_ff, req_to_alu_info_next)
`EN_FF(clock, !stall_decode, req_to_alu_pc_ff,   fetch_instr_pc      )


assign req_to_alu_valid_next =  ( flush_decode      ) ? 1'b0 : // Invalidate instruction
                                ( fetch_instr_valid ) ? 1'b1 : // New instruction from fetch
                                                       1'b0;

assign req_to_alu_valid = (stall_decode | flush_decode) ? 1'b0            : req_to_alu_valid_ff;
assign req_to_alu_info  = (stall_decode | flush_decode) ? req_to_alu_info : req_to_alu_info_ff;
assign req_to_alu_pc    = (stall_decode | flush_decode) ? req_to_alu_pc   : req_to_alu_pc_ff;


/////////////////////////////////////////
// Register file signals      
logic [`REG_FILE_DATA_RANGE] rf_reg1_data; 
logic [`REG_FILE_DATA_RANGE] rf_reg2_data; 

/////////////////////////////////////////
// Bypass control signals

logic update_decode_control;

// We store the rd and opcode to check if it was an R-type or M-type instr,
// so we know if the result is computed on ALU stage or Cache stage
decode_control_t alu_instr_next;
decode_control_t alu_instr_aux;
decode_control_t alu_instr_ff;
decode_control_t cache_instr_aux;
decode_control_t cache_instr_ff;

always_comb
begin
    alu_instr_next.rd_addr  = fetch_instr_data[`INSTR_DST_ADDR_RANGE];
    alu_instr_next.opcode   = fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE];
end

assign update_decode_control = !stall_decode;

//     CLK    EN                     DOUT            DIN
`EN_FF(clock, update_decode_control, alu_instr_aux,   alu_instr_next ) 
`EN_FF(clock, update_decode_control, cache_instr_aux, alu_instr_ff) 

assign alu_instr_ff     = (stall_decode) ? alu_instr_ff   : alu_instr_aux;
assign cache_instr_ff   = (stall_decode) ? cache_instr_ff : cache_instr_aux;

/////////////////////////////////////////
// Decode data
always_comb	
begin
    decode_xcpt_next.xcpt_illegal_instr = 1'b0;
    decode_xcpt_next.xcpt_pc = fetch_instr_pc;

    // Opcode and destination register are always decoded from the instruction
    // provided by the fetch stage
    req_to_alu_info_next.opcode  = fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE];
    req_to_alu_info_next.rd_addr = fetch_instr_data[`INSTR_DST_ADDR_RANGE];
    req_to_alu_info_next.ra_addr = fetch_instr_data[`INSTR_SRC1_ADDR_RANGE];
    req_to_alu_info_next.rb_addr = fetch_instr_data[`INSTR_SRC2_ADDR_RANGE];

    // Register A value depends on the instructions being performed at the
    // alu and cache stage at this cycle, because we may need to bypass data
    req_to_alu_info_next.ra_data = (  is_r_type_instr(alu_instr_ff.opcode)   
                                    & alu_instr_ff.rd_addr == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE] 
                                    & alu_data_valid)                                                   ? alu_data_bypass   : // Bypass from ALU  

                                   ( (is_r_type_instr(cache_instr_ff.opcode) |  is_load_instr(cache_instr_ff.opcode))
                                    & cache_instr_ff.rd_addr == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]  
                                    & cache_data_valid)                                                 ? cache_data_bypass : //Bypass from Cache (hit on LD req)

                                   ( writeEnRF & (destRF == fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]))  ? writeValRF : // intercept write to RF
				    					    					                                          rf_reg1_data; // data from register file

    // Use RD to store src2
    req_to_alu_info_next.rb_data = (  is_r_type_instr(alu_instr_ff.opcode) 
                                    & alu_instr_ff.rd_addr == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]
                                    & alu_data_valid)                                                       ? alu_data_bypass : // Bypass from ALU

                                   (  (is_r_type_instr(cache_instr_ff.opcode) |  is_load_instr(cache_instr_ff.opcode))
                                     & cache_instr_ff.rd_addr == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE] 
                                     & cache_data_valid)                                                    ? cache_data_bypass : //Bypass from Cache (hit on LD req)
	
                                   ( writeEnRF & (destRF == fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]))      ? writeValRF : // intercept write to RF
			   										                                                          rf_reg2_data; // data from register file

    // Encoding for ADDI and M-type instructions                                                                                                                     
    req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH,fetch_instr_data[14:0]);

    ////////////////////////////////////////////////
    // Decode instruction to determine RB or offset 
    
    //FIXME: [Optional] Need to add MOV, TLBWRITE and IRET decoding
    // B-format
    if (  is_branch_type_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]) 
        | is_jump_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]))  
    begin
    
        if ( is_branch_type_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]))// BEQ,BNE, BLT, BGT, BLE, BGE CASE
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
        if (  !is_r_type_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]) 
            & !is_m_type_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE])
            & !is_branch_type_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE])
            & !is_jump_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE])
            & !is_mov_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE])
            & !is_tlb_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE])
            & !is_iret_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE])
            & !is_nop_instr(fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE]))
                decode_xcpt_next.xcpt_illegal_instr = !flush_decode;
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
        $display("[BYPASSES SRC1]");
        $display("         is_r_type_instr(alu_instr_ff.opcode) = %h",is_r_type_instr(alu_instr_ff.opcode));
        $display("         alu_instr_ff.rd_addr = %h",alu_instr_ff.rd_addr);
        $display("         fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]);
        $display("         alu_data_bypass   = %h",alu_data_bypass);
        $display("         ----------------------");
        $display("         is_r_type_instr(cache_instr_ff.opcode) = %h",is_r_type_instr(cache_instr_ff.opcode));
        $display("         is_m_type_instr(cache_instr_ff.opcode) = %h",is_m_type_instr(cache_instr_ff.opcode));
        $display("         cache_instr_ff.rd_addr = %h",cache_instr_ff.rd_addr);
        $display("         fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]);
        $display("         cache_data_valid   = %h",cache_data_valid);
        $display("         cache_data_bypass  = %h",cache_data_bypass);
        $display("         ----------------------");
        $display("         ----------------------");
        $display("[BYPASSES SRC2]");
        $display("         is_r_type_instr(alu_instr_ff.opcode) = %h",is_r_type_instr(alu_instr_ff.opcode));
        $display("         alu_instr_ff.rd_addr = %h",alu_instr_ff.rd_addr);
        $display("         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]);
        $display("         alu_data_bypass   = %h",alu_data_bypass);
        $display("         ----------------------");
        $display("         is_r_type_instr(cache_instr_ff.opcode) = %h",is_r_type_instr(cache_instr_ff.opcode));
        $display("         is_m_type_instr(cache_instr_ff.opcode) = %h",is_m_type_instr(cache_instr_ff.opcode));
        $display("         cache_instr_ff.rd_addr = %h",cache_instr_ff.rd_addr);
        $display("         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]);
        $display("         cache_data_valid   = %h",cache_data_valid);
        $display("         cache_data_bypass  = %h",cache_data_bypass);
     `endif
    end
end
`endif

endmodule

