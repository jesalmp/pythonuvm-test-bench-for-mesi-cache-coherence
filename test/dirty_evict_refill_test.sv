//=====================================================================
// Project: 4 core MESI cache design
// File Name: dirty_evict_refill_test.sv
// Description: Catches Bug 4 — in main_func_lv1_dl.sv, when a
//              cpu_rd replacement hits a MODIFIED (dirty) line, the
//              design performs the L2 writeback correctly but never
//              issues a follow-up bus_rd / lv2_rd to fetch the
//              requested new block.  The processor stalls indefinitely
//              because data_in_bus_cpu_lv1_dl is never asserted.
//
//              Root cause (lines ~182-205, main_func_lv1_dl.sv):
//                MODIFIED replacement path sets lv2_wr and waits for
//                lv2_wr_done, then sets cache MESI to INVALID — but
//                the outer read-miss loop re-evaluates !blk_free &&
//                gnt_proc and sees the writeback is done.  It does NOT
//                re-issue bus_rd / lv2_rd for the incoming line, so the
//                refill transaction never starts.
//
// Waveform signals to inspect (Core 0 D-cache):
//   Hierarchy prefix:
//     inst_cache_top.inst_cache_lv1_multicore
//       .inst_cache_lv1_unicore_0
//       .inst_cache_wrapper_lv1_dl
//
//   Signals and expected vs actual:
//     inst_main_func_lv1_dl.lv2_wr       -- ACTUAL: pulses high during writeback
//     inst_main_func_lv1_dl.lv2_wr_done  -- ACTUAL: goes high when writeback completes
//     inst_main_func_lv1_dl.lv2_rd       -- EXPECTED: goes high after lv2_wr_done
//                                        -- ACTUAL:   stays 0 (refill never issued)
//     inst_main_func_lv1_dl.bus_rd       -- EXPECTED: asserted for refill
//                                        -- ACTUAL:   stays 0
//     inst_cache_block_lv1_dl
//       .data_in_bus_cpu_lv1_dl          -- EXPECTED: goes high when new data arrives
//                                        -- ACTUAL:   never goes high → processor stalls
//=====================================================================

class dirty_evict_refill_test extends base_test;

    `uvm_component_utils(dirty_evict_refill_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                dirty_evict_refill_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing dirty_evict_refill_test", UVM_LOW)
    endtask: run_phase

endclass : dirty_evict_refill_test


class dirty_evict_refill_seq extends base_vseq;

    `uvm_object_utils(dirty_evict_refill_seq)

    cpu_transaction_c trans;

    // Five D-cache addresses that map to the same cache set.
    // All are > 32'h3FFF_FFFF (D-cache range).
    bit [`ADDR_WID_LV1-1:0] addr_way0 = 32'h5000_0200;
    bit [`ADDR_WID_LV1-1:0] addr_way1 = 32'h5001_0200;
    bit [`ADDR_WID_LV1-1:0] addr_way2 = 32'h5002_0200;
    bit [`ADDR_WID_LV1-1:0] addr_way3 = 32'h5003_0200;
    bit [`ADDR_WID_LV1-1:0] addr_new  = 32'h5004_0200;

    function new (string name="dirty_evict_refill_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // ------------------------------------------------------------------
        // Step 1: Fill all 4 ways with reads → each goes to Exclusive state.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Fill way 0 (I->E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way0;
        })
        `uvm_info(get_type_name(), "Fill way 1 (I->E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way1;
        })
        `uvm_info(get_type_name(), "Fill way 2 (I->E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way2;
        })
        `uvm_info(get_type_name(), "Fill way 3 (I->E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way3;
        })

        // ------------------------------------------------------------------
        // Step 2: Write to way 0 — transitions E -> M (dirty).
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Write way0 — E->M (makes blk0 dirty)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way0;
        })

        // ------------------------------------------------------------------
        // Step 3: Touch ways 1, 2, 3 again so that way 0 becomes the LRU.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Touch way 1", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way1;
        })
        `uvm_info(get_type_name(), "Touch way 2", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way2;
        })
        `uvm_info(get_type_name(), "Touch way 3", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way3;
        })

        // ------------------------------------------------------------------
        // Step 4: Read a 5th unique address mapping to the same set.
        //         This is a read miss with no free block → replacement needed.
        //         LRU victim = way 0, which is MODIFIED (dirty).
        //         EXPECTED behaviour:
        //           1. lv2_wr asserted  → way 0 dirty data written back to L2
        //           2. lv2_wr_done     → writeback acknowledged
        //           3. lv2_rd + bus_rd asserted → new line fetched from L2
        //           4. data_in_bus_lv1_lv2 → new data arrives
        //           5. data_in_bus_cpu_lv1_dl → Core 0 receives the data
        //         ACTUAL (bug):
        //           Steps 1-2 complete, then lv2_rd / bus_rd are NEVER
        //           asserted; the CPU transaction stalls indefinitely
        //           (scoreboard timeout or incorrect data).
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(),
            "Read new addr — triggers dirty eviction of way0; refill must follow (bug: it never does)",
            UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_new;
        })

        // ------------------------------------------------------------------
        // Step 5: Re-read the new address — must now HIT (line should be
        //         resident after the refill).  If the bug is present the
        //         previous read never completed, so this also fails.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Re-read new addr — should hit (line resident after refill)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_new;
        })

        // ------------------------------------------------------------------
        // Step 6: Read from Core 1 to same address — confirms L2 received
        //         the correct dirty data during writeback.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Core1 read same addr — L2 should have the written-back dirty data", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_new;
        })
    endtask

endclass : dirty_evict_refill_seq
