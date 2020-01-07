`include "soc.vh"

module writeback_xcpt
(
    input   writeback_request_t                 alu_req_info,
    input   writeback_request_t                 mul_req_info,
    input   writeback_request_t                 cache_req_info,

    output  reorder_buffer_xcpt_info_t          alu_rob_xcpt_info,
    output  reorder_buffer_xcpt_info_t          mul_rob_xcpt_info,
    output  reorder_buffer_xcpt_info_t          cache_rob_xcpt_info
);

// Generate ALU RoB xcpt info
always_comb
begin
    alu_rob_xcpt_info.valid = 1'b0;

    if (  alu_req_info.xcpt_fetch.xcpt_itlb_miss 
        | alu_req_info.xcpt_fetch.xcpt_bus_error )
    begin
        alu_rob_xcpt_info.valid      = 1'b1;
        alu_rob_xcpt_info.xcpt_type  = (alu_req_info.xcpt_fetch.xcpt_itlb_miss) ? iTlb_miss : fetch_bus_error;
        alu_rob_xcpt_info.addr_val   = alu_req_info.xcpt_fetch.xcpt_addr_val; 
        alu_rob_xcpt_info.pc         = alu_req_info.xcpt_fetch.xcpt_pc;
    end
    else if (alu_req_info.xcpt_decode.xcpt_illegal_instr)
    begin
        alu_rob_xcpt_info.valid     = 1'b1;
        alu_rob_xcpt_info.xcpt_type = illegal_instr;
        alu_rob_xcpt_info.pc        = alu_req_info.xcpt_decode.xcpt_pc;
    end
    else if (alu_req_info.xcpt_alu.xcpt_overflow)
    begin
        alu_rob_xcpt_info.valid     = 1'b1;
        alu_rob_xcpt_info.xcpt_type = overflow;
        alu_rob_xcpt_info.pc        = alu_req_info.xcpt_alu.xcpt_pc;
    end
    else if (alu_req_info.xcpt_mul.xcpt_overflow)
    begin
        alu_rob_xcpt_info.valid     = 1'b1;
        alu_rob_xcpt_info.xcpt_type = overflow;
        alu_rob_xcpt_info.pc        = alu_req_info.xcpt_mul.xcpt_pc;
    end
    else if (  alu_req_info.xcpt_cache.xcpt_addr_fault 
             | alu_req_info.xcpt_cache.xcpt_dtlb_miss
             | alu_req_info.xcpt_cache.xcpt_bus_error)
    begin
        alu_rob_xcpt_info.valid      = 1'b1;
        alu_rob_xcpt_info.xcpt_type  = ( alu_req_info.xcpt_cache.xcpt_addr_fault ) ? cache_addr_fault :
                                       ( alu_req_info.xcpt_cache.xcpt_dtlb_miss  ) ? dTlb_miss        :
                                                                                     cache_bus_error; 
        alu_rob_xcpt_info.addr_val   = alu_req_info.xcpt_cache.xcpt_addr_val; 
        alu_rob_xcpt_info.pc         = alu_req_info.xcpt_cache.xcpt_pc;
    end
end

// Generate MUL RoB xcpt info
always_comb
begin
    mul_rob_xcpt_info.valid = 1'b0;

    if (  mul_req_info.xcpt_fetch.xcpt_itlb_miss 
        | mul_req_info.xcpt_fetch.xcpt_bus_error )
    begin
        mul_rob_xcpt_info.valid      = 1'b1;
        mul_rob_xcpt_info.xcpt_type  = (mul_req_info.xcpt_fetch.xcpt_itlb_miss) ? iTlb_miss : fetch_bus_error;
        mul_rob_xcpt_info.addr_val   = mul_req_info.xcpt_fetch.xcpt_addr_val; 
        mul_rob_xcpt_info.pc         = mul_req_info.xcpt_fetch.xcpt_pc;
    end
    else if (mul_req_info.xcpt_decode.xcpt_illegal_instr)
    begin
        mul_rob_xcpt_info.valid     = 1'b1;
        mul_rob_xcpt_info.xcpt_type = illegal_instr;
        mul_rob_xcpt_info.pc        = mul_req_info.xcpt_decode.xcpt_pc;
    end
    else if (mul_req_info.xcpt_alu.xcpt_overflow)
    begin
        mul_rob_xcpt_info.valid     = 1'b1;
        mul_rob_xcpt_info.xcpt_type = overflow;
        mul_rob_xcpt_info.pc        = mul_req_info.xcpt_alu.xcpt_pc;
    end
    else if (mul_req_info.xcpt_mul.xcpt_overflow)
    begin
        mul_rob_xcpt_info.valid     = 1'b1;
        mul_rob_xcpt_info.xcpt_type = overflow;
        mul_rob_xcpt_info.pc        = mul_req_info.xcpt_mul.xcpt_pc;
    end
    else if (  mul_req_info.xcpt_cache.xcpt_addr_fault 
             | mul_req_info.xcpt_cache.xcpt_dtlb_miss
             | mul_req_info.xcpt_cache.xcpt_bus_error)
    begin
        mul_rob_xcpt_info.valid      = 1'b1;
        mul_rob_xcpt_info.xcpt_type  = ( mul_req_info.xcpt_cache.xcpt_addr_fault ) ? cache_addr_fault :
                                       ( mul_req_info.xcpt_cache.xcpt_dtlb_miss  ) ? dTlb_miss        :
                                                                                     cache_bus_error; 
        mul_rob_xcpt_info.addr_val   = mul_req_info.xcpt_cache.xcpt_addr_val; 
        mul_rob_xcpt_info.pc         = mul_req_info.xcpt_cache.xcpt_pc;
    end
end

// Generate Cache RoB xcpt info
always_comb
begin
    cache_rob_xcpt_info.valid = 1'b0;

    if (  cache_req_info.xcpt_fetch.xcpt_itlb_miss 
        | cache_req_info.xcpt_fetch.xcpt_bus_error )
    begin
        cache_rob_xcpt_info.valid      = 1'b1;
        cache_rob_xcpt_info.xcpt_type  = (cache_req_info.xcpt_fetch.xcpt_itlb_miss) ? iTlb_miss : fetch_bus_error;
        cache_rob_xcpt_info.addr_val   = cache_req_info.xcpt_fetch.xcpt_addr_val; 
        cache_rob_xcpt_info.pc         = cache_req_info.xcpt_fetch.xcpt_pc;
    end
    else if (cache_req_info.xcpt_decode.xcpt_illegal_instr)
    begin
        cache_rob_xcpt_info.valid       = 1'b1;
        cache_rob_xcpt_info.xcpt_type   = illegal_instr;
        cache_rob_xcpt_info.pc          = cache_req_info.xcpt_decode.xcpt_pc;
    end
    else if (cache_req_info.xcpt_alu.xcpt_overflow)
    begin
        cache_rob_xcpt_info.valid       = 1'b1;
        cache_rob_xcpt_info.xcpt_type   = overflow;
        cache_rob_xcpt_info.pc          = cache_req_info.xcpt_alu.xcpt_pc;
    end
    else if (cache_req_info.xcpt_mul.xcpt_overflow)
    begin
        cache_rob_xcpt_info.valid       = 1'b1;
        cache_rob_xcpt_info.xcpt_type   = overflow;
        cache_rob_xcpt_info.pc          = cache_req_info.xcpt_mul.xcpt_pc;
    end
    else if (  cache_req_info.xcpt_cache.xcpt_addr_fault 
             | cache_req_info.xcpt_cache.xcpt_dtlb_miss
             | cache_req_info.xcpt_cache.xcpt_bus_error)
    begin
        cache_rob_xcpt_info.valid      = 1'b1;
        cache_rob_xcpt_info.xcpt_type  = ( cache_req_info.xcpt_cache.xcpt_addr_fault ) ? cache_addr_fault :
                                         ( cache_req_info.xcpt_cache.xcpt_dtlb_miss  ) ? dTlb_miss        :
                                                                                         cache_bus_error; 
        cache_rob_xcpt_info.addr_val   = cache_req_info.xcpt_cache.xcpt_addr_val; 
        cache_rob_xcpt_info.pc         = cache_req_info.xcpt_cache.xcpt_pc;
    end
end
endmodule
