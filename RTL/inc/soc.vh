`ifndef _SOC__
`define _SOC__
`include "macros.vh"
`include "core_defines.vh"
`include "core_types.vh"

`define CORE_BOOT_ADDRESS 0x1000
`define CORE_XCPT_ADDRESS 0x2000

// Main memory
`define MAIN_MEMORY_DEPTH       100
`define MAIN_MEMORY_LINE_WIDTH  128

`define MAIN_MEMORY_DEPTH_RANGE `MAIN_MEMORY_DEPTH-1:0
`define MAIN_MEMORY_LINE_RANGE  `MAIN_MEMORY_LINE_WIDTH-1:0

// Latency for going to memory
`define LATENCY_MM_REQ        5 
`define LATENCY_MM_REQ_WIDTH  $clog2(`LATENCY_MM_REQ)
`define LATENCY_MM_REQ_RANGE  `LATENCY_MM_REQ_WIDTH-1:0

// Latency to return data from memory to the core
`define LATENCY_MM_RSP 5 
`define LATENCY_MM_RSP_WIDTH $clog2(`LATENCY_MM_RSP)
`define LATENCY_MM_RSP_RANGE `LATENCY_MM_RSP_WIDTH-1:0


`endif // __SOC__

