// Instruction Cache does not allow write requests and its implementation must
// ensure that one request can be served each cycle if there are no misses.
// Otheriwse, in case of a miss it takes `MAIN_MEMORY_LATENCY cycles to got to 
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

logic [`ICACHE_LINE_WIDTH-1:0] instMem_data,instMem_data_ff [`ICACHE_NUM_LINES-1:0];
logic [`ICACHE_TAG_WIDTH-1:0]  instMem_tag, instMem_tag_ff  [`ICACHE_NUM_LINES-1:0];
logic [`ICACHE_NUM_LINES-1:0]  instMem_valid, instMem_valid_ff;

//  CLK        DOUT         DIN           DEF
`FF(clock, instMem_data_ff, instMem_data, '0)
`FF(clock, instMem_tag_ff , instMem_tag , '0)

//      CLK    RST    DOUT               DIN           DEF
`RST_FF(clock, reset, instMem_valid_ff, instMem_valid, '0)

logic tag_miss; // asserted when there is a miss on the instr. cache
logic valid_icache_line;
logic [`ICACHE_TAG_WIDTH-1:0]   tag_icache_line; // TAG of the line stored in the icache
logic [`ICACHE_NUM_LIN_LOG-1:0] req_addr_pos, req_addr_pos_ff; // Position where data should be allocated for the given address

//         CLK    RST    EN         DOUT             DIN           DEF
`RST_EN_FF(clock, reset, req_valid, req_addr_pos_ff, req_addr_pos, '0)

logic icache_ready_next;

//      CLK    RST    DOUT          DIN                DEF
`RST_FF(clock, reset, icache_ready, icache_ready_next, '0)

always_comb
begin
    // Mantain values for next clock
    instMem_valid       = instMem_valid_ff;
    instMem_tag         = instMem_tag_ff;
    instMem_data        = instMem_data_ff;
    icache_ready_next   = icache_ready;

    // There is a miss if the tag is not stored
    req_addr_tag    = req_addr[`ICACHE_TAG_R];

    //FIXME: THE NEXT 3 LINES DEPEND ON THE REPLACEMENT ALGORITHM AND THE
    //       CACHE TYPE
    req_addr_pos      = XXXXX; 
    tag_icache_line   = instMem_tag[req_addr_pos]; 
    valid_icache_line = instMem_valid[req_addr_pos];

    tag_miss          = (req_valid & valid_icache_line &
                         (tag_icache_line != req_addr_tag)) ? 1'b1 : 1'b0;

    // If there is a miss we send a request to main memory to get the line
    if ( tag_miss )
    begin
        req_addr_miss               = req_addr;
        req_valid_miss              = 1'b1;
        //FIXME: next line may change depending on the cache type
        instMem_valid[req_addr_pos] = 1'b0; // We invalidate the line that will be replaced
        icache_ready_next           = 1'b0;
    end

    // We wait until we reach the specified latency
    if (rsp_valid_miss)
    begin
        instMem_tag[req_addr_pos_ff]   = req_addr_tag;
        instMem_data[req_addr_pos_ff]  = rsp_data_miss;
        instMem_valid[req_addr_pos_ff] = 1'b1; 
        icache_ready_next              = 1'b1;
    end
end

assign rsp_data  = ( rsp_valid_miss ) ? instMem_data[req_addr_pos_ff] : // if there is a response for a miss
                   ( !tag_miss      ) ? instMem_data[req_addr_pos]    : // if we hit on the first access
                                        '0;                             // default

assign rsp_valid = ( rsp_valid_miss ) ? 1'b1 : // if there is a response for a miss
                   ( !tag_miss      ) ? 1'b1 : // if we hit on the first access
                                        1'b0;  // default

endmodule 
