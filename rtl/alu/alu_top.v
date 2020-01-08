`include "soc.vh"
module alu_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Control signals with RoB
    input   logic [`ROB_NUM_ENTRIES_W_RANGE] rob_tail,
    output  logic                            cache_stage_free,

    // Stall pipeline
    input   logic                           flush_alu,
    input   logic                           dcache_ready,
    output  logic                           stall_decode,

    // Exceptions
    input   fetch_xcpt_t                    xcpt_fetch_in,
    input   decode_xcpt_t                   xcpt_decode_in,
    
    // Request from decode stage
    input   logic                           req_alu_valid,  
    input   alu_request_t                   req_alu_info,  
    input   logic [`ROB_ID_RANGE]           req_alu_instr_id,
    input   logic [`PC_WIDTH-1:0]           req_alu_pc,
   
    // Request to dcache stage 
    output  logic                           req_dcache_valid,
    output  dcache_request_t                req_dcache_info,
    
    // Request to WB stage
    output  logic                           req_wb_valid,
    output  writeback_request_t             req_wb_info,
    output  logic                           req_wb_mem_blocked,
    output  dcache_request_t                req_wb_dcache_info,

    // Branch signals to fetch stage
    output  logic [`PC_WIDTH-1:0]           branch_pc,
    output  logic                           take_branch,
    output  logic                           iret_instr,

    // Bypasses
        // Reorder buffer
    output  logic [`ROB_ID_RANGE]           rob_src1_id,
    output  logic [`ROB_ID_RANGE]           rob_src2_id,
    input   logic                           rob_src1_hit,
    input   logic                           rob_src2_hit,
    input   logic [`REG_FILE_DATA_RANGE]    rob_src1_data,
    input   logic [`REG_FILE_DATA_RANGE]    rob_src2_data
);
//////////////////////////////////////
// Stall
logic stall_decode_ff;
//      CLK    RST                DOUT             DIN            DEF
`RST_FF(clock, reset | flush_alu, stall_decode_ff, stall_decode, 1'b0)

//////////////////////////////////////
// Exceptions
alu_xcpt_t      xcpt_alu;

logic fetch_xcpt_valid;
assign fetch_xcpt_valid = req_alu_valid &  
                         ( xcpt_fetch_in.xcpt_itlb_miss
                         | xcpt_fetch_in.xcpt_bus_error 
                         | xcpt_fetch_in.xcpt_addr_val); 

logic decode_xcpt_valid;
assign decode_xcpt_valid =  req_alu_valid
                          & xcpt_decode_in.xcpt_illegal_instr;



////////////////////////////////////
// Request to D$ stage or WB stage
    
// Cache will not receive a request next cycle from ALU because the request is
assign cache_stage_free = req_wb_valid | !req_alu_valid;

logic            req_dcache_valid_next;
logic            req_dcache_valid_ff;
logic            req_wb_mem_blocked_next;
logic            req_wb_mem_blocked_ff;

dcache_request_t req_dcache_info_next;
dcache_request_t req_dcache_info_ff;


//  CLK    DOUT                 DIN
`FF(clock, req_dcache_info_ff,  req_dcache_info_next)

//      CLK    RST                DOUT                    DIN                      DEF
`RST_FF(clock, reset | flush_alu, req_dcache_valid_ff,   req_dcache_valid_next,   1'b0)
`RST_FF(clock, reset | flush_alu, req_wb_mem_blocked_ff, req_wb_mem_blocked_next, 1'b0)

// Request to WB stage in case ST/LD is not the oldest instr or dcache is not
// ready
logic wb_mem_blocked_type;
assign wb_mem_blocked_type =   is_m_type_instr(req_alu_info.opcode) 
                             & ((rob_tail != req_alu_instr_id) | !dcache_ready );

assign req_wb_mem_blocked_next = (flush_alu)       ? 1'b0 :
                                 (stall_decode)    ? 1'b0 : 
                                 (stall_decode_ff) ? wb_mem_blocked_type : // was blocked waiting for reg value
                                                     req_alu_valid & wb_mem_blocked_type;

assign req_wb_mem_blocked = req_wb_mem_blocked_ff;

assign req_wb_dcache_info = req_dcache_info_ff;
                                                  
// Request to D$ stage in case ST/LD is the oldest instr on the pipe                                                  
logic dcache_mem_type;
assign dcache_mem_type =   is_m_type_instr(req_alu_info.opcode)
                         & dcache_ready
                         & (rob_tail == req_alu_instr_id);

assign req_dcache_valid_next = ( flush_alu           )    ? 1'b0 :     
                               ( stall_decode        ) ? 1'b0 : 
                               (  stall_decode_ff    ) ? dcache_mem_type : // was blocked waiting for reg value
                               (  fetch_xcpt_valid
                                | decode_xcpt_valid  ) ? 1'b0 :
                                                         req_alu_valid & dcache_mem_type;

assign req_dcache_valid = req_dcache_valid_ff;

assign req_dcache_info  = req_dcache_info_ff;


////////////////////////////////////
// Request to WB

logic alu_to_wb_intr;

assign alu_to_wb_intr = (  is_r_type_instr(req_alu_info.opcode) 
                         | is_mov_instr(req_alu_info.opcode) 
                         | is_branch_type_instr(req_alu_info.opcode) 
                         | is_jump_instr(req_alu_info.opcode) 
                         | is_iret_instr(req_alu_info.opcode) 
                         | is_tlb_instr(req_alu_info.opcode));

// TLB write request
logic           tlb_req_valid_next;
logic           tlb_id_next;
tlb_req_info_t  tlb_req_info_next;

logic               req_wb_valid_next;
logic               req_wb_valid_ff;
writeback_request_t req_wb_info_next;
writeback_request_t req_wb_info_ff;

//     CLK    EN           DOUT             DIN

//      CLK    RST                DOUT             DIN                DEF
`RST_FF(clock, reset | flush_alu, req_wb_valid_ff, req_wb_valid_next, 1'b0)
`RST_FF(clock, reset | flush_alu, req_wb_info_ff,  req_wb_info_next,  '0)

assign req_wb_valid_next = ( flush_alu              ) ? 1'b0 :
                           ( stall_decode           ) ? 1'b0 :
                           (  stall_decode_ff       ) ? alu_to_wb_intr : // was blocked waiting for reg value
                           (  fetch_xcpt_valid
                            | decode_xcpt_valid     ) ? 1'b1 : 
                                                        req_alu_valid & alu_to_wb_intr;

assign req_wb_valid = req_wb_valid_ff;

// xcpt must be 0
assign req_wb_info  = req_wb_info_ff;

logic   [`REG_FILE_DATA_RANGE]  rf_data;

always_comb
begin  
    req_wb_info_next.instr_id    = req_alu_instr_id;
    req_wb_info_next.pc          = req_alu_pc;

    req_wb_info_next.tlbwrite     = tlb_req_valid_next;  
    req_wb_info_next.tlb_id       = tlb_id_next; 
    req_wb_info_next.tlb_req_info = tlb_req_info_next;
                                
    req_wb_info_next.rf_wen       =   is_r_type_instr(req_alu_info.opcode) 
                                    | is_mov_instr(req_alu_info.opcode);
    req_wb_info_next.rf_dest      = req_alu_info.rd_addr;
    req_wb_info_next.rf_data      = rf_data;
                      
    req_wb_info_next.xcpt_fetch   = xcpt_fetch_in ;
    req_wb_info_next.xcpt_decode  = xcpt_decode_in;
    req_wb_info_next.xcpt_alu     = xcpt_alu;
    req_wb_info_next.xcpt_mul     = '0;
    req_wb_info_next.xcpt_cache   = '0;
end

////////////////////////////////////
// Branch signals
logic [`PC_WIDTH-1:0]   branch_pc_next;
logic			 	    take_branch_next;
logic                   iret_instr_next;

//      CLK    RST    DOUT         DIN               DEF
`RST_FF(clock, reset, take_branch, take_branch_next, 1'b0)
`RST_FF(clock, reset, iret_instr,  iret_instr_next, 1'b0)

//  CLK    DOUT       DIN
`FF(clock, branch_pc, branch_pc_next)

////////////////////////////////////
// Perform ALU instruction

logic   [`REG_FILE_DATA_RANGE]  ra_data;
logic   [`REG_FILE_DATA_RANGE]  rb_data;

// Overflow signal
logic [`ALU_OVW_DATA_RANGE] oper_data;
logic [`ALU_OVW_DATA_RANGE] oper_data_2;

// Bypass signals from RoB
logic rob_blocks_src1;
logic rob_blocks_src2;

logic rob_src1_found_next;
logic rob_src1_found_ff;
logic rob_src2_found_next;
logic rob_src2_found_ff;

logic   [`REG_FILE_DATA_RANGE]  rob_src1_data_ff;
logic   [`REG_FILE_DATA_RANGE]  rob_src2_data_ff;

//      CLK    RST                DOUT               DIN                  DEF
`RST_FF(clock, reset | flush_alu, rob_src1_found_ff, rob_src1_found_next, 1'b0)
`RST_FF(clock, reset | flush_alu, rob_src2_found_ff, rob_src2_found_next, 1'b0)

//     CLK    EN            DIN               DOUT
`EN_FF(clock, rob_src1_hit, rob_src1_data_ff, rob_src1_data)
`EN_FF(clock, rob_src2_hit, rob_src2_data_ff, rob_src2_data)

always_comb
begin
    // Bypass values from RoB
    rob_src1_id = req_alu_info.ticket_src1;
    rob_src2_id = req_alu_info.ticket_src2;
 
    rob_blocks_src1  = req_alu_info.rob_blocks_src1;
    rob_blocks_src2  = req_alu_info.rob_blocks_src2;

    rob_src1_found_next = rob_src1_found_ff;
    rob_src2_found_next = rob_src2_found_ff;

    stall_decode    = stall_decode_ff;

    if ( stall_decode_ff )
    begin
        // Check if there is a hit on this cycle and store the hit, only if we
        // did not hit last cycle
        if (!rob_src1_found_ff)
            rob_src1_found_next = rob_src1_hit;

        if (!rob_src2_found_ff)
            rob_src2_found_next = rob_src2_hit;
    
        // Check if we can unblock decode stage
        if (rob_blocks_src1 & rob_blocks_src2)
        begin
            stall_decode =!(  (rob_src1_found_ff | rob_src1_hit)
                            & (rob_src2_found_ff | rob_src2_hit));
        end
        else if ( rob_blocks_src1 )
        begin
            stall_decode = !(rob_src1_found_ff | rob_src1_hit);
        end
        else // if ( rob_blocks_src2 )
        begin
            stall_decode = !(rob_src2_found_ff | rob_src2_hit);
        end
    end // stall_decode_ff
    else
    begin   
        rob_src1_found_next = rob_src1_hit;
        rob_src2_found_next = rob_src2_hit;
        stall_decode     = ( fetch_xcpt_valid | decode_xcpt_valid ) ? 1'b0 : 
                           ( !req_alu_valid ) ? 1'b0 :  
                                               //  take_branch_next |
                                                 (rob_blocks_src1 & !rob_src1_hit)
                                               | (rob_blocks_src2 & !rob_src2_hit);

                                                /*
                                                 |                           
                                               (  rob_blocks_src1  & !rob_src1_hit
                                                &(req_alu_info.ticket_src1 != req_alu_instr_id)) 
                                              |(  rob_blocks_src2 & !rob_src2_hit
                                                &(req_alu_info.ticket_src2 != req_alu_instr_id));

                                                */
    end
end

always_comb
begin
    rf_data = '0;

    // Branch
	take_branch_next    = 1'b0;
    iret_instr_next     = 1'b0;
    branch_pc_next      = '0;

    // Dcache request
    req_dcache_info_next = '0;
    req_dcache_info_next.pc          = req_alu_pc;
    req_dcache_info_next.instr_id    = req_alu_instr_id;
    req_dcache_info_next.rd_addr     = req_alu_info.rd_addr;
    req_dcache_info_next.xcpt_fetch  = xcpt_fetch_in;
    req_dcache_info_next.xcpt_decode = xcpt_decode_in;

    // Exception
    xcpt_alu.xcpt_overflow = 1'b0 ;
    xcpt_alu.xcpt_pc       = req_alu_pc;

    /*
    ra_data = (  rob_blocks_src1
               & (req_alu_info.ticket_src1 != req_alu_instr_id)) ? (rob_src1_hit) ? rob_src1_data    : 
                                                                                    rob_src1_data_ff :
                                                                    req_alu_info.ra_data;


    rb_data = (   rob_blocks_src2
               & (req_alu_info.ticket_src2 != req_alu_instr_id)) ? (rob_src2_hit) ? rob_src2_data    : 
                                                                                    rob_src2_data_ff :
                                                                   req_alu_info.rb_data;
    */
    ra_data = ( rob_blocks_src1 ) ? (rob_src1_hit) ? rob_src1_data    : 
                                                     rob_src1_data_ff :
                                     req_alu_info.ra_data;


    rb_data = ( rob_blocks_src2 ) ? (rob_src2_hit) ? rob_src2_data    : 
                                                     rob_src2_data_ff :
                                    req_alu_info.rb_data;

    // TLB
    tlb_req_valid_next  = 1'b0;

    // ADD
	if (req_alu_info.opcode == `INSTR_ADD_OPCODE)
	begin
        oper_data =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) + `ZX(`ALU_OVW_DATA_WIDTH,rb_data);
        rf_data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0);
    end
    // SUB
	else if (req_alu_info.opcode == `INSTR_SUB_OPCODE)
    begin
        rf_data = ra_data - rb_data;        
    end
    //ADDI
    else if (req_alu_info.opcode == `INSTR_ADDI_OPCODE)
    begin
        oper_data =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) + `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.offset);
        rf_data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0);
    end
    //SLL
    else if (req_alu_info.opcode == `INSTR_SLL_OPCODE)
    begin
        oper_data =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) << `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.offset);
        rf_data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0);
    end
    //SRL
    else if (req_alu_info.opcode == `INSTR_SRL_OPCODE)
    begin
        oper_data =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) >> `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.offset);
        rf_data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0);
    end
    // MEM
	else if (is_m_type_instr(req_alu_info.opcode)) 
    begin
        //LD
        if (is_load_instr(req_alu_info.opcode))
        begin
            oper_data = `ZX(`ALU_OVW_DATA_WIDTH,ra_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) ;
        end
        //ST
        else
        begin
            oper_data = `ZX(`ALU_OVW_DATA_WIDTH,rb_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) ;
        end

        // Used only on store requests
		oper_data_2 = `ZX(`ALU_OVW_DATA_WIDTH,ra_data);
        
        // Specify LD or ST for dcache request
        if (is_load_instr(req_alu_info.opcode))
            req_dcache_info_next.is_store = 1'b0;
        else
            req_dcache_info_next.is_store = 1'b1;

        // Specify size for dcache request
        if (req_alu_info.opcode == `INSTR_LDB_OPCODE | req_alu_info.opcode == `INSTR_STB_OPCODE)
            req_dcache_info_next.size = Byte;
        else
            req_dcache_info_next.size = Word;

        // Check possible overflow
        req_dcache_info_next.addr   =  oper_data[`REG_FILE_DATA_RANGE];
        req_dcache_info_next.data   =  oper_data_2[`REG_FILE_DATA_RANGE];
        xcpt_alu.xcpt_overflow =   (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0)
                                      | (oper_data_2[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0);
    end	
    // BEQ
	else if (req_alu_info.opcode == `INSTR_BEQ_OPCODE) 
	begin
        if (ra_data == rb_data)
        begin
            branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		    take_branch_next = req_alu_valid;
        end
	end
    // BNE
	else if (req_alu_info.opcode == `INSTR_BNE_OPCODE) 
	begin
        if (ra_data != rb_data)
        begin
            branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		    take_branch_next = req_alu_valid;
        end
	end
    // BLT
	else if (req_alu_info.opcode == `INSTR_BLT_OPCODE) 
	begin
        if (ra_data < rb_data)
        begin
            branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		    take_branch_next = req_alu_valid;
        end
	end
    // BGT
	else if (req_alu_info.opcode == `INSTR_BGT_OPCODE) 
	begin
        if (ra_data > rb_data)
        begin
            branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		    take_branch_next = req_alu_valid;
        end
	end
    // BLE
	else if (req_alu_info.opcode == `INSTR_BLE_OPCODE) 
	begin
        if (ra_data <= rb_data)
        begin
            branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		    take_branch_next = req_alu_valid;
        end
	end
    // BGE
	else if (req_alu_info.opcode == `INSTR_BGE_OPCODE) 
	begin
        if (ra_data >= rb_data)
        begin
            branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		    take_branch_next = req_alu_valid;
        end
	end
    // JUMP
    else if (req_alu_info.opcode == `INSTR_JUMP_OPCODE) 
	begin
		branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
		take_branch_next = req_alu_valid;
	end

    // MOV
    else if (is_mov_instr(req_alu_info.opcode)) 
    begin
        rf_data = req_alu_info.ra_data;          
    end
    // TLBWRITE
	else if (is_tlb_instr(req_alu_info.opcode)) 
    begin
        tlb_req_valid_next           = req_alu_valid;
        tlb_id_next                  = req_alu_info.offset[0];
        tlb_req_info_next.virt_addr  = ra_data;
        tlb_req_info_next.phy_addr   = rb_data;
        tlb_req_info_next.writePriv  = 1'b1;            
    end
    // IRET
	else if (is_iret_instr(req_alu_info.opcode)) 
    begin
        branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.ra_data);
		take_branch_next = req_alu_valid;
        iret_instr_next  = req_alu_valid;
    end
    req_dcache_info_next.xcpt_alu    = xcpt_alu;   
end

/////////////////////////////////
// VERBOSE
`ifdef VERBOSE_ALU
always_ff @(posedge clock)
begin
    if (req_dcache_valid)
    begin
        $display("[ALU] Request to Cache. PC = %h",req_dcache_info.pc);
        $display("      addr             =  %h",req_dcache_info.addr);      
        $display("      size             =  %h",req_dcache_info.size) ;     
        $display("      is_store         =  %h",req_dcache_info.is_store);
        $display("      data             =  %h",req_dcache_info.data)  ;    
    end

    if (take_branch)
    begin
        $display("[ALU] Take branch. Current PC = %h",req_dcache_info.pc);
        $display("      Jump to  =  %h",branch_pc); 
    end
end
`endif
endmodule
