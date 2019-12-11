`include "soc.vh"

module store_buffer 
(
    // System signals
    input   logic               clock,
    input   logic               reset,

    output  logic               buffer_empty,

    // Search for the oldest store on the buffer 
    input   logic               get_oldest,
    output  store_buffer_t      oldest_info,

    // Push a new store to the buffer 
    input   logic               push_valid,
    input   store_buffer_t      push_info
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
store_buffer_t  [`DCACHE_ST_BUFFER_ENTRIES_RANGE] store_buffer_info,store_buffer_info_ff;
logic           [`DCACHE_ST_BUFFER_ENTRIES_RANGE] store_buffer_valid,store_buffer_valid_ff;

//  CLK    DOUT                  DIN       
`FF(clock, store_buffer_info_ff, store_buffer_info )

//      CLK    RST    DOUT                   DIN                 DEF
`RST_FF(clock, reset, store_buffer_valid_ff, store_buffer_valid, '0)

//////////////////////////////////////////////////
// Logic to control the oldest position and update the buffer if needed

assign buffer_empty = |store_buffer_valid_ff;
assign oldest_info = store_buffer_info_ff[oldest_id];

logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] counter, counter_ff;
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] max_count;
logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] oldest_id;

 //      CLK    RST    DOUT        DIN      DEF
`RST_FF(clock, reset, counter_ff, counter, '0 )

integer i,j;

logic [`DCACHE_ST_BUFFER_ENTRIES_WIDTH-1:0] free_pos;

always_comb
begin
    // Mantain values for next clock
    store_buffer_info   = store_buffer_info_ff;
    store_buffer_valid  = store_buffer_valid_ff;

    // Return victim ID
    if (get_oldest)
    begin
        max_count = '0;
        for (i = 0; i < `DCACHE_ST_BUFFER_NUM_ENTRIES; i++)
        begin
            // we look for the oldest way on the set
            if ( store_buffer_valid_ff[i]  &
                 max_count < counter_ff[i]  )
            begin
                max_count   = counter_ff[i];
                oldest_id   = i;
            end
        end
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
            if ( j != free_pos )
                counter[j] = counter_ff[j] + 1'b1;
        end

        // We reset the counter for the new block
        counter[free_pos] = '0;

    end // if (push_valid)
end // always_comb

endmodule
