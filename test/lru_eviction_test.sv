//=====================================================================
// Project: 4 core MESI cache design
// File Name: lru_eviction_test.sv
// Description: Catches Bug 3 — lru_replacement_proc is never used
//              in main_func_lv1_dl.sv. The eviction victim is selected
//              via blk_access_proc (hit logic) instead of the LRU
//              output. We fill all 4 ways of a single D-cache set,
//              then access a 5th address mapping to the same set.
//              With the bug, the wrong way is evicted and a subsequent
//              read to the evicted address returns incorrect data.
//=====================================================================

class lru_eviction_test extends base_test;

    `uvm_component_utils(lru_eviction_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", lru_eviction_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing lru_eviction_test" , UVM_LOW)
    endtask: run_phase

endclass : lru_eviction_test


class lru_eviction_seq extends base_vseq;

    `uvm_object_utils(lru_eviction_seq)

    cpu_transaction_c trans;

    // 5 addresses that map to the same cache set (same index bits [15:2])
    // but have different tags. D-cache addresses are > 32'h3FFF_FFFF.
    // Index bits [15:2] = 14'h0040 for all five addresses.
    // Tag differs in bits [31:16].
    bit [`ADDR_WID_LV1-1:0] addr_way0 = 32'h4000_0100;
    bit [`ADDR_WID_LV1-1:0] addr_way1 = 32'h4001_0100;
    bit [`ADDR_WID_LV1-1:0] addr_way2 = 32'h4002_0100;
    bit [`ADDR_WID_LV1-1:0] addr_way3 = 32'h4003_0100;
    bit [`ADDR_WID_LV1-1:0] addr_evict = 32'h4004_0100;

    function new (string name="lru_eviction_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Fill all 4 ways of the set on Core 0
        `uvm_info(get_type_name(), "Filling way 0", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way0;
        })

        `uvm_info(get_type_name(), "Filling way 1", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way1;
        })

        `uvm_info(get_type_name(), "Filling way 2", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way2;
        })

        `uvm_info(get_type_name(), "Filling way 3", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way3;
        })

        // Touch way 1, 2, 3 again so way 0 becomes the LRU victim
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way3;
        })

        // 5th address — must evict way 0 (LRU). Bug: wrong victim selected
        // because lru_replacement_proc is never consulted.
        `uvm_info(get_type_name(), "Eviction access — should evict LRU way 0", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_evict;
        })

        // Re-read way 1 — must still be in cache (was NOT evicted)
        `uvm_info(get_type_name(), "Re-read way1 — should hit", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way1;
        })

        // Re-read way 0 — was evicted, must miss and fetch from L2
        `uvm_info(get_type_name(), "Re-read way0 — should miss (evicted)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == addr_way0;
        })
    endtask

endclass : lru_eviction_seq
