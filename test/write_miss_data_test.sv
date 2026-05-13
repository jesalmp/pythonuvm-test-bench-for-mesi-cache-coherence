//=====================================================================
// Project: 4 core MESI cache design
// File Name: write_miss_data_test.sv
// Description: Catches Bug 5 — on a write miss with a free block,
//              the design stores L2 data into the cache instead of
//              the CPU's write data, and never asserts cpu_wr_done.
//              Core 0 writes to a cold D-cache address. The cache
//              should allocate the line AND write the CPU data into
//              it. A subsequent read from Core 0 must return the
//              written value, not the stale L2 value.
//=====================================================================

class write_miss_data_test extends base_test;

    `uvm_component_utils(write_miss_data_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", write_miss_data_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing write_miss_data_test" , UVM_LOW)
    endtask: run_phase

endclass : write_miss_data_test


class write_miss_data_seq extends base_vseq;

    `uvm_object_utils(write_miss_data_seq)

    cpu_transaction_c trans;
    bit [`ADDR_WID_LV1-1:0] test_addr = 32'h6000_0300;

    function new (string name="write_miss_data_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // Write to a cold address — write miss, free block available.
        // Bug: cache stores data_bus_lv1_lv2 (L2 data) instead of
        //      data_bus_cpu_lv1 (CPU write data), and cpu_wr_done
        //      is never asserted → driver times out or data is wrong.
        `uvm_info(get_type_name(), "Core0 write miss on cold address", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == WRITE_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })

        // Read back the same address from Core 0.
        // Must return the value that was just written.
        // Bug: returns L2's stale data instead.
        `uvm_info(get_type_name(), "Core0 read back — should return written data", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })

        // Read from Core 1 — triggers snoop on Core 0 (M->S).
        // Core 1 must also see the written value.
        `uvm_info(get_type_name(), "Core1 read — should see Core0's written data via snoop", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type     == READ_REQ;
            access_cache_type == DCACHE_ACC;
            address          == test_addr;
        })
    endtask

endclass : write_miss_data_seq
