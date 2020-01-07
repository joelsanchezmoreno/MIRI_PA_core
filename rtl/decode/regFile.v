`include "soc.vh"

module regFile 
(
    // System signals
    input   logic                               clock,
    input   logic                               reset, 

    // Read port
    input   logic [`REG_FILE_ADDR_RANGE]        src1_addr, 
    input   logic [`REG_FILE_ADDR_RANGE]        src2_addr,
    output  logic [`REG_FILE_DATA_RANGE]        reg1_data, 
    output  logic [`REG_FILE_DATA_RANGE]        reg2_data,

    // Internal registers
    input   logic                               iret_instr,
    output  priv_mode_t                         priv_mode,
    output  logic [`REG_FILE_DATA_RANGE]        rm0_data,
    output  logic [`REG_FILE_DATA_RANGE]        rm1_data,
    output  logic [`REG_FILE_DATA_RANGE]        rm2_data,

    // Write port
    input   logic                               writeEn,
    input   logic [`REG_FILE_ADDR_RANGE]        dest_addr,
    input   logic [`REG_FILE_DATA_RANGE]        writeVal,

    // Exception input
    input   logic                               xcpt_valid,
    input   xcpt_type_t                         xcpt_type,
    input   logic [`PC_WIDTH-1:0]               rmPC,
    input   logic [`REG_FILE_XCPT_ADDR_RANGE]   rmAddr
);

// FF to store the registers data
logic [`REG_FILE_NUM_REGS_RANGE][`REG_FILE_DATA_RANGE]regMem     ;
logic [`REG_FILE_NUM_REGS_RANGE][`REG_FILE_DATA_RANGE]regMem_ff  ;

// Exception PC
logic [`REG_FILE_DATA_RANGE] rm0;
logic [`REG_FILE_DATA_RANGE] rm0_ff;

// Exception address fault
logic [`REG_FILE_DATA_RANGE] rm1;
logic [`REG_FILE_DATA_RANGE] rm1_ff;

// Exception type
xcpt_type_t rm2;
xcpt_type_t rm2_ff;

// Privilege mode
priv_mode_t rm4;
priv_mode_t rm4_ff;

//      CLK    RST      DOUT     DIN     DEF
`RST_FF(clock, reset, regMem_ff, regMem, '0)
`RST_FF(clock, reset, rm0_ff,    rm0,    '0)
`RST_FF(clock, reset, rm1_ff,    rm1,    '0)
`RST_FF(clock, reset, rm2_ff,    rm2,    '0)
`RST_FF(clock, reset, rm4_ff,    rm4,    '1) //Default is Supervisor

always_comb
begin
    rm0     = rm0_ff;
    rm1     = rm1_ff;
    rm2     = rm2_ff;
    rm4     = rm4_ff;
    regMem  = regMem_ff;

    if (writeEn) 
        regMem[dest_addr] = writeVal;

    if (xcpt_valid)
    begin	
        rm0 = rmPC;
        rm1 = rmAddr;
        rm2 = xcpt_type;
        rm4 = Supervisor;
    end
    else
    begin
        if (iret_instr)
            rm4 = User;    
    end
    
    reg1_data   = (regMem_ff[src1_addr]);
    reg2_data   = (regMem_ff[src2_addr]);
    rm0_data    = rm0_ff;
    rm1_data    = rm1_ff;
    rm2_data    = rm2_ff;
    priv_mode   = rm4_ff;
end

endmodule 
