//=====================================================================
// Project: 4 core MESI cache design
// File Name: five_trans_test.sv
// Description: Test for 5 transaction sequence
// Designers: Venky & Suru
//=====================================================================

class five_trans_test extends base_test;

    //component macro
    `uvm_component_utils(five_trans_test)

    //Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    //UVM build phase
    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this,"tb.cpu[0].sequencer.run_phase","default_sequence",five_trans_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    //UVM run phase()
    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing five_trans_test test" , UVM_LOW)
    endtask : run_phase

endclass : five_trans_test
