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
            |(opcode == `INSTR_SLL_OPCODE)
            |(opcode == `INSTR_SRL_OPCODE)
            |(opcode == `INSTR_ADDI_OPCODE))
                is_r_type_instr = 1'b1;
    end
endfunction


function automatic is_addi_type_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_addi_type_instr = 1'b0;
        if (opcode == `INSTR_ADDI_OPCODE)
            is_addi_type_instr = 1'b1;
    end
endfunction

function automatic is_mul_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_mul_instr = 1'b0;
        if (opcode == `INSTR_MUL_OPCODE)
                is_mul_instr = 1'b1;
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

function automatic is_branch_type_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_branch_type_instr = 1'b0;
        if ( (opcode == `INSTR_BEQ_OPCODE)
            |(opcode == `INSTR_BNE_OPCODE)
            |(opcode == `INSTR_BLT_OPCODE)
            |(opcode == `INSTR_BGT_OPCODE)
            |(opcode == `INSTR_BLE_OPCODE)
            |(opcode == `INSTR_BGE_OPCODE))
                is_branch_type_instr = 1'b1;
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

function automatic is_jump_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_jump_instr = 1'b0;
        if (opcode == `INSTR_JUMP_OPCODE)
                is_jump_instr = 1'b1;
    end
endfunction

function automatic is_mov_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_mov_instr = 1'b0;
        if (opcode == `INSTR_MOV_OPCODE)
                is_mov_instr = 1'b1;
    end
endfunction

function automatic is_nop_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_nop_instr = 1'b0;
        if (opcode == `INSTR_NOP_OPCODE)
                is_nop_instr = 1'b1;
    end
endfunction

function automatic is_tlb_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_tlb_instr = 1'b0;
        if (opcode == `INSTR_TLBWRITE_OPCODE)
                is_tlb_instr = 1'b1;
    end
endfunction

function automatic is_iret_instr;
    input logic [`INSTR_OPCODE_RANGE] opcode;
    begin
        is_iret_instr = 1'b0;
        if (opcode == `INSTR_IRET_OPCODE)
                is_iret_instr = 1'b1;
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

typedef enum logic [0:0] {
   User            = 1'b0, 
   Supervisor      = 1'b1
} priv_mode_t;

typedef enum logic [2:0] {
   iTlb_miss        = 3'b000, 
   fetch_bus_error  = 3'b001,
   illegal_instr    = 3'b010,
   overflow         = 3'b011,
   dTlb_miss        = 3'b100,
   cache_bus_error  = 3'b101,
   cache_addr_fault = 3'b110,
   reserved         = 3'b111
} xcpt_type_t;

////////////////////////////////////////////////////////////////////////////////
// STRUCTS FOR EXCEPTIONS
////////////////////////////////////////////////////////////////////////////////

typedef struct packed 
{
    logic                       xcpt_itlb_miss;
    logic                       xcpt_bus_error;
    logic [`VIRT_ADDR_RANGE]    xcpt_addr_val;
    logic [`PC_WIDTH_RANGE]     xcpt_pc;
} fetch_xcpt_t; 

typedef struct packed 
{
    logic                   xcpt_illegal_instr;
    logic [`PC_WIDTH_RANGE] xcpt_pc;
} decode_xcpt_t; 

typedef struct packed 
{
    logic                   xcpt_overflow;
    logic [`PC_WIDTH_RANGE] xcpt_pc;
} alu_xcpt_t; 

typedef struct packed 
{
    logic                   xcpt_overflow;
    logic [`PC_WIDTH_RANGE] xcpt_pc;
} mul_xcpt_t; 

typedef struct packed 
{
    logic                       xcpt_addr_fault;
    logic                       xcpt_bus_error;
    logic                       xcpt_dtlb_miss;
    logic [`VIRT_ADDR_RANGE]    xcpt_addr_val;
    logic [`PC_WIDTH_RANGE]     xcpt_pc;
} cache_xcpt_t;


////////////////////////////////////////////////////////////////////////////////
// STRUCTS FOR CONTROL SIGNALS
////////////////////////////////////////////////////////////////////////////////

typedef struct packed 
{
    logic                    valid;
    logic [`VIRT_ADDR_RANGE] addr_val;
    logic [`PC_WIDTH_RANGE]  pc;
    xcpt_type_t              xcpt_type;
} reorder_buffer_xcpt_info_t;

typedef struct packed 
{
    logic [`PHY_ADDR_RANGE]             addr;
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

typedef struct packed 
{
    logic [`VIRT_TAG_RANGE] va_addr_tag; 
    logic [`PHY_TAG_RANGE]  pa_addr_tag; 
    logic                   writePriv;
} tlb_info_t;

typedef struct packed 
{
    logic [`VIRT_ADDR_RANGE] virt_addr; 
    logic [`PHY_ADDR_RANGE]  phy_addr; 
    logic                    writePriv;
} tlb_req_info_t;

typedef struct packed 
{
    logic [`ROB_ID_RANGE]           instr_id; // identifier
        //TLBWRITE
    logic                           tlbwrite;   // asserted if req is TLBWRITE
    logic                           tlb_id; 
    tlb_req_info_t                  tlb_req_info;
        // RF
    logic                           rf_wen;     // asserted if req is RF write
    logic [`REG_FILE_ADDR_RANGE]    rf_dest;
    logic [`REG_FILE_DATA_RANGE]    rf_data;
        // Exceptions
    reorder_buffer_xcpt_info_t      xcpt_info;
        // Memory
    logic [`VIRT_ADDR_RANGE]         virt_addr; 
    logic [`REG_FILE_ADDR_RANGE]     rd_addr;
    logic [`VIRT_ADDR_RANGE]         addr;
    req_size_t                       size;
    logic                            is_store; // asserted when request is a store
    logic [`DCACHE_MAX_ACC_SIZE-1:0] data;
} reorder_buffer_t;

typedef struct packed 
{
    logic [`PC_WIDTH_RANGE] pc;
    fetch_xcpt_t            xcpt_fetch;
    decode_xcpt_t           xcpt_decode;
    alu_xcpt_t              xcpt_alu;
} rob_dcache_request_t;

////////////////////////////////////////////////////////////////////////////////
// STRUCTS FOR REQUEST BETWEEN STAGES
////////////////////////////////////////////////////////////////////////////////
typedef struct packed 
{
    logic   [`REG_FILE_ADDR_RANGE]  rd_addr; // Destination register
    logic   [`REG_FILE_ADDR_RANGE]  ra_addr; // Source register A (rs1)
    logic   [`REG_FILE_ADDR_RANGE]  rb_addr; // Source register A (rs2)
    logic   [`REG_FILE_DATA_RANGE]  ra_data; // Source register A (rs1)
    logic   [`REG_FILE_DATA_RANGE]  rb_data; // Source register B (rs2) or ST dst value
    logic   [`ROB_ID_RANGE]         ticket_src1;    // instr. that is blocking src1
    logic                           rob_blocks_src1;// Asserted if there is an instr. blocking src1
    logic   [`ROB_ID_RANGE]         ticket_src2;    // instr. that is blocking src2
    logic                           rob_blocks_src2;// Asserted if there is an instr. blocking src2
} mul_request_t;

typedef struct packed 
{
    logic   [`REG_FILE_ADDR_RANGE]  rd_addr; // Destination register
    logic   [`REG_FILE_ADDR_RANGE]  ra_addr; // Source register A (rs1)
    logic   [`REG_FILE_ADDR_RANGE]  rb_addr; // Source register A (rs2)
    logic   [`REG_FILE_DATA_RANGE]  ra_data; // Source register A (rs1)
    logic   [`REG_FILE_DATA_RANGE]  rb_data; // Source register B (rs2) or ST dst value
    logic   [`ALU_OFFSET_RANGE]     offset;  // Offset value
    logic   [`INSTR_OPCODE_RANGE]   opcode;  // Operation code
    logic   [`ROB_ID_RANGE]         ticket_src1;    // instr. that is blocking src1
    logic                           rob_blocks_src1;// Asserted if there is an instr. blocking src1
    logic   [`ROB_ID_RANGE]         ticket_src2;    // instr. that is blocking src2
    logic                           rob_blocks_src2;// Asserted if there is an instr. blocking src2
} alu_request_t;

typedef struct packed 
{
    logic [`ROB_ID_RANGE]            instr_id;
    logic [`PC_WIDTH-1:0]            pc;
    logic [`REG_FILE_ADDR_RANGE]     rd_addr;
    logic [`VIRT_ADDR_RANGE]         addr;
    req_size_t                       size;
    logic                            is_store; // asserted when request is a store
    logic [`DCACHE_MAX_ACC_SIZE-1:0] data;
    fetch_xcpt_t                     xcpt_fetch;
    decode_xcpt_t                    xcpt_decode;
    alu_xcpt_t                       xcpt_alu;
} dcache_request_t;

typedef struct packed 
{
    logic [`ROB_ID_RANGE]           instr_id;
    logic [`PC_WIDTH-1:0]           pc;
        // TLBWRITE
    logic                           tlbwrite;  
    logic                           tlb_id; 
    tlb_req_info_t                  tlb_req_info;
        // RF
    logic                           rf_wen;
    logic [`REG_FILE_ADDR_RANGE]    rf_dest;
    logic [`REG_FILE_DATA_RANGE]    rf_data;
        // Exceptions
    fetch_xcpt_t                    xcpt_fetch;
    decode_xcpt_t                   xcpt_decode;
    alu_xcpt_t                      xcpt_alu;
    mul_xcpt_t                      xcpt_mul;
    cache_xcpt_t                    xcpt_cache;    
} writeback_request_t;



`endif // _CORE_TYPES_

