//=====================================================================
// Project: 4 core MESI cache design
// File Name: dirty_replacement_read_test.sv
// Description: Catches Bug 4 — after a dirty (Modified) block is
//              evicted and written back to L2, the design never
//              follows up with a bus_rd/lv2_rd to fetch the new block.
//              The processor never receives the requested data.
//              We fill all 4 ways, write one to make it Modified,
//              then read a 5th address in the same set. The dirty
//              line must be written back AND the new line must be
//              fetched. With the bug the refill never happens.
//=====================================================================

class dirty_replacement_read_test extends base_test;

    `uvm_component_utils(dirty_replacement_read_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", dirty_replacement_read_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing dirty_replacement_read_test" , UVM_LOW)
    endtask: run_phase

endclass : dirty_replacement_read_test


class dirty_replacement_read_seq extends base_vseq;

    `uvm_object_utils(dirty_replacement_read_seq)

    cpu_transaction_c trans;

    // 5 D-cache addresses mapping to the same set (same index bits)
    bit [`ADDR_WID_LV1-1:0] addr_way0 = 32'h5000_0200;
    bit [`ADDR_WID_LV1-1:0] addr_way1 = 32'h5001_0200;
    bit [`ADDR_WID_LV1-1:0] addr_way2 = 32'h5002_0200;
    bit [`ADDR_WID_LV1-1:0] addr_way3 = 32'h5003_0200;
    bit [`ADDR_WID_LV1-1:0] addr_new  = 32'h5004_0200;

    function new (string name="dirty_replacement_read_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Fill all 4 ways with reads (all go to Exclusive)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way0;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way3;
        })

        // Write to way 0 — transitions E->M (dirty)
        `uvm_info(get_type_name(), "Write way0 — E->M (dirty)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_way0;
        })

        // Touch ways 1-3 so way 0 is LRU
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_way3;
        })

        // Read new address — triggers eviction of dirty way 0.
        // Bug: writeback happens but refill never follows.
        // Test will timeout or return wrong data.
        `uvm_info(get_type_name(), "Read new addr — must evict dirty way0, writeback + refill", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_new;
        })

        // Verify the new address data is actually in cache (hit)
        `uvm_info(get_type_name(), "Re-read new addr — should hit", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_new;
        })
    endtask

endclass : dirty_replacement_read_seq
