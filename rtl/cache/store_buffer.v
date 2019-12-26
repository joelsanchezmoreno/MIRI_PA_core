`include "soc.vh"

module store_buffer 
(
    // System signals
    input   logic                       clock,
    input   logic                       reset,

    output  logic                       buffer_empty,
    output  logic                       buffer_full,

    // Search for the oldest store on the buffer 
    input   logic                       get_oldest,
    output  store_buffer_t              oldest_info,

    // Push a new store to the buffer 
    input   logic                       push_valid,
    input   store_buffer_t              push_info,

    // Look for the tag on the store buffer
    input   logic                               search_valid,
    input   logic [`DCACHE_TAG_RANGE]           search_tag,
    input   logic [`DCACHE_WAYS_PER_SET_RANGE]  search_way,
    output  logic                               search_rsp_hit_tag,
    output  logic                               search_rsp_hit_way,
    output  store_buffer_t                      search_rsp
 );

 ////////////////////////////////////////////////////////////////
// FUNCTIONS
////////////////////////////////////////////////////////////////

// Returns the first position in the buffer which valid signal is low
function automatic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] get_first_free_position;
    input logic [`DCACHE_ST_BUFFER_ENTRIES_RANGE] buffer_valid;

    logic found;
    begin
       get_first_free_position = '0;
       found = 1'b0;
       for ( int it = 0; it < `DCACHE_ST_BUFFER_NUM_ENTRIES; it++)
       begin
           if ( !found && !buffer_valid[it] )
           begin
               get_first_free_position  = it;
               found                    = 1'b1;                
           end
       end
    end
endfunction


//////////////////////////////////////////////////
// Store Buffer signals 
store_buffer_t  [`DCACHE_ST_BUFFER_ENTRIES_RANGE] store_buffer_info;
store_buffer_t  [`DCACHE_ST_BUFFER_ENTRIES_RANGE] store_buffer_info_ff;
logic           [`DCACHE_ST_BUFFER_ENTRIES_RANGE] store_buffer_valid;
logic           [`DCACHE_ST_BUFFER_ENTRIES_RANGE] store_buffer_valid_ff;

//  CLK    DOUT                  DIN       
`FF(clock, store_buffer_info_ff, store_buffer_info )

//      CLK    RST    DOUT                   DIN                 DEF
`RST_FF(clock, reset, store_buffer_valid_ff, store_buffer_valid, '0)

//////////////////////////////////////////////////
// Logic to control the oldest position and update the buffer if needed
localparam TREE_SIZE = 2*(`DCACHE_ST_BUFFER_NUM_ENTRIES)-1;
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] oldest_id;
logic [TREE_SIZE-1:0][`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] oldest_id_tree;
logic [TREE_SIZE-1:0][`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] maxcount_tree;
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] counter [`DCACHE_ST_BUFFER_NUM_ENTRIES-1:0];
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] counter_ff [`DCACHE_ST_BUFFER_NUM_ENTRIES-1:0];

assign buffer_empty = |store_buffer_valid_ff;
assign buffer_full  = (store_buffer_valid_ff == '1);
assign oldest_info  = store_buffer_info_ff[oldest_id];

// Since we have a circular buffer we need always to return the oldest store
// that hits on the store_buffer. Otherwise, if there are multiple stores for
// the same TAG/line we could return first the newest one, and then the latest
// one and if they target the same bytes we could be storing an old value.
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] max_count_search_tag;
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] max_count_search_way;
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] search_oldest;


genvar NODE_ID;
generate for (NODE_ID = 0; NODE_ID < (TREE_SIZE); ++NODE_ID) begin : TREE_GEN 
	localparam left_child = 2*NODE_ID + 1;
	localparam right_child = 2*NODE_ID + 2;
	if (NODE_ID >= (TREE_SIZE-`DCACHE_ST_BUFFER_NUM_ENTRIES)) begin
		//Leaf nodes, read from counter	
		assign maxcount_tree[NODE_ID] = counter_ff[NODE_ID-(`DCACHE_ST_BUFFER_NUM_ENTRIES-1)];
		assign oldest_id_tree[NODE_ID] = NODE_ID-(`DCACHE_ST_BUFFER_NUM_ENTRIES-1);
	end
	else begin
		assign maxcount_tree[NODE_ID]   = (maxcount_tree[left_child] <= maxcount_tree[right_child]) ? maxcount_tree[left_child]  : maxcount_tree[right_child]; 
		assign oldest_id_tree[NODE_ID]  = (maxcount_tree[left_child] <= maxcount_tree[right_child]) ? oldest_id_tree[left_child] : oldest_id_tree[right_child]; 
	end

end
endgenerate

assign oldest_id = oldest_id_tree[0];


generate for(genvar i = 0; i < `DCACHE_ST_BUFFER_NUM_ENTRIES; ++i) begin
    //      CLK    RST    DOUT           DIN         DEF
    `RST_FF(clock, reset, counter_ff[i], counter[i], '1 )
end
endgenerate

integer j,k;

logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] free_pos;

always_comb
begin
    // Mantain values for next clock
    store_buffer_info   = store_buffer_info_ff;
    store_buffer_valid  = store_buffer_valid_ff;

    search_rsp_hit_tag  = 1'b0;
    search_rsp_hit_way  = 1'b0;

    free_pos = '0;
    counter  = counter_ff;

    // Return victim ID
    if (get_oldest)
    begin
        store_buffer_valid[oldest_id] = 1'b0;
    end

    // Introduce a new entry
    if (push_valid)
    begin
        free_pos = get_first_free_position(store_buffer_valid_ff);
        store_buffer_valid[free_pos]    = 1'b1;
        store_buffer_info[free_pos]     = push_info;

        for (j = 0; j < `DCACHE_ST_BUFFER_NUM_ENTRIES; j++)
        begin
            // we increase in one the the buffer position as they get older
            counter[j] = counter_ff[j] + 1'b1;
        end

        // We reset the counter for the new block
        counter[free_pos] = '0;

    end // if (push_valid)

    // Search for a tag
    max_count_search_tag = '0;
    max_count_search_way = '0;
    if (search_valid)
    begin
        for (k = 0; k < `DCACHE_ST_BUFFER_NUM_ENTRIES; k++)
        begin
            // We check if there is a request on the buffer for the requested
            // TAG
            if ( search_tag == store_buffer_info_ff[k].addr[`DCACHE_TAG_ADDR_RANGE]
                 & store_buffer_valid_ff[k]  )
            begin
                search_rsp_hit_tag  = 1'b1;
                `ifdef VERBOSE_STORE_BUFFER
                    $display("[STORE BUFFER] search_rsp_hit_tag has been asserted");
                `endif
                // We always return the oldest one if there are multiple hits
                if ( max_count_search_tag <= counter_ff[k])
                begin
                    max_count_search_tag = counter_ff[k];
                    search_rsp           = store_buffer_info_ff[k];
                    search_oldest        = k;
                end
            end

            // We check if there is a request on the buffer for the requested
            // way
            if ( search_way == store_buffer_info_ff[k].way & store_buffer_valid_ff[k]  )
            begin
                `ifdef VERBOSE_STORE_BUFFER
                    $display("[STORE BUFFER] search_rsp_hit_way has been asserted");
                `endif
                search_rsp_hit_way = 1'b1;
                // We always return the oldest one if there are multiple hits.
                // In addition, we return the request that affects the way if
                // there is no request that affects the same TAG
                if (!search_rsp_hit_tag & (max_count_search_way <= counter_ff[k]))
                begin
                    max_count_search_way = counter_ff[k];
                    search_rsp           = store_buffer_info_ff[k];
                    search_oldest        = k;
                end
            end
        end
        
        if (search_rsp_hit_way | search_rsp_hit_tag) 
            store_buffer_valid[search_oldest] = 1'b0;
    end //!search_valid

end // always_comb

endmodule
