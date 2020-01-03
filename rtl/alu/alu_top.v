`include "soc.vh"
module alu_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Stall pipeline
    input   logic                           stall_alu,
    output  logic                           alu_busy,
    input   logic                           flush_alu,

    // Exceptions
    input   fetch_xcpt_t                    xcpt_fetch_in,
    output  fetch_xcpt_t                    xcpt_fetch_out,
    input   decode_xcpt_t                   xcpt_decode_in,
    output  decode_xcpt_t                   xcpt_decode_out,
    output  alu_xcpt_t                      xcpt_alu_out,
    
    // Request from decode stage
    input   logic                           req_alu_valid,  
    input   alu_request_t                   req_alu_info,  
    input   logic [`PC_WIDTH-1:0]           req_alu_pc,
   
    // Request to dcache stage 
    output  logic [`PC_WIDTH-1:0]           req_dcache_pc,
    output  dcache_request_t                req_dcache_info,
    output  logic                           req_dcache_valid,
    
    // Depending on the opcode the D$ will perform the operation or
    // will just flop the req to send it to WB stage to perform RF write
    // and/or retire the instruction
    output  logic                           req_m_type_instr,
    output  logic                           req_r_type_instr,
    output  logic  [`REG_FILE_ADDR_RANGE]   req_dst_reg, 

    // Branch signals to fetch stage
    output  logic [`PC_WIDTH-1:0]           branch_pc,
    output  logic                           take_branch,
    output  logic                           iret_instr,
 
    //Bypass
    output  logic [`REG_FILE_DATA_RANGE]    alu_data_bypass,
    output  logic                           alu_data_valid,
    input   logic [`REG_FILE_DATA_RANGE]    cache_data_bypass,
    input   logic                           cache_data_bp_valid,

    // Write requests to the Register File
    input logic [`REG_FILE_DATA_RANGE] 		writeValRF,
    input logic 				            writeEnRF,
    input logic [`REG_FILE_ADDR_RANGE] 		destRF,

    // Request to cache stage to propagate TLB write request
    output  logic                           tlb_req_valid,
    output  logic                           tlb_id,
    output  tlb_req_info_t                  tlb_req_info
);

logic alu_hazard;

logic   alu_busy_next;
assign alu_hazard = stall_alu | alu_busy; 

//////////////////////////////////////
// TLB write request
logic           tlb_req_valid_next;
logic           tlb_id_next;
tlb_req_info_t  tlb_req_info_next;

logic           tlb_req_valid_ff;
logic           tlb_id_ff; 
tlb_req_info_t  tlb_req_info_ff; 

//         CLK    RST                EN                                 DOUT              DIN                 DEF
`RST_EN_FF(clock, reset | flush_alu, !alu_hazard | cache_data_bp_valid, tlb_req_valid_ff, tlb_req_valid_next, '0)

//     CLK    EN                                 DOUT               DIN 
`EN_FF(clock, !alu_hazard | cache_data_bp_valid, tlb_id_ff,         tlb_id_next)
`EN_FF(clock, !alu_hazard | cache_data_bp_valid, tlb_req_info_ff,   tlb_req_info_next)

assign tlb_req_valid = (alu_hazard) ? tlb_req_valid : tlb_req_valid_ff;
assign tlb_id        = (alu_hazard) ? tlb_id        : tlb_id_ff;
assign tlb_req_info  = (alu_hazard) ? tlb_req_info  : tlb_req_info_ff;

//////////////////////////////////////
// Exceptions
fetch_xcpt_t    xcpt_fetch_ff;
decode_xcpt_t   xcpt_decode_ff;
alu_xcpt_t      xcpt_alu_ff;
alu_xcpt_t      xcpt_alu_next;

//         CLK    RST                EN                                 DOUT             DIN             DEF
`RST_EN_FF(clock, reset | flush_alu, !alu_hazard,                       xcpt_decode_ff,  xcpt_decode_in, '0)
`RST_EN_FF(clock, reset | flush_alu, !alu_hazard,                       xcpt_fetch_ff,   xcpt_fetch_in,  '0)
`RST_EN_FF(clock, reset | flush_alu, !alu_hazard | cache_data_bp_valid, xcpt_alu_ff,     xcpt_alu_next,  '0)

assign xcpt_decode_out  = (alu_hazard) ? xcpt_decode_out : 
                          (flush_alu ) ? '0              :
                                        xcpt_decode_ff;

assign xcpt_fetch_out   = (alu_hazard) ? xcpt_fetch_out  : 
                          (flush_alu ) ? '0              :
                                         xcpt_fetch_ff;

assign xcpt_alu_out     = (alu_hazard) ? xcpt_alu_out    : 
                          (flush_alu ) ? '0              :
                                         xcpt_alu_ff;

////////////////////////////////////
// Request to D$ stage

logic            req_dcache_valid_next;
logic            req_dcache_valid_ff;
dcache_request_t req_dcache_info_next;
dcache_request_t req_dcache_info_ff;

logic  req_m_type_instr_next;
logic  req_m_type_instr_ff;
logic  req_r_type_instr_next;
logic  req_r_type_instr_ff;

logic [`PC_WIDTH-1:0]           req_dcache_pc_ff;
logic [`REG_FILE_ADDR_RANGE]    req_dst_reg_ff;


// Compute if request to be sent to the D$ has to access memory or not
assign  req_m_type_instr_next = (is_m_type_instr(req_alu_info.opcode)) ? 1'b1 : 1'b0;

assign  req_r_type_instr_next = (is_r_type_instr(req_alu_info.opcode)) ? 1'b1 : // R-type 
                                (!alu_busy_next & alu_busy)            ? 1'b1 : // MUL
                                is_mov_instr(req_alu_info.opcode)      ? 1'b1 : // MOV
                                                                         1'b0 ; // M-type or B-type

//     CLK    EN                                  DOUT                 DIN
`EN_FF(clock, !alu_hazard | cache_data_bp_valid,  req_dcache_info_ff,  req_dcache_info_next)
`EN_FF(clock, !alu_hazard,                        req_m_type_instr_ff, req_m_type_instr_next)
`EN_FF(clock, !alu_hazard,                        req_r_type_instr_ff, req_r_type_instr_next)
`EN_FF(clock, !alu_hazard,                        req_dst_reg_ff,      req_alu_info.rd_addr)
`EN_FF(clock, !alu_hazard,                        req_dcache_pc_ff,    req_alu_pc)

//         CLK    RST    EN                       DOUT                 DIN                    DEF
`RST_EN_FF(clock, reset, !alu_hazard | flush_alu, req_dcache_valid_ff, req_dcache_valid_next, 1'b0)

assign req_dcache_valid_next = (flush_alu) ? 1'b0 : 
                                             req_alu_valid;

assign req_dcache_valid = (alu_hazard | flush_alu) ? 1'b0 : 
                                                     req_dcache_valid_ff;

assign req_dcache_info  = (alu_hazard | flush_alu) ? req_dcache_info  : req_dcache_info_ff;
assign req_m_type_instr = (alu_hazard | flush_alu) ? req_m_type_instr : req_m_type_instr_ff;
assign req_r_type_instr = (alu_hazard | flush_alu) ? req_r_type_instr : req_r_type_instr_ff;
assign req_dst_reg      = (alu_hazard | flush_alu) ? req_dst_reg      : req_dst_reg_ff;
assign req_dcache_pc    = (alu_hazard | flush_alu) ? req_dcache_pc    : req_dcache_pc_ff;

////////////////////////////////////
// ALU is busy when we perform MUL operation

//         CLK   RST    EN          DOUT      DIN            DEF
`RST_EN_FF(clock,reset, !stall_alu, alu_busy, alu_busy_next, 1'b0)

////////////////////////////////////
// Branch signals
logic [`PC_WIDTH-1:0]   branch_pc_next;
logic			 	    take_branch_next;
logic                   iret_instr_next;

//         CLK    RST    EN           DOUT         DIN               DEF
`RST_EN_FF(clock, reset, !alu_hazard, take_branch, take_branch_next, 1'b0)
`RST_EN_FF(clock, reset, !alu_hazard, iret_instr,  iret_instr_next, 1'b0)

//     CLK    EN           DOUT       DIN
`EN_FF(clock, !alu_hazard, branch_pc, branch_pc_next)


////////////////////////////////////
// Bypass data

assign alu_data_bypass = (alu_hazard) ? alu_data_bypass : 
                                        req_dcache_info_next.data;

assign alu_data_valid  = (flush_alu ) ? 1'b0            :
                         (alu_hazard) ? alu_data_valid  : 
                                        req_alu_valid   ;

logic cache_req_is_load;
//         CLK    RST    EN           DOUT               DIN                                 DEF
`RST_EN_FF(clock, reset, !alu_hazard, cache_req_is_load, is_load_instr(req_alu_info.opcode), 1'b0)


////////////////////////////////////
// Perform ALU instruction

logic   [`REG_FILE_DATA_RANGE]  ra_data;
logic   [`REG_FILE_DATA_RANGE]  rb_data;

// Overflow signal
logic [`ALU_OVW_DATA_RANGE] oper_data;
logic [`ALU_OVW_DATA_RANGE] oper_data_2;

always_comb
begin
    // Branch
	take_branch_next    = 1'b0;
    iret_instr_next     = 1'b0;
    branch_pc_next      = '0;

    // Dcache request
    req_dcache_info_next = '0;

    // Exception
    xcpt_alu_next.xcpt_overflow = 1'b0 ;
    xcpt_alu_next.xcpt_pc       = req_alu_pc;

    // Bypass
    ra_data = ((req_dst_reg == req_alu_info.ra_addr) & cache_data_bp_valid ) ? cache_data_bypass : 
              ((destRF      == req_alu_info.ra_addr) & writeEnRF           ) ? writeValRF        : // intercept write to RF
                                                                               req_alu_info.ra_data;

    rb_data = ((req_dst_reg == req_alu_info.rb_addr) & cache_data_bp_valid ) ? cache_data_bypass : 
              ((destRF      == req_alu_info.rb_addr) & writeEnRF           ) ? writeValRF        : // intercept write to RF
                                                                               req_alu_info.rb_data;
            
    // TLB
    tlb_req_valid_next  = 1'b0;

    // ADD
	if (req_alu_info.opcode == `INSTR_ADD_OPCODE)
	begin
        oper_data                   =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) + `ZX(`ALU_OVW_DATA_WIDTH,rb_data);
        req_dcache_info_next.data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu_next.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0) & (req_alu_valid | req_dcache_valid_ff);
    end
    // SUB
	else if (req_alu_info.opcode == `INSTR_SUB_OPCODE)
    begin
        req_dcache_info_next.data  = ra_data - rb_data;        
    end
    // MUL
    else if (req_alu_info.opcode == `INSTR_MUL_OPCODE)
    begin
        oper_data                   =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) * `ZX(`ALU_OVW_DATA_WIDTH,rb_data);
        req_dcache_info_next.data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu_next.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0) & (req_alu_valid | req_dcache_valid_ff);
    end
    //ADDI
    else if (req_alu_info.opcode == `INSTR_ADDI_OPCODE)
    begin
        oper_data                   =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) + `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.offset);
        req_dcache_info_next.data   =  oper_data[`REG_FILE_DATA_RANGE];
        xcpt_alu_next.xcpt_overflow = (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0) & (req_alu_valid | req_dcache_valid_ff);
    end
    // MEM
	else if (is_m_type_instr(req_alu_info.opcode)) 
    begin
        //LD
        if (is_load_instr(req_alu_info.opcode))
            oper_data = (  (req_dst_reg == req_alu_info.ra_addr)
                         & cache_data_bp_valid                ) ? `ZX(`ALU_OVW_DATA_WIDTH,cache_data_bypass    + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) : // Bypass Cache to Cache_next
                        (  writeEnRF 
                         & (destRF == req_alu_info.ra_addr))    ? `ZX(`ALU_OVW_DATA_WIDTH,writeValRF + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) : // intercept write to RF
                                                                  `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.ra_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) ;
        //ST
        else
            oper_data = (  cache_data_bp_valid 
                         & (req_dst_reg == req_alu_info.rd_addr)) ? `ZX(`ALU_OVW_DATA_WIDTH,cache_data_bypass    + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) : // Bypass Cache to Cache_next
                        (  writeEnRF 
                         & (destRF == req_alu_info.rd_addr))      ? `ZX(`ALU_OVW_DATA_WIDTH,writeValRF + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) : // intercept write to RF
                                                                    `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.rb_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset)) ;

        // Used only on store requests
		oper_data_2 = (  cache_req_is_load & cache_data_bp_valid
                       & (req_dst_reg == req_alu_info.ra_addr)  ) ? `ZX(`ALU_OVW_DATA_WIDTH,cache_data_bypass) : // Bypass Cache to Cache_next
                      (  writeEnRF 
                       & (destRF == req_alu_info.ra_addr))        ? writeValRF : // intercept write to RF
                                                                    `ZX(`ALU_OVW_DATA_WIDTH,req_alu_info.ra_data);
        
        // Specify LD or ST for dcache request
        if (req_alu_info.opcode == `INSTR_LDB_OPCODE | req_alu_info.opcode == `INSTR_LDW_OPCODE)
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
        xcpt_alu_next.xcpt_overflow =   (oper_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0)
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
        req_dcache_info_next.data  = req_alu_info.ra_data;          
    end
    // TLBWRITE
	else if (req_alu_info.opcode == `INSTR_TLBWRITE_OPCODE) 
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
end

////////////////////////////////////
// Perform MUL
logic [`ALU_MUL_LATENCY_RANGE] mul_count_next;
logic [`ALU_MUL_LATENCY_RANGE] mul_count;

//         CLK    RST                EN          DOUT       DIN             DEF
`RST_EN_FF(clock, reset | flush_alu, !stall_alu, mul_count, mul_count_next, '0)

always_comb
begin
    alu_busy_next   = alu_busy;
    mul_count_next  = mul_count;

    // If we receive a MUL request we are going to put ALU in busy stage to
    // stall the pipeline and we start increasing the counter
    if ( !alu_busy )
    begin
        if(!stall_alu & (req_alu_info.opcode == `INSTR_MUL_OPCODE & req_alu_valid))
        begin
            alu_busy_next  = 1'b1;
            mul_count_next = mul_count + 1'b1;
        end
    end //!alu_busy 
    else
    // We increase the counter until we reach the fixed latency for MUL
    // instructions
    begin
        mul_count_next = mul_count + 1'b1;
        if (!stall_alu & (mul_count_next == `ALU_MUL_LATENCY))
        begin
            alu_busy_next = 1'b0;
            mul_count_next  = '0;
        end
    end //alu_busy 
end

`ifdef VERBOSE_ALU
always_ff @(posedge clock)
begin
    if (req_dcache_valid)
    begin
        $display("[ALU] Request to Cache. PC = %h",req_dcache_pc);
        $display("      addr             =  %h",req_dcache_info.addr);      
        $display("      size             =  %h",req_dcache_info.size) ;     
        $display("      is_store         =  %h",req_dcache_info.is_store);
        $display("      data             =  %h",req_dcache_info.data)  ;    
        $display("      req_m_type_instr =  %h",req_m_type_instr);
        $display("      req_r_type_instr =  %h",req_r_type_instr);
        $display("      req_dst_reg      =  %h",req_dst_reg );
    end

    if (take_branch)
    begin
        $display("[ALU] Take branch. Current PC = %h",req_dcache_pc);
        $display("      Jump to  =  %h",branch_pc); 
    end
end
`endif
endmodule
