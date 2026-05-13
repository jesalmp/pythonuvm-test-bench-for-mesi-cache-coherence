//=====================================================================
// Project: 4 core MESI cache design
// File Name: mesi_full_transition_test.sv
// Description: Directed test to hit all MESI transitions and cross coverage
//=====================================================================

class mesi_full_transition_test extends base_test;

    `uvm_component_utils(mesi_full_transition_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", mesi_full_transition_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing mesi_full_transition_test" , UVM_LOW)
    endtask: run_phase

endclass : mesi_full_transition_test


class mesi_full_transition_seq extends base_vseq;

    `uvm_object_utils(mesi_full_transition_seq)

    cpu_transaction_c trans;

    bit [`ADDR_WID_LV1-1:0] trans_addr1 = 32'h4000_1000;
    bit [`ADDR_WID_LV1-1:0] trans_addr2 = 32'h4000_2000;

    function new (string name="mesi_full_transition_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        // -------------------------------------------------------------
        // Address 1: Target E -> I, E -> S, S -> M transitions
        // -------------------------------------------------------------
        
        // 1. Core 0 reads Address 1: I -> E
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == trans_addr1;
        })

        // 2. Core 1 reads Address 1: Core 0 (E -> S), Core 1 (I -> S)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == trans_addr1;
        })

        // 3. Core 0 writes Address 1: Core 0 (S -> M), Core 1 (S -> I)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == trans_addr1;
        })

        // 4. Core 0 writes Address 1 again: Core 0 (M -> M)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == trans_addr1;
        })

        // 5. Core 2 reads Address 1: Core 0 (M -> S), Core 2 (I -> S)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == trans_addr1;
        })
        
        // 6. Core 3 writes Address 1: Core 3 (I -> M), Core 0/2 (S -> I)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == trans_addr1;
        })

        // -------------------------------------------------------------
        // Address 2: Target I -> M, E -> I directly
        // -------------------------------------------------------------

        // 7. Core 1 reads Address 2: Core 1 (I -> E)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == trans_addr2;
        })

        // 8. Core 0 writes Address 2: Core 0 (I -> M), Core 1 (E -> I)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == trans_addr2;
        })

        // 9. Core 1 reads Address 2: Core 0 (M -> S), Core 1 (I -> S)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == trans_addr2;
        })

    endtask

endclass : mesi_full_transition_seq
