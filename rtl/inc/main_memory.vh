`ifndef __MAIN_MEMORY__
`define __MAIN_MEMORY__

// Main memory
`define MAIN_MEMORY_DEPTH       13288 // 1000 + 3 matrix = 1000 + 3*4096
`define MAIN_MEMORY_LINE_WIDTH  128
`define MAIN_MEMORY_LINE_SIZE  (`MAIN_MEMORY_LINE_WIDTH/8)

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

`endif // __MAIN_MEMORY__

