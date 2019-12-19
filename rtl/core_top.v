`include "soc.vh"

module core_top
(
    // System signals
    input   logic                                   clock,
    input   logic                                   reset,
 
    // Boot address
    input   logic   [`PC_WIDTH-1:0]                 boot_addr,

    // Exception address
    input   logic   [`PC_WIDTH-1:0]                 xcpt_addr,
    
    // Request from D$ to the memory hierarchy
    output  logic                                   dcache_req_valid_miss,
    output  memory_request_t                        dcache_req_info_miss,

    // Request from I$ to the memory hierarchy
    output  logic                                   icache_req_valid_miss,
    output  memory_request_t                        icache_req_info_miss,

    // Response from the memory hierarchy
    input   logic [`DCACHE_LINE_WIDTH-1:0]          rsp_data_miss,
    input   logic                                   rsp_valid_miss,
    input   logic                                   rsp_cache_id // 0 for I$, 1 for D$
);


// Control signals needed by the stages to synchronize between them

/////////////////////////////////////////
// Fetch signals to other stages

// Instruction from fetch to decode phase
logic                       fetch_instr_valid;
logic   [`INSTR_WIDTH-1:0]  fetch_instr_data;
logic   [`PC_WIDTH_RANGE]   decode_instr_pc;

// Exception signals
fetch_xcpt_t                xcpt_fetch_to_decode;

/////////////////////////////////////////
// Decode signals to other stages

logic                           req_to_alu_valid;
alu_request_t                   req_to_alu_info;
logic   [`PC_WIDTH_RANGE]       req_to_alu_pc;

// Exception signals
fetch_xcpt_t                    xcpt_fetch_to_alu;
decode_xcpt_t                   xcpt_decode_to_alu;

/////////////////////////////////////////
// ALU signals to other stages

logic [`PC_WIDTH_RANGE]         req_to_dcache_pc;
logic alu_busy;

// Connected to cache stage
logic [`REG_FILE_ADDR_RANGE]    load_dst_reg;
dcache_request_t                req_to_dcache_info;
logic                           req_to_dcache_valid;
logic                           req_to_dcache_mem_inst;
logic                           req_to_dcache_int_inst;

// Bypass signal
logic [`REG_FILE_DATA_RANGE]    alu_data_bypass;

// Branches signals

// We take a branch on the fetch stage so we have to cancel 
// the requests sent to decode stage and alu stage next cycle
// and we have to fetch another instruction instead of pc+4
logic                       take_branch; // from ALU to fetch  
logic   [`PC_WIDTH-1:0]     branch_pc;

// Exception signals
fetch_xcpt_t                    xcpt_fetch_to_cache;
decode_xcpt_t                   xcpt_decode_to_cache;

/////////////////////////////////////////
// Data cache signals to other stages

logic dcache_ready;

// Exceptions
fetch_xcpt_t                    xcpt_fetch_to_wb;
decode_xcpt_t                   xcpt_decode_to_wb;
cache_xcpt_t                    xcpt_cache_to_wb;

// Program counter value
logic [`PC_WIDTH_RANGE]             dcache_to_wb_pc;

// Bypass value
logic [`REG_FILE_DATA_RANGE]        dcache_data_bypass ;
logic                               dcache_data_bp_valid;

// Request to RF sent to WB
logic                               dcache_write_rf;
logic [`REG_FILE_ADDR_RANGE]        dcache_dest_rf;
logic [`DCACHE_MAX_ACC_SIZE-1:0]    dcache_rsp_data;

/////////////////////////////////////////
// WriteBack signals to other stages

logic [`REG_FILE_DATA_RANGE]        wb_writeValRF;
logic 				                wb_writeEnRF;
logic [`REG_FILE_ADDR_RANGE]    	wb_destRF;

logic                               wb_xcpt_valid;
logic [`PC_WIDTH_RANGE] 		    wb_rmPC;
logic [`REG_FILE_XCPT_ADDR_RANGE] 	wb_rmAddr;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Instruction Fetch. It fetches one instruction per cycle and sends it to the
// instruction decoder.
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
fetch_top
fetch_top
(
    // System signals
    .clock              ( clock                 ),
    .reset              ( reset                 ),

    .boot_addr          ( boot_addr             ),

    // Exception
    .xcpt_fetch         ( xcpt_fetch_to_decode  ),

    // Branches
    .take_branch        ( take_branch           ), 
    .branch_pc          ( branch_pc             ), 

    // Stop fetching instructions
    .stall_fetch        ( alu_busy | 
                          !dcache_ready         ),

    // Fetched instruction
    .decode_instr_data  ( fetch_instr_data      ),
    .decode_instr_valid ( fetch_instr_valid     ),
    .decode_instr_pc    ( decode_instr_pc       ),
    
    // Request to the memory hierarchy
    .req_valid_miss     ( icache_req_valid_miss ),
    .req_info_miss      ( icache_req_info_miss  ),

    // Response from the memory hierarchy
    .rsp_data_miss      ( rsp_data_miss         ),
    .rsp_valid_miss     ( !rsp_cache_id & 
                           rsp_valid_miss       )
);                

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Instruction Decoder. It decodes one instruction per cycle and sends it to the
// execution stage (alu).
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
    
decode_top
decode_top
(
    // System signals
    .clock              ( clock                 ),
    .reset              ( reset                 ),

    // Stall pipeline
    .stall_decode       ( alu_busy   | 
                          take_branch | 
                          !dcache_ready         ) , 

    // Exceptions
    .xcpt_fetch_in      ( xcpt_fetch_to_decode  ),
    .xcpt_fetch_out     ( xcpt_fetch_to_alu     ),
    .decode_xcpt        ( xcpt_decode_to_alu    ),
    
    // Fetched instruction
    .fetch_instr_valid  ( fetch_instr_valid     ),
    .fetch_instr_data   ( fetch_instr_data      ),
    .fetch_instr_pc     ( decode_instr_pc       ), 

    // Instruction to ALU
    .req_to_alu_valid   ( req_to_alu_valid      ), 
    .req_to_alu_info    ( req_to_alu_info       ), 
    .req_to_alu_pc      ( req_to_alu_pc         ), 

    // Write requests to the Register File from WB stage 
    .writeValRF         ( wb_writeValRF        ), 
    .writeEnRF          ( wb_writeEnRF         ), 
    .destRF             ( wb_destRF            ), 

    // Exceptions values to be stored on the RF
    .xcpt_valid         ( wb_xcpt_valid         ),
    .rmPC               ( wb_rmPC               ),
    .rmAddr             ( wb_rmAddr             ),

    // Bypasses
    .alu_data_bypass    ( alu_data_bypass       ),
    .cache_data_bypass  ( dcache_data_bypass    ),
    .cache_data_valid   ( dcache_data_bp_valid  )
);
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Arithmetical Logic Unit (ALU). Performs one instruction per cycle and sends 
// the result to the RF, fetch or cache stage depending on the instruction
// type
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
alu_top
alu_top
(
    // System signals
    .clock              ( clock                     ),
    .reset              ( reset                     ),

    // Stall pipeline
    .stall_alu          ( !req_to_alu_valid | 
                          !dcache_ready             ),
    .alu_busy           ( alu_busy                  ),

    // Exceptions
    .xcpt_fetch_in      ( xcpt_fetch_to_alu         ),
    .xcpt_fetch_out     ( xcpt_fetch_to_cache       ),
    .xcpt_decode_in     ( xcpt_decode_to_alu        ),
    .xcpt_decode_out    ( xcpt_decode_to_cache      ),

    // Request from decode stage
    .req_alu_info       ( req_to_alu_info           ),
    .req_alu_pc         ( req_to_alu_pc             ),

    // Request to dcache stage 
    .req_dcache_pc      ( req_to_dcache_pc          ),
    .req_dcache_info    ( req_to_dcache_info        ),
    .req_dcache_valid   ( req_to_dcache_valid       ),
    
    // Depending on the opcode the D$ will perform the operation or
    // will just flop the req to send it to WB stage to perform RF write
    // and/or retire the instruction
    .req_m_type_instr   ( req_to_dcache_mem_inst    ),
    .req_r_type_instr   ( req_to_dcache_int_inst    ),
    .req_dst_reg        ( load_dst_reg              ), 

    // Branch signals to fetch stage
    .branch_pc          ( branch_pc                 ),
    .take_branch        ( take_branch               ),
 
    //Bypass
    .alu_data_bypass    ( alu_data_bypass           ),
    .cache_data_bypass  ( dcache_data_bypass        )
);

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Cache stage (ALU). Performs the LD and ST requests by accessing the data
// cache.  
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
cache_top
cache_top
(
    // System signals
    .clock          ( clock                 ),
    .reset          ( reset                 ),

    // Send stall pipeline request
    .dcache_ready   ( dcache_ready          ), 

    //Exception
    .xcpt_fetch_in   ( xcpt_fetch_to_cache  ),
    .xcpt_fetch_out  ( xcpt_fetch_to_wb     ),
    .xcpt_decode_in  ( xcpt_decode_to_cache ),
    .xcpt_decode_out ( xcpt_decode_to_wb    ),
    .xcpt_cache      ( xcpt_cache_to_wb     ),

    // Receive stall pipeline request
    .stall_pipeline ( 1'b0                  ), //FIXME: WB flush in case of xcpt ??

    // Request from the ALU stage
    .req_instr_pc   ( req_to_dcache_pc      ), 
    .req_valid      ( req_to_dcache_valid   ), 
    .req_info       ( req_to_dcache_info    ), 
    .load_dst_reg   ( load_dst_reg          ), 
    .mem_instr      ( req_to_dcache_mem_inst), 
    .int_instr      ( req_to_dcache_int_inst), 

    // Bypasses to previous stages
    .data_bypass    ( dcache_data_bypass    ),
    .data_bp_valid  ( dcache_data_bp_valid  ),
    
    // Request to WB stage
    .write_rf       ( dcache_write_rf       ), 
    .dest_rf        ( dcache_dest_rf        ), 
    .rsp_data       ( dcache_rsp_data       ), 
    .wb_instr_pc    ( dcache_to_wb_pc       ), 
    
    // Request to the memory hierarchy
    .req_valid_miss ( dcache_req_valid_miss ),
    .req_info_miss  ( dcache_req_info_miss  ),

    // Response from the memory hierarchy
    .rsp_data_miss  ( rsp_data_miss         ),
    .rsp_valid_miss ( rsp_cache_id & 
                      rsp_valid_miss        )
);

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Write Back stage (WB).   
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
wb_top
wb_top
(
    // System signals
    .clock                  ( clock                 ),
    .reset                  ( reset                 ),

    // Exceptions
    .xcpt_fetch             ( xcpt_fetch_to_wb      ),
    .xcpt_decode            ( xcpt_decode_to_wb     ),
    .xcpt_cache             ( xcpt_cache_to_wb      ),

    // Request from cache stage
    .cache_req_write_rf     ( dcache_write_rf       ),
    .cache_req_dest_rf      ( dcache_dest_rf        ),
    .cache_req_rsp_data     ( dcache_rsp_data       ),

    // Request to RF
    .req_to_RF_data         ( wb_writeValRF         ),
    .req_to_RF_writeEn      ( wb_writeEnRF          ),
    .req_to_RF_dest         ( wb_destRF             ),

    // Exceptions values to be stored on the RF
    .xcpt_valid             ( wb_xcpt_valid        ),
    .rmPC                   ( wb_rmPC              ),
    .rmAddr                 ( wb_rmAddr            )
);

endmodule

