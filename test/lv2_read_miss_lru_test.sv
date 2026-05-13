//=====================================================================
// Project: 4 core MESI cache design
// File Name: lv2_read_miss_lru_test.sv
// Description: Catches L2 Bug — on a read miss with a free block,
//              main_func_lv2.sv lines 124-131 never update
//              blk_accessed_main, so the LRU tree is not informed
//              which way was just filled. After filling multiple ways
//              in the same L2 set, the LRU state is stale and future
//              evictions replace the wrong block, causing data loss.
//=====================================================================

class lv2_read_miss_lru_test extends base_test;

    `uvm_component_utils(lv2_read_miss_lru_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", lv2_read_miss_lru_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing lv2_read_miss_lru_test" , UVM_LOW)
    endtask: run_phase

endclass : lv2_read_miss_lru_test


class lv2_read_miss_lru_seq extends base_vseq;

    `uvm_object_utils(lv2_read_miss_lru_seq)

    cpu_transaction_c trans;
    // Three addresses in the same L2 set (same bits[19:2]), different L2 tags
    bit [`ADDR_WID_LV1-1:0] addr_a = 32'h5000_0200;
    bit [`ADDR_WID_LV1-1:0] addr_b = 32'h5010_0200;
    bit [`ADDR_WID_LV1-1:0] addr_c = 32'h5020_0200;

    function new (string name="lv2_read_miss_lru_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Fill three L2 ways via read misses from different cores.
        // Bug: blk_accessed_main is never updated on these fills,
        // so the LRU tree stays at its initial state.

        `uvm_info(get_type_name(), "Core0 read addr_a — L2 miss, fills way", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_a;
        })

        `uvm_info(get_type_name(), "Core1 read addr_b — L2 miss, fills way", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_b;
        })

        `uvm_info(get_type_name(), "Core2 read addr_c — L2 miss, fills way", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_c;
        })

        // Re-read addr_a from a different core to touch it in LRU.
        // With the bug, LRU doesn't know addr_a's way was recently used.
        `uvm_info(get_type_name(), "Core3 read addr_a — L2 hit, should refresh LRU", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_a;
        })

        // Read back all three to verify data integrity.
        // Stale LRU may have caused wrong eviction or misordering.
        `uvm_info(get_type_name(), "Core0 re-read addr_b — verify data", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_b;
        })

        `uvm_info(get_type_name(), "Core1 re-read addr_c — verify data", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_c;
        })
    endtask

endclass : lv2_read_miss_lru_seq
