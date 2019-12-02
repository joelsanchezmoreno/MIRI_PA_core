`ifndef _CORE_DEFINES_
`define _CORE_DEFINES_

////////////////////////////////////////////////////////////////////////////////
// Whatever
////////////////////////////////////////////////////////////////////////////////

// Global defines
`define PC_WIDTH            32

// Register file defines
`define REG_FILE_WIDTH      32
`define REG_FILE_RANGE      REG_FILE_WIDTH-1:0

// Instruction defines
`define INSTR_OPCODE        7
`define INSTR_OFFSET        20
`define INSTR_WIDTH         40 

// Instruction cache defines
`define ICACHE_ADDR_WIDTH   `PC_WIDTH
`define ICACHE_LINE_WIDTH   512         // bits


// Decoder defines
`define DEC_RB_OFF_WIDTH    `MAX(`REG_FILE_RANGE, `INSTR_OFFSET)
`define DEC_FUNC3_WIDTH     3
`define DEC_FUNC7_WIDTH     7
`define DEC_NOP_INSTR       `INSTR_WIDTH

`endif // _CORE_DEFINES_
