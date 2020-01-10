// Data Cache allows write and read requests, and keeps track of modified lines
// such that dirty lines are evicted to main memory before being replaced. 
// The data cache implementation ensures that one request can be served each cycle 
// if there are no misses. Otheriwse, in case of a miss it takes `MAIN_MEMORY_LATENCY 
// cycles to go to memory and bring the line if evict is not needed.
`include "soc.vh"

module data_cache
(
    input   logic                            clock,
    input   logic                            reset,
    output  logic                            dcache_ready,

    // Exception
    output  logic                            xcpt_bus_error,

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
    input   logic                            rsp_bus_error,
    input   logic                            rsp_valid_miss
);

//////////////////////////////////////////////////
// Data Cache arrays: tag, data, dirty and valid
logic [`DCACHE_LINE_RANGE]   dCache_data    [`DCACHE_NUM_WAYS_R];
logic [`DCACHE_LINE_RANGE]   dCache_data_ff [`DCACHE_NUM_WAYS_R];
logic [`DCACHE_TAG_RANGE]    dCache_tag     [`DCACHE_NUM_WAYS_R];
logic [`DCACHE_TAG_RANGE]    dCache_tag_ff  [`DCACHE_NUM_WAYS_R];
logic [`DCACHE_NUM_WAYS_R]   dCache_dirty;
logic [`DCACHE_NUM_WAYS_R]   dCache_dirty_ff;
logic [`DCACHE_NUM_WAYS_R]   dCache_valid;
logic [`DCACHE_NUM_WAYS_R]   dCache_valid_ff;

//  CLK    DOUT             DIN       
`FF(clock, dCache_data_ff , dCache_data)
`FF(clock, dCache_tag_ff  , dCache_tag )

//      CLK    RST    DOUT               DIN         DEF
`RST_FF(clock, reset, dCache_valid_ff, dCache_valid, '0)
`RST_FF(clock, reset, dCache_dirty_ff, dCache_dirty, '0)

//////////////////////////////////////////////////
// Control signals 
logic dcache_tags_hit;  // asserted when there is a hit on the instr. cache
logic [`DCACHE_WAYS_PER_SET_RANGE] hit_way; // stores the way in case of a D$ hit 

//////////////////////////////////////////////////
// Store Buffer signals 
store_buffer_t  store_buffer_push_info;
store_buffer_t  store_buffer_pop_info;
logic store_buffer_perform;
logic store_buffer_pending;
logic store_buffer_full;
assign store_buffer_perform = store_buffer_pending & !req_valid & dcache_ready;

//////////////////////////////////////////////////
// Signals to save the request information for possible next stages

// Position of the D$ data in case there is a hit on tag array
logic [`DCACHE_NUM_WAY_RANGE]   req_target_pos; 
logic [`DCACHE_NUM_WAY_RANGE]   req_target_pos_ff; 

//  CLK    DOUT                DIN       
`FF(clock, req_target_pos_ff,  req_target_pos)

//////////////////////////////////////////////////
// Position of the victim to be evicted from the D$
logic [`DCACHE_NUM_SET_RANGE]       req_set;  
logic [`DCACHE_WAYS_PER_SET_RANGE]  miss_dcache_way;  

//////////////////////////////////////////////////
// Ready signal to stall the pipeline if DCache is busy
logic dcache_ready_next, dcache_ready_ff;

//      CLK    RST    DOUT          DIN                DEF
`RST_FF(clock, reset, dcache_ready_ff, dcache_ready_next, '0)

assign dcache_ready = dcache_ready_ff;

//////////////////////////////////////////////////
// Store buffer signals

// Asserted when we request the store_buffer to search for a specific address
logic search_store_buffer;
logic [`DCACHE_TAG_RANGE]  search_tag;

// Asserted if the store buffer contains a req. to the same TAG as the one requested
// in which case we have to perform the store before returning/modifying the line
logic store_buffer_hit_tag;
logic store_buffer_hit_tag_ff ;

// Asserted if the store buffer contains a req. to the same line as the one requested
// in which case we have to perform the store before evicting the line (if needed)
logic store_buffer_hit_way;
logic store_buffer_hit_way_ff;

//         CLK    RST    EN                   DOUT                      DIN                    DEF
`RST_EN_FF(clock, reset, search_store_buffer, store_buffer_hit_tag_ff, store_buffer_hit_tag, '0)
`RST_EN_FF(clock, reset, search_store_buffer, store_buffer_hit_way_ff, store_buffer_hit_way, '0)

// Saves the request extracted from the ST buffer
store_buffer_t pending_store_req;
store_buffer_t pending_store_req_ff;

//         CLK    RST    EN                                              DOUT                  DIN                DEF
`RST_EN_FF(clock, reset, (store_buffer_hit_tag | store_buffer_hit_way), pending_store_req_ff, pending_store_req, '0)

// Saves the request received in case we need to perform a request from the ST
// buffer
dcache_request_t pending_req;
dcache_request_t pending_req_ff;
`FF(clock, pending_req_ff, pending_req)

// Signals for operating the partial stores to write on the D$
logic [`DCACHE_OFFSET_RANGE] req_offset;
logic [`DCACHE_TAG_RANGE]    req_tag   ;
req_size_t                   req_size  ;

dcache_state_t dcache_state;
dcache_state_t dcache_state_ff;

//      CLK    RST    DOUT             DIN           DEF
`RST_FF(clock, reset, dcache_state_ff, dcache_state, '0)

//////////////////////////////////////////////////
// Logic
integer iter;

always_comb
begin
    // Mantain values for next clock
        // Status signals
    dcache_ready_next   = dcache_ready_ff;
    dcache_state        = dcache_state_ff;

        // Cache arrays
    dCache_valid        = dCache_valid_ff;
    dCache_tag          = dCache_tag_ff;
    dCache_data         = dCache_data_ff;
    dCache_dirty        = dCache_dirty_ff;

        // Control signals
    req_target_pos          = req_target_pos_ff;

    search_store_buffer     = 1'b0;

        // Exception
    xcpt_bus_error = 1'b0;

    pending_req         = pending_req_ff;
    
    case( dcache_state_ff )
        idle:
        begin
            dcache_ready_next = !store_buffer_full;

            rsp_valid       = 1'b0;
            req_valid_miss  = 1'b0; 
            dcache_tags_hit = 1'b0;
          
            // Compute the tag and set for the given address 
            req_tag    = req_info.addr[`DCACHE_TAG_ADDR_RANGE];
            req_set    = req_info.addr[`DCACHE_SET_ADDR_RANGE]; 
            req_offset = req_info.addr[`DCACHE_OFFSET_ADDR_RANGE] >> $clog2(req_info.size+1);

            // Perform the request
            if (req_valid)
            begin
                // Look if the requested tag is on the cache
                for (iter = 0; iter < `DCACHE_WAYS_PER_SET; iter++)
                begin
                     if((dCache_tag_ff[iter + req_set*`DCACHE_WAYS_PER_SET] == req_tag) &
                         dCache_valid[iter + req_set*`DCACHE_WAYS_PER_SET]  == 1'b1)
                    begin
                        req_target_pos  = iter + req_set*`DCACHE_WAYS_PER_SET;
                        dcache_tags_hit = 1'b1;
                        hit_way         = iter;
                    end
                end

                // Look on the ST buffer if there are pendent requests for
                // the requested address. 
                //    LD miss -- look if we need to modify the line to be
                //               evicted in case evict is needed
                //    LD hit  -- look if we need to modify the line before
                //               returning the data
                //    ST miss -- look if we need to modify the line to be
                //               evicted in case evict is needed
                //    ST hit  -- we just push the request to ST buffer, no
                //               need to look for requests to the same way/tag

                // Position of the way to be written
                if (!dcache_tags_hit)
                    req_target_pos = miss_dcache_way + req_set*`DCACHE_WAYS_PER_SET;
                    
                search_store_buffer = ( req_info.is_store & dcache_tags_hit  ) ? 1'b0 : // ST hit
                                      (!req_info.is_store & dcache_tags_hit  ) ? 1'b1 : // LD hit
                                                                                 dCache_dirty_ff[req_target_pos]; // LD/ST miss                                      

                search_tag          = req_info.addr[`DCACHE_TAG_ADDR_RANGE];

                // [INFO] If we hit on the D$ we may hit on the ST buffer 
                // since the ST buffer cannot have requests to lines that
                // are not on the D$ 
                
                // If there is a ST hit we push the request to the store buffer
                if (dcache_tags_hit & req_info.is_store)
                begin
                    //FIXME.TODO. Merge requests if there are more on the store buffer
                    //            with same tag?
                    rsp_valid = 1'b1;
                    store_buffer_push_info.addr = req_info.addr;
                    store_buffer_push_info.way  = hit_way;
                    store_buffer_push_info.size = req_info.size;
                    store_buffer_push_info.data = req_info.data;
                    `ifdef VERBOSE_DCACHE
                        $display("[DCACHE] D$ hit and store -- adding req to store buffer");
                        $display("          addr = %h",req_info.addr);
                    `endif
                end

                // If there is a LD hit we evaluate the conditions of that hit
                // depending if there are ST on the store buffer waiting to
                // modify the same line
                else if (dcache_tags_hit & !req_info.is_store) //LD_hit
                begin
                    // If there is no store waiting to modify that line we return
                    // the data
                    if ( !store_buffer_hit_tag )
                    begin
                        `ifdef VERBOSE_DCACHE
                            $display("[DCACHE] D$ hit and load with ST buffer empty -- respond request");
                            $display("         addr = %h",req_info.addr);
                        `endif

                        if ( req_info.size == Byte)
                        begin
                            req_offset  = req_info.addr[`DCACHE_OFFSET_ADDR_RANGE];
                            rsp_data    = `ZX_BYTE(`DCACHE_MAX_ACC_SIZE,dCache_data[req_target_pos][`GET_LOWER_BOUND(`BYTE_BITS,req_offset)+:`BYTE_BITS]);
                        end
                        else
                        begin
                            req_offset  = req_info.addr[`DCACHE_OFFSET_ADDR_RANGE] >> $clog2(req_info.size+1);
                            rsp_data  = `ZX_DWORD(`DCACHE_MAX_ACC_SIZE, dCache_data[req_target_pos][`GET_LOWER_BOUND(`DWORD_BITS,req_offset)+:`DWORD_BITS]);
                        end

                        rsp_valid = 1'b1;
                    end
                    // If there is a store request on the store buffer that
                    // modifies the same line, we should perform the store before
                    // returning the line
                    else
                    begin
                        `ifdef VERBOSE_DCACHE
                            $display("[DCACHE] D$ hit and load with ST buffer NOT empty -- jump to write cache line state");
                            $display("         addr = %h",req_info.addr);
                        `endif
                        dcache_ready_next   = 1'b0;
                        pending_req         = req_info; // We save the request we received
                        dcache_state        = write_cache_line;
                    end
                end
                // If we do NOT hit on the D$ Tags (miss either LD or ST)
                else
                begin
                    dcache_ready_next   = 1'b0;

                    // If there is a request on the store buffer that targets
                    // the way we want to replace, we need to perform the ST
                    // and then evict the line
                    if (store_buffer_hit_way)
                    begin
                        pending_req         = req_info;
                        dcache_state        = write_cache_line;
                    end
                    // If there are NO requests on the store buffer that targets
                    // the line we want to replace. Then, we can evict the line 
                    else 
                    begin
                        // If the data is dirty on the cache we have to evict
                        if ( dCache_dirty_ff[req_target_pos] )
                        begin
                            `ifdef VERBOSE_DCACHE
                                $display("[DCACHE] D$ miss and dirty -- send evict request to main memory");
                                $display("         addr = %h",req_info.addr);
                                $display("    dirty pos = %h",req_target_pos);
                            `endif
                            // Send request to evict the line
                            req_info_miss.addr            = ( {dCache_tag[req_target_pos],req_set, 
                                                              {`DCACHE_OFFSET_WIDTH{1'b0}}} >> `DCACHE_ADDR_RSH_VAL);
                            req_info_miss.is_store        = 1'b1;
                            req_info_miss.data            = dCache_data_ff[req_target_pos];
                            req_valid_miss                = 1'b1;
                            
                            // Invalidate the line
                            dCache_valid[req_target_pos] = 1'b0;
                            dCache_dirty[req_target_pos] = 1'b0;

                            // Next stage
                            pending_req     = req_info;                    
                            dcache_state    = evict_line;
                        end
                        // If the line is not dirty on the cache we just need to bring
                        // the new one.
                        else 
                        begin
                            `ifdef VERBOSE_DCACHE
                                $display("[DCACHE] D$ miss and NOT dirty -- send miss request to main memory");
                                $display("         addr = %h",req_info.addr);
                            `endif

                            req_info_miss.addr      = req_info.addr >> `DCACHE_ADDR_RSH_VAL;
                            req_info_miss.is_store  = 1'b0;                            
                            req_valid_miss          = 1'b1;

                            // Next stage
                            pending_req             = req_info;                    
                            dcache_state            = bring_line;
                        end //!dCache_dirty_ff[req_target_pos]
                    end // store_buffer_hit_way
                end // !LD_hit
            end // req_valid
            else
            begin
                // Modify the D$ with the store buffer request information

                // Compute the tag and set for the given address 
                req_tag     = store_buffer_pop_info.addr[`DCACHE_TAG_ADDR_RANGE];
                req_set     = store_buffer_pop_info.addr[`DCACHE_SET_ADDR_RANGE]; 
                req_size    = store_buffer_pop_info.size;

                req_target_pos  = store_buffer_pop_info.way + req_set*`DCACHE_WAYS_PER_SET;
               
                // Update D$ 
                if (store_buffer_pending)
                begin
                    dCache_tag[req_target_pos]   = req_tag;
                    dCache_dirty[req_target_pos] = 1'b1; 
           
                    if ( req_size == Byte)
                    begin
                        req_offset  = store_buffer_pop_info.addr[`DCACHE_OFFSET_ADDR_RANGE];
                        dCache_data[req_target_pos][`GET_LOWER_BOUND(`BYTE_BITS,req_offset)+:`BYTE_BITS] = store_buffer_pop_info.data[`BYTE_RANGE];
                    end
                    else
                    begin
                        req_offset  = store_buffer_pop_info.addr[`DCACHE_OFFSET_ADDR_RANGE] >> $clog2(store_buffer_pop_info.size+1);
                        dCache_data[req_target_pos][`GET_LOWER_BOUND(`DWORD_BITS,req_offset)+:`DWORD_BITS] = store_buffer_pop_info.data[`DWORD_RANGE];
                    end
                end
            end
        end

        // This state is executed when we've sent an evict request for a D$ line,
        // so we wait until we receive the ACK signal and then we send a request
        // to get the new line.
        evict_line:
        begin
            req_valid_miss = 1'b0;

            // Wait for response from memory ACK
            if (rsp_valid_miss)
            begin
                // Send new request to bring the new line
                req_info_miss.addr      = pending_req_ff.addr >> `DCACHE_ADDR_RSH_VAL;
                req_info_miss.is_store  = 1'b0;
                req_valid_miss          = 1'b1;
                
                // Next stage 
                dcache_state  = bring_line;
            end
        end

        // This state is executed when a line has been requested to main memory,
        // so we wait for response from main memory and then we respond to the
        // dcache_top
        bring_line:
        begin
            req_valid_miss = 1'b0;
            // We wait until we receive the response from main memory. Then, we update
            // the tag, data and valid information for the position related to that
            // tag 
            if (rsp_valid_miss)
            begin
                xcpt_bus_error = rsp_bus_error;
                rsp_valid      = 1'b1;
                if (!rsp_bus_error)
                begin
                    // Compute signals from the pending ST request
                    req_tag    = pending_req_ff.addr[`DCACHE_TAG_ADDR_RANGE];
                    req_set    = pending_req_ff.addr[`DCACHE_SET_ADDR_RANGE]; 
                    req_size   = pending_req_ff.size;

                    // If it was a ST, we modify the received line and put
                    // that line as dirty
                    if (pending_req_ff.is_store)
                    begin
                        dCache_data[req_target_pos_ff]  = rsp_data_miss; 
                        dCache_dirty[req_target_pos_ff] = 1'b1; 
                        if ( req_size == Byte)
                        begin
                            req_offset = pending_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE];
                            dCache_data[req_target_pos_ff][`GET_LOWER_BOUND(`BYTE_BITS,req_offset)+:`BYTE_BITS] =  pending_req_ff.data[`BYTE_RANGE];
                        end
                        else
                        begin
                            req_offset = pending_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE]  >> $clog2(pending_req_ff.size+1);
                            dCache_data[req_target_pos_ff][`GET_LOWER_BOUND(`DWORD_BITS,req_offset)+:`DWORD_BITS] =  pending_req_ff.data[`DWORD_RANGE];
                        end
                    end
                    // If it was a LD, we copy the line received from memory and
                    // return valid data
                    else
                    begin
                        dCache_data[req_target_pos_ff]  = rsp_data_miss;

                        // Respond request from dcache_top
                        if ( req_size == Byte)
                        begin
                            req_offset = pending_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE];
                            rsp_data  = `ZX_BYTE(`DCACHE_MAX_ACC_SIZE,rsp_data_miss[`GET_LOWER_BOUND(`BYTE_BITS,req_offset)+:`BYTE_BITS]);
                        end
                        else
                        begin
                            req_offset = pending_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE]  >> $clog2(pending_req_ff.size+1);
                            rsp_data  = `ZX_DWORD(`DCACHE_MAX_ACC_SIZE, rsp_data_miss[`GET_LOWER_BOUND(`DWORD_BITS,req_offset)+:`DWORD_BITS]);
                        end
                    end

                    dCache_tag[req_target_pos_ff]   = req_tag;
                    dCache_valid[req_target_pos_ff] = 1'b1;
                end 

                // Next stage
                dcache_ready_next   = 1'b1;
                dcache_state        = idle;
            end //!rsp_valid_miss
        end

        // This state is executed:
        // 1.When there is a LD request that hits and there are requests 
        //   on the store buffer that modify the targetted line, so we 
        //   have to modify the data before returning it.
        // or
        //  2. When there is a miss (either LD or ST) and there are pending
        //     stores on the store_buffer for the line we want to replace.
        write_cache_line:
        begin
            req_valid_miss    = 1'b0;
            dcache_ready_next = 1'b0;
            // If there is a pending ST req. on the store buffer. Then, we should modify
            // the line before responding the LD or evicting the line
            if (store_buffer_hit_tag_ff | store_buffer_hit_way_ff)
            begin
                // Compute signals from the pending ST request
                req_tag    = pending_store_req_ff.addr[`DCACHE_TAG_ADDR_RANGE];
                req_size   = pending_store_req_ff.size;

                // Modify the D$ with the store buffer request information
                dCache_tag[req_target_pos_ff]   =  req_tag;
                dCache_dirty[req_target_pos_ff] = 1'b1; 
                dCache_valid[req_target_pos_ff] = 1'b1;

                if ( req_size == Byte)
                begin
                    req_offset = pending_store_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE];
                    dCache_data[req_target_pos_ff][`GET_LOWER_BOUND(`BYTE_BITS,req_offset)+:`BYTE_BITS] = pending_store_req_ff.data[`BYTE_RANGE];
                end
                else
                begin
                    req_offset = pending_store_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE] >> $clog2(pending_req_ff.size+1);
                    dCache_data[req_target_pos_ff][`GET_LOWER_BOUND(`DWORD_BITS,req_offset)+:`DWORD_BITS] = pending_store_req_ff.data[`DWORD_RANGE];
                end

                `ifdef VERBOSE_WRITE_CACHE_LINE
                    $display("[WRITE CACHE LINE]");
                    $display("                   req_target_pos_ff              = %h",req_target_pos_ff );
                    $display("                   req_offset                     = %h",req_offset );
                    $display("                   req_size                       = %h",req_size );
                    $display("                   pending_store_req_ff.data      = %h",pending_store_req_ff.data );
                    $display("                   dCache_data[req_target_pos_ff] = %h",dCache_data[req_target_pos_ff] );
                `endif

                // Check if there are more ST that affect the line on the store buffer.
                // If there is another ST that affects the same line or TAG, we perform
                // the write request
                search_store_buffer = 1'b1;
                search_tag         = pending_req_ff.addr[`DCACHE_TAG_ADDR_RANGE];
                if (store_buffer_hit_tag | store_buffer_hit_way)
                begin
                    dcache_state        = write_cache_line;
                end
                // Otherwise, if there are no more store_buff req. that affect this line.
                else
                begin
                    // If we were updating the line due to a LD hit we return the data and go to idle
                    if ( store_buffer_hit_tag_ff)
                    begin
                        req_size    = pending_req_ff.size;
                       
                        // If it was a LD request we return the data 
                        if (!pending_req_ff.is_store)
                        begin
                            if ( req_size == Byte)
                            begin
                                req_offset  = pending_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE];
                                rsp_data  = dCache_data[req_target_pos_ff] >> ((req_size+1)*`BYTE_BITS*req_offset) ;
                                rsp_data  = `ZX_BYTE(`DCACHE_MAX_ACC_SIZE, rsp_data[`BYTE_RANGE]);
                            end
                            else
                            begin
                                req_offset  = pending_req_ff.addr[`DCACHE_OFFSET_ADDR_RANGE] >> $clog2(pending_req_ff.size+1);
                                rsp_data  = dCache_data[req_target_pos_ff] >> ((req_size+1)*`BYTE_BITS*req_offset) ;
                                rsp_data  = `ZX_DWORD(`DCACHE_MAX_ACC_SIZE, rsp_data[`DWORD_RANGE]);
                            end

                            rsp_valid = 1'b1;
                        end
                
                        // Next stage 
                        dcache_ready_next   = 1'b1;                    
                        dcache_state        = idle;
                    end 
                    //Otherwise, if we were updating the line before an evict, we
                    //send the evict request
                    else
                    begin
                        // Send request to evict the line
                        req_info_miss.addr            = pending_store_req_ff.addr >> `DCACHE_ADDR_RSH_VAL; //Evict full line
                        req_info_miss.is_store        = 1'b1;
                        req_info_miss.data            = dCache_data[req_target_pos_ff];
                        req_valid_miss                = 1'b1;
                        
                        // Invalidate the line
                        dCache_valid[req_target_pos_ff] = 1'b0;
                        dCache_dirty[req_target_pos_ff] = 1'b0;

                        // Next stage
                        dcache_state    = evict_line;
                    end
                end                
            end
        end
    endcase
end

//////////////////////////////////////
// Dcache LRU logic

logic [`ICACHE_NUM_SET_RANGE] update_set;  
logic [`DCACHE_WAYS_PER_SET_RANGE] update_way;  
logic update_dcache_lru;

assign update_dcache_lru = dcache_tags_hit | 
                           ( (dcache_state_ff == bring_line) & rsp_valid_miss);

assign update_set = req_set ;

assign update_way = (dcache_tags_hit) ? hit_way  :
                                        req_target_pos_ff -  (req_size+1)*`BYTE_BITS*`DCACHE_WAYS_PER_SET; // bring new line 

// This module returns the oldest way accessed for a given set and updates the
// the LRU logic when there's a hit on the D$ or we bring a new line                        
cache_lru
#(
    .NUM_SET       ( `DCACHE_NUM_SET        ),
    .NUM_WAYS      ( `DCACHE_NUM_WAYS       ),
    .WAYS_PER_SET  ( `DCACHE_WAYS_PER_SET   )
)
dcache_lru
(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),

    // Info to select the victim
    .victim_req         ( !dcache_tags_hit  ),
    .victim_set         ( req_info.addr[`DCACHE_SET_ADDR_RANGE] ),
    .victim_way         ( miss_dcache_way   ),

    // Update the LRU logic
    .update_req         ( update_dcache_lru ),
    .update_set         ( update_set        ),
    .update_way         ( update_way        )
);

//////////////////////////////////////
// Dcache Store Buffer instance

store_buffer
store_buffer
(
    // System signals
    .clock              ( clock                 ),
    .reset              ( reset                 ),

    .buffer_empty       ( store_buffer_pending  ),
    .buffer_full        ( store_buffer_full     ),

    // Get the information from the oldest store on the buffer
    .get_oldest         ( store_buffer_perform  ),
    .oldest_info        ( store_buffer_pop_info ),

    // Push a new store to the buffer Update the LRU logic
    .push_valid         ( dcache_tags_hit & 
                          req_info.is_store     ),
    .push_info          ( store_buffer_push_info), 

    // Look for hit on store buffer
    .search_valid       ( search_store_buffer   ), 
    .search_tag         ( search_tag            ), 
    .search_way         ( miss_dcache_way       ), 
    .search_rsp_hit_tag ( store_buffer_hit_tag  ),
    .search_rsp_hit_way ( store_buffer_hit_way  ),
    .search_rsp         ( pending_store_req     )
);

endmodule 
