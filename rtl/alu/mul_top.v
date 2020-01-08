`include "soc.vh"
module mul_top
(
    // System signals
    input   logic                           clock,
    input   logic                           reset,

    // Stall pipeline
    input   logic                           flush_mul,
    output  logic                           stall_decode,
    
    // Request from decode stage
        // Operation
    input   logic                           req_mul_valid,  
    input   mul_request_t                   req_mul_info,  
    input   logic [`ROB_ID_RANGE]           req_mul_instr_id,
    input   logic [`PC_WIDTH-1:0]           req_mul_pc,
   
        // Exceptions
    input   fetch_xcpt_t                    xcpt_fetch_in,
    input   decode_xcpt_t                   xcpt_decode_in,

    // Request to WB stage
    output  logic                           req_wb_valid,
    output  writeback_request_t             req_wb_info,

    // Bypasses
        // Reorder buffer
    output  logic [`ROB_ID_RANGE]           rob_src1_id,
    output  logic [`ROB_ID_RANGE]           rob_src2_id,
    input   logic                           rob_src1_hit,
    input   logic                           rob_src2_hit,
    input   logic [`REG_FILE_DATA_RANGE]    rob_src1_data,
    input   logic [`REG_FILE_DATA_RANGE]    rob_src2_data
);

logic fetch_xcpt_valid;
assign fetch_xcpt_valid = req_mul_valid &  
                         ( xcpt_fetch_in.xcpt_itlb_miss
                         | xcpt_fetch_in.xcpt_bus_error 
                         | xcpt_fetch_in.xcpt_addr_val); 

logic decode_xcpt_valid;
assign decode_xcpt_valid =  req_mul_valid
                          & xcpt_decode_in.xcpt_illegal_instr;




//////////////////////////////////////
// Stall

logic stall_decode_ff;

//      CLK    RST                DOUT             DIN           DEF
`RST_FF(clock, reset | flush_mul, stall_decode_ff, stall_decode, 1'b0)

//////////////
// Signals between stages
logic [`ALU_MUL_LATENCY:0]                       instr_valid_next;
logic [`ALU_MUL_LATENCY:0]                       instr_valid_ff;      

//      CLK    RST                DOUT            DIN               DEF
`RST_FF(clock, reset | flush_mul, instr_valid_ff, instr_valid_next, '0)

logic [`ALU_MUL_LATENCY:0][`PC_WIDTH-1:0]        req_wb_pc_ff;
logic [`ALU_MUL_LATENCY:0][`PC_WIDTH-1:0]        req_wb_pc_next;

logic [`ALU_MUL_LATENCY:0][`ALU_OVW_DATA_RANGE]  mul_oper_data_next;
logic [`ALU_MUL_LATENCY:0][`ALU_OVW_DATA_RANGE]  mul_oper_data_ff;

logic [`ALU_MUL_LATENCY:0][`REG_FILE_ADDR_RANGE] rd_addr_next;
logic [`ALU_MUL_LATENCY:0][`REG_FILE_ADDR_RANGE] rd_addr_ff;

logic [`ALU_MUL_LATENCY:0][`ROB_ID_RANGE]        instr_id_next; 
logic [`ALU_MUL_LATENCY:0][`ROB_ID_RANGE]        instr_id_ff; 

//  CLK    DOUT              DIN
`FF(clock, req_wb_pc_ff,     req_wb_pc_next)
`FF(clock, mul_oper_data_ff, mul_oper_data_next)
`FF(clock, rd_addr_ff,       rd_addr_next)
`FF(clock, instr_id_ff,      instr_id_next)


fetch_xcpt_t    [`ALU_MUL_LATENCY:0]             mul_xcpt_fetch_next;
fetch_xcpt_t    [`ALU_MUL_LATENCY:0]             mul_xcpt_fetch_ff;
decode_xcpt_t   [`ALU_MUL_LATENCY:0]             mul_xcpt_decode_next;
decode_xcpt_t   [`ALU_MUL_LATENCY:0]             mul_xcpt_decode_ff;
mul_xcpt_t      [`ALU_MUL_LATENCY:0]             mul_xcpt_stages_next;
mul_xcpt_t      [`ALU_MUL_LATENCY:0]             mul_xcpt_stages_ff;


//      CLK    RST                DOUT                DIN                   DEF
`RST_FF(clock, reset | flush_mul, mul_xcpt_fetch_ff,  mul_xcpt_fetch_next,  '0)
`RST_FF(clock, reset | flush_mul, mul_xcpt_decode_ff, mul_xcpt_decode_next, '0)
`RST_FF(clock, reset | flush_mul, mul_xcpt_stages_ff, mul_xcpt_stages_next, '0)


// Overflow signal
logic [`ALU_OVW_DATA_RANGE]                      mul_overflow_data;

// Data from bypasses
logic   [`REG_FILE_DATA_RANGE]  ra_data;
logic   [`REG_FILE_DATA_RANGE]  rb_data;

// Bypass signals from RoB
logic rob_blocks_src1;
logic rob_blocks_src2;

logic rob_src1_found_next;
logic rob_src1_found_ff;
logic rob_src2_found_next;
logic rob_src2_found_ff;

logic   [`REG_FILE_DATA_RANGE]  rob_src1_data_ff;
logic   [`REG_FILE_DATA_RANGE]  rob_src2_data_ff;

//      CLK    RST                DOUT               DIN                  DEF
`RST_FF(clock, reset | flush_mul, rob_src1_found_ff, rob_src1_found_next, 1'b0)
`RST_FF(clock, reset | flush_mul, rob_src2_found_ff, rob_src2_found_next, 1'b0)

//     CLK    EN            DIN               DOUT
`EN_FF(clock, rob_src1_hit, rob_src1_data_ff, rob_src1_data)
`EN_FF(clock, rob_src2_hit, rob_src2_data_ff, rob_src2_data)

always_comb
begin
    // Bypass values from RoB
    rob_src1_id = req_mul_info.ticket_src1;
    rob_src2_id = req_mul_info.ticket_src2;

    rob_blocks_src1     = req_mul_info.rob_blocks_src1;
    rob_blocks_src2     = req_mul_info.rob_blocks_src2;

    rob_src1_found_next = rob_src1_found_ff;
    rob_src2_found_next = rob_src2_found_ff;

    stall_decode        = stall_decode_ff;

    if ( stall_decode_ff )
    begin
        // Check if there is a hit on this cycle and store the hit, only if we
        // did not hit last cycle
        if (!rob_src1_found_ff)
            rob_src1_found_next = rob_src1_hit;

        if (!rob_src2_found_ff)
            rob_src2_found_next = rob_src2_hit;

        // Check if we can unblock decode stage
        if (rob_blocks_src1 & rob_blocks_src2)
        begin
            stall_decode =!(  (rob_src1_found_ff | rob_src1_hit)
                            & (rob_src2_found_ff | rob_src2_hit));
        end
        else if ( rob_blocks_src1 )
        begin
            stall_decode = !(rob_src1_found_ff | rob_src1_hit);
        end
        else // if ( rob_blocks_src2 )
        begin
            stall_decode = !(rob_src2_found_ff | rob_src2_hit);
        end
    end // stall_decode_ff

    // if !stall_decode
    else 
    begin
        rob_src1_found_next = rob_src1_hit;
        rob_src2_found_next = rob_src2_hit;

        stall_decode =  (  fetch_xcpt_valid
                         | decode_xcpt_valid ) ? 1'b0 : 
                        ( req_mul_valid      ) ?   ( rob_blocks_src1 
                                                    & !rob_src1_hit  
                                                    & (req_mul_info.ticket_src1 != req_mul_instr_id))
                                                 | ( rob_blocks_src2 
                                                    & !rob_src2_hit  
                                                    & (req_mul_info.ticket_src2 != req_mul_instr_id)) :
                                                 1'b0;
    end
end


always_comb
begin

    ra_data = (rob_blocks_src1) ? (rob_src1_hit) ? rob_src1_data    : 
                                                   rob_src1_data_ff :
                                  req_mul_info.ra_data;

    rb_data = (rob_blocks_src2) ?  (rob_src2_hit) ? rob_src2_data    : 
                                                    rob_src2_data_ff :
                                  req_mul_info.rb_data;

    // Request to MUL stage 0
        // Operation
    instr_id_next[0]        = req_mul_instr_id;
    instr_valid_next[0]     = ( flush_mul           ) ? 1'b0 :
                              ( stall_decode        ) ? 1'b0 :
                              ( stall_decode_ff     ) ? 1'b1 :
                                                        req_mul_valid;

    req_wb_pc_next[0]       = req_mul_pc;
    mul_overflow_data       =  `ZX(`ALU_OVW_DATA_WIDTH,ra_data) * `ZX(`ALU_OVW_DATA_WIDTH,rb_data);
    mul_oper_data_next[0]   =  mul_overflow_data[`REG_FILE_DATA_RANGE];
    rd_addr_next[0]         =  req_mul_info.rd_addr;
        // Exception
    mul_xcpt_fetch_next[0]                  = (instr_valid_next[0]) ? xcpt_fetch_in : '0;
    mul_xcpt_decode_next[0]                 = (instr_valid_next[0]) ? xcpt_decode_in : '0;
    mul_xcpt_stages_next[0].xcpt_pc         = req_mul_pc;
    mul_xcpt_stages_next[0].xcpt_overflow   =   (mul_overflow_data[`REG_FILE_DATA_WIDTH+:`REG_FILE_DATA_WIDTH] != '0) 
                                              & instr_valid_next[0];
end

genvar mulStage;

// Generate for MUL stages
generate for(mulStage = 0; mulStage < `MUL_STAGES; mulStage++) //-1 because first stage is FF
begin : gen_mul_stages
    // Local signals to mantain value in case of stall
    logic                        instr_valid_aux;      
    logic [`PC_WIDTH-1:0]        req_wb_pc_aux;
    logic [`ALU_OVW_DATA_RANGE]  mul_oper_data_aux;
    logic [`REG_FILE_ADDR_RANGE] rd_addr_aux;
    logic [`ROB_ID_RANGE]        instr_id_aux;

    fetch_xcpt_t                 mul_xcpt_fetch_aux;
    decode_xcpt_t                mul_xcpt_decode_aux;
    mul_xcpt_t                   mul_xcpt_stages_aux;

    assign instr_valid_aux      = instr_valid_ff[mulStage];

    assign req_wb_pc_aux        = req_wb_pc_ff[mulStage];

    assign mul_oper_data_aux    = mul_oper_data_ff[mulStage];

    assign rd_addr_aux          = rd_addr_ff[mulStage];

    assign instr_id_aux         = instr_id_ff[mulStage];

    assign mul_xcpt_fetch_aux   = mul_xcpt_fetch_ff[mulStage];

    assign mul_xcpt_decode_aux  = mul_xcpt_decode_ff[mulStage];

    assign mul_xcpt_stages_aux  = mul_xcpt_stages_ff[mulStage];

    mul_stage
    mul_stage
    (
    // Signals from previous stage        
        // MUL request
        .instr_valid_in     ( instr_valid_aux      ),
        .instr_id_in        ( instr_id_aux         ),
        .program_counter_in ( req_wb_pc_aux        ),
        .dest_reg_in        ( rd_addr_aux          ),
        .data_result_in     ( mul_oper_data_aux    ),
    
        // Exception input
        .xcpt_fetch_in      ( mul_xcpt_fetch_aux    ),
        .xcpt_decode_in     ( mul_xcpt_decode_aux   ),
        .xcpt_mul_in        ( mul_xcpt_stages_aux   ),

    // Signals to next stage        
        // MUL request
        .instr_valid_out    ( instr_valid_next[mulStage+1]      ),
        .instr_id_out       ( instr_id_next[mulStage+1]         ),
        .program_counter_out( req_wb_pc_next[mulStage+1]        ),
        .dest_reg_out       ( rd_addr_next[mulStage+1]          ),
        .data_result_out    ( mul_oper_data_next[mulStage+1]    ),

        // Exception output
        .xcpt_fetch_out     ( mul_xcpt_fetch_next[mulStage+1]   ),
        .xcpt_decode_out    ( mul_xcpt_decode_next[mulStage+1]  ),
        .xcpt_mul_out       ( mul_xcpt_stages_next[mulStage+1]  )
    );
end
endgenerate


logic               req_wb_valid_next;
writeback_request_t req_wb_info_next;

//      CLK    RST                DOUT          DIN                  DEF
`RST_FF(clock, reset | flush_mul, req_wb_valid, req_wb_valid_next, 1'b0 )
`RST_FF(clock, reset | flush_mul, req_wb_info,  req_wb_info_next,  '0   )

// Request to WB
always_comb
begin
    req_wb_valid_next = (flush_mul)    ? 1'b0 :
                        (stall_decode) ? 1'b0 : 
                                        instr_valid_ff[`MUL_STAGES];
  
    req_wb_info_next.instr_id    = instr_id_ff[`MUL_STAGES];
    req_wb_info_next.pc          = req_wb_pc_ff[`MUL_STAGES];

    req_wb_info_next.tlbwrite     = 1'b0;  
    req_wb_info_next.tlb_id       = '0; 
    req_wb_info_next.tlb_req_info = '0;
                                
    req_wb_info_next.rf_wen       = 1'b1;
    req_wb_info_next.rf_dest      = rd_addr_ff[`MUL_STAGES];
    req_wb_info_next.rf_data      = mul_oper_data_ff[`MUL_STAGES];
                      
    req_wb_info_next.xcpt_fetch   = mul_xcpt_fetch_ff[`MUL_STAGES];
    req_wb_info_next.xcpt_decode  = mul_xcpt_decode_ff[`MUL_STAGES];
    req_wb_info_next.xcpt_alu     = '0;
    req_wb_info_next.xcpt_mul     = mul_xcpt_stages_ff[`MUL_STAGES];  //overflow
    req_wb_info_next.xcpt_cache   = '0;
end


/////////////////////////////////
// VERBOSE
`ifdef VERBOSE_MUL
always_ff @(posedge clock)
begin
    if (req_wb_valid)
    begin
        $display("[MUL] Request to WB. PC = %h",req_wb_info.pc);
        $display("      req_wb_info.rf_wen  =  %h",req_wb_info.rf_wen);
        $display("      req_wb_info.rf_dest =  %h",req_wb_info.rf_dest);
        $display("      req_wb_info.rf_data =  %h",req_wb_info.rf_data);
    end
end
`endif
endmodule
