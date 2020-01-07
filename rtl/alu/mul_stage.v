`include "soc.vh"
module mul_stage
(
    // Request from previous mul stage
        // Operation
    input   logic                           instr_valid_in,
    input   logic [`ROB_ID_RANGE]           instr_id_in,
    input   logic [`PC_WIDTH-1:0]           program_counter_in,
    input   logic [`REG_FILE_ADDR_RANGE]    dest_reg_in,
    input   logic [`REG_FILE_DATA_RANGE]    data_result_in,
  
        // Exceptions
    input   fetch_xcpt_t                    xcpt_fetch_in,
    input   decode_xcpt_t                   xcpt_decode_in,
    input   mul_xcpt_t                      xcpt_mul_in,

    // Request to next mul stage 
        // RF
    output  logic                           instr_valid_out,
    output  logic [`ROB_ID_RANGE]           instr_id_out,
    output  logic [`PC_WIDTH-1:0]           program_counter_out,
    output  logic [`REG_FILE_ADDR_RANGE]    dest_reg_out,
    output  logic [`REG_FILE_DATA_RANGE]    data_result_out,
    
        // Exceptions
    output  fetch_xcpt_t                    xcpt_fetch_out,
    output  decode_xcpt_t                   xcpt_decode_out,
    output  mul_xcpt_t                      xcpt_mul_out
);

always_comb
begin
    instr_valid_out     = instr_valid_in;
    instr_id_out        = instr_id_in;
    program_counter_out = program_counter_in;
    dest_reg_out        = dest_reg_in;
    data_result_out     = data_result_in;                             
                                              
    xcpt_fetch_out      = xcpt_fetch_in;                      
    xcpt_decode_out     = xcpt_decode_in;
    xcpt_mul_out        = xcpt_mul_in;
end                      

endmodule
