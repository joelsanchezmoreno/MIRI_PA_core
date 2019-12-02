`include "soc.vh"

module fetch_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,

    input   logic   [`PC_WIDTH-1:0]             boot_addr,

    // Branches 
    input   logic                               take_branch,
    input   logic   [`PC_WIDTH-1:0]             branch_pc,

    // Stall pipeline
    input   logic                               stall_fetch,

    // Fetched instruction
    output  logic   [`FETCH_INSTR_DATA-1:0]     instr_data,
    output  logic   [`FETCH_INSTR_DATA-1:0]     instr_valid
 );

logic   [`PC_WIDTH-1:0] program_counter;
logic   [`PC_WIDTH-1:0] program_counter_next;
logic                   program_counter_update;

//         CLK    RST      EN                      DOUT             DIN                   DEF
`RST_EN_FF(clock, reset_c, program_counter_update, program_counter, program_counter_next, boot_addr)

assign program_counter_update   = ( stall_fetch ) ? 1'b0 : 1'b1;

always_comb
begin
    program_counter_next = ( take_branch ) ? branch_pc : 
                                             program_counter + 4;
end

// Request to the Instruction Cache
logic                               icache_req_valid;

// Response from the Instruction Cache
logic                               icache_rsp_valid;
logic   [`ICACHE_LINE_WIDTH-1:0]    icache_rsp_data;

// Data for the next stage
logic   [`FETCH_INSTR_DATA-1:0]     instr_data_next;

//     CLK    RST      DOUT            DIN
`EN_FF(clock, reset_c, instr_data, instr_data_next)

//      CLK    RST      DOUT             DIN                     DEF
`RST_FF(clock, reset_c, dec_instr_valid, program_counter_update, 1'b0)

// TODO: HOW TO SEND INSTR FROM ICACHE LINE TO DECODER  -> RAW DATA NOT PROCESSED
always_comb
begin
    instr_data_next = XXXX; // FIXME
end

// Request to the memory hierarchy
logic [`ICACHE_ADDR_WIDTH-1:0]   req_addr_miss;
logic                            req_valid_miss;

// Response from the memory hierarchy
logic [`ICACHE_LINE_WIDTH-1:0]   rsp_data_miss;
logic                            rsp_valid_miss;

instruction_cache
icache(
    // System signals
    .clock      ( clock             ),
    .reset      ( reset             ),

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

// Logic to emulate main memory latency
logic [`MAIN_MEMORY_LAT_LOG-1:0] mem_rsp_count, mem_rsp_count_ff ;
//      CLK    RST    DOUT              DIN           DEF
`RST_FF(clock, reset, mem_rsp_count_ff, mem_rsp_count, '0)

always_comb
begin
    rsp_valid_miss = 1'b0;

    if (req_valid_miss)
    begin
        mem_rsp_count = mem_rsp_count_ff + 1'b1;
        if (mem_rsp_count_ff == `MAIN_MEMORY_LATENCY) )
        begin
            rsp_valid_miss   = 1'b1;
            rsp_data_miss   = XXXX[req_addr_miss]; // FIXME: Maybe we should have a very big array as main memory
            mem_rsp_count   = '0;
        end
    end
end

endmodule

