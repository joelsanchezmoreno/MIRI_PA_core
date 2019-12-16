module regFile 
(
    // System signals
    input   logic                          clock,
    input   logic                          reset, 

    // Read port
    input   logic [`REG_FILE_ADDR_RANGE]   src1_addr, 
    input   logic [`REG_FILE_ADDR_RANGE]   src2_addr,
    output  logic [`REG_FILE_DATA_RANGE]   reg1_data, 
    output  logic [`REG_FILE_DATA_RANGE]   reg2_data,

    // Write port
    input   logic                          writeEn,
    input   logic [`REG_FILE_ADDR_RANGE]   dest_addr,
    input   logic [`REG_FILE_DATA_RANGE]   writeVal,

    // Exception input
    input   logic                          xcpt_valid,
    input   logic [`PC_WIDTH-1:0]          rmPC,
    input   logic [`REG_FILE_ADDR_RANGE]   rmAddr
);

// FF to store the registers data
logic [`REG_FILE_DATA_RANGE] regMem,regMem_ff [`REG_FILE_ADDR_RANGE];
logic [`REG_FILE_DATA_RANGE] rm0, rm0_ff;
logic [`REG_FILE_DATA_RANGE] rm1, rm1_ff;

//      CLK    RST      DOUT     DIN     DEF
`RST_FF(clock, reset, regMem_ff, regMem, '0)
`RST_FF(clock, reset, rm0_ff, rm0, '0)
`RST_FF(clock, reset, rm1_ff, rm1, '0)

integer i;

always_comb
begin
    rm0     = rm0_ff;
    rm1     = rm1_ff;
    regMem  = regMem_ff;

    if (writeEn) 
        regMem[dest_addr] = writeVal;

    if (xcpt_valid)
    begin	
          rm0 = rmPC;
          rm1 = rmAddr;
    end
    
    reg1_data = (regMem_ff[src1_addr]);
    reg2_data = (regMem_ff[src2_addr]);
end

endmodule 
