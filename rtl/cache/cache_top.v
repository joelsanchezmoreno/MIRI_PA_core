`include "soc.vh"

module cache_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    // Send stall pipeline request
    output  logic                               dcache_ready, 

    // Exception
    input   fetch_xcpt_t                        xcpt_fetch_in,
    output  fetch_xcpt_t                        xcpt_fetch_out,
    input   decode_xcpt_t                       xcpt_decode_in,
    output  decode_xcpt_t                       xcpt_decode_out,
    output  cache_xcpt_t                        xcpt_cache,
    
    // Receive stall pipeline request
    input   logic                               stall_pipeline,

    // Request from the ALU stage
    input   logic                               req_valid,
    input   dcache_request_t                    req_info,
    input   logic [`REG_FILE_ADDR_RANGE]        load_dst_reg,
    input   logic                               mem_instr,    
    input   logic                               int_instr,    
    input   logic [`PC_WIDTH_RANGE]             req_instr_pc,

    // Bypasses to previous stages and signals to WB
    output  logic [`REG_FILE_DATA_RANGE]        data_bypass,
    output  logic                               data_bp_valid,
    
    // Request to WB stage
    output  logic                               write_rf,
    output  logic [`REG_FILE_ADDR_RANGE]        dest_rf,
    output  logic [`DCACHE_MAX_ACC_SIZE-1:0]    rsp_data,
    output  logic [`PC_WIDTH_RANGE]             wb_instr_pc,
    
    // Request to the memory hierarchy
    output  logic                               req_valid_miss,
    output  memory_request_t                    req_info_miss,

    // Response from the memory hierarchy
    input   logic [`DCACHE_LINE_WIDTH-1:0]      rsp_data_miss,
    input   logic                               rsp_valid_miss
 );

//     CLK   EN            DOUT         DIN         
`EN_FF(clock,dcache_ready, wb_instr_pc, req_instr_pc)

//////////////////////////////////////////////////
// Exceptions
cache_xcpt_t  xcpt_cache_next;
logic xcpt_addr_fault_aux;

//      CLK    RST    DOUT             DIN             DEF
`RST_FF(clock, reset, xcpt_decode_out, xcpt_decode_in, '0)
`RST_FF(clock, reset, xcpt_fetch_out,  xcpt_fetch_in,  '0)
`RST_FF(clock, reset, xcpt_cache,      xcpt_cache_next,'0)

always_comb
begin
    xcpt_cache_next.xcpt_addr_fault = xcpt_addr_fault_aux;
    xcpt_cache_next.xcpt_fetch_dtlb_miss = '0; //FIXME connect to tlb
    xcpt_cache_next.xcpt_addr_val = req_info.addr;
    xcpt_cache_next.xcpt_pc       = req_instr_pc;
end

//////////////////////////////////////////////////
// Request to the Data Cache
logic dcache_req_valid;
assign dcache_req_valid = !stall_pipeline & dcache_ready & req_valid & mem_instr;

//////////////////////////////////////////////////
// Request to WB 
logic   req_is_load;
logic   write_rf_next;

logic [`DCACHE_MAX_ACC_SIZE-1:0] rsp_data_dcache;
logic [`DCACHE_MAX_ACC_SIZE-1:0] rsp_data_next;

//  CLK    DOUT      DIN
`FF(clock, rsp_data, rsp_data_next)

//      CLK    RST    DOUT      DIN           DEF
`RST_FF(clock, reset, write_rf, write_rf_next, '0)


//         CLK    RST    EN                                    DOUT         DIN                 DEF
`RST_EN_FF(clock, reset, req_valid & mem_instr & dcache_ready, req_is_load, !req_info.is_store, '0)
`RST_EN_FF(clock, reset, req_valid & dcache_ready            , dest_rf    , load_dst_reg      , '0)


// In case of LD request we will have to write that data on the RF.
// In addition, we also check if the request is for an ALU R type 
// instruction, which also writes on the RF.
logic dcache_rsp_valid;
assign write_rf_next = !stall_pipeline &
                       ( ((req_is_load | !req_info.is_store) & dcache_rsp_valid) |  // M-type instruction this cycle or the last one with a hit
                          (req_valid & int_instr )) ; // R-type instruction this cycle

assign rsp_data_next = (req_is_load & dcache_rsp_valid) ? rsp_data_dcache :  // M-type instruction (LDB or LDW)
                       req_info.data; // R-type instruction


// Data bypass
assign data_bp_valid = (int_instr) ? req_valid : ((req_is_load | !req_info.is_store) & dcache_rsp_valid);

assign data_bypass   = ((req_is_load | !req_info.is_store) & dcache_rsp_valid) ? rsp_data_dcache : 
                                                                                 req_info.data;

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
    .xcpt_address_fault ( xcpt_addr_fault_aux),
    
    // Request from the core pipeline
    .req_valid          ( dcache_req_valid  ),
    .req_info           ( req_info          ),

    // Response to the core pipeline
    .rsp_valid          ( dcache_rsp_valid  ),
    .rsp_data           ( rsp_data_dcache   ),
    
    // Request to the memory hierarchy
    .req_info_miss      ( req_info_miss     ),
    .req_valid_miss     ( req_valid_miss    ),
                    
    // Response from the memory hierarchy
    .rsp_data_miss      ( rsp_data_miss     ),
    .rsp_valid_miss     ( rsp_valid_miss    )
);
`ifdef VERBOSE_DECODE
always_ff @(posedge clock)
begin
    if (write_rf)
    begin
        $display("[CACHE]  Request to WB for RF. PC = %h",wb_instr_pc);
        $display("         dest_rf =  %h",dest_rf);
        $display("         rsp_data =  %h",rsp_data);
    end
    if (data_bp_valid)
    begin
        $display("[CACHE]  Request to WB for RF. PC = %h",wb_instr_pc);
        $display("         data_bypass =  %h",data_bypass);
    end
end
`endif
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

