`ifndef _CORE_TYPES_
`define _CORE_TYPES_

////////////////////////////////////////////////////////////////
// FUNCTIONS
////////////////////////////////////////////////////////////////

function automatic is_r_type_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_r_type_instr = 1'b0;
        if ( (opcode == `INSTR_ADD_OPCODE)
            |(opcode == `INSTR_SUB_OPCODE)
            |(opcode == `INSTR_MUL_OPCODE)
            |(opcode == `INSTR_ADDI_OPCODE))
                is_r_type_instr = 1'b1;
    end
endfunction

function automatic is_m_type_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_m_type_instr = 1'b0;
        if ( (opcode == `INSTR_LDB_OPCODE)
            |(opcode == `INSTR_LDW_OPCODE)
            |(opcode == `INSTR_STB_OPCODE)
            |(opcode == `INSTR_STW_OPCODE))
                is_m_type_instr = 1'b1;
    end
endfunction

function automatic is_load_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_load_instr = 1'b0;
        if ( (opcode == `INSTR_LDB_OPCODE)
            |(opcode == `INSTR_LDW_OPCODE))
                is_load_instr = 1'b1;
    end
endfunction

function automatic is_store_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_store_instr = 1'b0;
        if ( (opcode == `INSTR_STB_OPCODE)
            |(opcode == `INSTR_STW_OPCODE))
                is_store_instr = 1'b1;
    end
endfunction
////////////////////////////////////////////////////////////////////////////////
// ENUMS
////////////////////////////////////////////////////////////////////////////////

typedef enum logic [1:0] {
   Byte            = 2'b00, // 8b
   HWord           = 2'b01, // 16b
   Word            = 2'b11  // 32b
} req_size_t;

typedef enum logic [1:0] {
   idle            = 2'b00, 
   evict_line      = 2'b01, 
   bring_line      = 2'b10, 
   write_cache_line= 2'b11
} dcache_state_t;

////////////////////////////////////////////////////////////////////////////////
// STRUCTS
////////////////////////////////////////////////////////////////////////////////

typedef struct packed 
{
    logic   [`REG_FILE_ADDR_RANGE]  rd_addr; // Destination register
    logic   [`REG_FILE_ADDR_RANGE]  ra_addr; // Source register A (rs1)
    logic   [`REG_FILE_DATA_RANGE]  ra_data; // Source register A (rs1)
    logic   [`REG_FILE_DATA_RANGE]  rb_data; // Source register B (rs2)
    logic   [`ALU_OFFSET_RANGE]     offset;  // Offset value
    logic   [`INSTR_OPCODE_RANGE]   opcode;  // Operation code
} alu_request_t;

typedef struct packed 
{
    logic [`DCACHE_ADDR_RANGE]       addr;
    req_size_t                       size;
    logic                            is_store; // asserted when request is a store
    logic [`DCACHE_MAX_ACC_SIZE-1:0] data;
} dcache_request_t;

typedef struct packed 
{
    logic [`DCACHE_ADDR_RANGE]          addr;
    logic                               is_store; // asserted when request is a store
    logic [`MAIN_MEMORY_LINE_WIDTH-1:0] data;
} memory_request_t;

typedef struct packed 
{
    logic [`DCACHE_ADDR_RANGE]          addr; 
    logic [`DCACHE_WAYS_PER_SET_RANGE]  way; 
    req_size_t                          size;
    logic [`DCACHE_MAX_ACC_SIZE-1:0]    data;
} store_buffer_t;


// Exceptions
typedef struct packed 
{
    logic                   xcpt_fetch_itlb_miss;
    logic [`PC_WIDTH_RANGE] xcpt_pc;
} fetch_xcpt_t; //FIXME: add address of the miss???

typedef struct packed 
{
    logic                   xcpt_illegal_instr;
    logic [`PC_WIDTH_RANGE] xcpt_pc;
} decode_xcpt_t; //FIXME: add opcode ??

typedef struct packed 
{
    logic                       xcpt_addr_fault;
    logic                       xcpt_fetch_dtlb_miss;
    logic [`DCACHE_ADDR_RANGE]  xcpt_addr_val;
    logic [`PC_WIDTH_RANGE]     xcpt_pc;
} cache_xcpt_t; //FIXME: add dTlb address???

`endif // _CORE_TYPES_

