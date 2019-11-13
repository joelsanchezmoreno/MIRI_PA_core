module instructionMem (rst, addr, instruction);
  input rst;
  input [31:0] addr;
  output [31:0] instruction;

  reg [31:0] instMem [31:0];
  //5 cycles to go to memory
  //5 cycles to return data to processor
  always @ (*) begin
  	if (rst) begin
        // Here initialize the memory 

      end
    end

  assign instruction = instMem[address];
endmodule 

