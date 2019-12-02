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
    logic   [`DEC_FUNC3_WIDTH-1:0]  funct3;
} dec_instruction_info;

typedef struct packed 
{
    logic                                       valid; //active
    logic   [3:0]                               counter; //rsp counter
    logic                                       error; //error found
    logic   [`SC_MESH_SLAVE_AXI_ID_SIZE-1:0]    axi_id; //id of axi req
} alu_ctrl;
