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
`define INSTR_WIDTH         32

// Instruction cache defines
`define ICACHE_ADDR_WIDTH   `PC_WIDTH
`define ICACHE_LINE_WIDTH   128 // data

`define ICACHE_INSTR_PER_LINE   (`ICACHE_LINE_WIDTH/`INSTR_WIDTH)
`define ICACHE_LINE_ADDRESSMENT $clog2(`ICACHE_INSTR_PER_LINE)
`define ICACHE_INSTR_IN_LINE    5:2

`define ICACHE_TAG_WIDTH    (`ICACHE_ADDR_WIDTH - `ICACHE_LINE_ADDRESSMENT)
`define ICACHE_TAG_R        `ICACHE_ADDR_WIDTH -:`ICACHE_TAG_WIDTH
`define ICACHE_NUM_LINES    4
`define ICACHE_NUM_LIN_LOG  $clog2(`ICACHE_NUM_LINES)


`define MAIN_MEMORY_LATENCY 5 // FIXME: 5 or 10 ?
`define MAIN_MEMORY_LAT_LOG $clog2(`MAIN_MEMORY_LATENCY)


// Decoder defines
`define DEC_RB_OFF_WIDTH    `MAX(`REG_FILE_RANGE, `INSTR_OFFSET)
`define DEC_FUNC3_WIDTH     3
`define DEC_FUNC7_WIDTH     7
`define DEC_NOP_INSTR       `INSTR_WIDTH

`endif // _CORE_DEFINES_
