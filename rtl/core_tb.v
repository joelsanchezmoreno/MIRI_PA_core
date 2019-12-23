`include "soc.vh"

module core_tb(
    input   logic   clk_i,
    input   logic   reset_i
);


initial
begin
    $display("[CORE TB] PA core tb init");
end

//////////////////////////////////////////////////
//// Generate clock and reset signals

//timeunit 1ns;
//timeprecision 100ps;
//logic clock;
//logic reset;
//
//initial 
//begin 
//    clock = 1'b0;
//    reset = 1'b1;
//    #10 reset = 1'b0;
//end
//
//always #5 clock = ~clock;


//////////////////////////////////////////////////
// Interface signals with main memory

// Request from D$ to the memory hierarchy
logic                                   dcache_req_valid_miss;
memory_request_t                        dcache_req_info_miss;

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
    .clock                  ( clk_i                 ),
    .reset                  ( reset_i               ),

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
memory_request_t    req_mm_info;
memory_request_t    req_mm_info_ff;

//  CLK    DOUT            DIN           
`FF(clk_i, req_mm_info_ff, req_mm_info)

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
logic [`LATENCY_MM_REQ_RANGE] mem_req_count;
logic [`LATENCY_MM_REQ_RANGE] mem_req_count_ff ;

//      CLK    RST      DOUT              DIN           DEF
`RST_FF(clk_i, reset_i, mem_req_count_ff, mem_req_count, '0)

// Request from D$ to the memory hierarchy
logic               dcache_req_valid_next,dcache_req_valid_ff;
memory_request_t    dcache_req_info_ff;

// Request from I$ to the memory hierarchy
logic               icache_req_valid_next,icache_req_valid_ff;
memory_request_t    icache_req_info_ff;

//      CLK    RST      DOUT                 DIN           DEF
`RST_FF(clk_i, reset_i, dcache_req_valid_ff, dcache_req_valid_next, '0)
`RST_FF(clk_i, reset_i, icache_req_valid_ff, icache_req_valid_next, '0)

//         CLK    RST      EN                     DOUT                DIN                   DEF
`RST_EN_FF(clk_i, reset_i, dcache_req_valid_miss, dcache_req_info_ff, dcache_req_info_miss, '0)
`RST_EN_FF(clk_i, reset_i, icache_req_valid_miss, icache_req_info_ff, icache_req_info_miss, '0)

logic   wait_rsp_icache_next,wait_rsp_icache_ff ;
logic   wait_rsp_enable;
logic   wait_icache_rsp_update;

assign wait_rsp_enable = (!dcache_req_valid_miss & icache_req_valid_miss) | wait_icache_rsp_update;

//         CLK    RST      EN               DOUT                DIN                   DEF
`RST_EN_FF(clk_i, reset_i, wait_rsp_enable, wait_rsp_icache_ff, wait_rsp_icache_next, '0)

always_comb
begin
    rsp_valid_miss  = 1'b0;

    // Hold values for next cycle
    dcache_req_valid_next = dcache_req_valid_ff;
    icache_req_valid_next = icache_req_valid_ff;
    req_mm_info           = req_mm_info_ff;
    mem_req_count         = mem_req_count_ff;

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
        if (mem_req_count_ff < `LATENCY_MM_REQ-1) 
            mem_req_count = mem_req_count_ff + 1'b1;
        else
        begin
            req_mm_valid = !rsp_mm_valid;
            req_mm_info  = dcache_req_info_ff;

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

    // If there is a request from the I$ and not from the D$ or we are 
    // already performing the I$ request we (continue) perform the I$ request
    if ((!dcache_req_valid_ff & icache_req_valid_ff) | wait_rsp_icache_ff)
    begin
        wait_rsp_icache_next = 1'b1;

        if (mem_req_count_ff < `LATENCY_MM_REQ-1) 
            mem_req_count = mem_req_count_ff + 1'b1;
        else
        begin
            req_mm_valid = !rsp_mm_valid;
            req_mm_info  = icache_req_info_ff;    
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

// Logic to emulate main memory latency
logic [`LATENCY_MM_RSP_RANGE] mem_rsp_count;

always_ff @(posedge clk_i) 
begin
    rsp_mm_valid  <= 1'b0;

    if (reset_i)
    begin 
    	$readmemh("data_input_file.hex", main_memory, `MM_BOOT_ADDR);
        $display("[CORE TB] Main memory loaded. PC@'h0 =  %h",main_memory[0]);          
        $display("[CORE TB] Main memory loaded. PC@'h1 =  %h",main_memory[1]);          
        $display("[CORE TB] Main memory loaded. PC@'h1000 = %h",main_memory['h1000 >> `ICACHE_RSH_VAL]);          
        $display("[CORE TB] Main memory loaded. PC@'h1010 = %h",main_memory['h1010 >> `ICACHE_RSH_VAL]);          
        $display("[CORE TB] Main memory loaded. PC@'h1020 = %h",main_memory['h1020 >> `ICACHE_RSH_VAL]);          
        $display("[CORE TB] Main memory loaded. PC@'h1030 = %h",main_memory['h1030 >> `ICACHE_RSH_VAL]);          
        $display("------------------------------------------");          
        $display("------------------------------------------");          
    end
    else if (req_mm_valid)
    begin
        mem_rsp_count <= mem_rsp_count + 1'b1;

        if (mem_rsp_count == `LATENCY_MM_RSP-1)
        begin
            // Send response to the core arbiter
            rsp_mm_valid  <= 1'b1;

            // Load
            if (!req_mm_info_ff.is_store)
            begin
                `ifdef VERBOSE_CORETB       
                    $display("[CORE TB] Main memory LD to address %h",req_mm_info_ff.addr );  
                `endif             
                rsp_mm_data <= main_memory[req_mm_info_ff.addr];
            end
            //Store
            else
            begin
        	    main_memory[req_mm_info_ff.addr] <= req_mm_info_ff.data;
            end
            // Reset counter
            mem_rsp_count <= '0; 
        end
    end
end

always_ff @(posedge clk_i) 
begin
    // If there is a request from the D$ and we are not busy sending the
    // response for the I$ we perform the D$ request
    if (dcache_req_valid_ff & !wait_rsp_icache_ff)
    begin
        if ( mem_req_count_ff >= `LATENCY_MM_REQ-1 &
             rsp_mm_valid)
        begin
            `ifdef VERBOSE_CORETB       
                $display("[CORE TB] Response arbiter. Data to D$ %h",rsp_mm_data);                               
            `endif
        end
    end

    // If there is a request from the I$ and not from the D$ or we are 
    // already performing the I$ request we (continue) perform the I$ request
    if ((!dcache_req_valid_ff & icache_req_valid_ff) | wait_rsp_icache_ff)
    begin
        if ( mem_req_count_ff >= `LATENCY_MM_REQ-1 & rsp_mm_valid)
        begin     
            `ifdef VERBOSE_CORETB       
                $display("[CORE TB] Response arbiter. Data to I$ %h",rsp_mm_data);   
            `endif                    
        end
    end
end

endmodule

