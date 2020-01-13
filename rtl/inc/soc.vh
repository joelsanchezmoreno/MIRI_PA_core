`ifndef _SOC__
`define _SOC__
`include "macros.vh"
`include "main_memory.vh"
`include "core_defines.vh"
`include "core_types.vh"

`define CORE_BOOT_ADDRESS `PC_WIDTH'h1000
`define CORE_XCPT_ADDRESS `PC_WIDTH'h2000

// Load data at boot address
`define MM_BOOT_ADDR        (`PC_WIDTH'h1000 >> `ICACHE_RSH_VAL)

// Defines for Matrix Multiply test
// ------------------------------------
/*
`define MATRIX_MULTIPLY_TEST
`define MATRIX_C_ADDR           `PC_WIDTH'h3000
`define MATRIX_A_ADDR           `PC_WIDTH'h13000
`define MATRIX_B_ADDR           `PC_WIDTH'h23000
`define MM_MATRIX_C_ADDR        (`MATRIX_C_ADDR >> `ICACHE_RSH_VAL)
`define MM_MATRIX_A_ADDR        (`MATRIX_A_ADDR >> `ICACHE_RSH_VAL)
`define MM_MATRIX_B_ADDR        (`MATRIX_B_ADDR >> `ICACHE_RSH_VAL)
*/
// Defines for Buffer Sum test
// ------------------------------------
//`define BUFFER_SUM_TEST
//`define ARRAY_A_ADDR     `PC_WIDTH'h3000
//`define MM_ARRAY_A_ADDR  (`ARRAY_A_ADDR >> `ICACHE_RSH_VAL)

// Defines for verbosity and debugging
`define VERBOSE_CORETB  
//`define VERBOSE_FETCH   
//`define VERBOSE_ICACHE  1
//`define VERBOSE_DECODE  
//`define VERBOSE_DECODE_BYPASS
//`define VERBOSE_ALU     
//`define VERBOSE_DCACHE  
//`define VERBOSE_WRITE_CACHE_LINE 
//`define VERBOSE_STORE_BUFFER

`endif // __SOC__

