`include "soc.vh"

module cache_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    // Send stall pipeline request
    output  logic                               dcache_ready, 

    // Receive stall pipeline request
    input   logic                               stall_pipeline,

    // Request from the ALU stage
    input   logic                               req_valid,
    input   dcache_request_t                    req_info,
    input   logic [`REG_FILE_ADDR_RANGE]        load_dst_reg,

    // Bypasses to previous stages
    output  logic                               write_rf,
    output  logic [`REG_FILE_ADDR_RANGE]        dest_rf,
    output  logic [`DCACHE_MAX_ACC_SIZE-1:0]    rsp_data,
    
    // Request to the memory hierarchy
    output  logic                               req_valid_miss,
    output  memory_request_t                    req_info_miss,

    // Response from the memory hierarchy
    input   logic [`DCACHE_LINE_WIDTH-1:0]      rsp_data_miss,
    input   logic                               rsp_valid_miss
 );

//////////////////////////////////////////////////
// Request to the Data Cache
logic dcache_req_valid;
assign dcache_req_valid = !stall_pipeline & dcache_ready & req_valid;

//////////////////////////////////////////////////
// Logic to write on the RF the LD response
logic req_is_load;

//         CLK    RST    EN         DOUT         DIN                 DEF
`RST_EN_FF(clock, reset, req_valid, req_is_load, !req_info.is_store, '0)
`RST_EN_FF(clock, reset, req_valid, dest_rf    , load_dst_reg,       '0)

// In case of LD request we will have to write that data on the RF
assign write_rf = !stall_pipeline & req_is_load & rsp_valid;

//////////////////////////////////////////////////
// Data Cache instance
data_cache
dcache
(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),
    .dcache_ready       ( dcache_ready      ),

    // Exception
    .xcpt_address_fault ( xcpt_address_fault), //FIXME
    
    // Request from the core pipeline
    .req_valid          ( dcache_req_valid  ),
    .req_info           ( req_info          ),

    // Response to the core pipeline
    .rsp_valid          ( rsp_valid         ),
    .rsp_data           ( rsp_data          ),
    
    // Request to the memory hierarchy
    .req_addr_miss      ( req_addr_miss     ),
    .req_valid_miss     ( req_valid_miss    ),
                    
    // Response from the memory hierarchy
    .rsp_data_miss      ( rsp_data_miss     ),
    .rsp_valid_miss     ( rsp_valid_miss    )
);

/*
//FIXME: Create module
data_tlb
itlb
(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),

    // Request from the core pipeline
    .req_valid          (                   ),
    .req_addr           (                   ),

    // Response to the core pipeline
    .rsp_valid          (                   ),
    .rsp_data           (                   ),
    
    // Request to the memory hierarchy
    .req_addr_miss      (                   ),
    .req_valid_miss     (                   ),
                    
    // Response from the memory hierarchy
    .rsp_data_miss      (                   ),
    .rsp_valid_miss     (                   )
);
*/
endmodule

