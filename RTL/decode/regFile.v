module regFile (clk, rst, src1, src2, dest, writeVal, writeEn, reg1, reg2, rmPC; rmAddr, excV);
  input clk, rst, writeEn;
  input [4:0] src1, src2, dest;
  input [31:0] writeVal;
  output [31:0] reg1, reg2;

  reg [31:0] regMem [4:0];
  reg [31:0] rm0;
  reg [31:0] rm1;

  integer i;

  always @ (posedge clk) begin
    if (rst) begin
      rm0 <= 0;
      rm1 <= 0;
      for (i = 0; i < 31; i = i + 1)
        regMem[i] <= 0;
    end

    else if (writeEn) regMem[dest] <= writeVal;
    else if (excV) 
	    rm0 <= rmPC;
    	    rm1 <= rmAddr;
  end

  assign reg1 = (regMem[src1]);
  assign reg2 = (regMem[src2]);

endmodule 
