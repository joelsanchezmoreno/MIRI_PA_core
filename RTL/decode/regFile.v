module regFile (
  input logic clock,
  input logic reset, 
  input logic writeEn,

  input logic [`REG_FILE_ADDR_RANGE] src1, 
  input logic [`REG_FILE_ADDR_RANGE] src2, 
  input logic [`REG_FILE_ADDR_RANGE] dest,

  input  logic [`REG_FILE_RANGE] writeVal,
  output logic [`REG_FILE_RANGE] reg1, 
  output logic [`REG_FILE_RANGE] reg2,

  input logic excV,
  input logic [`PC_WIDTH-1:0] rmPC,
  input logic [`REG_FILE_ADDR_RANGE] rmAddr

);

  logic [`REG_FILE_RANGE] regMem [`REG_FILE_ADDR_RANGE];
  logic [`REG_FILE_RANGE] rm0;
  logic [`REG_FILE_RANGE] rm1;


  logic [`REG_FILE_RANGE] regMem_ff [`REG_FILE_ADDR_RANGE];
  logic [`REG_FILE_RANGE] rm0_ff;
  logic [`REG_FILE_RANGE] rm1_ff;

  //      CLK    RST      DOUT     DIN     DEF
  `RST_FF(clock, reset, regMem_ff, regMem, '0)
  `RST_FF(clock, reset, rm0_ff, rm0, '0)
  `RST_FF(clock, reset, rm1_ff, rm1, '0)


  integer i;
  always_comb
  begin
	rm0 = rm0_ff;
	rm1 = rm1_ff;
	regMem = regMem_ff;
	if (writeEn) regMem[dest] = writeVal;	
	if (excV)
	begin	
          rm0 = rmPC;
          rm1 = rmAddr;
 	end
  	reg1 = (regMem_ff[src1]);
	reg2 = (regMem_ff[src2]);
  end

endmodule 
