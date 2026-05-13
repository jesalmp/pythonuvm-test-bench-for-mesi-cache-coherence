//=====================================================================
// Project: 4 core MESI cache design
// File Name: snoop_exclusive_test.sv
// Description: Targeted test to hit E -> S and E -> I snoop transitions
//=====================================================================

class snoop_exclusive_seq extends base_vseq;
    `uvm_object_utils(snoop_exclusive_seq)

    function new(string name = "snoop_exclusive_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info(get_type_name(), "Executing Snoop Exclusive Transitions", UVM_LOW)

        // 1. Core 0 Reads Addr A (Miss -> I to E)
        do_on_cpu(CORE0, READ_REQ, 32'h0000_1000, FIX_WAIT, 0);
        
        // 2. Core 1 Reads Addr A (Snoop Rd to Core 0 -> E to S)
        do_on_cpu(CORE1, READ_REQ, 32'h0000_1000, FIX_WAIT, 0);

        // 3. Core 2 Reads Addr B (Miss -> I to E)
        do_on_cpu(CORE2, READ_REQ, 32'h0000_2000, FIX_WAIT, 0);

        // 4. Core 3 Writes Addr B (Snoop Wr to Core 2 -> E to I)
        do_on_cpu(CORE3, WRITE_REQ, 32'h0000_2000, FIX_WAIT, 0);

        #100;
        `uvm_info(get_type_name(), "Snoop Exclusive Test Finished", UVM_LOW)
    endtask
endclass

class snoop_exclusive_test extends base_test;
    `uvm_component_utils(snoop_exclusive_test)

    function new(string name = "snoop_exclusive_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(this, "env.v_seqr.run_phase", "default_sequence", snoop_exclusive_seq::type_id::get());
    endfunction
endclass
