//=====================================================================
// Project: 4 core MESI cache design
// File Name: lru_blk3_bias_test.sv
// Description: Catches Bug 3 — lru_block_lv1.sv case 3'b011
//              (blk_accessed_main == block 3) incorrectly sets
//              lru_var[0] = 1'b1 instead of 1'b0.
//
//              Pseudo-LRU encoding for a 4-way set:
//                bit[2]: 0 = evict from {blk0,blk1}, 1 = evict from {blk2,blk3}
//                bit[1]: 0 = evict blk0,             1 = evict blk1
//                bit[0]: 0 = evict blk2,             1 = evict blk3
//
//              After accessing block 3:
//                bit[2] must be set to 1'b1  (right subtree is MRU → left is victim)
//                bit[0] must be set to 1'b0  (blk3 is MRU within right → blk2 is victim)
//
//              Bug: code writes lru_var[index][0] = 1'b1 (ACTUAL),
//              meaning the next eviction victim within the right subtree
//              is blk3 — the block just accessed — instead of blk2.
//
// Waveform signals to inspect (Core 0 D-cache):
//   inst_cache_top.inst_cache_lv1_multicore
//     .inst_cache_lv1_unicore_0
//     .inst_cache_wrapper_lv1_dl
//     .inst_cache_controller_lv1_dl
//     .inst_lru_block_lv1
//       .blk_accessed_main        -- should show 2'b11 (block 3) when bug fires
//       .lru_var[<set_index>]     -- ACTUAL: 3'b1?1 (BLK3_REPLACEMENT)
//                                 -- EXPECTED: 3'b1?0 (BLK2_REPLACEMENT)
//       .lru_replacement_proc     -- ACTUAL: 2'b11 (selects block 3 again)
//                                 -- EXPECTED: 2'b10 (selects block 2)
//=====================================================================

class lru_blk3_bias_test extends base_test;

    `uvm_component_utils(lru_blk3_bias_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                lru_blk3_bias_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing lru_blk3_bias_test", UVM_LOW)
    endtask: run_phase

endclass : lru_blk3_bias_test


class lru_blk3_bias_seq extends base_vseq;

    `uvm_object_utils(lru_blk3_bias_seq)

    cpu_transaction_c trans;

    // Five D-cache addresses that all map to the same cache set.
    // Index bits [15:2] are identical; tags differ in bits [31:16].
    // Using base 32'h4000_0200 so all addresses are > IL_DL_ADDR_BOUND.
    bit [`ADDR_WID_LV1-1:0] addr_way0  = 32'h4000_0200;   // fills way 0
    bit [`ADDR_WID_LV1-1:0] addr_way1  = 32'h4001_0200;   // fills way 1
    bit [`ADDR_WID_LV1-1:0] addr_way2  = 32'h4002_0200;   // fills way 2
    bit [`ADDR_WID_LV1-1:0] addr_way3  = 32'h4003_0200;   // fills way 3 (becomes blk3)
    bit [`ADDR_WID_LV1-1:0] addr_evict = 32'h4004_0200;   // 5th unique address, triggers eviction

    function new (string name="lru_blk3_bias_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // ------------------------------------------------------------------
        // Step 1: Fill all 4 ways of one D-cache set on Core 0.
        //         After this, access order is 0→1→2→3, so:
        //           lru_var bit[2]=1, bit[0]=1  ← bug root (bit[0] should be 0)
        //           lru_replacement_proc = 2'b11 (blk3) ← wrong, should be 2'b10 (blk2)
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

        `uvm_info(get_type_name(), "Fill way 3 (I->E) — MRU becomes blk3", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way3;
        })

        // ------------------------------------------------------------------
        // Step 2: Re-access ways 0 and 1 to make way 2 the cold LRU victim
        //         within the left subtree and confirm blk3 is the MRU within
        //         the right subtree.
        //         Correct lru_var after accessing blk3 last:
        //           bit[2]=1 (left subtree is next victim), bit[0]=0 (blk2 is right victim)
        //         Bug lru_var: bit[2]=1, bit[0]=1 → blk3 is victim instead of blk2.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Touch way 0 — lru update", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way0;
        })

        `uvm_info(get_type_name(), "Touch way 1 — lru update", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way1;
        })

        // At this point lru_replacement_proc should point to way 2 (left subtree LRU).
        // But way 3 was accessed last within the right subtree.
        // The bug causes lru_var[0]=1, so lru_replacement_proc points to blk3 (right victim)
        // when the next global victim is actually in the left subtree (blk2 or blk0).
        // We now access addr_way3 again to make block 3 the absolute MRU;
        // the next eviction should fall on block 2 (right LRU), not block 3.

        `uvm_info(get_type_name(), "Re-access way 3 — blk3 is absolute MRU", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way3;
        })

        // ------------------------------------------------------------------
        // Step 3: Trigger eviction with a 5th address.
        //         EXPECTED: blk2 is evicted (lru_replacement_proc = 2'b10).
        //         ACTUAL (bug): blk3 is evicted (lru_replacement_proc = 2'b11).
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "5th address — eviction must choose blk2 (EXPECTED), bug chooses blk3", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_evict;
        })

        // ------------------------------------------------------------------
        // Step 4: Re-read way 3 — must HIT (blk3 was MRU; only blk2 should
        //         have been evicted).  With the bug, blk3 was evicted so this
        //         is a MISS, meaning the scoreboard sees an unexpected bus_rd.
        // ------------------------------------------------------------------
        `uvm_info(get_type_name(), "Re-read way3 — MUST hit (blk3 was NOT evicted)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way3;
        })

        // Step 5: Re-read way 2 — must MISS (blk2 was the correct LRU victim).
        `uvm_info(get_type_name(), "Re-read way2 — MUST miss (blk2 was the correct eviction victim)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_way2;
        })
    endtask

endclass : lru_blk3_bias_seq
