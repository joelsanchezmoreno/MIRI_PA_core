`include "soc.vh"

module cache_lru
#(
    parameter NUM_SET        = `ICACHE_NUM_SET,
    parameter NUM_WAYS       = `ICACHE_NUM_WAYS,
    parameter WAYS_PER_SET   = `ICACHE_WAYS_PER_SET,
    parameter NUM_SET_W      = $clog2(NUM_SET),
    parameter NUM_WAYS_W     = $clog2(NUM_WAYS),
    parameter WAYS_PER_SET_W = $clog2(WAYS_PER_SET) 
)
(
    // System signals
    input   logic                       clock,
    input   logic                       reset,

    // Search for a victim 
    input   logic                       victim_req,
    input   logic  [NUM_SET_W-1:0]      victim_set,
    output  logic  [WAYS_PER_SET_W-1:0] victim_way,

    // Update the set LRU
    input   logic                       update_req,
    input   logic  [NUM_SET_W-1:0]      update_set,
    input   logic  [WAYS_PER_SET_W-1:0] update_way
 );


logic [WAYS_PER_SET_W-1:0] victim_per_set [NUM_SET-1:0];

assign victim_way = victim_per_set[victim_set];

genvar gen_it;

generate
    for (gen_it = 0; gen_it < NUM_SET; gen_it++) 
    begin :gen_set_lru

        logic [WAYS_PER_SET-1:0][WAYS_PER_SET_W-1:0]  counter;
        logic [WAYS_PER_SET-1:0][WAYS_PER_SET_W-1:0]  counter_ff;
        //logic [NUM_WAYS_W-1:0][WAYS_PER_SET-1:0]  counter;
        //logic [NUM_WAYS_W-1:0][WAYS_PER_SET-1:0]  counter_ff;
        logic [WAYS_PER_SET_W-1:0]                max_count;
        
        //      CLK    RST    DOUT        DIN      DEF
        `RST_FF(clock, reset, counter_ff, counter, '0 )

        integer i,j;
        always_comb
        begin
            counter = counter_ff;
            // Return victim ID
            if (victim_req && victim_set == gen_it )
            begin
                max_count = '0;
                victim_per_set[gen_it] = '0;
                for (i = 0; i < WAYS_PER_SET ; i++)
                begin
                    // we look for the oldest way on the set
                    if ( max_count < counter_ff[i] )
                    begin
                        max_count               = counter_ff[i];
                        victim_per_set[gen_it]  = i;
                    end
                end
            end
        
            // Replace victim with the new line
            if (update_req && update_set == gen_it)
            begin
                for (j = 0; j < WAYS_PER_SET; j++)
                begin
                    // we increase in one the ways as they get older
                    if ( counter_ff[j] <= counter_ff[update_way] )
                        counter[j] = counter_ff[j] + 1'b1;
                end

                // We reset the counter for the new block
                counter[update_way] = '0;

            end // if (update_req)
        end // always_comb
    end // for (gen_it = 0; gen_it < NUM_SET; gen_it++)
endgenerate
endmodule
