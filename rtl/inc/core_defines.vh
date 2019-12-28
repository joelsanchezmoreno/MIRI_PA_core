`ifndef _CORE_DEFINES_
`define _CORE_DEFINES_

////////////////////////////////////////////////////////////////////////////////
// Whatever
////////////////////////////////////////////////////////////////////////////////

///////////////////////
// Global defines
///////////////////////
`define PC_WIDTH        32
`define PA_WIDTH        20
`define PC_WIDTH_RANGE  `PC_WIDTH-1:0

`define BYTE_RANGE      `BYTE_BITS-1:0
`define DWORD_RANGE     `DWORD_BITS-1:0

///////////////////////
// Register file defines
///////////////////////
`define REG_FILE_DATA_WIDTH 32
`define REG_FILE_DATA_RANGE `REG_FILE_DATA_WIDTH-1:0
`define REG_FILE_NUM_REGS   32
`define REG_FILE_NUM_REGS_RANGE  `REG_FILE_NUM_REGS-1:0
`define REG_FILE_ADDR_WIDTH $clog2(`REG_FILE_NUM_REGS)
`define REG_FILE_ADDR_RANGE `REG_FILE_ADDR_WIDTH-1:0

`define REG_FILE_XCPT_ADDR_WIDTH `PC_WIDTH  //FIXME: what should be the @ width
`define REG_FILE_XCPT_ADDR_RANGE `REG_FILE_XCPT_ADDR_WIDTH-1:0

///////////////////////
// Instruction defines
///////////////////////
`define INSTR_OPCODE_WIDTH  7
`define INSTR_OFFSET        20
`define INSTR_WIDTH         32 

`define INSTR_OPCODE_RANGE `INSTR_OPCODE_WIDTH-1:0

//////////////////////
// Decode defines
///////////////////////

`define INSTR_OPCODE_ADDR_RANGE 31:25
`define INSTR_DST_ADDR_RANGE    24:20
`define INSTR_SRC1_ADDR_RANGE   19:15
`define INSTR_SRC2_ADDR_RANGE   14:10

`define INSTR_OFFSET_LO_ADDR_RANGE  9:0
`define INSTR_OFFSET_M_ADDR_RANGE   14:10
`define INSTR_OFFSET_HI_ADDR_RANGE  24:20


`define INSTR_M_OFFSET_WIDTH 15
`define INSTR_M_OFFSET_RANGE `INSTR_M_OFFSET_WIDTH-1:0

`define INSTR_B_OFFSET_WIDTH 20
`define INSTR_B_OFFSET_RANGE `INSTR_B_OFFSET_WIDTH-1:0

`define ALU_OFFSET_WIDTH    `MAX(`INSTR_M_OFFSET_WIDTH, \
                                 `INSTR_B_OFFSET_WIDTH)

`define ALU_OFFSET_RANGE    `ALU_OFFSET_WIDTH-1:0

`define ALU_MUL_LATENCY         5
`define ALU_MUL_LATENCY_WIDTH   $clog2(`ALU_MUL_LATENCY)
`define ALU_MUL_LATENCY_RANGE   `ALU_MUL_LATENCY_WIDTH-1:0

///////////////////////
// OPCODES
///////////////////////

`define INSTR_ADD_OPCODE        `INSTR_OPCODE_WIDTH'h00
`define INSTR_SUB_OPCODE        `INSTR_OPCODE_WIDTH'h01
`define INSTR_MUL_OPCODE        `INSTR_OPCODE_WIDTH'h02
`define INSTR_ADDI_OPCODE       `INSTR_OPCODE_WIDTH'h03

`define INSTR_LDB_OPCODE        `INSTR_OPCODE_WIDTH'h10
`define INSTR_LDW_OPCODE        `INSTR_OPCODE_WIDTH'h11
`define INSTR_STB_OPCODE        `INSTR_OPCODE_WIDTH'h12
`define INSTR_STW_OPCODE        `INSTR_OPCODE_WIDTH'h13
`define INSTR_MOV_OPCODE        `INSTR_OPCODE_WIDTH'h14

`define INSTR_BEQ_OPCODE        `INSTR_OPCODE_WIDTH'h30
`define INSTR_BNE_OPCODE        `INSTR_OPCODE_WIDTH'h34
`define INSTR_BLT_OPCODE        `INSTR_OPCODE_WIDTH'h35
`define INSTR_BGT_OPCODE        `INSTR_OPCODE_WIDTH'h36
`define INSTR_BLE_OPCODE        `INSTR_OPCODE_WIDTH'h37
`define INSTR_BGE_OPCODE        `INSTR_OPCODE_WIDTH'h38
`define INSTR_JUMP_OPCODE       `INSTR_OPCODE_WIDTH'h31

`define INSTR_TLBWRITE_OPCODE   `INSTR_OPCODE_WIDTH'h32
`define INSTR_IRET_OPCODE       `INSTR_OPCODE_WIDTH'h33

`define INSTR_NOP_OPCODE        `INSTR_OPCODE_WIDTH'hFF

///////////////////////
// Instruction cache defines
///////////////////////
`define ICACHE_ADDR_WIDTH   `PC_WIDTH
`define ICACHE_LINE_WIDTH   `MAIN_MEMORY_LINE_WIDTH // data

`define ICACHE_NUM_SET          2
`define ICACHE_NUM_SET_WIDTH    $clog2(`ICACHE_NUM_SET)
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
`define ICACHE_INSTR_IN_LINE_WIDTH 4

`define ICACHE_TAG_WIDTH        (`ICACHE_ADDR_WIDTH - `ICACHE_NUM_SET_WIDTH - `ICACHE_BLOCK_ADDR_SIZE)
`define ICACHE_TAG_RANGE        `ICACHE_TAG_WIDTH - 1:0

`define ICACHE_RSH_VAL      $clog2(`ICACHE_BLOCK_SIZE)


// Instruction cache address decoding
`define ICACHE_TAG_ADDR_RANGE  (`ICACHE_ADDR_WIDTH - 1):(`ICACHE_NUM_SET_WIDTH + `ICACHE_BLOCK_ADDR_SIZE)
`define ICACHE_SET_ADDR_RANGE  (`ICACHE_NUM_SET_WIDTH + `ICACHE_BLOCK_ADDR_SIZE-1):`ICACHE_BLOCK_ADDR_SIZE


///////////////////////
// Data cache defines
///////////////////////
`define DCACHE_ADDR_WIDTH       `PC_WIDTH  //FIXME: what should be the @ width
`define DCACHE_ADDR_RANGE       `DCACHE_ADDR_WIDTH-1:0
`define DCACHE_LINE_WIDTH       `MAIN_MEMORY_LINE_WIDTH // data
`define DCACHE_LINE_RANGE       `DCACHE_LINE_WIDTH-1:0 // data

`define DCACHE_MAX_ACC_SIZE     `DWORD_BITS // maximum access size is to words
`define DCACHE_SIZE_WIDTH        $clog2(2)

`define DCACHE_NUM_SET          2
`define DCACHE_NUM_SET_WIDTH    $clog2(`DCACHE_NUM_SET)
`define DCACHE_NUM_SET_RANGE   `DCACHE_NUM_SET_WIDTH-1:0

`define DCACHE_NUM_WAYS         4
`define DCACHE_NUM_WAYS_R       `DCACHE_NUM_WAYS-1:0
`define DCACHE_NUM_WAY_WIDTH    $clog2(`DCACHE_NUM_WAYS)
`define DCACHE_NUM_WAY_RANGE   `DCACHE_NUM_WAY_WIDTH-1:0

`define DCACHE_WAYS_PER_SET         (`DCACHE_NUM_WAYS/`DCACHE_NUM_SET)
`define DCACHE_WAYS_PER_SET_WIDTH   $clog2(`DCACHE_WAYS_PER_SET)
`define DCACHE_WAYS_PER_SET_RANGE   `DCACHE_WAYS_PER_SET_WIDTH-1:0

`define DCACHE_BLOCK_SIZE       (`DCACHE_LINE_WIDTH/8)
`define DCACHE_BLOCK_ADDR_SIZE  $clog2(`DCACHE_BLOCK_SIZE)

`define DCACHE_TAG_WIDTH        (`DCACHE_ADDR_WIDTH - `DCACHE_NUM_SET_WIDTH - `DCACHE_BLOCK_ADDR_SIZE)
`define DCACHE_TAG_RANGE        `DCACHE_TAG_WIDTH- 1:0

`define DCACHE_OFFSET_WIDTH      `DCACHE_ADDR_WIDTH-`DCACHE_TAG_WIDTH-`DCACHE_NUM_SET_WIDTH
`define DCACHE_OFFSET_RANGE      `DCACHE_OFFSET_WIDTH-1:0

// Data cache address decoding
`define DCACHE_TAG_ADDR_RANGE  (`DCACHE_ADDR_WIDTH - 1):(`DCACHE_NUM_SET_WIDTH + `DCACHE_BLOCK_ADDR_SIZE)
`define DCACHE_SET_ADDR_RANGE  (`DCACHE_NUM_SET_WIDTH + `DCACHE_BLOCK_ADDR_SIZE-1):`DCACHE_BLOCK_ADDR_SIZE
`define DCACHE_OFFSET_ADDR_RANGE `DCACHE_BLOCK_ADDR_SIZE-1:0

`define DCACHE_ADDR_RSH_VAL      $clog2(`DCACHE_BLOCK_SIZE)

// Store Buffer
`define DCACHE_ST_BUFFER_NUM_ENTRIES    8
`define DCACHE_ST_BUFFER_ENTRIES_RANGE  `DCACHE_ST_BUFFER_NUM_ENTRIES-1:0
`define DCACHE_ST_BUFFER_ENTRIES_WIDTH  $clog2(`DCACHE_ST_BUFFER_NUM_ENTRIES)

`define GET_UPPER_BOUND(req_size,req_offset) (req_size*req_offset+req_size)
`define GET_LOWER_BOUND(req_size,req_offset) (req_size*req_offset)


`endif // _CORE_DEFINES_
