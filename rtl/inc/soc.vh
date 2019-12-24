`ifndef _SOC__
`define _SOC__
`include "macros.vh"
`include "main_memory.vh"
`include "core_defines.vh"
`include "core_types.vh"

`define CORE_BOOT_ADDRESS `PC_WIDTH'h1000
`define CORE_XCPT_ADDRESS `PC_WIDTH'h2000

`define VERBOSE_CORETB  
`define VERBOSE_FETCH   
//`define VERBOSE_ICACHE  1
`define VERBOSE_DECODE  
`define VERBOSE_ALU     
`define VERBOSE_CACHE   
//`define VERBOSE_DCACHE  
`define VERBOSE_WRITE_CACHE_LINE 

`endif // __SOC__

