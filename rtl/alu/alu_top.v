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
    input   logic [`REG_FILE_DATA_RANGE]    cache_data_bypass
);
// Exceptions
//      CLK    RST    DOUT              DIN             DEF
`RST_FF(clock, reset, xcpt_decode_out,  xcpt_decode_in, '0)
`RST_FF(clock, reset, xcpt_fetch_out,   xcpt_fetch_in,  '0)

////////////////////////////////////
// Request to D$ stage

//  CLK    DOUT          DIN
`FF(clock, req_dcache_pc,req_alu_pc)


dcache_request_t req_dcache_info_next;
logic  req_mem_instr_next;
logic  req_int_instr_next;

assign  req_mem_instr_next = (req_alu_info.opcode == `INSTR_M_TYPE) ? 1'b1 : 1'b0;
assign  req_int_instr_next = (req_alu_info.opcode == `INSTR_R_TYPE) ? 1'b1 : // R-type 
                             (!alu_busy_next & alu_busy)            ? 1'b1 : // MUL
                                                                      1'b0 ; // M-type or B-type

//  CLK    DOUT              DIN
`FF(clock, req_dcache_info,  req_dcache_info_next)
`FF(clock, req_m_type_instr, req_mem_instr_next)
`FF(clock, req_r_type_instr, req_int_instr_next)
`FF(clock, req_dst_reg,      req_alu_info.rd_addr)

//      CLK    RST    DOUT              DIN                          DEF
`RST_FF(clock, reset, req_dcache_valid, !stall_alu & !alu_busy_next, '0)


////////////////////////////////////
// ALU is busy when we perform MUL operation
logic   alu_busy_next;
logic [`REG_FILE_DATA_RANGE] alu_mul_data;
logic [`REG_FILE_DATA_RANGE] alu_mul_data_ff;

//      CLK   RST    DOUT      DIN           DEF
`RST_FF(clock,reset, alu_busy, alu_busy_next,1'b0)

//     CLK   EN                         DOUT             DIN
`EN_FF(clock,!alu_busy & alu_busy_next, alu_mul_data_ff, alu_mul_data)


////////////////////////////////////
// Branch signals
logic [`PC_WIDTH-1:0]   branch_pc_next;
logic			 	    take_branch_next;

//      CLK    RST    DOUT         DIN                  DEF
`RST_FF(clock, reset, take_branch, take_branch_next, 1'b0)

//  CLK    DOUT       DIN
`FF(clock, branch_pc, branch_pc_next)


////////////////////////////////////
// Bypass data

assign alu_data_bypass = req_dcache_info_next.data;

////////////////////////////////////
// Perform ALU instruction

always_comb
begin
	take_branch_next     = 1'b0;
    branch_pc_next       = '0;
    req_dcache_info_next = '0;

    // Respond MUL request when latency has finished
    if (!alu_busy_next & alu_busy)
    begin
        req_dcache_info_next.data = alu_mul_data_ff;
    end
    else
    begin
        // ADD
	    if (req_alu_info.opcode == `INSTR_ADD_OPCODE)
	    begin
	    	req_dcache_info_next.data  = req_alu_info.ra_data + req_alu_info.rb_data;
	    end
        // SUB
	    else if (req_alu_info.opcode == `INSTR_SUB_OPCODE)
        begin
            req_dcache_info_next.data  = req_alu_info.ra_data - req_alu_info.rb_data;
        end
        // MUL
	    else if (req_alu_info.opcode == `INSTR_MUL_OPCODE)
        begin
            alu_mul_data = req_alu_info.ra_data * req_alu_info.rb_data;
        end
        //ADDI
        else if (req_alu_info.opcode == `INSTR_ADDI_OPCODE)
        begin
            alu_mul_data = req_alu_info.ra_data * req_alu_info.offset;
        end

        // MEM
	    else if (req_alu_info.opcode == `INSTR_M_TYPE) 
        begin
            req_dcache_info_next.addr   = (  (  req_alu_info.opcode == `INSTR_LDB_OPCODE 
                                              | req_alu_info.opcode == `INSTR_LDW_OPCODE)
                                           & (req_dst_reg == req_alu_info.rd_addr))? cache_data_bypass : // Bypass Cache to Cache_next
                                                                                     req_alu_info.ra_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset);

            // Used only on store requests
	    	req_dcache_info_next.data   = (  (req_alu_info.opcode == `INSTR_LDB_OPCODE | req_alu_info.opcode == `INSTR_LDW_OPCODE)
                                           & (req_dst_reg == req_alu_info.ra_addr))? cache_data_bypass : // Bypass Cache to Cache_next
                                                                                     req_alu_info.ra_data + `ZX(`REG_FILE_DATA_WIDTH,req_alu_info.offset);
            
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
            if (req_alu_info.ra_data == req_alu_info.rb_data)
            begin
                branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
	    	    take_branch_next = 1'b1;
            end
	    end
        // JUMP
        else if (req_alu_info.opcode == `INSTR_JUMP_OPCODE) 
	    begin
	    	branch_pc_next   = `ZX(`PC_WIDTH,req_alu_info.offset);
	    	take_branch_next = 1'b1;
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

// Perform MUL
logic [`ALU_MUL_LATENCY_RANGE] mul_count_next;
logic [`ALU_MUL_LATENCY_RANGE] mul_count;

//      CLK    RST    DOUT       DIN             DEF
`RST_FF(clock, reset, mul_count, mul_count_next, '0)

always_comb
begin
    alu_busy_next   = 1'b0;
    mul_count_next  = mul_count;

    if ( !alu_busy & req_alu_info.opcode == `INSTR_MUL_OPCODE )
    begin
        alu_busy_next  = 1'b1;
        mul_count_next = mul_count + 1'b1;
    end

    if (alu_busy)
    begin
        mul_count_next = mul_count + 1'b1;
        if (mul_count_next == `ALU_MUL_LATENCY)
        begin
            alu_busy_next = 1'b0;
            mul_count_next  = '0;
        end
    end
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
