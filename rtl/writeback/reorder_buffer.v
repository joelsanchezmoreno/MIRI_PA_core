`include "soc.vh"

module reorder_buffer
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,
    output  logic                               reorder_buffer_full,
    output  logic [`ROB_NUM_ENTRIES_W_RANGE]    reorder_buffer_oldest,

    // Request to invalidate the buffer
    input   logic                               invalidate_buffer,

    // Request from ALU
    input   logic                               alu_req_valid,
    input   writeback_request_t                 alu_req_info,
    
    input   logic                               mem_instr_blocked,
    input   dcache_request_t                    mem_instr_info,

    // Request from MUL
    input   logic                               mul_req_valid,
    input   writeback_request_t                 mul_req_info,

    // Request from Cache
    input   logic                               cache_req_valid,
    input   writeback_request_t                 cache_req_info,

    // Request to Cache
    input   logic                               cache_stage_ready,
    output  logic                               req_to_dcache_valid,
    output  dcache_request_t                    req_to_dcache_info,

    // Request to RF
    output  logic                               req_to_RF_writeEn,
    output  logic [`REG_FILE_DATA_RANGE]        req_to_RF_data,
    output  logic [`REG_FILE_ADDR_RANGE]        req_to_RF_dest,
    output  logic [`ROB_ID_RANGE]               req_to_RF_instr_id,

    // Exceptions values to be stored on the RF
    output  logic 				                xcpt_valid,
    output  xcpt_type_t                         xcpt_type,
    output  logic [`PC_WIDTH_RANGE] 		    xcpt_pc,
    output  logic [`REG_FILE_XCPT_ADDR_RANGE] 	xcpt_addr,

    // Request from WB to TLB
    output  logic                               new_tlb_entry,
    output  logic                               new_tlb_id,
    output  tlb_req_info_t                      new_tlb_info,

    // Bypass info    
        // MUL
    input   logic [`ROB_ID_RANGE]               mul_src1_id,
    input   logic [`ROB_ID_RANGE]               mul_src2_id,
    output  logic                               mul_src1_hit,
    output  logic                               mul_src2_hit,
    output  logic [`REG_FILE_DATA_RANGE]        mul_src1_data,
    output  logic [`REG_FILE_DATA_RANGE]        mul_src2_data,
    
        // ALU
    input   logic [`ROB_ID_RANGE]               alu_src1_id,
    input   logic [`ROB_ID_RANGE ]              alu_src2_id,
    output  logic                               alu_src1_hit,
    output  logic                               alu_src2_hit,
    output  logic [`REG_FILE_DATA_RANGE]        alu_src1_data,
    output  logic [`REG_FILE_DATA_RANGE]        alu_src2_data
);

///////////////////////////
// Exceptions
reorder_buffer_xcpt_info_t alu_reorder_buffer_xcpt_info;
reorder_buffer_xcpt_info_t mul_reorder_buffer_xcpt_info;
reorder_buffer_xcpt_info_t cache_reorder_buffer_xcpt_info;

writeback_xcpt
writeback_xcpt
(
    // Request from stages to WB
    .alu_req_info       ( alu_req_info                  ),
    .mul_req_info       ( mul_req_info                  ),
    .cache_req_info     ( cache_req_info                ),

    // Reorder buffer xcpt info generated
    .alu_rob_xcpt_info  ( alu_reorder_buffer_xcpt_info  ),
    .mul_rob_xcpt_info  ( mul_reorder_buffer_xcpt_info  ),
    .cache_rob_xcpt_info( cache_reorder_buffer_xcpt_info)
);

////////////////////////////
// Reorder Buffer buffer signals

logic [`ROB_NUM_ENTRIES_RANGE]  reorder_buffer_valid;
logic [`ROB_NUM_ENTRIES_RANGE]  reorder_buffer_valid_ff;

reorder_buffer_t [`ROB_NUM_ENTRIES_RANGE]   reorder_buffer_data;
reorder_buffer_t [`ROB_NUM_ENTRIES_RANGE]   reorder_buffer_data_ff;

//      CLK    RST                        DOUT                     DIN                   DEF
`RST_FF(clock, reset | invalidate_buffer, reorder_buffer_valid_ff, reorder_buffer_valid , '0)

//  CLK    DOUT                    DIN                 
`FF(clock, reorder_buffer_data_ff, reorder_buffer_data)

////////////
// Store D$ requests
logic [`ROB_NUM_ENTRIES_RANGE]  reorder_buffer_mem_instr_blocked;
logic [`ROB_NUM_ENTRIES_RANGE]  reorder_buffer_mem_instr_blocked_ff;

rob_dcache_request_t [`ROB_NUM_ENTRIES_RANGE] rob_dcache_request;
rob_dcache_request_t [`ROB_NUM_ENTRIES_RANGE] rob_dcache_request_ff;

//      CLK    RST                        DOUT                                 DIN                               DEF
`RST_FF(clock, reset | invalidate_buffer, reorder_buffer_mem_instr_blocked_ff, reorder_buffer_mem_instr_blocked, '0)

//  CLK    DOUT                   DIN                 
`FF(clock, rob_dcache_request_ff, rob_dcache_request)

////////////
// Control signals
assign reorder_buffer_full  = ((reorder_buffer_valid_ff | reorder_buffer_mem_instr_blocked_ff) == '1); 

logic   [`ROB_NUM_ENTRIES_W_RANGE] reorder_buffer_tail;
logic   [`ROB_NUM_ENTRIES_W_RANGE] reorder_buffer_tail_ff;

//      CLK    RST                        DOUT                    DIN                  DEF
`RST_FF(clock, reset | invalidate_buffer, reorder_buffer_tail_ff, reorder_buffer_tail, '0)

assign reorder_buffer_oldest = reorder_buffer_tail_ff;

////////////////////////////
// Reorder Buffer buffer push and pop

logic   [`ROB_NUM_ENTRIES_W_RANGE] alu_free_pos;
logic   [`ROB_NUM_ENTRIES_W_RANGE] mul_free_pos;
logic   [`ROB_NUM_ENTRIES_W_RANGE] cache_free_pos;
logic   [`ROB_NUM_ENTRIES_W_RANGE] oldest_pos;

always_comb
begin
    // Maintain values
    reorder_buffer_data              = reorder_buffer_data_ff;
    reorder_buffer_valid             = reorder_buffer_valid_ff;
    reorder_buffer_tail              = reorder_buffer_tail_ff;
    reorder_buffer_mem_instr_blocked = reorder_buffer_mem_instr_blocked_ff;

    // No RF write nor xcpt taken by default
    req_to_RF_writeEn   = 1'b0;
    xcpt_valid          = 1'b0;
    new_tlb_entry       = 1'b0;
    req_to_dcache_valid = 1'b0;

    // Determine position to allocate ALU, MUL and C requests
    alu_free_pos        = alu_req_info.instr_id;
    mul_free_pos        = mul_req_info.instr_id;
    cache_free_pos      = cache_req_info.instr_id;

    // Get the oldest request on the RoB
    oldest_pos          = reorder_buffer_tail_ff;

    // If the instruction at the oldest position is valid
    // we can retire the instr. by returning the xcpt, RF write and 
    // TLB write.
    if (reorder_buffer_valid_ff[oldest_pos])
    begin
        reorder_buffer_valid[oldest_pos]  = 1'b0;
        reorder_buffer_tail = reorder_buffer_tail_ff + 1'b1;

        // Request to RF
        req_to_RF_writeEn  =   reorder_buffer_data_ff[oldest_pos].rf_wen 
                             & !reorder_buffer_data_ff[oldest_pos].xcpt_info.valid;
        req_to_RF_dest     = reorder_buffer_data_ff[oldest_pos].rf_dest;
        req_to_RF_data     = reorder_buffer_data_ff[oldest_pos].rf_data;
        req_to_RF_instr_id = reorder_buffer_data_ff[oldest_pos].instr_id;

        // Request to TLB
        new_tlb_entry   =   reorder_buffer_data_ff[oldest_pos].tlbwrite
                          & !reorder_buffer_data_ff[oldest_pos].xcpt_info.valid;
        new_tlb_id      = reorder_buffer_data_ff[oldest_pos].tlb_id;
        new_tlb_info    = reorder_buffer_data_ff[oldest_pos].tlb_req_info; 

        // Exceptions
        xcpt_valid  = reorder_buffer_data_ff[oldest_pos].xcpt_info.valid    ;
        xcpt_type   = reorder_buffer_data_ff[oldest_pos].xcpt_info.xcpt_type;
        xcpt_pc     = reorder_buffer_data_ff[oldest_pos].xcpt_info.pc       ;
        xcpt_addr   = reorder_buffer_data_ff[oldest_pos].xcpt_info.addr_val ;
    end   
    // If the instruction being retired at the ALU, MUL or Cache would be at the oldest 
    // position, we can retire the instr. immediately by returning the xcpt, RF write and 
    // TLB write.
    else if (  (alu_req_valid   & (oldest_pos == alu_req_info.instr_id  ))
             | (mul_req_valid   & (oldest_pos == mul_req_info.instr_id  ))
             | (cache_req_valid & (oldest_pos == cache_req_info.instr_id))
            )
    begin
        reorder_buffer_valid[oldest_pos]  = 1'b0;
        reorder_buffer_tail = reorder_buffer_tail_ff + 1'b1;

        if (alu_req_valid & (oldest_pos == alu_req_info.instr_id))
        begin
            // Request to RF
            req_to_RF_writeEn  =   alu_req_info.rf_wen 
                                 & !alu_reorder_buffer_xcpt_info.valid;
            req_to_RF_dest     = alu_req_info.rf_dest;
            req_to_RF_data     = alu_req_info.rf_data;
            req_to_RF_instr_id = alu_req_info.instr_id;

            // Request to TLB
            new_tlb_entry   =   alu_req_info.tlbwrite
                              & !alu_reorder_buffer_xcpt_info.valid;
            new_tlb_id      = alu_req_info.tlb_id;
            new_tlb_info    = alu_req_info.tlb_req_info; 

            // Exceptions
            xcpt_valid  = alu_reorder_buffer_xcpt_info.valid    ;
            xcpt_type   = alu_reorder_buffer_xcpt_info.xcpt_type;
            xcpt_pc     = alu_reorder_buffer_xcpt_info.pc       ;
            xcpt_addr   = alu_reorder_buffer_xcpt_info.addr_val ;
        end
        else if (mul_req_valid & (oldest_pos == mul_req_info.instr_id))
        begin
            // Request to RF
            req_to_RF_writeEn  =   mul_req_info.rf_wen 
                                 & !mul_reorder_buffer_xcpt_info.valid;
            req_to_RF_dest     = mul_req_info.rf_dest;
            req_to_RF_data     = mul_req_info.rf_data;
            req_to_RF_instr_id = mul_req_info.instr_id;

            // Request to TLB
            new_tlb_entry   =  1'b0;

            // Exceptions
            xcpt_valid  = mul_reorder_buffer_xcpt_info.valid    ;
            xcpt_type   = mul_reorder_buffer_xcpt_info.xcpt_type;
            xcpt_pc     = mul_reorder_buffer_xcpt_info.pc       ;
            xcpt_addr   = mul_reorder_buffer_xcpt_info.addr_val ;
        end
        else //(cache_req_valid & (oldest_pos == cache_req_info.instr_id))
        begin
            // Request to RF
            req_to_RF_writeEn  =   cache_req_info.rf_wen 
                                 & !cache_reorder_buffer_xcpt_info.valid;
            req_to_RF_dest     = cache_req_info.rf_dest;
            req_to_RF_data     = cache_req_info.rf_data;
            req_to_RF_instr_id = cache_req_info.instr_id;

            // Request to TLB
            new_tlb_entry   =  1'b0;

            // Exceptions
            xcpt_valid  = cache_reorder_buffer_xcpt_info.valid    ;
            xcpt_type   = cache_reorder_buffer_xcpt_info.xcpt_type;
            xcpt_pc     = cache_reorder_buffer_xcpt_info.pc       ;
            xcpt_addr   = cache_reorder_buffer_xcpt_info.addr_val ;
        end
    end

    // If the instruction at the oldest position was blocked waiting for cache 
    // to be ready, or if we received a response from cache and the next
    // oldest instruction is blocked waiting to access cache. 
    // Then, in case Cache is ready we send the request.
    if ( cache_stage_ready
        &( (reorder_buffer_mem_instr_blocked_ff[oldest_pos])
          |(reorder_buffer_mem_instr_blocked_ff[reorder_buffer_tail]) )
       ) 
    begin
        if ( reorder_buffer_mem_instr_blocked_ff[oldest_pos] )       
        begin
            reorder_buffer_mem_instr_blocked[oldest_pos]  = 1'b0;
            req_to_dcache_valid            = 1'b1;
            req_to_dcache_info.instr_id    = reorder_buffer_data_ff[oldest_pos].instr_id;
            req_to_dcache_info.rd_addr     = reorder_buffer_data_ff[oldest_pos].rd_addr;
            req_to_dcache_info.addr        = reorder_buffer_data_ff[oldest_pos].virt_addr;
            req_to_dcache_info.size        = reorder_buffer_data_ff[oldest_pos].size;
            req_to_dcache_info.is_store    = reorder_buffer_data_ff[oldest_pos].is_store;
            req_to_dcache_info.data        = reorder_buffer_data_ff[oldest_pos].data;
            req_to_dcache_info.pc          = rob_dcache_request_ff[oldest_pos].pc;
            req_to_dcache_info.xcpt_fetch  = rob_dcache_request_ff[oldest_pos].xcpt_fetch ;
            req_to_dcache_info.xcpt_decode = rob_dcache_request_ff[oldest_pos].xcpt_decode;
            req_to_dcache_info.xcpt_alu    = rob_dcache_request_ff[oldest_pos].xcpt_alu   ;
        end
        else
        begin
            reorder_buffer_mem_instr_blocked[reorder_buffer_tail]  = 1'b0;
            req_to_dcache_valid            = 1'b1;
            req_to_dcache_info.instr_id    = reorder_buffer_data_ff[reorder_buffer_tail].instr_id;
            req_to_dcache_info.rd_addr     = reorder_buffer_data_ff[reorder_buffer_tail].rd_addr;
            req_to_dcache_info.addr        = reorder_buffer_data_ff[reorder_buffer_tail].virt_addr;
            req_to_dcache_info.size        = reorder_buffer_data_ff[reorder_buffer_tail].size;
            req_to_dcache_info.is_store    = reorder_buffer_data_ff[reorder_buffer_tail].is_store;
            req_to_dcache_info.data        = reorder_buffer_data_ff[reorder_buffer_tail].data;
            req_to_dcache_info.pc          = rob_dcache_request_ff[reorder_buffer_tail].pc;
            req_to_dcache_info.xcpt_fetch  = rob_dcache_request_ff[reorder_buffer_tail].xcpt_fetch ;
            req_to_dcache_info.xcpt_decode = rob_dcache_request_ff[reorder_buffer_tail].xcpt_decode;
            req_to_dcache_info.xcpt_alu    = rob_dcache_request_ff[reorder_buffer_tail].xcpt_alu   ;
        end
    end

    // If the instr. that has been received comes from the ALU, 
    // then we have to push the received instruction
    if ( !reorder_buffer_full & (alu_req_valid | mem_instr_blocked) )
    begin 
        // Check if the instr. is a ST/LD request that could not be executed
        // because it is not the oldest instr.
        if (!mem_instr_blocked)
        begin 
            reorder_buffer_valid[alu_free_pos] = !(oldest_pos == alu_req_info.instr_id);

            reorder_buffer_data[alu_free_pos].instr_id      = alu_req_info.instr_id; 
            reorder_buffer_data[alu_free_pos].tlbwrite      = alu_req_info.tlbwrite;
            reorder_buffer_data[alu_free_pos].tlb_id        = alu_req_info.tlb_id;
            reorder_buffer_data[alu_free_pos].tlb_req_info  = alu_req_info.tlb_req_info;
            reorder_buffer_data[alu_free_pos].rf_wen        = alu_req_info.rf_wen;
            reorder_buffer_data[alu_free_pos].rf_dest       = alu_req_info.rf_dest;
            reorder_buffer_data[alu_free_pos].rf_data       = alu_req_info.rf_data;
            reorder_buffer_data[alu_free_pos].xcpt_info     = alu_reorder_buffer_xcpt_info;
        end
        else
        begin
            `ifdef VERBOSE_ROB
            $display("[ROB] ALU TO WB TO STORE DCACHE REQUEST");
            $display("[ROB] instr_id is %h",mem_instr_info.instr_id);
            `endif

            alu_free_pos = mem_instr_info.instr_id;
            reorder_buffer_mem_instr_blocked[alu_free_pos]  = 1'b1;

            reorder_buffer_data[alu_free_pos].instr_id      = mem_instr_info.instr_id; 
            reorder_buffer_data[alu_free_pos].rd_addr       = mem_instr_info.rd_addr; 
            reorder_buffer_data[alu_free_pos].virt_addr     = mem_instr_info.addr; 
            reorder_buffer_data[alu_free_pos].size          = mem_instr_info.size; 
            reorder_buffer_data[alu_free_pos].is_store      = mem_instr_info.is_store; 
            reorder_buffer_data[alu_free_pos].data          = mem_instr_info.data;
            rob_dcache_request[alu_free_pos].pc             = mem_instr_info.pc; 
            rob_dcache_request[alu_free_pos].xcpt_fetch     = mem_instr_info.xcpt_fetch;
            rob_dcache_request[alu_free_pos].xcpt_decode    = mem_instr_info.xcpt_decode;
            rob_dcache_request[alu_free_pos].xcpt_alu       = mem_instr_info.xcpt_alu;
        end
    end
    // If the instr. that has been received comes from the MUL stage, 
    // then we have to push the received instruction
    if ( !reorder_buffer_full & mul_req_valid )
    begin  
        reorder_buffer_valid[mul_free_pos] = !(oldest_pos == mul_req_info.instr_id);

        reorder_buffer_data[mul_free_pos].instr_id      = mul_req_info.instr_id; 
        reorder_buffer_data[mul_free_pos].tlbwrite      = mul_req_info.tlbwrite;
        reorder_buffer_data[mul_free_pos].tlb_id        = mul_req_info.tlb_id;
        reorder_buffer_data[mul_free_pos].tlb_req_info  = mul_req_info.tlb_req_info;
        reorder_buffer_data[mul_free_pos].rf_wen        = mul_req_info.rf_wen;
        reorder_buffer_data[mul_free_pos].rf_dest       = mul_req_info.rf_dest;
        reorder_buffer_data[mul_free_pos].rf_data       = mul_req_info.rf_data;
        reorder_buffer_data[mul_free_pos].xcpt_info     = mul_reorder_buffer_xcpt_info;
    end

    // If the instr. that has been received comes from the Cache, 
    // then we have to push the received instruction
    if ( !reorder_buffer_full & cache_req_valid )
    begin  
        reorder_buffer_valid[cache_free_pos]  = !(oldest_pos == cache_req_info.instr_id);

        reorder_buffer_data[cache_free_pos].instr_id      = cache_req_info.instr_id; 
        reorder_buffer_data[cache_free_pos].tlbwrite      = cache_req_info.tlbwrite;
        reorder_buffer_data[cache_free_pos].tlb_id        = cache_req_info.tlb_id;
        reorder_buffer_data[cache_free_pos].tlb_req_info  = cache_req_info.tlb_req_info;
        reorder_buffer_data[cache_free_pos].rf_wen        = cache_req_info.rf_wen;
        reorder_buffer_data[cache_free_pos].rf_dest       = cache_req_info.rf_dest;
        reorder_buffer_data[cache_free_pos].rf_data       = cache_req_info.rf_data;
        reorder_buffer_data[cache_free_pos].xcpt_info     = cache_reorder_buffer_xcpt_info;
    end
end


////////////////////////////
// Bypass info

always_comb
begin
    mul_src1_hit        = 1'b0;
    mul_src2_hit        = 1'b0;
    alu_src1_hit        = 1'b0;
    alu_src2_hit        = 1'b0;

    // MUL src1
        // Check if RoB has the instr
    if (reorder_buffer_valid_ff[mul_src1_id])
    begin
        mul_src1_hit   = 1'b1;
        mul_src1_data  = reorder_buffer_data[mul_src1_id].rf_data;
    end
        // Check ALU instr received this cycle
    else if (!reorder_buffer_full & alu_req_valid & alu_req_info.rf_wen ) 
    begin
        mul_src1_hit   = (mul_src1_id == alu_req_info.instr_id) ? 1'b1 : 1'b0;
        mul_src1_data  = alu_req_info.rf_data;        
    end
        // Check MUL instr received this cycle 
    else if (!reorder_buffer_full & mul_req_valid & mul_req_info.rf_wen ) 
    begin
        mul_src1_hit   = (mul_src1_id == mul_req_info.instr_id) ? 1'b1 : 1'b0;
        mul_src1_data  = mul_req_info.rf_data;        
    end
        // Check Cache instr received this cycle 
    else if (!reorder_buffer_full & cache_req_valid & cache_req_info.rf_wen)  
    begin
        mul_src1_hit   = (mul_src1_id == cache_req_info.instr_id) ? 1'b1 : 1'b0;
        mul_src1_data  = cache_req_info.rf_data;        
    end


    // MUL src2
        // Check if RoB has the instr
    if (reorder_buffer_valid_ff[mul_src2_id])
    begin
        mul_src2_hit   = 1'b1;
        mul_src2_data  = reorder_buffer_data[mul_src2_id].rf_data;
    end
        // Check ALU instr received this cycle
    else if (!reorder_buffer_full & alu_req_valid & alu_req_info.rf_wen ) 
    begin
        mul_src2_hit   = (mul_src2_id == alu_req_info.instr_id) ? 1'b1 : 1'b0;
        mul_src2_data  = alu_req_info.rf_data;        
    end
        // Check MUL instr received this cycle 
    else if (!reorder_buffer_full & mul_req_valid & mul_req_info.rf_wen ) 
    begin
        mul_src2_hit   = (mul_src2_id == mul_req_info.instr_id) ? 1'b1 : 1'b0;
        mul_src2_data  = mul_req_info.rf_data;        
    end
        // Check Cache instr received this cycle 
    else if (!reorder_buffer_full & cache_req_valid & cache_req_info.rf_wen) 
    begin
        mul_src2_hit   = (mul_src2_id == cache_req_info.instr_id) ? 1'b1 : 1'b0;
        mul_src2_data  = cache_req_info.rf_data;        
    end


    // ALU src1
        // Check if RoB has the instr
    if (reorder_buffer_valid_ff[alu_src1_id])
    begin
        alu_src1_hit   = 1'b1;
        alu_src1_data  = reorder_buffer_data[alu_src1_id].rf_data;
    end
        // Check ALU instr received this cycle
    else if (!reorder_buffer_full & alu_req_valid & alu_req_info.rf_wen ) 
    begin
        alu_src1_hit   = (alu_src1_id == alu_req_info.instr_id) ? 1'b1 : 1'b0;
        alu_src1_data  = alu_req_info.rf_data;        
    end
        // Check MUL instr received this cycle 
    else if (!reorder_buffer_full & mul_req_valid & mul_req_info.rf_wen ) 
    begin
        alu_src1_hit   = (alu_src1_id == mul_req_info.instr_id) ? 1'b1 : 1'b0;
        alu_src1_data  = mul_req_info.rf_data;        
    end
        // Check Cache instr received this cycle 
    else if (!reorder_buffer_full & cache_req_valid & cache_req_info.rf_wen)  
    begin
        alu_src1_hit   = (alu_src1_id == cache_req_info.instr_id) ? 1'b1 : 1'b0;
        alu_src1_data  = cache_req_info.rf_data;        
    end

    // ALU src2
        // Check if RoB has the instr
    if (reorder_buffer_valid_ff[alu_src2_id])
    begin
        alu_src2_hit   = 1'b1;
        alu_src2_data  = reorder_buffer_data[alu_src2_id].rf_data;
    end
        // Check ALU instr received this cycle
    else if (!reorder_buffer_full & alu_req_valid & alu_req_info.rf_wen ) 
    begin
        alu_src2_hit   = (alu_src2_id == alu_req_info.instr_id) ? 1'b1 : 1'b0;
        alu_src2_data  = alu_req_info.rf_data;        
    end
        // Check MUL instr received this cycle 
    else if (!reorder_buffer_full & mul_req_valid & mul_req_info.rf_wen ) 
    begin
        alu_src2_hit   = (alu_src2_id == mul_req_info.instr_id) ? 1'b1 : 1'b0;
        alu_src2_data  = mul_req_info.rf_data;        
    end
        // Check Cache instr received this cycle 
    else if (!reorder_buffer_full & cache_req_valid & cache_req_info.rf_wen)  
    begin
        alu_src2_hit   = (alu_src2_id == cache_req_info.instr_id) ? 1'b1 : 1'b0;
        alu_src2_data  = cache_req_info.rf_data;        
    end
end
endmodule
