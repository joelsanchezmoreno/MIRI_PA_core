`include "soc.vh"

module core_tb();

timeunit 1ns;
timeprecision 100ps;

// Generate clock and reset signals
logic clock;
logic reset;

initial 
begin 
    clock = 1'b0;
    reset = 1'b1;
    #10 reset = 1'b0;
end

always #5 clock = ~clock;

/* FIXME: Needed for dump?
initial
begin
      $dumpfile("$REPOROOT/trace.vcd");
      $dumpvars;
end
*/

//////////////////////////////////////////////////
// Interface signals with main memory

// Request from D$ to the memory hierarchy
logic                                   dcache_req_valid_miss;
memory_request_t                        dcache_req_info_miss,

// Request from I$ to the memory hierarchy
logic                                   icache_req_valid_miss;
memory_request_t                        icache_req_info_miss;

// Response from the memory hierarchy
logic [`DCACHE_LINE_WIDTH-1:0]          rsp_data_miss;
logic                                   rsp_valid_miss;
logic                                   rsp_cache_id;

//////////////////////////////////////////////////
// Core top instance
core_top
core_top
(
    // System signals
    .clock                  ( clock                 ),
    .reset                  ( reset                 ),

    // Boot address
    .boot_addr              ( `CORE_BOOT_ADDRESS    ),

    // Exception address
    .xcpt_addr              ( `CORE_XCPT_ADDRESS    ),

    // Request from I$ to the memory hierarchy
    .dcache_req_valid_miss  ( dcache_req_valid_miss ),
    .dcache_req_info_miss   ( dcache_req_info_miss  ),

    // Request from D$ to the memory hierarchy                                      
    .icache_req_valid_miss  ( icache_req_valid_miss ),
    .icache_req_info_miss   ( icache_req_info_miss  ),
                                      
    // Response from the memory hierarchy                                  
    .rsp_data_miss          ( rsp_data_miss         ),
    .rsp_valid_miss         ( rsp_valid_miss        ),
    .rsp_cache_id           ( rsp_cache_id          ) // 0 for I$, 1 for D$
);

//////////////////////////////////////////////////
// MAIN MEMORY

// FF to act as main memory
logic [`MAIN_MEMORY_LINE_RANGE] main_memory [`MAIN_MEMORY_DEPTH_RANGE];

// Request from core arbiter to MM
logic               req_mm_valid;
memory_request_t    req_mm_info, req_mm_info_ff;

//  CLK    DOUT            DIN           
`FF(clock, req_mm_info_ff, req_mm_info)

// Response from MM to core arbiter
logic rsp_mm_valid;
logic [`ICACHE_LINE_WIDTH-1:0]  rsp_mm_data;

//////////////////////////////////////////////////
// Arbiter logic
//
// Arbiter between instruction cache and data cache. 
// D$ has always priority except if we are performing an instruction cache
// request

// Logic to emulate main memory latency
logic [`LATENCY_MM_REQ_RANGE] mem_req_count, mem_req_count_ff ;

//      CLK    RST    DOUT              DIN           DEF
`RST_FF(clock, reset, mem_req_count_ff, mem_req_count, '0)

// Request from D$ to the memory hierarchy
logic               dcache_req_valid_next,dcache_req_valid_ff;
memory_request_t    dcache_req_info_ff;

// Request from I$ to the memory hierarchy
logic               icache_req_valid_next,icache_req_valid_ff;
memory_request_t    icache_req_info_miss_ff;

//      CLK    RST    DOUT                 DIN           DEF
`RST_FF(clock, reset, dcache_req_valid_ff, dcache_req_valid_next, '0)
`RST_FF(clock, reset, icache_req_valid_ff, icache_req_valid_next, '0)

//         CLK    RST    EN                     DOUT                DIN                   DEF
`RST_EN_FF(clock, reset, dcache_req_valid_miss, dcache_req_info_ff, dcache_req_info_miss, '0)
`RST_EN_FF(clock, reset, icache_req_valid_miss, icache_req_info_ff, icache_req_info_miss, '0)

logic   wait_rsp_icache_next,wait_rsp_icache_ff ;
logic   wait_rsp_enable;
logic   wait_icache_rsp_update;

assign wait_rsp_enable = (!dcache_req_valid_miss & icache_req_valid_miss) | wait_icache_rsp_update;

//         CLK    RST    EN               DOUT                DIN                   DEF
`RST_EN_FF(clock, reset, wait_rsp_enable, wait_rsp_icache_ff, wait_rsp_icache_next, '0)

always_comb
begin
    rsp_valid_miss  = 1'b0;
    wait_rsp_update = 1'b0;

    // Hold values for next cycle
    dcache_req_valid_next = dcache_req_valid_ff;
    icache_req_valid_next = icache_req_valid_ff;
    req_mm_info           = req_mm_info_ff;

    // We store that we have a pending request from D$
    if (dcache_req_valid_miss)
    begin
        dcache_req_valid_next   = 1'b1;
    end

    // We store that we have a pending request from I$    
    if (icache_req_valid_miss)
    begin
        icache_req_valid_next   = 1'b1;
    end

    // If there is a request from the D$ and we are not busy sending the
    // response for the I$ we perform the D$ request
    if (dcache_req_valid_ff & !wait_rsp_icache_ff)
    begin
        if (mem_req_count < `LATENCY_MM_REQ-1) )
        begin
            mem_req_count = mem_req_count_ff + 1'b1;
            req_mm_valid = 1'b1;
            req_mm_info  = dcache_req_info_ff;
        end
        else
        begin
            if (rsp_mm_valid)
            begin
                // De-assert request to the MM
                req_mm_valid    = 1'b0;

                // Response to the core
                rsp_valid_miss  = 1'b1;
                rsp_cache_id    = 1'b1; // response to D$
                rsp_data_miss   = rsp_mm_data; 

                // Reset counter
                mem_req_count   = '0;

                // Reset control signal
                dcache_req_valid_next   = 1'b0;
            end
        end
        end
    end

    // If there is a request from the I$ and not from the D$ or we are 
    // already performing the I$ request we (continue) perform the I$ request
    if ((!dcache_req_valid_ff & icache_req_valid_ff) | wait_rsp_icache_ff)
    begin
        wait_rsp_icache_next    = 1'b1;

        if (mem_req_count == `LATENCY_MM_REQ-1) )
        begin
            mem_req_count = mem_req_count_ff + 1'b1;
            req_mm_valid = 1'b1;
            req_mm_info  = dcache_req_info_ff;
        end
        else
        begin
            if (rsp_mm_valid)
            begin            
                // De-assert request to the MM
                req_mm_valid    = 1'b0;

                // Response to the core                
                rsp_valid_miss  = 1'b1;
                rsp_cache_id    = 1'b0; // response to I$
                rsp_data_miss   = rsp_mm_data;
                
                // Reset counter
                mem_req_count   = '0;

                // Reset control signal
                wait_rsp_icache_next    = 1'b0;
                wait_icache_rsp_update  = 1'b1; 
                icache_req_valid_next   = 1'b0;
            end
        end
    end
end

//////////////////////////////////////////////////
// Main memory

integer i;

initial 
begin
    // Open text file with memory content
    data_file = $fopen("C:/outputs.txt", "r"); //Opening text file

    $readmemh({"data_input_file",".hex"}, main_memory);
end

// Logic to emulate main memory latency
logic [`LATENCY_MM_RSP_RANGE] mem_rsp_count, mem_rsp_count_ff ;

//      CLK    RST    DOUT              DIN           DEF
`RST_FF(clock, reset, mem_rsp_count_ff, mem_rsp_count, '0)

always_comb 
begin
    mem_rsp_count = mem_rsp_count_ff;
    rsp_mm_valid  = 1'b0;

    if (req_mm_valid)
    begin
        mem_rsp_count = mem_rsp_count_ff + 1'b1;

        if (mem_req_count == `LATENCY_MM_RSP)
        begin
            // Send response to the core arbiter
            rsp_mm_valid  = 1'b1;
            // Load
            if (!req_mm_info_ff.is_store)
                rsp_mm_data = main_memory[req_mm_info_ff.addr];
            //Store
            else
                main_memory[req_mm_info_ff.addr] = req_mm_info_ff.data;
           
            // Reset counter
            mem_req_count = '0; 
        end
    end
end

endmodule

