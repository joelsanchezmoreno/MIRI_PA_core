`ifndef _CORE_TYPES_
`define _CORE_TYPES_
////////////////////////////////////////////////////////////////////////////////
// ENUMS
////////////////////////////////////////////////////////////////////////////////

// Instruction function
//
typedef enum logic [1:0]
{
    // ALU pipe operations
    core_alu_func_X       = 2'bxx, // Don't care 
    core_alu_func_ADD     = 2'b00, // Add
    core_alu_func_OR      = 2'b01, // Or
    core_alu_func_AND     = 2'b10, // And
    core_alu_func_SUB     = 2'b11  // Sub
} core_alu_func;

typedef struct packed 
{
    logic   [`REG_FILE_RANGE]       rd;         // Destination register
    logic   [`REG_FILE_RANGE]       ra;         // Source register A (rs1)
    logic   [`DEC_RB_OFF_WIDTH-1:0] rb_offset;  // Source register B (rs2) or Offset value
    logic   [`INSTR_OPCODE-1:0]     opcode;     // Operation code
} dec_instruction_info;

typedef struct packed 
{
    logic                                       valid; //active
    logic   [3:0]                               counter; //rsp counter
    logic                                       error; //error found
    logic   [`SC_MESH_SLAVE_AXI_ID_SIZE-1:0]    axi_id; //id of axi req
} alu_ctrl;

typedef struct packed 
{
    logic [`DCACHE_ADDR_WIDTH-1:0]   addr;
    logic [`WORD_WIDTH-1:0]          size;     // maximum size is word (32b)
    logic                            is_store; // asserted when request is a store
    logic [`DCACHE_MAX_ACC_SIZE-1:0] data;
} dcache_request_t;

typedef struct packed 
{
    logic [`DCACHE_ADDR_WIDTH-1:0]      addr;
    logic                               is_store; // asserted when request is a store
    logic [`MAIN_MEMORY_LINE_WIDTH-1:0] data;
} memory_request_t;

typedef struct packed 
{
    logic [`DCACHE_ADDR_WIDTH-1:0]      tag;
    logic [`DCACHE_ADDR_WIDTH-1:0]      set; 
    logic [`WORD_WIDTH-1:0]             size;
    logic [`DCACHE_MAX_ACC_SIZE-1:0]    data;
} store_buffer_t;

`endif // _CORE_TYPES_

