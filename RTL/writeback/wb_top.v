`include "soc.vh"

module wb_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    // Exceptions
    input   fetch_xcpt_t                        xcpt_fetch,
    input   decode_xcpt_t                       xcpt_decode,
    input   cache_xcpt_t                        xcpt_cache,    
     
    // Request from cache stage
    input   logic                               cache_req_write_rf,
    input   logic [`REG_FILE_ADDR_RANGE]        cache_req_dest_rf,
    input   logic [`DCACHE_MAX_ACC_SIZE-1:0]    cache_req_rsp_data,

    // Request to RF
    output  logic [`REG_FILE_DATA_RANGE] 		req_to_RF_data,
    output  logic 				                req_to_RF_writeEn,
    output  logic [`REG_FILE_ADDR_RANGE] 		req_to_RF_dest,

    // Exceptions values to be stored on the RF
    output  logic 				                xcpt_valid,
    output  logic [`PC_WIDTH_RANGE] 		    rmPC,
    output  logic [`REG_FILE_ADDR_RANGE] 		rmAddr
);


// Exception priorities
always_comb
begin
    xcpt_valid = 1'b0;

end

// RF write requests
always_comb
begin
   req_to_RF_data    = cache_req_rsp_data;
   req_to_RF_writeEn = cache_req_write_rf;
   req_to_RF_dest    = cache_req_dest_rf;
end

endmodule
