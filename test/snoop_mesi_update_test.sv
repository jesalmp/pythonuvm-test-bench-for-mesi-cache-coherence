//=====================================================================
// Project: 4 core MESI cache design
// File Name: snoop_mesi_update_test.sv
// Description: Catches Bug 2 — snoop invalidate path uses
//              updated_mesi_proc instead of updated_mesi_snoop.
//              Core 0 writes an address (goes to Modified). Core 1
//              then reads the same address, triggering a bus_rd snoop
//              on Core 0. The snoop side should use updated_mesi_snoop
//              (M->S) but the bug writes updated_mesi_proc instead,
//              corrupting the MESI state. A follow-up write from
//              Core 1 then exposes the inconsistency.
//=====================================================================

class snoop_mesi_update_test extends base_test;

    `uvm_component_utils(snoop_mesi_update_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", snoop_mesi_update_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing snoop_mesi_update_test" , UVM_LOW)
    endtask: run_phase

endclass : snoop_mesi_update_test


class snoop_mesi_update_seq extends base_vseq;

    `uvm_object_utils(snoop_mesi_update_seq)

    cpu_transaction_c trans;
    bit [`ADDR_WID_LV1-1:0] test_addr = 32'h8000_0200;

    function new (string name="snoop_mesi_update_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Core 0 writes address — cold miss, allocate, goes to Modified
        `uvm_info(get_type_name(), "Core0 write — I->M", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })

        // Core 1 reads same address — bus_rd snoops Core 0.
        // Core 0 snoop should transition M->S using updated_mesi_snoop.
        // Bug: uses updated_mesi_proc which gives wrong next-state.
        `uvm_info(get_type_name(), "Core1 read — Core0 snoop M->S (bug: uses proc FSM output)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })

        // Core 0 reads the same address to verify its state is now Shared
        `uvm_info(get_type_name(), "Core0 re-read — should be S, wrong state if bug present", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })

        // Core 0 writes the same address — write hit on SHARED triggers
        // invalidate on the bus. Core 1 snoop processes the invalidate;
        // Bug 2 fires here (uses updated_mesi_proc instead of
        // updated_mesi_snoop), corrupting Core 1's MESI state.
        `uvm_info(get_type_name(), "Core0 write — S->M, invalidate sent, Core1 snoop uses wrong MESI src", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })

        // Core 1 reads again — should miss (line was invalidated) and
        // re-fetch from bus. If Bug 2 is present, Core 1 still thinks
        // it is SHARED and returns stale cached data.
        `uvm_info(get_type_name(), "Core1 final read — stale data returned if snoop MESI was wrong", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })
    endtask

endclass : snoop_mesi_update_seq
