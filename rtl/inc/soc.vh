`ifndef _SOC__
`define _SOC__
`include "macros.vh"
`include "main_memory.vh"
`include "core_defines.vh"
`include "core_types.vh"

`define CORE_BOOT_ADDRESS `PC_WIDTH'h1000
`define CORE_XCPT_ADDRESS `PC_WIDTH'h2000

`define VERBOSE_CORETB  1
`define VERBOSE_FETCH   1
//`define VERBOSE_ICACHE  1
`define VERBOSE_DECODE  1
`define VERBOSE_ALU     1

`endif // __SOC__

