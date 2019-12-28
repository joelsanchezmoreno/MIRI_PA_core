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

logic cache_hazard;
assign cache_hazard = (!dcache_ready & !dcache_rsp_valid) | stall_pipeline;

//////////////////////////////////////////////////
// Exceptions
decode_xcpt_t  xcpt_decode_ff; 
fetch_xcpt_t   xcpt_fetch_ff;

cache_xcpt_t  xcpt_cache_next;
cache_xcpt_t  xcpt_cache_ff;
logic xcpt_addr_fault_aux;


//         CLK    RST    EN            DOUT            DIN             DEF
`RST_EN_FF(clock, reset, !cache_hazard, xcpt_fetch_ff,  xcpt_fetch_in,  '0)
`RST_EN_FF(clock, reset, !cache_hazard, xcpt_decode_ff, xcpt_decode_in, '0)
`RST_EN_FF(clock, reset, !cache_hazard, xcpt_cache_ff,  xcpt_cache_next,'0)

always_comb
begin
    xcpt_cache_next.xcpt_addr_fault = xcpt_addr_fault_aux;
    xcpt_cache_next.xcpt_fetch_dtlb_miss = '0; //FIXME connect to tlb
    xcpt_cache_next.xcpt_addr_val = req_info.addr;
    xcpt_cache_next.xcpt_pc       = req_instr_pc;
end

assign xcpt_fetch_out   = (cache_hazard) ? xcpt_fetch_out  : xcpt_fetch_ff;
assign xcpt_decode_out  = (cache_hazard) ? xcpt_decode_out : xcpt_decode_ff;
assign xcpt_cache       = (cache_hazard) ? xcpt_cache      : xcpt_cache_ff;

//////////////////////////////////////////////////
// Request to WB 
logic   req_is_load;
logic   req_is_load_ff;
logic [`REG_FILE_ADDR_RANGE] dest_rf_ff;
logic [`PC_WIDTH_RANGE]      wb_instr_pc_ff;

logic   write_rf_next;
logic   write_rf_ff;

logic [`DCACHE_MAX_ACC_SIZE-1:0] rsp_data_dcache;
logic [`DCACHE_MAX_ACC_SIZE-1:0] rsp_data_next;
logic [`DCACHE_MAX_ACC_SIZE-1:0] rsp_data_ff;

//         CLK    RST    EN             DOUT         DIN            DEF
`RST_EN_FF(clock, reset, !cache_hazard, write_rf_ff, write_rf_next, '0)

//     CLK    EN                                DOUT            DIN         
`EN_FF(clock, !cache_hazard & mem_instr,        req_is_load_ff, !req_info.is_store)
`EN_FF(clock, !cache_hazard,                    dest_rf_ff    , load_dst_reg      )
`EN_FF(clock, !cache_hazard,                    wb_instr_pc_ff, req_instr_pc      )
`EN_FF(clock, !cache_hazard | dcache_rsp_valid, rsp_data_ff,    rsp_data_next     )


assign write_rf     = (cache_hazard) ? 1'b0         : write_rf_ff;
assign req_is_load  = (cache_hazard) ? req_is_load  : req_is_load_ff;
assign dest_rf      = (cache_hazard) ? dest_rf      : dest_rf_ff;
assign rsp_data     = (cache_hazard) ? rsp_data     : rsp_data_ff;
assign wb_instr_pc  = (cache_hazard) ? wb_instr_pc  : wb_instr_pc_ff;

// In case of LD request we will have to write that data on the RF.
// In addition, we also check if the request is for an ALU R type 
// instruction, which also writes on the RF.
logic dcache_rsp_valid;
assign write_rf_next =  !stall_pipeline &
                       &(   ((req_is_load | !req_info.is_store) & dcache_rsp_valid)  // M-type instruction this cycle or the last one with a hit
                          | (req_valid & int_instr )) ; // R-type instruction this cycle

assign rsp_data_next = ((req_is_load | !req_info.is_store ) & dcache_rsp_valid) ? rsp_data_dcache :  // M-type instruction (LDB or LDW)
                       req_info.data; // R-type instruction


//////////////////////////////////////////////////
// Data bypass

assign data_bp_valid = ((req_is_load | !req_info.is_store) & dcache_rsp_valid) ? 1'b1 :
                       (cache_hazard) ? data_bp_valid :
                       (int_instr)    ? req_valid     : 
                                        1'b0;

                                                               
assign data_bypass = (cache_hazard) ? data_bypass : 
                     ((req_is_load | !req_info.is_store) & dcache_rsp_valid) ? rsp_data_dcache : 
                                                                               req_info.data;


//////////////////////////////////////////////////
// Request to the Data Cache
logic dcache_req_valid;
assign dcache_req_valid = dcache_ready & req_valid & mem_instr;

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

