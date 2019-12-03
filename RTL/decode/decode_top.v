`include "soc.vh"

module decode_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset_c,

    // Stall pipeline
    input   logic                               stall_decode,

    // Fetched instruction
    input   logic                               fetch_instr_valid,
    input   logic   [`INSTR_WIDTH-1:0]          fetch_instr_data,

    // Instruction to ALU
    output  logic                               dec_instr_valid,
    output  dec_instruction_info                dec_instr_info
);

logic   dec_instr_update;
dec_instruction_info        dec_instr_info_next;

//     CLK    RST      DOUT            DIN
`EN_FF(clock, reset_c, dec_instr_info, dec_instr_info_next)

//      CLK    RST      DOUT            DIN                  DEF
`RST_FF(clock, reset_c, dec_instr_valid, dec_instr_update, 1'b0)

assign dec_instr_update = ( stall_decode ) ? 1'b0 : 1'b1;

//TODO: Finish encoding and ask Roger the instructions really needed
always_comb
begin
// risc-v 32I ISA
    dec_instr_info_next.opcode    = fetch_instr_data[6:0];
    dec_instr_info_next.rd        = fetch_instr_data[11:7];
    dec_instr_info_next.funct3    = fetch_instr_data[14:12];
    dec_instr_info_next.ra        = fetch_instr_data[19:15];

    if ( dec_instr_info_next.opcode < XXX ) // R-format
    begin
        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH,fetch_instr_data[24:20]);
    end
    else if ( dec_instr_info_next.opcode < XXX ) // I-format
    begin
        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH,fetch_instr_data[31:20]);
    end
    else if ( dec_instr_info_next.opcode < XXX ) // S-format
    begin
        // These instructions have 12b of offset and src2 register. We encode
        // them in the struct such as: {3'b000,12b'offset, 5b'rs2}
        dec_instr_info_next.rb_offset = `ZX(`DEC_RB_OFF_WIDTH, {fetch_instr_data[31:25],   // imm[11:5]
                                                                fetch_instr_data[11:7],    // imm[4:0]
                                                                fetch_instr_data[24:20]}); // register source 2
    end
    else // U-format
    begin
        dec_instr_info_next.rb_offset = fetch_instr_data[31:12];
    end
end

endmodule

