`include "soc.vh"

module dcache_lru 
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    // Search for a victim 
    input   logic                               victim_req,
    input   logic   [`DCACHE_NUM_SET_WIDTH_R]   victim_set,
    output  logic   [`DCACHE_NUM_WAY_WIDTH_R]   victim_way,

    // Update the set LRU
    input   logic                               update_req,
    input   logic   [`DCACHE_NUM_SET_WIDTH_R]   update_set,
    input   logic   [`DCACHE_NUM_WAY_WIDTH_R]   update_way
 );


logic [`DCACHE_NUM_SET_WIDTH_R][`DCACHE_NUM_WAY_WIDTH_R] victim_per_set;

assign victim_pos = victim_per_set[victim_set];

genvar gen_it;

generate
    for (gen_it = 0; gen_it < DCACHE_NUM_SET; gen_it++) 
    begin :gen_set_lru

        logic [`DCACHE_NUM_WAYS_R][`DCACHE_WAYS_PER_SET_RANGE]  counter;
        logic [`DCACHE_WAYS_PER_SET_RANGE]                      max_count;
        logic [`DCACHE_NUM_WAY_WIDTH_R]                         victim_id;
        
        integer i,j;
        always_comb
        begin
            // Return victim ID
            if (victim_req and victim_set == gen_it )
            begin
                for (i = 0; i < `DCACHE_WAYS_PER_SET ; i++)
                begin
                    // we look for the oldest way on the set
                    if ( max_count < counter_ff[i] )
                    begin
                        max_count = counter_ff[i];
                        victim_id = i;
                    end
                end
            end
        
            // Replace victim with the new line
            if (update_req and update_set == gen_it)
            begin
                for (j = 0; j < `DCACHE_WAYS_PER_SET; j++)
                begin
                    // we increase in one the ways as they get older
                    if ( j != id_victim )
                        counter[j] = counter_ff[j] + 1'b1;
                end

                // We reset the counter for the new block
                counter[update_way] = '0;

            end // if (update_req)
        end // always_comb
    end // for (gen_it = 0; gen_it < DCACHE_NUM_SET; gen_it++)
endgenerate
