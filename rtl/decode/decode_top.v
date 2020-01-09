`include "soc.vh"

module decode_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    output  priv_mode_t                     priv_mode,
    input   logic                           iret_instr,

    // Stall pipeline
    input   logic                           stall_decode,
    input   logic                           flush_decode,
    input   logic                           flush_rob,

    // Exceptions from fetch
    input   fetch_xcpt_t                    xcpt_fetch_in,

    // Fetched instruction
    input   logic                           fetch_instr_valid,
    input   logic   [`INSTR_WIDTH-1:0]      fetch_instr_data,
    input   logic   [`PC_WIDTH_RANGE]       fetch_instr_pc, 

    // Instruction to ALU
    output  logic                           req_to_alu_valid,
    output  alu_request_t                   req_to_alu_info,
    output  logic   [`ROB_ID_RANGE]         req_to_alu_instr_id,
    output  logic   [`PC_WIDTH_RANGE]       req_to_alu_pc,
    output  fetch_xcpt_t                    alu_xcpt_fetch_out,
    output  decode_xcpt_t                   alu_decode_xcpt,

    // Instruction to MUL
    output  logic                           req_to_mul_valid,
    output  mul_request_t                   req_to_mul_info,
    output  logic   [`ROB_ID_RANGE]         req_to_mul_instr_id,
    output  logic   [`PC_WIDTH_RANGE]       req_to_mul_pc,
    output  fetch_xcpt_t                    mul_xcpt_fetch_out,
    output  decode_xcpt_t                   mul_decode_xcpt,

    // Write requests to the Register File
    input logic 				            writeEnRF,
    input logic [`REG_FILE_DATA_RANGE] 		writeValRF,
    input logic [`REG_FILE_ADDR_RANGE] 		destRF,
    input logic [`ROB_ID_RANGE]             write_idRF,
    
    // Exceptions values to be stored on the RF
    input logic 				            xcpt_valid,
    input logic [`PC_WIDTH_RANGE] 		    rmPC,
    input logic [`REG_FILE_XCPT_ADDR_RANGE] rmAddr,
    input   xcpt_type_t                     xcpt_type
);

// Decode fetch data
logic [`REG_FILE_ADDR_RANGE] rd_addr;
logic [`REG_FILE_ADDR_RANGE] ra_addr;
logic [`REG_FILE_ADDR_RANGE] rb_addr;
logic [`INSTR_OPCODE_RANGE]  opcode;
assign rd_addr = fetch_instr_data[`INSTR_DST_ADDR_RANGE];
assign opcode = fetch_instr_data[`INSTR_OPCODE_ADDR_RANGE];

assign ra_addr = fetch_instr_data[`INSTR_SRC1_ADDR_RANGE];
assign rb_addr = fetch_instr_data[`INSTR_SRC2_ADDR_RANGE];

// Compute if is mul instruction
logic   mul_instr;
assign  mul_instr = fetch_instr_valid & is_mul_instr(opcode);

/////////////////////////////////////////
// Exceptions
decode_xcpt_t   decode_xcpt_next;
decode_xcpt_t   decode_xcpt_ff;
fetch_xcpt_t    xcpt_fetch_ff;

//         CLK    RST                    EN            DOUT            DIN               DEF
`RST_EN_FF(clock, reset | flush_decode, !stall_decode, decode_xcpt_ff, decode_xcpt_next, '0)
`RST_EN_FF(clock, reset | flush_decode, !stall_decode, xcpt_fetch_ff,  xcpt_fetch_in,    '0)

assign alu_decode_xcpt      = (flush_decode) ? '0 : 
                              (mul_instr)    ? '0 :
                                               decode_xcpt_ff;

assign alu_xcpt_fetch_out   = (flush_decode) ? '0 : 
                              (mul_instr)    ? '0 :
                                               xcpt_fetch_ff;

assign mul_decode_xcpt      = (flush_decode)  ? '0 : 
                              (!mul_instr)    ? '0 :
                                                decode_xcpt_ff;

assign mul_xcpt_fetch_out   = (flush_decode)  ? '0 : 
                              (!mul_instr)    ? '0 :
                                               xcpt_fetch_ff;
                                           
/////////////////////////////////////////
// Control logic for requests to be sent to ALU
logic                   req_to_alu_valid_next;
logic                   req_to_alu_valid_ff;
alu_request_t           req_to_alu_info_next;
alu_request_t           req_to_alu_info_ff;
logic [`PC_WIDTH-1:0]   req_to_alu_pc_ff;

//      CLK    RST                   DOUT                 DIN                    DEF
`RST_FF(clock, reset | flush_decode, req_to_alu_valid_ff, req_to_alu_valid_next, '0)

//     CLK    EN             DOUT              DIN            
`EN_FF(clock, !stall_decode, req_to_alu_pc_ff, fetch_instr_pc)

//     CLK    EN             DOUT                DIN                  
`EN_FF(clock, !stall_decode, req_to_alu_info_ff, req_to_alu_info_next)
//`EN_FF(clock, !stall_decode | writeEnRF, req_to_alu_info_ff, req_to_alu_info_next)


assign req_to_alu_valid_next =  ( flush_decode      ) ? 1'b0       : // Invalidate instruction
                                ( stall_decode      ) ? 1'b0       :
                                ( fetch_instr_valid ) ? !mul_instr : // New instruction from fetch
                                                        1'b0;

assign req_to_alu_valid = (flush_decode) ? 1'b0 : req_to_alu_valid_ff;
assign req_to_alu_info  = req_to_alu_info_ff;
assign req_to_alu_pc    = req_to_alu_pc_ff;

/////////////////////////////////////////
// Control logic for requests to be sent to MUL
logic                   req_to_mul_valid_next;
logic                   req_to_mul_valid_ff;
mul_request_t           req_to_mul_info_next;
mul_request_t           req_to_mul_info_ff;
logic [`PC_WIDTH-1:0]   req_to_mul_pc_ff;

//      CLK    RST                   DOUT                 DIN                    DEF
`RST_FF(clock, reset | flush_decode, req_to_mul_valid_ff, req_to_mul_valid_next, '0)

//     CLK    EN            DOUT                DIN                  
`EN_FF(clock, !stall_decode, req_to_mul_pc_ff,   fetch_instr_pc      )

//     CLK    EN             DOUT                DIN                  
`EN_FF(clock, !stall_decode, req_to_mul_info_ff, req_to_mul_info_next)
//`EN_FF(clock, !stall_decode | writeEnRF, req_to_mul_info_ff, req_to_mul_info_next)


assign req_to_mul_valid_next =  ( flush_decode      ) ? 1'b0         : // Invalidate instruction
                                ( stall_decode      ) ? 1'b0         : // Stall the pipeline 
                                ( fetch_instr_valid ) ? mul_instr : // New instruction from fetch
                                                        1'b0;

assign req_to_mul_valid = (flush_decode) ? 1'b0 : req_to_mul_valid_ff;
assign req_to_mul_info  = req_to_mul_info_ff;
assign req_to_mul_pc    = req_to_mul_pc_ff;


/////////////////////////////////////////
// Register file signals      
logic [`REG_FILE_DATA_RANGE] rf_reg1_data; 
logic [`REG_FILE_DATA_RANGE] rf_reg2_data; 
logic [`REG_FILE_DATA_RANGE] rm0_data;
logic [`REG_FILE_DATA_RANGE] rm1_data;
logic [`REG_FILE_DATA_RANGE] rm2_data;

/////////////////////////////////////////
// Bypass control signals

logic stall_decode_ff;
//      CLK    RST                DOUT             DIN           DEF
`RST_FF(clock, reset | flush_rob, stall_decode_ff, stall_decode, '0)

// FF to store the instr. ID that blocks each register
logic [`REG_FILE_NUM_REGS_RANGE][`ROB_NUM_ENTRIES_W_RANGE] reg_rob_id_next;
logic [`REG_FILE_NUM_REGS_RANGE][`ROB_NUM_ENTRIES_W_RANGE] reg_rob_id_ff;

//     CLK    EN             DOUT           DIN   
`EN_FF(clock, !stall_decode, reg_rob_id_ff, (flush_decode_ff) ? reg_rob_id_next_2 : reg_rob_id_next)

// Valid bit for each register that is asserted if we are waiting for a instr.
// to finish before performing the operation
logic [`REG_FILE_NUM_REGS_RANGE] reg_blocked_valid_next;
logic [`REG_FILE_NUM_REGS_RANGE] reg_blocked_valid_ff;

//         CLK    RST                EN             DOUT                  DIN                                                                    DEF
`RST_EN_FF(clock, reset | flush_rob, !stall_decode, reg_blocked_valid_ff, (flush_decode_ff) ? reg_blocked_valid_next_2 : reg_blocked_valid_next, '0)

logic   [`ROB_ID_RANGE]         ticket_src1;    // instr. that is blocking src1
logic                           rob_blocks_src1;// Asserted if there is an instr. blocking src1
logic   [`ROB_ID_RANGE]         ticket_src2;    // instr. that is blocking src2
logic                           rob_blocks_src2;// Asserted if there is an instr. blocking src2

logic   [`ROB_NUM_ENTRIES_W_RANGE] reorder_buffer_tail_next;
logic   [`ROB_NUM_ENTRIES_W_RANGE] reorder_buffer_tail_ff;

//         CLK    RST                EN             DOUT                    DIN                       DEF
`RST_EN_FF(clock, reset | flush_rob, !stall_decode, reorder_buffer_tail_ff, reorder_buffer_tail_next, '0)

// Needed in case ALU forces to take a branch, so we have to restore the
// value we had, instead of taking into account the current instruction
logic [`REG_FILE_NUM_REGS_RANGE] reg_blocked_valid_ff_2;
logic [`REG_FILE_NUM_REGS_RANGE][`ROB_NUM_ENTRIES_W_RANGE] reg_rob_id_ff_2;

// Needed in case we receive a RF write request while restoring status
logic [`REG_FILE_NUM_REGS_RANGE] reg_blocked_valid_next_2;
logic [`REG_FILE_NUM_REGS_RANGE][`ROB_NUM_ENTRIES_W_RANGE] reg_rob_id_next_2;


//      CLK    RST                DOUT                      DIN                         DEF
`RST_FF(clock, reset | flush_rob, reg_blocked_valid_ff_2,   reg_blocked_valid_next_2,   '0)
`RST_FF(clock, reset | flush_rob, reg_rob_id_ff_2,          reg_rob_id_next_2,          '0)

logic flush_decode_ff;
//      CLK    RST                DOUT             DIN           DEF
`RST_FF(clock, reset | flush_rob, flush_decode_ff, flush_decode, '0)

///////////////////////
// Manage RoB tickets and blocker
always_comb
begin
   // Maintain values from 2 cycles ago for restore purposes
    reg_blocked_valid_next_2   = (flush_decode | flush_decode_ff) ? reg_blocked_valid_ff_2 : reg_blocked_valid_ff;
    reg_rob_id_next_2          = (flush_decode | flush_decode_ff) ? reg_rob_id_ff_2 : reg_rob_id_ff;

    // Mantain values from previous cycle by default
    reg_blocked_valid_next     = reg_blocked_valid_ff;
    reg_rob_id_next            = reg_rob_id_ff;
    reorder_buffer_tail_next   = reorder_buffer_tail_ff;

    rob_blocks_src1 = 1'b0;
    rob_blocks_src2 = 1'b0;

    // Send blocker information to ALU/MUL stages
    // Check if the instruction makes use of source1 register
    if (  is_r_type_instr(opcode) | is_mul_instr(opcode) 
        | is_m_type_instr(opcode) | is_branch_type_instr(opcode) 
        | is_tlb_instr(opcode))
    begin
        // Check if this register is protected because was the destination
        // of a previous instruction. If that is the case we also have to
        // check if the instruction being written this cycle corresponds
        // to the blocker instruction that was protecting the register.
        if (reg_blocked_valid_ff[ra_addr]) //check if this register is protected
        begin
            if(writeEnRF & (reg_rob_id_ff[ra_addr] == write_idRF))
                rob_blocks_src1 = 1'b0;
            else
                rob_blocks_src1 = 1'b1;
        end
       ticket_src1     = reg_rob_id_ff[ra_addr];
    end  
    // Check if the instruction makes use of source2 register
    if (  is_r_type_instr(opcode)| is_mul_instr(opcode) 
        | is_store_instr(opcode) | is_branch_type_instr(opcode) 
        | is_tlb_instr(opcode))
    begin
        if (is_store_instr(opcode))
        begin
            ticket_src2 = reg_rob_id_ff[rd_addr];
            if (reg_blocked_valid_ff[rd_addr]) //check if this register is protected
            begin
                // check if the value written to RF corresponds to the
                // blocker instr
                if(writeEnRF & (reg_rob_id_ff[rd_addr] == write_idRF))
                    rob_blocks_src2 = 1'b0;
                else
                    rob_blocks_src2 = 1'b1;
            end
        end
        else
        begin
            ticket_src2 = reg_rob_id_ff[rb_addr];
            if (  !is_addi_type_instr(opcode) 
                & reg_blocked_valid_ff[rb_addr]) //check if this register is protected
            begin
                // check if the value written to RF corresponds to the
                // blocker instr
                if(writeEnRF & (reg_rob_id_ff[rb_addr] == write_idRF))
                    rob_blocks_src2 = 1'b0;
                else
                    rob_blocks_src2 = 1'b1;
            end
        end
    end          
    
     
    if ( (req_to_alu_valid | req_to_mul_valid)
        | (!stall_decode & stall_decode_ff))
        reorder_buffer_tail_next = reorder_buffer_tail_ff + 1'b1;

    // Update blocker arrays if needed
    if (fetch_instr_valid)
    begin
        // Check if the instruction generates a result
        if (  is_r_type_instr(opcode) | is_mul_instr(opcode) 
            | is_load_instr(opcode) | is_mov_instr(opcode))
        begin
            reg_blocked_valid_next[rd_addr]  = 1'b1;
            reg_rob_id_next[rd_addr]         = reorder_buffer_tail_next;
        end
    end

    // Check if some register is going to be written and if
    // the identifier we have is the same as the one written
    if ( writeEnRF & (reg_rob_id_ff[destRF] == write_idRF))
    begin
        reg_blocked_valid_next[destRF] = 1'b0;
    end

    if ( writeEnRF & (reg_rob_id_ff_2[destRF] == write_idRF))
    begin
        reg_blocked_valid_next_2[destRF] = 1'b0;        
    end
end


/////////////////////////////////////////
// Decode data
logic [`REG_FILE_DATA_RANGE] ra_data;
logic [`REG_FILE_DATA_RANGE] rb_data;       
always_comb	
begin
    // Exception
    decode_xcpt_next.xcpt_illegal_instr = 1'b0;
    decode_xcpt_next.xcpt_pc = fetch_instr_pc;

    // Opcode and destination register are always decoded from the instruction
    // provided by the fetch stage
        // ALU
    req_to_alu_instr_id                  = reorder_buffer_tail_ff;
    req_to_alu_info_next.opcode          = opcode;
    req_to_alu_info_next.rd_addr         = rd_addr;
    req_to_alu_info_next.ra_addr         = ra_addr;
    req_to_alu_info_next.rb_addr         = rb_addr;  
    req_to_alu_info_next.ticket_src1     = ticket_src1;     
    req_to_alu_info_next.rob_blocks_src1 = rob_blocks_src1;  
    req_to_alu_info_next.ticket_src2     = ticket_src2;     
    req_to_alu_info_next.rob_blocks_src2 = rob_blocks_src2;  

        // MUL                                                                              
    req_to_mul_instr_id                  = reorder_buffer_tail_ff;
    req_to_mul_info_next.rd_addr         = rd_addr;
    req_to_mul_info_next.ra_addr         = ra_addr;
    req_to_mul_info_next.rb_addr         = rb_addr;
    req_to_mul_info_next.ticket_src1     = ticket_src1;     
    req_to_mul_info_next.rob_blocks_src1 = rob_blocks_src1;  
    req_to_mul_info_next.ticket_src2     = ticket_src2;     
    req_to_mul_info_next.rob_blocks_src2 = rob_blocks_src2; 

    // Register A value depends on the instructions being performed at the
    // mul,alu and cache stage at this cycle, because we may need to bypass data
    ra_data = (writeEnRF & (destRF == ra_addr)) ? writeValRF    : // intercept write to RF
	   		      				                  rf_reg1_data; // data from register file

    // Register B value depends on the instructions being performed at the
    // mul,alu and cache stage at this cycle, because we may need to bypass data
    if (is_store_instr(opcode) & reg_blocked_valid_ff[rd_addr])
    begin
        rb_data = (writeEnRF & (destRF == rd_addr)) ? writeValRF : // intercept write to RF
                                                      rf_reg2_data; // data from register file
    end
    else
        rb_data = (writeEnRF & (destRF == rb_addr)) ? writeValRF : // intercept write to RF
                                                      rf_reg2_data; // data from register file
     

                                                                                                         
    // Data for MUL and ALU
    req_to_alu_info_next.ra_data = ra_data;
    req_to_alu_info_next.rb_data = rb_data;
    req_to_mul_info_next.ra_data = ra_data;
    req_to_mul_info_next.rb_data = rb_data;
     
    // Encoding for ADDI and M-type instructions                                                                                                                     
    req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH,fetch_instr_data[14:0]);

    ////////////////////////////////////////////////
    // Decode instruction to determine RB or offset 
    
    // B-format
    if (  is_branch_type_instr(opcode) | is_jump_instr(opcode) | is_tlb_instr(opcode) )  
    begin
    
        if ( is_branch_type_instr(opcode))// BEQ,BNE, BLT, BGT, BLE, BGE CASE
        begin
            req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH, {fetch_instr_data[`INSTR_OFFSET_HI_ADDR_RANGE], 
                                                                  fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE]}); 
        end
        else if (is_jump_instr(opcode))  // JUMP CASE
        begin
            req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH, {fetch_instr_data[`INSTR_OFFSET_HI_ADDR_RANGE], 
                                                                  fetch_instr_data[`INSTR_OFFSET_M_ADDR_RANGE], 
                                                                  fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE]}); 
        end
        else //TLBWRITE
        begin
            req_to_alu_info_next.offset = `ZX(`ALU_OFFSET_WIDTH, fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE]);
            decode_xcpt_next.xcpt_illegal_instr = (priv_mode == User) ? fetch_instr_valid & !flush_decode : 1'b0;
        end
    end
    else
    begin
        // MOV
        if (is_mov_instr(opcode))
        begin
            // rm1 : @ fault
            req_to_alu_info_next.ra_data = rm1_data; 
            // rm0 : xcpt PC
            if (fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE] == 9'h001)
                req_to_alu_info_next.ra_data = rm0_data;
            // rm2 : xcpt type
            else if (fetch_instr_data[`INSTR_OFFSET_LO_ADDR_RANGE] == 9'h002)
                req_to_alu_info_next.ra_data = rm2_data;
        end
        // IRET
        else if (is_iret_instr(opcode))
        begin
             req_to_alu_info_next.ra_data = rm0_data;
        end

        // Raise an exception because the instruction is not supported
        else if (  !is_r_type_instr(opcode) & !is_mul_instr(opcode)
                 & !is_m_type_instr(opcode) & !is_nop_instr(opcode))
        begin
            decode_xcpt_next.xcpt_illegal_instr = fetch_instr_valid & !flush_decode;
        end
    end
end


////////////////////////////////
// Register File

logic [`REG_FILE_ADDR_RANGE]   src1_addr; 
logic [`REG_FILE_ADDR_RANGE]   src2_addr;
logic [`REG_FILE_ADDR_RANGE]   dest_addr;

assign src1_addr = fetch_instr_data[`INSTR_SRC1_ADDR_RANGE];

assign src2_addr = (  opcode == `INSTR_STB_OPCODE  
                    | opcode == `INSTR_STW_OPCODE) ? fetch_instr_data[`INSTR_DST_ADDR_RANGE]:
                                                     fetch_instr_data[`INSTR_SRC2_ADDR_RANGE];

assign dest_addr = destRF;

regFile 
registerFile
(
    // System signals
    .clock      ( clock         ),
    .reset      ( reset         ),

    // Internal register values
    .iret_instr ( iret_instr    ),
    .priv_mode  ( priv_mode     ),
    .rm0_data   ( rm0_data      ),
    .rm1_data   ( rm1_data      ),
    .rm2_data   ( rm2_data      ),

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
    .rmAddr     ( rmAddr        ),
    .xcpt_type  ( xcpt_type     )
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
        $display("         fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]);
        $display("         ----------------------");
        $display("         fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC1_ADDR_RANGE]);
        $display("         ----------------------");
        $display("         ----------------------");
        $display("[BYPASSES SRC2]");
        $display("         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]);
        $display("         ----------------------");
        $display("         fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]= %h",fetch_instr_data[`INSTR_SRC2_ADDR_RANGE]);
     `endif
    end
end
`endif

endmodule

