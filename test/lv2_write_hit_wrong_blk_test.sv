//=====================================================================
// Project: 4 core MESI cache design
// File Name: lv2_write_hit_wrong_blk_test.sv
// Description: Catches L2 Bug — on a write hit, main_func_lv2.sv
//              line 117 uses blk_accessed_main (stale) instead of
//              blk_access_proc (current hit way) to index cache_var.
//              Two addresses in the same L2 set are written by Core 0
//              (Modified in L1). Core 1 reads them in sequence,
//              triggering snoop writebacks (lv2_wr) to L2. The second
//              writeback corrupts the first address's L2 block because
//              blk_accessed_main still points to the previous way.
//=====================================================================

class lv2_write_hit_wrong_blk_test extends base_test;

    `uvm_component_utils(lv2_write_hit_wrong_blk_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", lv2_write_hit_wrong_blk_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing lv2_write_hit_wrong_blk_test" , UVM_LOW)
    endtask: run_phase

endclass : lv2_write_hit_wrong_blk_test


class lv2_write_hit_wrong_blk_seq extends base_vseq;

    `uvm_object_utils(lv2_write_hit_wrong_blk_seq)

    cpu_transaction_c trans;
    // Same L2 index (bits[19:2]), different L2 tag (bits[31:20])
    bit [`ADDR_WID_LV1-1:0] addr_a = 32'h4000_0100;
    bit [`ADDR_WID_LV1-1:0] addr_b = 32'h4010_0100;

    function new (string name="lv2_write_hit_wrong_blk_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Core 0 writes addr_a — cold miss, L1 Modified, L2 fills way
        `uvm_info(get_type_name(), "Core0 write addr_a — cold miss, M in L1", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_a;
        })

        // Core 0 writes addr_b (same L2 set) — cold miss, L1 Modified, L2 fills different way
        `uvm_info(get_type_name(), "Core0 write addr_b — cold miss, M in L1", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type      == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_b;
        })

        // Core 1 reads addr_b — BusRd snoops Core 0 M, writeback to L2.
        // L2 lv2_wr hit: blk_accessed_main updated to addr_b's way.
        `uvm_info(get_type_name(), "Core1 read addr_b — snoop writeback sets blk_accessed_main", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_b;
        })

        // Core 1 reads addr_a — BusRd snoops Core 0 M, writeback to L2.
        // Bug: lv2_wr hit writes addr_a data into addr_b's way (blk_accessed_main)
        `uvm_info(get_type_name(), "Core1 read addr_a — snoop writeback, bug corrupts addr_b block", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_a;
        })

        // Core 2 reads addr_b — exposes corrupted L2 data if bug present
        `uvm_info(get_type_name(), "Core2 read addr_b — check for data corruption", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type      == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address           == addr_b;
        })
    endtask

endclass : lv2_write_hit_wrong_blk_seq
