//=====================================================================
// Project: 4 core MESI cache design
// File Name: shared_snoop_invalidate_test.sv
// Description: Catches Bug 1 — MESI FSM SHARED snoop transitions
//              are inverted (bus_rdx/invalidate keeps SHARED instead
//              of going to INVALID).
//              Core 0 and Core 1 read the same D-cache address so both
//              go to SHARED. Then Core 0 writes the same address which
//              issues an invalidate on the bus. Core 1's snoop side
//              must transition SHARED -> INVALID. With the bug, it
//              stays SHARED, causing a coherence violation.
//=====================================================================

class shared_snoop_invalidate_test extends base_test;

    `uvm_component_utils(shared_snoop_invalidate_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", shared_snoop_invalidate_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing shared_snoop_invalidate_test" , UVM_LOW)
    endtask: run_phase

endclass : shared_snoop_invalidate_test


class shared_snoop_invalidate_seq extends base_vseq;

    `uvm_object_utils(shared_snoop_invalidate_seq)

    cpu_transaction_c trans;
    bit [`ADDR_WID_LV1-1:0] shared_addr = 32'h4000_0100;

    function new (string name="shared_snoop_invalidate_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Step 1: Core 0 reads address — cold miss, goes to Exclusive
        `uvm_info(get_type_name(), "Core0 read — I->E", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == shared_addr;
        })

        // Step 2: Core 1 reads same address — snoop hits E, both go to Shared
        `uvm_info(get_type_name(), "Core1 read same addr — E->S on Core0, I->S on Core1", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == shared_addr;
        })

        // Step 3: Core 0 writes same address — invalidate sent on bus.
        // Core 1 snoop side must go SHARED -> INVALID.
        // Bug: FSM keeps it SHARED.
        `uvm_info(get_type_name(), "Core0 write — S->M on Core0, Core1 snoop S->I (bug: stays S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address          == shared_addr;
        })

        // Step 4: Core 1 reads the same address again.
        // If Core 1 still thinks it is SHARED (bug), it will return stale
        // data from its own cache instead of fetching the updated value.
        `uvm_info(get_type_name(), "Core1 re-read — should miss (I), gets stale hit if bug present", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == shared_addr;
        })
    endtask

endclass : shared_snoop_invalidate_seq
