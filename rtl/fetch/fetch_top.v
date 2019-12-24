`include "soc.vh"

module fetch_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    input   logic   [`PC_WIDTH-1:0]             boot_addr,
    
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
    input   logic                               rsp_valid_miss
 );

/////////////////////////////////////////
// Signals
logic icache_ready;

// Response from the Instruction Cache
logic                                   icache_rsp_valid;
logic [`ICACHE_LINE_WIDTH-1:0]          icache_rsp_data;
logic [`ICACHE_INSTR_IN_LINE_WIDTH-1:0] word_in_line;
logic [`INSTR_WIDTH-1:0]                decode_instr_data_next;

/////////////////////////////////////////
// Exceptions
assign xcpt_fetch = '0; //FIXME: connect to iTLB

/////////////////////////////////////////
// Program counter
logic   [`PC_WIDTH-1:0] program_counter;
logic   [`PC_WIDTH-1:0] program_counter_next;
logic                   program_counter_update;

//         CLK    RST    EN                      DOUT             DIN                   DEF
`RST_EN_FF(clock, reset, program_counter_update, program_counter, program_counter_next, boot_addr)

assign program_counter_update   = ( stall_fetch | !icache_ready | !icache_rsp_valid) ? 1'b0 : 1'b1;
assign program_counter_next     = ( take_branch ) ? branch_pc : 
                                                    program_counter + 4;

/////////////////////////////////////////                                                
// Request to the Instruction Cache
logic icache_req_valid;
logic icache_req_valid_ff;
logic icache_req_valid_next;
logic first_req_sent,first_req_sent_ff;

//         CLK    RST    EN                  DOUT               DIN              DEF
`RST_EN_FF(clock, reset, !first_req_sent_ff, first_req_sent_ff, first_req_sent, 1'b0)

always_comb
begin
    first_req_sent = first_req_sent_ff;
    if (program_counter == `CORE_BOOT_ADDRESS & !first_req_sent_ff)
    begin
        icache_req_valid_next = 1'b1;
        first_req_sent        = 1'b1;
    end
    else
        icache_req_valid_next = program_counter_update;
end

//      CLK    RST    DOUT                 DIN                    DEF
`RST_FF(clock, reset, icache_req_valid_ff, icache_req_valid_next, 1'b0)

assign icache_req_valid = (stall_fetch) ? 1'b0 :
                                          icache_req_valid_ff;

/////////////////////////////////////////
// Fetch to Decode

// In case of stall we mantain the value of the instr to be decoded because
// decode stage may need it to relaunch the instruction
logic                               decode_instr_valid_ff;
logic   [`INSTR_WIDTH-1:0]          decode_instr_data_ff;
logic   [`PC_WIDTH-1:0]             decode_instr_pc_ff;

//         CLK    RST     EN           DOUT                   DIN               DEF
`RST_EN_FF(clock, reset, !stall_fetch, decode_instr_valid_ff, icache_rsp_valid, 1'b0)


//     CLK    EN            DOUT                   DIN                   
`EN_FF(clock, !stall_fetch, decode_instr_data_ff,  decode_instr_data_next)
`EN_FF(clock, !stall_fetch, decode_instr_pc_ff,    program_counter)

assign decode_instr_valid = (stall_fetch) ? 1'b0              : decode_instr_valid_ff;
assign decode_instr_data  = (stall_fetch) ? decode_instr_data : decode_instr_data_ff; 
assign decode_instr_pc    = (stall_fetch) ? decode_instr_pc   : decode_instr_pc_ff;

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
    
    // Request from the core pipeline
    .req_valid          ( icache_req_valid  ),
    .req_addr           ( program_counter   ),

    // Response to the core pipeline
    .rsp_valid          ( icache_rsp_valid  ),
    .rsp_data           ( icache_rsp_data   ),
    
    // Request to the memory hierarchy
    .req_info_miss      ( req_info_miss     ),
    .req_valid_miss     ( req_valid_miss    ),
                    
    // Response from the memory hierarchy
    .rsp_data_miss      ( rsp_data_miss     ),
    .rsp_valid_miss     ( rsp_valid_miss    )
);


/*
//FIXME: Create module
instruction_tlb
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

