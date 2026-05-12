//=====================================================================
// Project: 4 core MESI cache design
// File Name: icache_eviction_test.sv
// Description: Catches Bug 6 — main_func_lv1_il.sv no-free-block
//              path just sets MESI=VALID without evicting the old
//              block, updating the tag, or fetching new data.
//              We read 5 I-cache addresses that map to the same set
//              to force an eviction on the 5th access. With the bug,
//              the tag is never updated so the 5th read returns stale
//              data from the old line and the old address incorrectly
//              misses on re-read.
//=====================================================================

class icache_eviction_test extends base_test;

    `uvm_component_utils(icache_eviction_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", icache_eviction_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing icache_eviction_test" , UVM_LOW)
    endtask: run_phase

endclass : icache_eviction_test


class icache_eviction_seq extends base_vseq;

    `uvm_object_utils(icache_eviction_seq)

    cpu_transaction_c trans;

    // 5 I-cache addresses mapping to the same set (same index bits [15:2])
    // but different tags. I-cache addresses are <= 32'h3FFF_FFFF.
    bit [`ADDR_WID_LV1-1:0] iaddr_way0 = 32'h0000_0400;
    bit [`ADDR_WID_LV1-1:0] iaddr_way1 = 32'h0001_0400;
    bit [`ADDR_WID_LV1-1:0] iaddr_way2 = 32'h0002_0400;
    bit [`ADDR_WID_LV1-1:0] iaddr_way3 = 32'h0003_0400;
    bit [`ADDR_WID_LV1-1:0] iaddr_evict = 32'h0004_0400;

    function new (string name="icache_eviction_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Fill all 4 ways of one I-cache set
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way0;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way3;
        })

        // Touch ways 1-3 so way 0 becomes LRU victim
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way3;
        })

        // 5th address — triggers eviction.
        // Bug: MESI is set to VALID but tag and data are never updated.
        // The read returns stale data from the evicted line.
        `uvm_info(get_type_name(), "5th I-cache read — must evict and refill", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_evict;
        })

        // Re-read the evicted address — must miss and re-fetch
        `uvm_info(get_type_name(), "Re-read evicted way0 — should miss", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_way0;
        })

        // Re-read the new address — must hit now
        `uvm_info(get_type_name(), "Re-read new addr — should hit", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == ICACHE_ACC; address == iaddr_evict;
        })
    endtask

endclass : icache_eviction_seq
