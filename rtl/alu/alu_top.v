`include "soc.vh"
module alu_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Stall pipeline
    input   logic                           stall_alu,
    output  logic                           alu_busy,

    // Exceptions
    input   fetch_xcpt_t                    xcpt_fetch_in,
    output  fetch_xcpt_t                    xcpt_fetch_out,
    input   decode_xcpt_t                   xcpt_decode_in,
    output  decode_xcpt_t                   xcpt_decode_out,
    
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
 
    //Bypass
    output  logic [`REG_FILE_DATA_RANGE]    alu_data_bypass,
    input   logic [`REG_FILE_DATA_RANGE]    cache_data_bypass,
    input   logic                           cache_data_bp_valid
);

logic alu_hazard;

logic   alu_busy_next;
assign alu_hazard = stall_alu | alu_busy_next; 

//////////////////////////////////////
// Exceptions
fetch_xcpt_t    xcpt_fetch_ff;
decode_xcpt_t   xcpt_decode_ff;

//         CLK    RST    EN           DOUT             DIN             DEF
`RST_EN_FF(clock, reset, !alu_hazard, xcpt_decode_ff,  xcpt_decode_in, '0)
`RST_EN_FF(clock, reset, !alu_hazard, xcpt_fetch_ff,   xcpt_fetch_in,  '0)

assign xcpt_decode_out  = (alu_hazard) ? xcpt_decode_out : xcpt_decode_ff;
assign xcpt_fetch_out   = (alu_hazard) ? xcpt_fetch_out  : xcpt_fetch_ff;

////////////////////////////////////
// Request to D$ stage

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
                                                                         1'b0 ; // M-type or B-type

//     CLK    EN                                  DOUT                 DIN
`EN_FF(clock, !alu_hazard | cache_data_bp_valid,  req_dcache_info_ff,  req_dcache_info_next)
`EN_FF(clock, !alu_hazard,                        req_m_type_instr_ff, req_m_type_instr_next)
`EN_FF(clock, !alu_hazard,                        req_r_type_instr_ff, req_r_type_instr_next)
`EN_FF(clock, !alu_hazard,                        req_dst_reg_ff,      req_alu_info.rd_addr)
`EN_FF(clock, !alu_hazard,                        req_dcache_pc_ff,    req_alu_pc)

//         CLK    RST    EN           DOUT                 DIN            DEF
`RST_EN_FF(clock, reset, !alu_hazard, req_dcache_valid_ff, req_alu_valid, 1'b0)

assign req_dcache_valid = (alu_hazard) ? 1'b0 : req_dcache_valid_ff;

assign req_dcache_info  = (alu_hazard) ? req_dcache_info  : req_dcache_info_ff;
assign req_m_type_instr = (alu_hazard) ? req_m_type_instr : req_m_type_instr_ff;
assign req_r_type_instr = (alu_hazard) ? req_r_type_instr : req_r_type_instr_ff;
assign req_dst_reg      = (alu_hazard) ? req_dst_reg      : req_dst_reg_ff;
assign req_dcache_pc    = (alu_hazard) ? req_dcache_pc    : req_dcache_pc_ff;

////////////////////////////////////
// ALU is busy when we perform MUL operation
logic [`REG_FILE_DATA_RANGE] alu_mul_data;
logic [`REG_FILE_DATA_RANGE] alu_mul_data_ff;

//         CLK   RST    EN          DOUT      DIN            DEF
`RST_EN_FF(clock,reset, !stall_alu, alu_busy, alu_busy_next, 1'b0)

//     CLK   EN                         DOUT             DIN
`EN_FF(clock,!alu_busy & alu_busy_next, alu_mul_data_ff, alu_mul_data)

////////////////////////////////////
// Branch signals
logic [`PC_WIDTH-1:0]   branch_pc_next;
logic			 	    take_branch_next;

//         CLK    RST    EN           DOUT         DIN               DEF
`RST_EN_FF(clock, reset, !alu_hazard, take_branch, take_branch_next, 1'b0)

//     CLK    EN           DOUT       DIN
`EN_FF(clock, !alu_hazard, branch_pc, branch_pc_next)


////////////////////////////////////
// Bypass data

assign alu_data_bypass = (alu_hazard) ? alu_data_bypass : req_dcache_info_next.data;

logic cache_req_is_load;
//         CLK    RST    EN           DOUT               DIN                                 DEF
`RST_EN_FF(clock, reset, !alu_hazard, cache_req_is_load, is_load_instr(req_alu_info.opcode), 1'b0)


////////////////////////////////////
// Perform ALU instruction

logic   [`REG_FILE_DATA_RANGE]  ra_data;
logic   [`REG_FILE_DATA_RANGE]  rb_data;

always_comb
begin
	take_branch_next     = 1'b0;
    branch_pc_next       = '0;
    req_dcache_info_next = '0;

    ra_data = ((req_dst_reg == req_alu_info.ra_addr) & cache_data_bp_valid ) ? cache_data_bypass : req_alu_info.ra_data;
    rb_data = ((req_dst_reg == req_alu_info.rb_addr) & cache_data_bp_valid ) ? cache_data_bypass : req_alu_info.rb_data;

    // We assign computed MUL data to request for D$ stage once we took into
    // account the fixed latency for this operation
    if (!alu_busy_next & alu_busy)
    begin
        req_dcache_info_next.data = alu_mul_data_ff;
    end
    else
    begin
        // ADD
	    if (req_alu_info.opcode == `INSTR_ADD_OPCODE)
	    begin
	    	req_dcache_info_next.data  = ra_data + rb_data;
	    end
        // SUB
	    else if (req_alu_info.opcode == `INSTR_SUB_OPCODE)
        begin
            req_dcache_info_next.data  = ra_data - rb_data;
        end
        // MUL
	    else if (req_alu_info.opcode == `INSTR_MUL_OPCODE)
        begin
            alu_mul_data = ra_data * rb_data;
        end
        //ADDI
        else if (req_alu_info.opcode == `INSTR_ADDI_OPCODE)
        begin
            req_dcache_info_next.data = ra_data + req_alu_info.offset;
        end
        // MEM
	    else if (is_m_type_instr(req_alu_info.opcode)) 
        begin
            //LD
            if (is_load_instr(req_alu_info.opcode))
                req_dcache_info_next.addr = (  req_dst_reg == req_alu_info.ra_addr
                                             & cache_data_bp_valid              ) ? cache_data_bypass    + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset) : // Bypass Cache to Cache_next
                                                                                    req_alu_info.ra_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset) ;
            //ST
            else
                req_dcache_info_next.addr = (  req_dst_reg == req_alu_info.rd_addr
                                             & cache_data_bp_valid)               ? cache_data_bypass    + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset) : // Bypass Cache to Cache_next
                                                                                    req_alu_info.rb_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset) ;

            // Used only on store requests
	    	req_dcache_info_next.data   = (  cache_req_is_load & cache_data_bp_valid
                                           & (req_dst_reg == req_alu_info.ra_addr))? cache_data_bypass : // Bypass Cache to Cache_next
                                                                                     req_alu_info.ra_data;
            
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
        // BNQ
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

        /* FIXME: Optional not supported
        // MOV
        else if (req_alu_info.opcode == `INSTR_MOV_OPCODE) 
        begin
            //TODO          
        end
        // TLBWRITE
	    else if (req_alu_info.opcode == `INSTR_TLBWRITE_OPCODE) 
        begin
            //TODO          
        end
        // IRET
	    else if (req_alu_info.opcode == `INSTR_IRET_OPCODE) 
        begin
            //TODO
        end
        */
   end
end

////////////////////////////////////
// Perform MUL
logic [`ALU_MUL_LATENCY_RANGE] mul_count_next;
logic [`ALU_MUL_LATENCY_RANGE] mul_count;

//         CLK    RST    EN          DOUT       DIN             DEF
`RST_EN_FF(clock, reset, !stall_alu, mul_count, mul_count_next, '0)

always_comb
begin
    alu_busy_next   = 1'b0;
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
