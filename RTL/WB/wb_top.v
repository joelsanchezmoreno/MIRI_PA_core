`include "soc.vh"

module wb_top
(
  // System signals
  input   logic                         clock,
  input   logic                         reset_c,

  // Stall pipeline
  input   logic                         stall_wb,


  input  logic [`REG_FILE_RANGE]  	aluOut,
  input  logic [`REG_FILE_RANGE]  	cacheOut,
  
  input  logic 			 	memtoReg, //Mem Access

  input  logic [`REG_FILE_ADDR_RANGE] 	rdAddr, //Propagate the rd address

  output  logic [`REG_FILE_RANGE]  	wbOut,
  output  logic [`REG_FILE_ADDR_RANGE] 	wbOutAddr, 
  output logic 				writeEn
);

logic [`REG_FILE_RANGE]       wbOut_next;
logic [`REG_FILE_ADDR_RANGE]  wbOutAddr_next;
logic			      writeEn_next;

`RST_FF(clock, reset_c, wbOut, wbOut_next, '0)
`RST_FF(clock, reset_c, wbOutAddr, wbOutAddr_next, '0)
`RST_FF(clock, reset_c, , writeEn, writeEn_next, 1'b0)

always_comb
begin
	wbOut_next = '0;
	wbOutAddr_next = rdAddr;
	if (MemtoReg == 1)
		wbOut_next = cacheOut;
	else
		wbOut_next = aluOut;

end
endmodule
