`include "soc.vh"

module icache_lru 
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    // Search for a victim 
    input   logic                               victim_req,
    input   logic   [`ICACHE_NUM_SET_RANGE]     victim_set,
    output  logic   [`ICACHE_NUM_WAY_RANGE]     victim_way,

    // Update the set LRU
    input   logic                               update_req,
    input   logic   [`ICACHE_NUM_SET_RANGE]     update_set,
    input   logic   [`ICACHE_NUM_WAY_RANGE]     update_way
 );


logic [`ICACHE_NUM_SET_RANGE][`ICACHE_NUM_WAY_RANGE] victim_per_set;

assign victim_way = victim_per_set[victim_set];

genvar gen_it;

generate
    for (gen_it = 0; gen_it < ICACHE_NUM_SET; gen_it++) 
    begin :gen_set_lru

        logic [`ICACHE_WAYS_PER_SET_RANGE]   max_count;
        logic [`ICACHE_NUM_WAYS-1:0][`ICACHE_WAYS_PER_SET_RANGE]  counter,counter_ff;

        //      CLK    RST    DOUT        DIN      DEF
        `RST_FF(clock, reset, counter_ff, counter, '0 )

        integer i,j;
        always_comb
        begin
            // Return victim ID
            if (victim_req and victim_set == gen_it )
            begin
                for (i = 0; i < `ICACHE_WAYS_PER_SET ; i++)
                begin
                    // we look for the oldest way on the set
                    if ( max_count < counter_ff[i] )
                    begin
                        max_count = counter_ff[i];
                        victim_per_set[gen_it] = i;
                    end
                end
            end
        
            // Replace victim with the new line
            if (update_req and update_set == gen_it)
            begin
                for (j = 0; j < `ICACHE_WAYS_PER_SET; j++)
                begin
                    // we increase in one the ways as they get older
                    if ( j != victim_per_set[gen_it] )
                        counter[j] = counter_ff[j] + 1'b1;
                end

                // We reset the counter for the new block
                counter[update_way] = '0;

            end // if (update_req)
        end // always_comb
    end // for (gen_it = 0; gen_it < ICACHE_NUM_SET; gen_it++)
endgenerate
endmodule
