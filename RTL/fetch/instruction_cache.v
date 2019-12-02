// Instruction Cache does not allow write requests and its implementation must
// ensure that one request can be served each cycle if there are no misses.
// Otheriwse, in case of a miss it takes 5 cycles to got to memory and bring
// the line. 

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
logic [`ICACHE_TAG_WIDTH-1:0] tag_icache_line; // TAG of the line stored in the icache
logic [`ICACHE_NUM_LIN_LOG-1:0] req_addr_pos, req_addr_pos_ff; // Position where data should be allocated for the given address

//         CLK    RST    EN         DOUT             DIN           DEF
`RST_EN_FF(clock, reset, req_valid, req_addr_pos_ff, req_addr_pos, '0)

always_comb
begin
    // Mantain values for next clock
    instMem_valid = instMem_valid_ff;
    instMem_tag   = instMem_tag_ff;
    instMem_data  = instMem_data_ff;

    // There is a miss if the tag is not stored
    req_addr_tag    = XXXXX; //FIXME
    req_addr_pos    = XXXXX; //FIXME: in which line the data should be
    tag_icache_line = instMem_tag[req_addr_pos]; //FIXME
    tag_miss        = (req_valid & (tag_icache_line != req_addr_tag) & !rsp_valid_miss) ? 1'b1 : 1'b0;

    // If there is a miss we send a request to main memory to get the line
    if ( tag_miss )
    begin
        req_addr_miss               = req_addr;
        req_valid_miss              = 1'b1;
        instMem_valid[req_addr_pos] = 1'b0; // We invalidate the line that will be replaced
    end

    // We wait until we reach the specified latency
    if (rsp_valid_miss)
    begin
        instMem_tag[req_addr_pos_ff]   = req_addr_tag;
        instMem_data[req_addr_pos_ff]  = rsp_data_miss;
        instMem_valid[req_addr_pos_ff] = 1'b1; 
    end
end

assign rsp_data  = instMem_data[req_addr_pos_ff];
assign rsp_valid = (!tag_miss & instMem_valid[req_addr_pos_ff]);

endmodule 
