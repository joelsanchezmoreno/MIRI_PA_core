module regFile (clk, rst, src1, src2, dest, writeVal, writeEn, reg1, reg2);
  input clk, rst, writeEn;
  input [4:0] src1, src2, dest;
  input [31:0] writeVal;
  output [31:0] reg1, reg2;

  reg [31:0] regMem [4:0];
  integer i;

  always @ (posedge clk) begin
    if (rst) begin
      for (i = 0; i < 31; i = i + 1)
        regMem[i] <= 0;
	    end

    else if (writeEn) regMem[dest] <= writeVal;
  end

  assign reg1 = (regMem[src1]);
  assign reg2 = (regMem[src2]);

endmodule 
