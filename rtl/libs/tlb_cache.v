`include "soc.vh"

module tlb_cache
(
    input  logic                    clock,
    input  logic                    reset,

    // Request from the core pipeline
    input  logic                    req_valid,
    input  logic [`VIRT_ADDR_RANGE] req_virt_addr,
    input  priv_mode_t              priv_mode,

    // Response to the cache
    output logic                    rsp_valid,
    output logic                    tlb_miss,
    output logic [`PHY_ADDR_RANGE]  rsp_phy_addr,
    output logic                    writePriv,

    // New TLB entry
    input   logic                   new_tlb_entry,
    input   tlb_req_info_t          new_tlb_info
);

//////////////////////////////////////////////////
// TLB cache arrays: info and valid
tlb_info_t [`TLB_ENTRIES_RANGE] tlb_cache;
tlb_info_t [`TLB_ENTRIES_RANGE] tlb_cache_ff;

logic [`TLB_ENTRIES_RANGE]   tlb_valid;
logic [`TLB_ENTRIES_RANGE]   tlb_valid_ff;

//  CLK    DOUT          DIN         
`FF(clock, tlb_cache_ff, tlb_cache)

//      CLK    RST    DOUT          DIN        DEF
`RST_FF(clock, reset, tlb_valid_ff, tlb_valid, '0)

//////////////////////////////////////////////////
// Control signals 
logic [`TLB_WAYS_PER_SET_RANGE] hit_way; 
logic [`VIRT_TAG_RANGE]         req_virt_tag;
logic [`TLB_NUM_WAYS_RANGE]     req_addr_pos; // Position of the data in case there is a hit on TLB array
logic [`TLB_NUM_WAYS_RANGE]     replace_tlb_pos;

//////////////////////////////////////////////////
// Position of the victim to be evicted from the TLB
logic [`TLB_NUM_SET_RANGE]          req_addr_set;  
logic [`TLB_WAYS_PER_SET_RANGE]     victim_way; 

integer iter;

always_comb
begin
    // Mantain values for next clock
    tlb_valid   = tlb_valid_ff;
    tlb_cache   = tlb_cache_ff;

    // There is a miss if the virtual tag is not stored
    req_virt_tag    = req_virt_addr[`VIRT_ADDR_TAG_RANGE];
    hit_way         = '0;
    req_addr_pos    = '0; 
  
    // Do not respond to the fetch top until we ensure we have the correct
    // data
    tlb_miss        = 1'b0;
    rsp_valid       = 1'b0;

    // If there is a request and we are not performing one
    if (req_valid)
    begin
        if ( priv_mode == Supervisor) //Virtual memory disabled
        begin
            rsp_valid    = 1'b1;
            tlb_miss     = 1'b0;
            rsp_phy_addr = req_virt_addr[`PHY_ADDR_RANGE];
            writePriv    = 1'b1;
        end
        else // User mode
        begin
            req_addr_set    = req_virt_addr[`TLB_SET_ADDR_RANGE]; 
            tlb_miss    = 1'b1;
            // Look if the tag is on the cache
            for (iter = 0; iter < `TLB_WAYS_PER_SET; iter++)
            begin
                if ((tlb_cache_ff[iter + req_addr_set*`TLB_WAYS_PER_SET].va_addr_tag == req_virt_tag) &
                     tlb_valid_ff[iter + req_addr_set*`TLB_WAYS_PER_SET])
                begin
                    req_addr_pos      = iter + req_addr_set*`TLB_WAYS_PER_SET;
                    hit_way           = iter;

                    // Return data to fetch top
                    rsp_valid    = 1'b1;
                    tlb_miss     = 1'b0;
                    rsp_phy_addr = {tlb_cache_ff[req_addr_pos].pa_addr_tag,req_virt_addr[`VIRT_ADDR_OFFSET_RANGE]};
                    writePriv    = tlb_cache_ff[req_addr_pos].writePriv;

                    `ifdef VERBOSE_TLB
                        $display("[TLB] TAG hit. Position in TLB is %h , way %h",req_addr_pos,hit_way);
                    `endif
                end
            end
        end
    end

    // Update TLB
    if ( new_tlb_entry )
    begin
        req_addr_set            = new_tlb_info.virt_addr[`TLB_SET_ADDR_RANGE];
        replace_tlb_pos         = victim_way + req_addr_set*`TLB_WAYS_PER_SET;

        tlb_valid[replace_tlb_pos]  = 1'b1;
        tlb_cache[replace_tlb_pos].va_addr_tag   = new_tlb_info.virt_addr[`VIRT_ADDR_TAG_RANGE];
        tlb_cache[replace_tlb_pos].pa_addr_tag   = new_tlb_info.phy_addr[`PHY_ADDR_TAG_RANGE];
        //NOTE: We suppose that TLBWrite always give write privilege to the page
        tlb_cache[replace_tlb_pos].writePriv     = 1'b1; 

        `ifdef VERBOSE_TLB
            $display("[TLB] NEW TRANSLATION. ");
            $display("         - Position in TLB is %h",replace_tlb_pos);
            $display("         - VA TAG is %h",new_tlb_info.virt_addr[`VIRT_ADDR_TAG_RANGE]);
            $display("         - PA TAG is %h",new_tlb_info.phy_addr[`PHY_ADDR_TAG_RANGE]);
        `endif
    end
end

logic                           update_en;
logic [`TLB_WAYS_PER_SET_RANGE] update_way;  

assign update_en    = (req_valid & !tlb_miss) | new_tlb_entry;

assign update_way   = (req_valid & !tlb_miss  ) ? hit_way :
                                                  victim_way;              

// This module returns the oldest way accessed for a given set and updates the
// the LRU logic when there's a hit on the TLB or we bring a new translation
cache_lru
#(
    .NUM_SET       ( `TLB_NUM_SET       ),
    .NUM_WAYS      ( `TLB_NUM_WAYS      ),
    .WAYS_PER_SET  ( `TLB_WAYS_PER_SET  )
)
tlb_lru
(
    // System signals
    .clock              ( clock             ),
    .reset              ( reset             ),

    // Info to select the victim
    .victim_req         ( new_tlb_entry     ),
    .victim_set         ( req_addr_set      ),

    // Victim way
    .victim_way         ( victim_way        ),

    // Update the LRU logic
    .update_req         ( update_en         ),
    .update_set         ( req_addr_set      ),
    .update_way         ( update_way        )
);

endmodule 
