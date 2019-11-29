module ALU (val1, val2, instr, aluOut);
  input [31:0] val1, val2;
  input [7:0] instr;
  output reg [31:0] aluOut;

  always @ ( * ) begini
    case (instr)
      8'b00000000: aluOut <= val1 + val2; //add
      8'b00000001: aluOut <= val1 - val2; //sub
      8'b00000010: aluOut <= val1 * val2; //mul (to add 3 cicles latency)
      8'b00010000: aluOut <= val1 + val2; //ldb base register + offset
      8'b00010001: aluOut <= val1 + val2; //ldw
      8'b00010010: aluOut <= val1 + val2; ///stb
      8'b00010011: aluOut <= val1 + val2; ///stw
      8'b00110000: aluOut <= (val1 = val2) ? 1 : 0; //beq
      8'b00110001: aluOut <= val1 + val2; //jump r1 + offset
      8'b00110010: ;//tlbwrite
      8'b00110011: ;//iret
      default: aluOut <= 0;
    endcase
  end
endmodule
