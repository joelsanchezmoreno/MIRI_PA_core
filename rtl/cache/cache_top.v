`include "soc.vh"

module cache_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,
    input   priv_mode_t                         priv_mode,

    // Send stall pipeline request
    output  logic                               dcache_ready,
    input   logic                               flush_cache, 

    // Exception
    input   fetch_xcpt_t                        xcpt_fetch_in,
    output  fetch_xcpt_t                        xcpt_fetch_out,
    input   decode_xcpt_t                       xcpt_decode_in,
    output  decode_xcpt_t                       xcpt_decode_out,
    input   alu_xcpt_t                          xcpt_alu_in,
    output  alu_xcpt_t                          xcpt_alu_out,
    output  cache_xcpt_t                        xcpt_cache,
    
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
    input   logic                               rsp_bus_error,
    input   logic                               rsp_valid_miss,

 /////// TLB ports
    // Request from ALU stage
    input   logic                               alu_tlb_req_valid,
    input   logic                               alu_tlb_id,
    input   tlb_req_info_t                      alu_tlb_req_info,

    // Request to WB stage
    output  logic                               tlb_to_wb_req_valid,
    output  logic                               tlb_to_wb_id,
    output  tlb_req_info_t                      tlb_to_wb_req_info,
    
    // Request from WB stage to add a new entry
    input   logic                               new_tlb_entry,
    input   tlb_req_info_t                      new_tlb_info
);

logic cache_hazard;
assign cache_hazard = (!dcache_ready & !dcache_rsp_valid);

//////////////////////////////////////////////////
// TLB write
logic           alu_tlb_req_valid_ff;
logic           alu_tlb_id_ff;
tlb_req_info_t  alu_tlb_req_info_ff;

//         CLK    RST                  EN             DOUT                  DIN                 DEF
`RST_EN_FF(clock, reset | flush_cache, !cache_hazard, alu_tlb_req_valid_ff, alu_tlb_req_valid,  '0)

//     CLK    EN             DOUT                  DIN 
`EN_FF(clock, !cache_hazard, alu_tlb_id_ff,        alu_tlb_id      )
`EN_FF(clock, !cache_hazard, alu_tlb_req_info_ff,  alu_tlb_req_info)

assign tlb_to_wb_req_valid  = (cache_hazard) ? tlb_to_wb_req_valid : alu_tlb_req_valid_ff;
assign tlb_to_wb_id         = (cache_hazard) ? tlb_to_wb_id        : alu_tlb_id_ff;
assign tlb_to_wb_req_info   = (cache_hazard) ? tlb_to_wb_req_info  : alu_tlb_req_info_ff;

//////////////////////////////////////////////////
// Exceptions
fetch_xcpt_t   xcpt_fetch_ff;
decode_xcpt_t  xcpt_decode_ff; 
alu_xcpt_t     xcpt_alu_ff;

cache_xcpt_t  xcpt_cache_next;
cache_xcpt_t  xcpt_cache_ff;
logic xcpt_bus_error;
logic xcpt_dtlb_miss;

//         CLK    RST                  EN            DOUT            DIN             DEF
`RST_EN_FF(clock, reset | flush_cache, !cache_hazard, xcpt_fetch_ff,  xcpt_fetch_in,  '0)
`RST_EN_FF(clock, reset | flush_cache, !cache_hazard, xcpt_decode_ff, xcpt_decode_in, '0)
`RST_EN_FF(clock, reset | flush_cache, !cache_hazard, xcpt_alu_ff,    xcpt_alu_in,    '0)
`RST_EN_FF(clock, reset | flush_cache, !cache_hazard, xcpt_cache_ff,  xcpt_cache_next,'0)

always_comb
begin
    xcpt_cache_next.xcpt_bus_error  = xcpt_bus_error    ;
    xcpt_cache_next.xcpt_dtlb_miss  =   xcpt_dtlb_miss 
                                      | (!dTlb_write_privilege & dTlb_rsp_valid & req_info.is_store); 
    xcpt_cache_next.xcpt_addr_fault = 1'b0; //FIXME: We do not have different privilege modes
    xcpt_cache_next.xcpt_addr_val   = req_info.addr;
    xcpt_cache_next.xcpt_pc         = req_instr_pc;
end

assign xcpt_fetch_out   = (cache_hazard) ? xcpt_fetch_out  : xcpt_fetch_ff;
assign xcpt_decode_out  = (cache_hazard) ? xcpt_decode_out : xcpt_decode_ff;
assign xcpt_alu_out     = (cache_hazard) ? xcpt_alu_out    : xcpt_alu_ff;
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

//         CLK    RST    EN                           DOUT         DIN            DEF
`RST_EN_FF(clock, reset, !cache_hazard | flush_cache, write_rf_ff, write_rf_next, '0)

//     CLK    EN                                DOUT            DIN         
`EN_FF(clock, !cache_hazard & mem_instr,        req_is_load_ff, !req_info.is_store)
`EN_FF(clock, !cache_hazard,                    dest_rf_ff    , load_dst_reg      )
`EN_FF(clock, !cache_hazard,                    wb_instr_pc_ff, req_instr_pc      )
`EN_FF(clock, !cache_hazard | dcache_rsp_valid, rsp_data_ff,    rsp_data_next     )


assign write_rf     = (cache_hazard | flush_cache) ? 1'b0         : write_rf_ff;
assign req_is_load  = (cache_hazard | flush_cache) ? req_is_load  : req_is_load_ff;
assign dest_rf      = (cache_hazard | flush_cache) ? dest_rf      : dest_rf_ff;
assign rsp_data     = (cache_hazard | flush_cache) ? rsp_data     : rsp_data_ff;
assign wb_instr_pc  = (cache_hazard | flush_cache) ? wb_instr_pc  : wb_instr_pc_ff;

// In case of LD request we will have to write that data on the RF.
// In addition, we also check if the request is for an ALU R type 
// instruction, which also writes on the RF.
logic dcache_rsp_valid;
assign write_rf_next =  ( flush_cache ) ? 1'b0 :
                                          (((req_is_load | !req_info.is_store) & dcache_rsp_valid)  // M-type instruction this cycle or the last one with a hit
                                            |(req_valid & int_instr )) ; // R-type instruction this cycle

assign rsp_data_next = ((req_is_load | !req_info.is_store ) & dcache_rsp_valid) ? rsp_data_dcache :  // M-type instruction (LDB or LDW)
                       req_info.data; // R-type instruction


//////////////////////////////////////////////////
// Data bypass

assign data_bp_valid = ( flush_cache )                                          ? 1'b0 :
                       ((req_is_load | !req_info.is_store) & dcache_rsp_valid)  ? 1'b1 :
                       (cache_hazard)                                           ? data_bp_valid :
                       (int_instr)                                              ? req_valid     : 
                                                                                  1'b0;

                                                               
assign data_bypass = (cache_hazard) ? data_bypass : 
                     ((req_is_load | !req_info.is_store) & dcache_rsp_valid) ? rsp_data_dcache : 
                                                                               req_info.data;


/////////////////////////////////////////                                                
// Data TLB signals

// Request to dTLB
logic dtlb_req_valid;

assign dtlb_req_valid = (flush_cache) ? 1'b0 :
                                       dcache_ready & req_valid & mem_instr;


// Response from dTLB
logic                   dTlb_rsp_valid;
logic [`PHY_ADDR_RANGE] dTlb_rsp_phy_addr;
logic                   dTlb_write_privilege;


//////////////////////////////////////////////////
// Request to the Data Cache
logic               dcache_req_valid;
dcache_request_t    req_dcache_info;

assign dcache_req_valid = (flush_cache) ? 1'b0 :
                                          dTlb_rsp_valid & !xcpt_dtlb_miss;

always_comb
begin
    req_dcache_info      = req_info;
    req_dcache_info.addr = dTlb_rsp_phy_addr;
end
                                      
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
    .xcpt_bus_error     ( xcpt_bus_error    ),
    
    // Request from the core pipeline
    .req_valid          ( dcache_req_valid  ),
    .req_info           ( req_dcache_info   ),

    // Response to the core pipeline
    .rsp_valid          ( dcache_rsp_valid  ),
    .rsp_data           ( rsp_data_dcache   ),
    
    // Request to the memory hierarchy
    .req_info_miss      ( req_info_miss     ),
    .req_valid_miss     ( req_valid_miss    ),
                    
    // Response from the memory hierarchy
    .rsp_data_miss      ( rsp_data_miss     ),
    .rsp_bus_error      ( rsp_bus_error     ),
    .rsp_valid_miss     ( rsp_valid_miss    )
);

//////////////////////////////////////////////////
// Data TLB instance
tlb_cache
dtlb
(
    // System signals
    .clock              ( clock                 ),
    .reset              ( reset                 ),

    // Request from the core pipeline
    .req_valid          ( dtlb_req_valid        ),
    .req_virt_addr      ( req_info.addr         ),
    .priv_mode          ( priv_mode             ),

    // Response to the cache
    .rsp_valid          ( dTlb_rsp_valid        ), 
    .tlb_miss           ( xcpt_dtlb_miss        ), 
    .rsp_phy_addr       ( dTlb_rsp_phy_addr     ), 
    .writePriv          ( dTlb_write_privilege  ), 
    
    // Write request from the O.S
    .new_tlb_entry      ( new_tlb_entry         ),
    .new_tlb_info       ( new_tlb_info          )
);

//////////////////////////////////////////////////
// VERBOSE

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

endmodule

