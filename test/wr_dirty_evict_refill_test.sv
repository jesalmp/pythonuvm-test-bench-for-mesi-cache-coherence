//=====================================================================
// Project: 4 core MESI cache design
// File Name: wr_dirty_evict_refill_test.sv
// Description: Catches Bug 5 — in main_func_lv1_dl.sv, when a
//              cpu_wr replacement must evict a MODIFIED (dirty) line,
//              the design performs the L2 writeback but never follows up
//              with a bus_rdx / lv2_rd to allocate and write the new
//              block.  cpu_wr_done is therefore never asserted.
//
//              Root cause (lines ~274-295, main_func_lv1_dl.sv):
//                In the cpu_wr replacement (else-if bus_lv1_lv2_gnt_proc)
//                branch, the MODIFIED case asserts lv2_wr and, after
//                lv2_wr_done, marks the victim INVALID.  The design
//                does NOT re-enter the write-miss / bus_rdx path to
//                allocate the new line and write the CPU data.
//                cpu_wr_done stays low, the driver times out.
//
// Waveform signals to inspect (Core 0 D-cache):
//   Hierarchy prefix:
//     inst_cache_top.inst_cache_lv1_multicore
//       .inst_cache_lv1_unicore_0
//       .inst_cache_wrapper_lv1_dl
//
//   Signal                                  EXPECTED          ACTUAL (bug)
//   inst_main_func_lv1_dl.lv2_wr           pulses high       pulses high      (same)
//   inst_main_func_lv1_dl.lv2_wr_done      goes high         goes high        (same)
//   inst_main_func_lv1_dl.bus_rdx          asserted after    stays 0
//                                          wr_done
//   inst_main_func_lv1_dl.lv2_rd           asserted after    stays 0
//                                          wr_done
//   inst_main_func_lv1_dl.cpu_wr_done      asserted when     never asserted
//                                          new line written
//   inst_cache_block_lv1_dl.cache_proc_mesi updated to M     stays I (victim
//    [way of new line]                                        cleared, new
//                                                             line never alloc)
//=====================================================================

class wr_dirty_evict_refill_test extends base_test;

    `uvm_component_utils(wr_dirty_evict_refill_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                wr_dirty_evict_refill_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing wr_dirty_evict_refill_test", UVM_LOW)
    endtask: run_phase

endclass : wr_dirty_evict_refill_test


class wr_dirty_evict_refill_seq extends base_vseq;

    `uvm_object_utils(wr_dirty_evict_refill_seq)

    cpu_transaction_c trans;

    // Five D-cache addresses mapping to the same cache set.
    // All > 32'h3FFF_FFFF (D-cache range). Index bits [15:2] identical.
    bit [`ADDR_WID_LV1-1:0] addr_way0  = 32'h6000_0300;
    bit [`ADDR_WID_LV1-1:0] addr_way1  = 32'h6001_0300;
    bit [`ADDR_WID_LV1-1:0] addr_way2  = 32'h6002_0300;
    bit [`ADDR_WID_LV1-1:0] addr_way3  = 32'h6003_0300;
    bit [`ADDR_WID_LV1-1:0] addr_new   = 32'h6004_0300;

    function new (string name="wr_dirty_evict_refill_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // ------------------------------------------------------------------
        // Step 1: Fill all 4 ways with reads → each enters Exclusive state.
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
        // Step 2: Write way 0 → E->M (dirty).
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Write way0 — E->M (dirty)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way0;
        })

        // ------------------------------------------------------------------
        // Step 3: Touch ways 1, 2, 3 to make way 0 the LRU victim.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Touch way 1, 2, 3 to age way 0 into LRU slot", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way3;
        })

        // ------------------------------------------------------------------
        // Step 4: WRITE to a new address that maps to the same set.
        //         This is a write miss with no free block.
        //         LRU victim = way 0 (MODIFIED).
        //         EXPECTED behaviour:
        //           1. lv2_wr asserted  → dirty way 0 written back to L2
        //           2. lv2_wr_done      → writeback acknowledged, way 0 → INVALID
        //           3. bus_rdx + lv2_rd asserted → Read-for-Ownership of new address
        //           4. data_in_bus_lv1_lv2 → new line arrives from L2
        //           5. cache stores data_bus_cpu_lv1 (CPU write data) into new way
        //           6. cpu_wr_done asserted → write completes
        //         ACTUAL (bug):
        //           Steps 1-2 complete; then bus_rdx and lv2_rd are NOT
        //           re-issued.  cpu_wr_done is never asserted.  The CPU
        //           driver times out (scoreboard error / simulation hang).
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(),
            "Write miss on new addr — dirty eviction + refill required; bug: cpu_wr_done never fires",
            UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_new;
        })

        // ------------------------------------------------------------------
        // Step 5: Read back the new address from Core 0.
        //         Must return the value that was just written (CPU write data).
        //         If the bug is present the write never completed, so this
        //         read also stalls or returns incorrect data.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Core0 read back new addr — must return written data", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_new;
        })

        // ------------------------------------------------------------------
        // Step 6: Core 1 reads the old address (addr_way0) to confirm L2
        //         received the dirty data during the writeback phase.
        //         Also verifies the L2 writeback path itself is functional.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Core1 reads evicted addr — L2 must have dirty writeback data", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way0;
        })
    endtask

endclass : wr_dirty_evict_refill_seq
