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
assign xcpt_fetch = '0; //FIXME: connect to iTLB

logic   [`PC_WIDTH-1:0] program_counter;
logic   [`PC_WIDTH-1:0] program_counter_next;
logic                   program_counter_update;

//         CLK    RST    EN                      DOUT             DIN                   DEF
`RST_EN_FF(clock, reset, program_counter_update, program_counter, program_counter_next, boot_addr)

assign program_counter_update   = ( stall_fetch | !icache_ready) ? 1'b0 : 1'b1;
assign program_counter_next     = ( take_branch ) ? branch_pc : 
                                                    program_counter + 4;


// Request to the Instruction Cache
logic icache_req_valid;
logic icache_ready;

assign icache_req_valid = !stall_fetch & icache_ready;

// Response from the Instruction Cache
logic                                   icache_rsp_valid;
logic [`ICACHE_LINE_WIDTH-1:0]          icache_rsp_data;
logic [`ICACHE_INSTR_IN_LINE_WIDTH-1:0] word_in_line;
logic [`INSTR_WIDTH-1:0]                decode_instr_data_next;

//     CLK    EN            DOUT                DIN                   
`EN_FF(clock, !stall_fetch, decode_instr_data,  decode_instr_data_next)
`EN_FF(clock, !stall_fetch, decode_instr_valid, icache_rsp_valid)

assign decode_instr_pc = program_counter;

always_comb
begin
    word_in_line            = program_counter[`ICACHE_INSTR_IN_LINE];
    decode_instr_data_next  = icache_rsp_data[`INSTR_WIDTH*word_in_line+:`INSTR_WIDTH];
end

// Request to the memory hierarchy
logic [`ICACHE_ADDR_WIDTH-1:0]   req_addr_miss;

always_comb
begin
    req_info_miss.addr      = req_addr_miss;
    req_info_miss.is_store  = 1'b0;
    req_info_miss.data      = '0;
end

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
    .req_addr_miss      ( req_addr_miss     ),
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

endmodule

