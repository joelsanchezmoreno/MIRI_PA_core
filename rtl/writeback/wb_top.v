`include "soc.vh"

module wb_top
(
    // System signals
    input   logic                               clock,
    input   logic                               reset,
    output  logic                               reorder_buffer_full,
    output  logic [`ROB_NUM_ENTRIES_W_RANGE]    reorder_buffer_oldest,

    // Request from ALU
    input   logic                               alu_req_valid,
    input   writeback_request_t                 alu_req_info,
    
    input   logic                               mem_instr_blocked,
    input   dcache_request_t                    mem_instr_info,

    // Request from MUL
    input   logic                               mul_req_valid,
    input   writeback_request_t                 mul_req_info,

    // Request from Cache
    input   logic                               cache_req_valid,
    input   writeback_request_t                 cache_req_info,

    // Request to Cache
    input   logic                               cache_stage_ready,
    output  logic                               req_to_dcache_valid,
    output  dcache_request_t                    req_to_dcache_info,
     
    // Request to RF
    output  logic 				                req_to_RF_writeEn,
    output  logic [`REG_FILE_DATA_RANGE] 		req_to_RF_data,
    output  logic [`REG_FILE_ADDR_RANGE] 		req_to_RF_dest,
    output  logic [`ROB_ID_RANGE]               req_to_RF_instr_id,

    // Exceptions values to be stored on the RF
    output  logic 				                xcpt_valid,
    output  xcpt_type_t                         xcpt_type,
    output  logic [`PC_WIDTH_RANGE] 		    xcpt_pc,
    output  logic [`REG_FILE_XCPT_ADDR_RANGE] 	xcpt_addr,

    // Request from WB to TLB
    output  logic                               new_tlb_entry,
    output  logic                               new_tlb_id,
    output  tlb_req_info_t                      new_tlb_info,
    
    // Bypass info    
        // MUL
    input   logic [`ROB_ID_RANGE]               mul_src1_id,
    input   logic [`ROB_ID_RANGE]               mul_src2_id,
    output  logic                               mul_src1_hit,
    output  logic                               mul_src2_hit,
    output  logic [`REG_FILE_DATA_RANGE]        mul_src1_data,
    output  logic [`REG_FILE_DATA_RANGE]        mul_src2_data,
    
        // ALU
    input   logic [`ROB_ID_RANGE]               alu_src1_id,
    input   logic [`ROB_ID_RANGE ]              alu_src2_id,
    output  logic                               alu_src1_hit,
    output  logic                               alu_src2_hit,
    output  logic [`REG_FILE_DATA_RANGE]        alu_src1_data,
    output  logic [`REG_FILE_DATA_RANGE]        alu_src2_data
);

logic invalidate_buffer;

//      CLK    RST    DOUT               DIN         DEF
`RST_FF(clock, reset, invalidate_buffer, xcpt_valid , '0)

reorder_buffer
reorder_buffer
(    // System signals
    .clock                  ( clock                 ),
    .reset                  ( reset                 ),

    .reorder_buffer_full    ( reorder_buffer_full   ),
    .reorder_buffer_oldest  ( reorder_buffer_oldest ),

    // Request to invalidate the buffer
    .invalidate_buffer      ( invalidate_buffer     ), 
    
    // Request from ALU
    .alu_req_valid          ( alu_req_valid         ),
    .alu_req_info           ( alu_req_info          ),
                                                    
    .mem_instr_blocked      ( mem_instr_blocked     ),
    .mem_instr_info         ( mem_instr_info        ),

    // Request from MUL
    .mul_req_valid          ( mul_req_valid         ),
    .mul_req_info           ( mul_req_info          ),

    // Request from Cache
    .cache_req_valid        ( cache_req_valid       ),
    .cache_req_info         ( cache_req_info        ),

    // Request to Cache
    .cache_stage_ready      ( cache_stage_ready     ),
    .req_to_dcache_valid    ( req_to_dcache_valid   ),
    .req_to_dcache_info     ( req_to_dcache_info    ),

    // Request to RF
    .req_to_RF_writeEn      ( req_to_RF_writeEn     ),
    .req_to_RF_data         ( req_to_RF_data        ),
    .req_to_RF_dest         ( req_to_RF_dest        ),
    .req_to_RF_instr_id     ( req_to_RF_instr_id    ),

    // Exceptions values to be stored on the RF
    .xcpt_valid             ( xcpt_valid            ),
    .xcpt_type              ( xcpt_type             ),
    .xcpt_pc                ( xcpt_pc               ),
    .xcpt_addr              ( xcpt_addr             ),

    // Request from WB to TLB
    .new_tlb_entry          ( new_tlb_entry         ),
    .new_tlb_id             ( new_tlb_id            ),
    .new_tlb_info           ( new_tlb_info          ),

    // Bypass info    
        // MUL
    .mul_src1_id            ( mul_src1_id           ),
    .mul_src2_id            ( mul_src2_id           ),
    .mul_src1_hit           ( mul_src1_hit          ),
    .mul_src2_hit           ( mul_src2_hit          ),
    .mul_src1_data          ( mul_src1_data         ),
    .mul_src2_data          ( mul_src2_data         ),
    
        // ALU
    .alu_src1_id            ( alu_src1_id           ),
    .alu_src2_id            ( alu_src2_id           ),
    .alu_src1_hit           ( alu_src1_hit          ),
    .alu_src2_hit           ( alu_src2_hit          ),
    .alu_src1_data          ( alu_src1_data         ),
    .alu_src2_data          ( alu_src2_data         )
);


endmodule
