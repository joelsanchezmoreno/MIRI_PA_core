// Instruction Cache does not allow write requests from the fetch logic, only
// reads are allowed. The Instruction cache implementation must
// ensure that one request can be served each cycle if there are no misses.
// Otheriwse, in case of a miss it takes `MAIN_MEMORY_LATENCY cycles to go to 
// memory and bring the line. 

module instruction_cache
(
    input  logic                            clock,
    input  logic                            reset,

    // Request from the core pipeline
    input  logic [`ICACHE_ADDR_WIDTH-1:0]   req_addr,
    input  logic                            req_valid,

    // Response to the core pipeline
    output logic [`ICACHE_LINE_WIDTH-1:0]   rsp_data,
    output logic                            rsp_valid,

    // Request to the memory hierarchy
    output logic [`ICACHE_ADDR_WIDTH-1:0]   req_addr_miss,
    output logic                            req_valid_miss,

    // Response from the memory hierarchy
    input  logic [`ICACHE_LINE_WIDTH-1:0]   rsp_data_miss,
    input  logic                            rsp_valid_miss
);

logic [`ICACHE_LINE_WIDTH-1:0] instMem_data,instMem_data_ff [`ICACHE_NUM_WAYS-1:0];
logic [`ICACHE_TAG_WIDTH-1:0]  instMem_tag, instMem_tag_ff  [`ICACHE_NUM_WAYS-1:0];
logic [`ICACHE_NUM_WAYS-1:0]   instMem_valid, instMem_valid_ff;

//  CLK        DOUT         DIN           DEF
`FF(clock, instMem_data_ff, instMem_data, '0)
`FF(clock, instMem_tag_ff , instMem_tag , '0)

//      CLK    RST    DOUT               DIN           DEF
`RST_FF(clock, reset, instMem_valid_ff, instMem_valid, '0)

logic tag_miss; // asserted when there is a miss on the instr. cache
logic icache_hit;
logic [`ICACHE_TAG_WIDTH-1:0]   tag_icache_line; // TAG of the line stored in the icache
logic [`ICACHE_NUM_WAY_LOG-1:0] req_addr_pos; // Position of the data in case there is a hit on tag array
logic [`ICACHE_NUM_SET_LOG-1:0] miss_icache_set_ff; // Position of the victim in case of replacement 
logic [`ICACHE_NUM_WAY_LOG-1:0] miss_icache_way, miss_icache_way_ff; // Position of the victim in case of replacement 

//         CLK    RST    EN        DOUT                DIN              DEF
`RST_EN_FF(clock, reset, tag_miss, miss_icache_set_ff, req_addr_set,    '0)
`RST_EN_FF(clock, reset, tag_miss, miss_icache_way_ff, miss_icache_way, '0)

logic icache_ready_next;

//      CLK    RST    DOUT          DIN                DEF
`RST_FF(clock, reset, icache_ready, icache_ready_next, '0)


integer iter;

always_comb
begin
    // Mantain values for next clock
    instMem_valid       = instMem_valid_ff;
    instMem_tag         = instMem_tag_ff;
    instMem_data        = instMem_data_ff;
    icache_ready_next   = icache_ready;

    // There is a miss if the tag is not stored
    req_addr_tag    = req_addr[`ICACHE_TAG_R];
    req_addr_set    = req_addr[`ICACHE_SET_R]; 
    
    icache_hit   = 1'b0;
    req_addr_pos = '0; 

    // Look if the tag is on the cache
    for (iter = 0; iter < `ICACHE_WAYS_PER_SET; i++)
    begin
        if ((instMem_tag[iter + req_addr_set*`ICACHE_WAYS_PER_SET]   == req_addr_tag) &
             instMem_valid[iter + req_addr_set*`ICACHE_WAYS_PER_SET] == 1'b1)
        begin
            req_addr_pos      = iter + req_addr_set*`ICACHE_WAYS_PER_SET;
            icache_hit        = 1'b1;
        end

    end
    
    // If there is a request from the fetch stage and there is no hit, we
    // have a miss
    tag_miss = (req_valid & icache_hit) ? 1'b0 : 1'b1;

    // If there is a miss we send a request to main memory to get the line
    if ( tag_miss )
    begin
        req_addr_miss                   = req_addr;
        req_valid_miss                  = 1'b1;
        icache_ready_next               = 1'b0;
    end

    // We wait until we receive the response from main memory. Then, we update
    // the tag, data and valid information for the position related to that
    // tag 
    if (rsp_valid_miss)
    begin
        miss_icache_pos = miss_icache_way_ff + miss_icache_set_ff*`ICACHE_WAYS_PER_SET;;
        instMem_tag[miss_icache_pos]   = req_addr_tag;
        instMem_data[miss_icache_pos]  = rsp_data_miss;
        instMem_valid[miss_icache_pos] = 1'b1; 
        icache_ready_next                 = 1'b1;
    end
end

assign rsp_data  = ( rsp_valid_miss ) ? instMem_data[miss_icache_pos] : // if there is a response for a miss
                   ( !tag_miss      ) ? instMem_data[req_addr_pos]    : // if we hit on the first access
                                        '0;                             // default

assign rsp_valid = ( rsp_valid_miss ) ? 1'b1 : // if there is a response for a miss
                   ( !tag_miss      ) ? 1'b1 : // if we hit on the first access
                                        1'b0;  // default


icache_lru
icache_lru
(
    // System signals
    .clock              ( clock                 ),
    .reset              ( reset                 ),
    // Victim read port
    .victim_req         ( tag_miss              ),
    .victim_set         ( req_addr_set          ),
    .victim_way         ( miss_icache_way       ),

    // Update
    .update_req         ( rsp_valid_miss        ),
    .update_set         ( miss_icache_set_ff    ),
    .update_way         ( miss_icache_way_ff    )
)

);

endmodule 
