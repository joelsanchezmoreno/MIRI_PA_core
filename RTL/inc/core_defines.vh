`ifndef _CORE_DEFINES_
`define _CORE_DEFINES_

////////////////////////////////////////////////////////////////////////////////
// Whatever
////////////////////////////////////////////////////////////////////////////////

///////////////////////
// Global defines
///////////////////////
`define PC_WIDTH            32
`define PA_WIDTH            20

`define WORD_BITS           32
`define WORD_WIDTH          $clog2(`WORD_BITS)

// Main memory
`define MAIN_MEMORY_LATENCY 5 // FIXME: 5 or 10 ?
`define MAIN_MEMORY_LAT_LOG $clog2(`MAIN_MEMORY_LATENCY)

`define MAIN_MEMORY_LINE_WIDTH  128

///////////////////////
// Register file defines
///////////////////////
`define REG_FILE_WIDTH      32
`define REG_FILE_RANGE      `REG_FILE_WIDTH-1:0
`define REG_FILE_NUM_REGS   32
`define REG_FILE_ADDR_WIDTH $clog2(`REG_FILE_NUM_REGS)
`define REG_FILE_ADDR_RANGE `REG_FILE_ADDR_WIDTH-1:0

///////////////////////
// Instruction defines
///////////////////////
`define INSTR_OPCODE        7
`define INSTR_OFFSET        20
`define INSTR_WIDTH         32 

///////////////////////
// Instruction cache defines
///////////////////////
`define ICACHE_ADDR_WIDTH   `PC_WIDTH
`define ICACHE_LINE_WIDTH   `MAIN_MEMORY_LINE_WIDTH // data

`define ICACHE_NUM_SET          2
`define ICACHE_NUM_SET_WIDTH    $clog(`ICACHE_NUM_SET)
`define ICACHE_NUM_SET_RANGE   `ICACHE_NUM_SET_WIDTH-1:0

`define ICACHE_NUM_WAYS         4
`define ICACHE_NUM_WAY_WIDTH    $clog2(`ICACHE_NUM_WAYS)
`define ICACHE_NUM_WAY_RANGE    `ICACHE_NUM_WAY_WIDTH-1:0

`define ICACHE_WAYS_PER_SET         (`ICACHE_NUM_WAYS/`ICACHE_NUM_SET)
`define ICACHE_WAYS_PER_SET_WIDTH   $clog2(`ICACHE_WAYS_PER_SET)
`define ICACHE_WAYS_PER_SET_RANGE   `ICACHE_WAYS_PER_SET_WIDTH-1:0

`define ICACHE_BLOCK_SIZE       (`ICACHE_LINE_WIDTH/8)
`define ICACHE_BLOCK_ADDR_SIZE  $clog2(`ICACHE_BLOCK_SIZE)
`define ICACHE_INSTR_IN_LINE    5:2

`define ICACHE_TAG_WIDTH        (`ICACHE_ADDR_WIDTH - `ICACHE_NUM_SET_WIDTH - `ICACHE_BLOCK_ADDR_SIZE)
`define ICACHE_TAG_RANGE        `ICACHE_TAG_WIDTH - 1:0


// Instruction cache address decoding
`define ICACHE_TAG_ADDR_RANGE  (`ICACHE_ADDR_WIDTH - 1):(`ICACHE_NUM_SET_WIDTH + `ICACHE_BLOCK_ADDR_SIZE)
`define ICACHE_SET_ADDR_RANGE  (`ICACHE_BLOCK_ADDR_SIZE+`ICACHE_NUM_SET_WIDTH):`ICACHE_BLOCK_ADDR_SIZE


///////////////////////
// Decoder defines
///////////////////////
`define DEC_RB_OFF_WIDTH    `MAX(`REG_FILE_RANGE, `INSTR_OFFSET)
`define DEC_FUNC3_WIDTH     3
`define DEC_FUNC7_WIDTH     7
`define DEC_NOP_INSTR       `INSTR_WIDTH

///////////////////////
// Data cache defines
///////////////////////
`define DCACHE_ADDR_WIDTH       `PC_WIDTH  //FIXME: what should be the @ width
`define DCACHE_LINE_WIDTH       `MAIN_MEMORY_LINE_WIDTH // data
`define DCACHE_MAX_ACC_SIZE     `WORD_BITS // maximum access size is to words

`define DCACHE_NUM_SET          2
`define DCACHE_NUM_SET_WIDTH    $clog(`DCACHE_NUM_SET)
`define DCACHE_NUM_SET_WIDTH_R  `DCACHE_NUM_SET_WIDTH-1:0

`define DCACHE_NUM_WAYS         4
`define DCACHE_NUM_WAYS_R       `DCACHE_NUM_WAYS-1:0
`define DCACHE_NUM_WAY_WIDTH    $clog2(`DCACHE_NUM_WAYS)
`define DCACHE_NUM_WAY_WIDTH_R  `DCACHE_NUM_WAY_WIDTH-1:0

`define DCACHE_WAYS_PER_SET         (`DCACHE_NUM_WAYS/`DCACHE_NUM_SET)
`define DCACHE_WAYS_PER_SET_WIDTH   $clog2(`DCACHE_WAYS_PER_SET)
`define DCACHE_WAYS_PER_SET_RANGE   `DCACHE_WAYS_PER_SET_WIDTH-1:0

`define DCACHE_BLOCK_SIZE       (`DCACHE_LINE_WIDTH/8)
`define DCACHE_BLOCK_ADDR_SIZE  $clog2(`DCACHE_BLOCK_SIZE)
`define DCACHE_INSTR_IN_LINE    5:2

`define DCACHE_TAG_WIDTH        (`DCACHE_ADDR_WIDTH - `DCACHE_NUM_SET_WIDTH - `DCACHE_BLOCK_ADDR_SIZE)
`define DCACHE_TAG_RANGE        `DCACHE_TAG_WIDTH- 1:0

`define DCACHE_OFFSET_WIDTH      `DCACHE_ADDR_WIDTH-`DCACHE_TAG_WIDTH-`DCACHE_NUM_SET_WIDTH
`define DCACHE_OFFSET_ADDR_RANGE `DCACHE_BLOCK_ADDR_SIZE+:2

// Data cache address decoding
`define DCACHE_TAG_ADDR_RANGE  (`DCACHE_ADDR_WIDTH - 1):(`DCACHE_NUM_SET_WIDTH + `DCACHE_BLOCK_ADDR_SIZE)
`define DCACHE_SET_ADDR_RANGE  (`DCACHE_BLOCK_ADDR_SIZE+`DCACHE_NUM_SET_WIDTH):`DCACHE_BLOCK_ADDR_SIZE

`endif // _CORE_DEFINES_
