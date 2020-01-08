`include "soc.vh"

module fetch_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    input   logic   [`PC_WIDTH-1:0]             boot_addr,
    input   priv_mode_t                         priv_mode,
    
    // Exception
    output  fetch_xcpt_t                        xcpt_fetch,

    // Branches 
    input   logic                               take_branch,
    input   logic   [`PC_WIDTH-1:0]             branch_pc,

    // Stall pipeline
    input   logic                               stall_fetch,

    // Fetched instruction
    output  logic   [`INSTR_WIDTH-1:0]          decode_instr_data,
    output  logic                               decode_instr_valid,
    output  logic   [`PC_WIDTH_RANGE]           decode_instr_pc, 
    
    // Request to the memory hierarchy
    output  logic                               req_valid_miss,
    output  memory_request_t                    req_info_miss,

    // Response from the memory hierarchy
    input   logic [`ICACHE_LINE_WIDTH-1:0]      rsp_data_miss,
    input   logic                               rsp_bus_error,
    input   logic                               rsp_valid_miss,

    // New entry for iTLB
    input   logic                               new_tlb_entry,
    input   tlb_req_info_t                      new_tlb_info
 );

/////////////////////////////////////////
// Signals
logic                                   mm_pendent_rsp;
logic                                   mm_pendent_rsp_ff;

//         CLK    RST    DOUT             DIN          DEF
`RST_FF(clock, reset, mm_pendent_rsp_ff, mm_pendent_rsp, 1'b0)
always_comb
begin
    mm_pendent_rsp = mm_pendent_rsp_ff;
    if(req_valid_miss)
        mm_pendent_rsp = 1'b1;
    else if (rsp_valid_miss)
        mm_pendent_rsp = 1'b0;
end

logic icache_ready;

// Response from the Instruction Cache
logic                                   icache_rsp_valid;
logic [`ICACHE_LINE_WIDTH-1:0]          icache_rsp_data;
logic [`ICACHE_INSTR_IN_LINE_WIDTH-1:0] word_in_line;
logic [`INSTR_WIDTH-1:0]                decode_instr_data_next;

// Response from iTLB
logic                   iTlb_rsp_valid;
logic [`PHY_ADDR_RANGE] iTlb_rsp_phy_addr;

/////////////////////////////////////////
// Branches
logic                   take_branch_ff;
logic                   take_branch_update;
logic                   branch_executed;
logic   [`PC_WIDTH-1:0] branch_pc_ff;

//         CLK    RST    EN                  DOUT             DIN          DEF
`RST_EN_FF(clock, reset, take_branch_update, take_branch_ff, take_branch, 1'b0)

//     CLK    EN                  DOUT          DIN
`EN_FF(clock, take_branch_update, branch_pc_ff, branch_pc)

assign branch_executed    = (take_branch | take_branch_ff) & icache_ready;

assign take_branch_update = (!take_branch_ff & take_branch) ? 1'b1 : // branch request received
                            (branch_executed)               ? 1'b1 : // new PC has been requested and updated
                                                              1'b0 ;

/////////////////////////////////////////
// Program counter
logic   [`PC_WIDTH-1:0] program_counter;
logic   [`PC_WIDTH-1:0] program_counter_next;
logic                   program_counter_update;

//         CLK    RST    EN                      DOUT             DIN                   DEF
`RST_EN_FF(clock, reset, program_counter_update, program_counter, program_counter_next, boot_addr)

assign program_counter_update   = ( stall_fetch | !icache_ready | mm_pendent_rsp) ? 1'b0 : 1'b1;
assign program_counter_next     = ( take_branch     & icache_ready ) ? branch_pc    : 
                                  ( take_branch_ff  & icache_ready ) ? branch_pc_ff :
                                                                       program_counter + 4;

                                                  
/////////////////////////////////////////
// Exceptions

fetch_xcpt_t   xcpt_fetch_next;

//     CLK    EN            DOUT        DIN                   
`EN_FF(clock, !stall_fetch, xcpt_fetch, xcpt_fetch_next)

logic xcpt_bus_error_aux;
logic xcpt_itlb_miss;

always_comb
begin
    xcpt_fetch_next.xcpt_itlb_miss   = xcpt_itlb_miss;
    xcpt_fetch_next.xcpt_bus_error   = xcpt_bus_error_aux;
    xcpt_fetch_next.xcpt_addr_val    = program_counter;
    xcpt_fetch_next.xcpt_pc          = program_counter;
end

/////////////////////////////////////////                                                
// Request to the Instruction TLB
logic itlb_req_valid;
logic itlb_req_valid_ff;
logic itlb_req_valid_next;
logic first_req_sent,first_req_sent_ff;

//         CLK    RST    EN                  DOUT               DIN              DEF
`RST_EN_FF(clock, reset, !first_req_sent_ff, first_req_sent_ff, first_req_sent, 1'b0)

logic stall_fetch_ff;

//  CLK    DOUT            DIN
`FF(clock, stall_fetch_ff, stall_fetch)

always_comb
begin
    first_req_sent = first_req_sent_ff;
    if (program_counter == `CORE_BOOT_ADDRESS & !first_req_sent_ff)
    begin
        itlb_req_valid_next     = 1'b1;
        first_req_sent          = 1'b1;
    end
    else
        itlb_req_valid_next = program_counter_update;
end

//      CLK    RST    DOUT                 DIN                    DEF
`RST_FF(clock, reset, itlb_req_valid_ff, itlb_req_valid_next, 1'b0)


assign itlb_req_valid = (stall_fetch)    ? 1'b0 :
                        (stall_fetch_ff) ? 1'b1 : // !stall_fetch & stall_fetch_ff
                                           itlb_req_valid_ff;

/////////////////////////////////////////                                                
// Request to the Instruction Cache
logic icache_req_valid;

assign icache_req_valid = (stall_fetch) ? 1'b0 :
                                          iTlb_rsp_valid & !xcpt_itlb_miss;

/////////////////////////////////////////
// Fetch to Decode

// In case of stall we mantain the value of the instr to be decoded because
// decode stage may need it to relaunch the instruction
logic                               decode_instr_valid_ff;
logic                               decode_instr_valid_next;
logic   [`INSTR_WIDTH-1:0]          decode_instr_data_ff;
logic   [`PC_WIDTH-1:0]             decode_instr_pc_ff;

assign decode_instr_valid_next = (take_branch | take_branch_ff) ? 1'b0:
                                 (  xcpt_fetch.xcpt_itlb_miss
                                  | xcpt_fetch.xcpt_bus_error) ? 1'b1:
                                                                 icache_rsp_valid;

//         CLK    RST     EN           DOUT                   DIN                      DEF
`RST_EN_FF(clock, reset, !stall_fetch, decode_instr_valid_ff, decode_instr_valid_next, 1'b0)


//     CLK    EN            DOUT                   DIN                   
`EN_FF(clock, !stall_fetch, decode_instr_data_ff,  decode_instr_data_next)
`EN_FF(clock, !stall_fetch, decode_instr_pc_ff,    program_counter)

assign decode_instr_valid = (take_branch) ? 1'b0 : decode_instr_valid_ff;
//assign decode_instr_valid = (stall_fetch | take_branch) ? 1'b0 : decode_instr_valid_ff; //FIXME: maybe stall_fetch_ff ?
assign decode_instr_data  = decode_instr_data_ff; 
assign decode_instr_pc    = decode_instr_pc_ff;

always_comb
begin
    word_in_line            = program_counter[`ICACHE_INSTR_IN_LINE];
    decode_instr_data_next  = icache_rsp_data[`INSTR_WIDTH*word_in_line+:`INSTR_WIDTH];
end

/////////////////////////////////////////
// Instruction Cache instance
instruction_cache
icache(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),
    .icache_ready       ( icache_ready      ),
    .xcpt_bus_error     ( xcpt_bus_error_aux),
    
    // Request from the core pipeline
    .req_valid          ( icache_req_valid  ),
    .req_addr           ( iTlb_rsp_phy_addr ),

    // Response to the core pipeline
    .rsp_valid          ( icache_rsp_valid  ),
    .rsp_data           ( icache_rsp_data   ),
    
    // Request to the memory hierarchy
    .req_info_miss      ( req_info_miss     ),
    .req_valid_miss     ( req_valid_miss    ),
                    
    // Response from the memory hierarchy
    .rsp_data_miss      ( rsp_data_miss     ),
    .rsp_bus_error      ( rsp_bus_error     ),
    .rsp_valid_miss     ( rsp_valid_miss    )
);


logic tlb_write_privilege;

tlb_cache
itlb
(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),

    // Request from the core pipeline
    .req_valid          ( itlb_req_valid    ),
    .req_virt_addr      ( program_counter   ),
    .priv_mode          ( priv_mode         ),

    // Response to the cache
    .rsp_valid          ( iTlb_rsp_valid    ), 
    .tlb_miss           ( xcpt_itlb_miss    ), 
    .rsp_phy_addr       ( iTlb_rsp_phy_addr ), 
    .writePriv          (tlb_write_privilege), //unused for Icache
    
    // Write request from the O.S
    .new_tlb_entry      ( new_tlb_entry     ),
    .new_tlb_info       ( new_tlb_info      )
);


/////////////////////////////////////////
// Verbose
`ifdef VERBOSE_FETCH
always_ff @(posedge clock)
begin
    /*
    if (program_counter_update)
    begin
        $display("[FETCH] Program counter value is %h",program_counter);
        $display("[FETCH] Program counter next value is %h",program_counter_next);
    end
    */
    if (decode_instr_valid)
    begin
        $display("[FETCH] Request to decode. PC is %h",decode_instr_pc);
        $display("        Data to be decoded = %h",decode_instr_data);
    end
end
`endif

endmodule

