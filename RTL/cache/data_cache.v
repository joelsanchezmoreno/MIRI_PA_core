// Data Cache allows write and read requests, and keeps track of modified lines
// such that dirty lines are evicted to main memory before being replaced. 
// The data cache implementation ensures that one request can be served each cycle 
// if there are no misses. Otheriwse, in case of a miss it takes `MAIN_MEMORY_LATENCY 
// cycles to go to memory and bring the line if evict is not needed.

module data_cache
(
    input   logic                            clock,
    input   logic                            reset,
    output  logic                            dcache_ready,

    // Exception
    output  logic                            xcpt_address_fault,

    // Request from the core pipeline
    input   dcache_request_t                 req_info,
    input   logic                            req_valid,

    // Response to the core pipeline
    output  logic [`DCACHE_MAX_ACC_SIZE-1:0] rsp_data,
    output  logic                            rsp_valid,

    // Request to the memory hierarchy
    output  logic                            req_valid_miss,
    output  memory_request_t                 req_info_miss,

    // Response from the memory hierarchy
    input   logic [`DCACHE_LINE_WIDTH-1:0]   rsp_data_miss,
    input   logic                            rsp_valid_miss
);

//////////////////////////////////////////////////
// Data Cache arrays: tag, data, dirty and valid
logic [`DCACHE_LINE_WIDTH-1:0]  dCache_data,dCache_data_ff [`DCACHE_NUM_WAYS-1:0];
logic [`DCACHE_TAG_RANGE]       dCache_tag, dCache_tag_ff  [`DCACHE_NUM_WAYS-1:0];
logic [`DCACHE_NUM_WAYS-1:0]    dCache_dirty, dCache_dirty_ff;
logic [`DCACHE_NUM_WAYS-1:0]    dCache_valid, dCache_valid_ff;

//  CLK    DOUT                    DIN       
`FF(clock, dCache_data_ff        , dCache_data)
`FF(clock, dCache_tag_ff         , dCache_tag )
`FF(clock, reset, dCache_dirty_ff, dCache_dirty)

//      CLK    RST    DOUT               DIN         DEF
`RST_FF(clock, reset, dCache_valid_ff, dCache_valid, '0)

//////////////////////////////////////////////////
// Control signals 
logic tag_miss;     // asserted when there is a miss on the instr. cache
logic tag_store;    // asserted if we need to store the TAG for next stages

logic [`DCACHE_NUM_WAY_RANGE]       hit_way;  

//////////////////////////////////////////////////
// Store Buffer signals 
store_buffer_t  store_buffer_info;
logic store_buffer_perform;
logic store_buffer_pending;
assign store_buffer_perform = store_buffer_pending & !req_valid & dcache_ready;

//////////////////////////////////////////////////
// Signals to save the request information for possible next stages
logic [`DCACHE_TAG_RANGE]           req_addr_tag, req_addr_tag_ff;
logic [`DCACHE_NUM_WAY_WIDTH-1:0]   req_addr_pos, req_addr_pos_ff; // Position of the D$ data in case there is a hit on tag array
logic [`WORD_WIDTH-1:0]             req_size_ff;
logic [`DCACHE_OFFSET_WIDTH-1:0]    req_addr_offset, req_addr_offset_ff;

//  CLK    EN                      DOUT             DIN       
`FF(clock, !tag_miss && req_valid, req_addr_pos_ff,     req_addr_pos)
`FF(clock, tag_store,              req_addr_tag_ff,     req_addr_tag)
`FF(clock, req_valid,              req_size_ff,         req_info.size)
`FF(clock, req_valid,              req_addr_offset_ff,  req_addr_offset)

//////////////////////////////////////////////////
// Position of the victim to be evicted from the D$
logic [`DCACHE_NUM_SET_WIDTH-1:0] req_addr_set, miss_dcache_set_ff;  
logic [`DCACHE_NUM_WAY_WIDTH-1:0] miss_dcache_way, miss_dcache_way_ff;  

//         CLK    RST    EN        DOUT                DIN              DEF
`RST_EN_FF(clock, reset, tag_miss, miss_dcache_set_ff, req_addr_set,    '0)
`RST_EN_FF(clock, reset, tag_miss, miss_dcache_way_ff, miss_dcache_way, '0)

//////////////////////////////////////////////////
// Ready signal to stall the pipeline if DCache is busy
logic dcache_ready_next;

//      CLK    RST    DOUT          DIN                DEF
`RST_FF(clock, reset, dcache_ready, dcache_ready_next, '0)


integer iter;

typedef enum logic [1:0]
{
    idle             = 2'b00, // tag search
    evict_line       = 2'b01,
    bring_line       = 2'b10,
    write_cache_line = 2'b11
} dcache_stages;

dcache_stages dcache_state, dcache_state_ff;

//      CLK    RST    DOUT             DIN           DEF
`RST_FF(clock, reset, dcache_state_ff, dcache_state, '0)


always_comb
begin
    // Mantain values for next clock
        // Control signals
    dcache_ready_next   = dcache_ready;
    dcache_state        = dcache_state_ff;

        // Cache arrays
    dCache_valid        = dCache_valid_ff;
    dCache_tag          = dCache_tag_ff;
    dCache_data         = dCache_data_ff;
    dCache_dirty        = dCache_dirty_ff;

    tag_miss            = 1'b0;
    hit_way             = '0;
    tag_store           = 1'b1;
    xcpt_address_fault  = 1'b0;

    case( dcache_state_ff )
        idle:
        begin
            rsp_valid       = 1'b0;
            req_valid_miss  = 1'b0; 
            tag_miss        = 1'b1;
            req_addr_pos    = '0; 

            // If there is a new request
            if ( req_valid )
            begin
                // Compute the tag and set for the given address 
                req_addr_tag    = req_info.addr[`DCACHE_TAG_ADDR_RANGE];
                req_addr_set    = req_info.addr[`DCACHE_SET_ADDR_RANGE]; 
                req_addr_offset = req_info.addr[`DCACHE_OFFSET_ADDR_RANGE];

                // Check that requested size and offset fits on the line
                if ((req_info.size*req_addr_offset+req_info.size) > `DCACHE_LINE_WIDTH/`DCACHE_MAX_ACC_SIZE )
                begin
                    xcpt_address_fault = 1'b1;
                end
                else 
                begin
                    // Look if the requested tag is on the cache
                    for (iter = 0; iter < `DCACHE_WAYS_PER_SET; i++)
                    begin
                        if ((dCache_tag_ff[iter + req_addr_set*`DCACHE_WAYS_PER_SET]   == req_addr_tag) &
                             dCache_valid[iter + req_addr_set*`DCACHE_WAYS_PER_SET] == 1'b1)
                        begin
                            req_addr_pos    = iter + req_addr_set*`DCACHE_WAYS_PER_SET;
                            tag_miss        = 1'b0;
                            hit_way         = iter;
                        end
                    end
                    
                    // If there is a request from the fetch stage and there is no 
                    // hit, we have a miss
                    evict_line  = tag_miss && dCache_valid[req_addr_pos] && dCache_dirty_ff[req_addr_pos]; 

                    // If there is a miss we need to send a request to main memory 
                    // to get the requested line
                    if ( tag_miss )
                    begin
                        dcache_ready_next   = 1'b0;
                        tag_store           = 1'b1;
                        // If we do not need to evict the line, we send a request 
                        // to get the requested line from main memory
                        if ( !evict_line )
                        begin
                            req_info_miss.addr      = req_info.addr;
                            req_info_miss.is_store  = 1'b0;                            
                            req_valid_miss          = 1'b1;

                            // Next stage
                            dcache_state            = bring_line;
                        end
                        // Otherwise, we need to evict the current line and bring
                        // the new one from main memory
                        else
                        begin
                            // Send request to evict the line
                            req_info_miss.addr            = {dCache_tag[req_addr_pos],req_addr_set,
                                                             `DCACHE_OFFSET_WIDTH{1'b0}}; //Evict full line
                            req_info_miss.is_store        = 1'b1;
                            req_info_miss.data            = dCache_data_ff[req_addr_pos];
                            req_valid_miss                = 1'b1;

                            // Invalidate the line
                            dCache_valid[miss_dcache_pos] = 1'b0;
                            dCache_dirty[miss_dcache_pos] = 1'b0;

                            // Next stage 
                            dcache_state                   = evict_line;
                        end
                    end // tag_miss
                    // If we hit on the dcache
                    else
                    begin
                        if (!req_info.is_store)
                        begin
                            rsp_valid   = 1'b1;                           
                            dcache_ready_next             = 1'b1;
                        end
                        else
                        begin
                            next_stage  = write_cache_line;
                            tag_store   = 1'b1;

                            //FIXME: Current implementation needs 2 cycles for
                            //       writes we could split that in two modules,
                            //       one for idle (lookup) and one for the rest
                            //       (cache)
                            dcache_ready_next   = 1'b0; 
                        end // req_info.is_store
                    end // !tag_miss
                end // !exception
            end // req_valid

            // If there is no valid request this cycle we check the Store
            // Buffer status
            else
            begin
                // If dcache is ready and there are pending ST on the buffer
                if ( store_buffer_perform )
                begin
                    // The store buffer LRU module returns the oldest store on
                    // the buffer
                    // FIXME: TODO
                    store_buffer_oldest_pos 
                end
            end // !req_valid
        end

        evict_line:
        begin
            // Wait for write ACK
            if (rsp_valid_miss)
            begin
                // Send new request to bring the new line
                req_info_miss.addr      = req_info.addr;
                req_info_miss.is_store  = 1'b0;
                req_valid_miss          = 1'b1;

                // Next stage 
                dcache_state            = bring_line;
            end
        end

        bring_line:
        begin
            // We wait until we receive the response from main memory. Then, we update
            // the tag, data and valid information for the position related to that
            // tag 
            if (rsp_valid_miss)
            begin
                miss_dcache_pos               = miss_dcache_way_ff + miss_dcache_set_ff*`DCACHE_WAYS_PER_SET;
                dCache_data[miss_dcache_pos]  = rsp_data_miss; 
                dCache_tag[miss_dcache_pos]   = req_addr_tag_ff;
                dCache_valid[miss_dcache_pos] = 1'b1; 
                if (!req_info.is_store)
                begin
                    dCache_dirty[miss_dcache_pos] = 1'b0; 
                end
                else
                begin
                    dCache_data[miss_dcache_pos][req_size_ff*req_addr_offset_ff+:req_size_ff]  = req_info.data[req_size_ff-1:0]; 
                    dCache_dirty[miss_dcache_pos] = 1'b1; 
                end
                dcache_ready_next   = 1'b1;
                dcache_state        = idle;
            end
        end

        write_cache_line:
        begin 
            dCache_tag[req_addr_pos_ff]   = req_addr_tag_ff;
            dCache_data[req_addr_pos_ff][req_size_ff*req_addr_offset_ff+:req_size_ff]  = req_info.data[req_size_ff-1:0]; 
            dCache_valid[req_addr_pos_ff] = 1'b1; 
            dCache_dirty[req_addr_pos_ff] = 1'b1; 
            dcache_ready_next             = 1'b1;
            // Next stage 
            dcache_state        = idle;
        end
    endcase
end


assign rsp_data  = ((dcache_state_ff == idle) & req_valid & !tag_miss ) ? // hit on the dcache
                            dCache_data_ff[req_addr_pos][req_info.size*req_addr_offset+:req_info.size] :
                   
                   ((dcache_state_ff == bring_line) & rsp_valid_miss ) ? // response from main memory
                            rsp_data_miss[req_size_ff*req_addr_offset_ff+:req_size_ff] :

                   '0;                             // default

assign rsp_valid = ((dcache_state_ff == idle) & req_valid & !tag_miss ) ? 1'b1 : // if we hit on the dcache
                   ((dcache_state_ff == bring_line) & rsp_valid_miss )  ? 1'b1 : // response from main memory
                   ( dcache_state_ff == write_cache_line)               ? 1'b1 : // data has been written on dcache
                                                                          1'b0;  // default


logic [`ICACHE_NUM_SET_RANGE] update_set;  
logic [`ICACHE_NUM_WAY_RANGE] update_way;  
logic dcache_hit;

assign icache_hit = !tag_miss & req_valid;
assign update_set = (rsp_valid_miss) ? miss_dcache_set_ff :
                    (dcache_hit)     ? req_addr_set       :
                    '0;

assign update_way = (rsp_valid_miss) ? miss_dcache_way_ff :
                    (dcache_hit)     ? hit_way            :
                    '0;              
// This module returns the oldest way accessed for a given set and updates the
// the LRU logic when there's a hit on the D$ or we bring a new line                        
dcache_lru
dcache_lru
(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),

    // Info to select the victim
    .victim_req         ( tag_miss          ),
    .victim_set         ( req_addr_set      ),
    .victim_way         ( miss_dcache_way   ),

    // Update the LRU logic
    .update_req         ( rsp_valid_miss |
                          dcache_hit        ),
    .update_set         ( update_set        ),
    .update_way         ( update_way        )
);

// FIXME: TODO
store_buffer
store_buffer
(
    // System signals
    .clock              ( clock                 ),
    .reset              ( reset                 ),

    .buffer_empty       ( store_buffer_pending  ),

    // Get the information from the oldest store on the buffer
    .get_oldest         ( store_buffer_perform  ),
    .oldest_info        ( store_buffer_info     ),

    // Push a new store to the buffer Update the LRU logic
    .push_valid         ( rsp_valid_miss        ), // FIXME
    .push_info          ( miss_dcache_set_ff    )  // FIXME
);
endmodule 
