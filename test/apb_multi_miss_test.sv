//=====================================================================
// Project: 4 core MESI cache design
// File Name: apb_multi_miss_test.sv
// Description: Stress test that generates high APB traffic to cover
//   remaining APB cover properties and covergroup bins.
//
//   Targets:
//     cover_write_transfer       : write to a D-cache address → L1 miss
//                                  write-back → lv2_wr → APB write transfer
//     cover_read_transfer        : read from a D-cache address → L1 miss
//                                  → lv2_rd → APB read transfer
//     cover_idle_after_access_state : naturally covered by any transfer
//     cp_paddr mid_range/high_range : uses addresses in 0x4xxx and 0x8xxx
//     cp_pwrite read/write       : both read and write APB transfers
//     cp_state_transition bins   : all transitions covered by normal flow
//     tran_access_wait           : dirty eviction causes lv2_wr which
//                                  needs multiple beats — may cover wait
//
//   Generates a large number of rapid-fire misses across all cores
//   targeting both the mid_range (0x4000_0000+) and high_range
//   (0x8000_0000+) address spaces to cover all three paddr bins.
//=====================================================================

class apb_multi_miss_seq extends base_vseq;
    `uvm_object_utils(apb_multi_miss_seq)

    cpu_transaction_c trans;

    function new(string name = "apb_multi_miss_seq");
        super.new(name);
    endfunction

    virtual task body();
        int unsigned num_rounds = 8;

        // Low-range I-cache addresses (< 0x4000_0000) → cp_paddr low_range
        bit [`ADDR_WID_LV1-1:0] low_base  = 32'h0010_0000;
        // Mid-range D-cache addresses (0x4000_0000 – 0x7FFF_FFFF) → mid_range
        bit [`ADDR_WID_LV1-1:0] mid_base  = 32'h4010_0000;
        // High-range D-cache addresses (0x8000_0000+) → high_range
        bit [`ADDR_WID_LV1-1:0] high_base = 32'h8010_0000;

        `uvm_info(get_type_name(), "=== apb_multi_miss_seq START ===", UVM_LOW)

        // ---------------------------------------------------------------
        // Round 1: I-cache reads → generates APB read transfers in low range
        // ---------------------------------------------------------------
        for (int r = 0; r < num_rounds; r++) begin
            for (int c = 0; c < 4; c++) begin
                bit [`ADDR_WID_LV1-1:0] a = low_base + (c * 32'h0001_0000) + (r * 32'h0000_0010);
                `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                    request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == a;
                })
            end
        end

        // ---------------------------------------------------------------
        // Round 2: D-cache reads in mid-range → APB read transfers, mid_range paddr
        // ---------------------------------------------------------------
        for (int r = 0; r < num_rounds; r++) begin
            for (int c = 0; c < 4; c++) begin
                bit [`ADDR_WID_LV1-1:0] a = mid_base + (c * 32'h0001_0000) + (r * 32'h0000_0010);
                `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                    request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == a;
                })
            end
        end

        // ---------------------------------------------------------------
        // Round 3: D-cache writes in mid-range
        //   Cold write misses → write-allocate → lv2_rd (fetch) then lv2_wr
        //   Results in both read and write APB transfers
        // ---------------------------------------------------------------
        for (int r = 0; r < num_rounds; r++) begin
            for (int c = 0; c < 4; c++) begin
                bit [`ADDR_WID_LV1-1:0] a = mid_base + (c * 32'h0001_0000) + (r * 32'h0000_0010);
                `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                    request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == a;
                })
            end
        end

        // ---------------------------------------------------------------
        // Round 4: D-cache reads and writes in high-range → high_range paddr bins
        // ---------------------------------------------------------------
        for (int r = 0; r < num_rounds; r++) begin
            for (int c = 0; c < 4; c++) begin
                bit [`ADDR_WID_LV1-1:0] a = high_base + (c * 32'h0001_0000) + (r * 32'h0000_0010);
                // Alternate read and write each round
                if (r % 2 == 0)
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                        request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == a;
                    })
                else
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                        request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == a;
                    })
            end
        end

        // ---------------------------------------------------------------
        // Round 5: Dirty eviction sequence to generate lv2_wr APB writes
        //   Fill 4 ways in a set (mid-range), write the oldest way (→M),
        //   re-touch other 3 ways, then evict with 5th address.
        //   The M-line writeback generates an APB WRITE transfer.
        // ---------------------------------------------------------------
        begin
            bit [`ADDR_WID_LV1-1:0] ev_base = 32'h4020_0000;
            bit [`ADDR_WID_LV1-1:0] ew0 = ev_base;
            bit [`ADDR_WID_LV1-1:0] ew1 = ev_base + 32'h0001_0000;
            bit [`ADDR_WID_LV1-1:0] ew2 = ev_base + 32'h0002_0000;
            bit [`ADDR_WID_LV1-1:0] ew3 = ev_base + 32'h0003_0000;
            bit [`ADDR_WID_LV1-1:0] eev = ev_base + 32'h0004_0000;

            `uvm_info(get_type_name(), "Dirty eviction sequence for APB write traffic", UVM_LOW)
            // Fill 4 ways on Core0
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew0; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew1; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew2; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew3; })
            // Write way0 → makes it MODIFIED
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == ew0; })
            // Re-touch ways 1,2,3 → way0 is LRU
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew1; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew2; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == ew3; })
            // Evict → triggers M-line writeback to L2 (lv2_wr → APB WRITE)
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == eev; })
        end

        // ---------------------------------------------------------------
        // Round 6: Cross-core sharing to exercise cp_pwrite both = 0 and 1
        // ---------------------------------------------------------------
        begin
            bit [`ADDR_WID_LV1-1:0] sh = 32'h4030_0000;
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == sh; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == sh; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], { request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == sh; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], { request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == sh; })
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], { request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == sh; })
        end

        `uvm_info(get_type_name(), "=== apb_multi_miss_seq DONE ===", UVM_LOW)
    endtask

endclass : apb_multi_miss_seq


class apb_multi_miss_test extends base_test;
    `uvm_component_utils(apb_multi_miss_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                apb_multi_miss_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing apb_multi_miss_test", UVM_LOW)
    endtask: run_phase

endclass : apb_multi_miss_test
