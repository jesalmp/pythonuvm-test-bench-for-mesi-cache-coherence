//=====================================================================
// Project: 4 core MESI cache design
// File Name: virtual_seqs.sv
// Description: virtual sequences library
// Designers: Venky & Suru
//=====================================================================

typedef enum bit [1:0] {CORE0=0, CORE1=1, CORE2=2, CORE3=3} core_num_t;
typedef enum bit {RAND_WAIT=0,FIX_WAIT=1} wait_t;

class rand_num_c;
    // randomize pick
    randc bit [2:0] idx;

    constraint c_idx{
        idx inside {['d0:'d4]};
    }
endclass: rand_num_c

class base_vseq extends uvm_sequence;

    `uvm_object_utils(base_vseq)
    `uvm_declare_p_sequencer(virtual_sequencer_c)

    // for random indices between 0 and 4 for LRU test cases
    rand_num_c        rand_num_idx;
    //main processor number, secondary processor 1 and 2
    rand int mp, sp1, sp2;
    extern task do_on_cpu(core_num_t core_num, request_t req_type, bit [`ADDR_WID_LV1-1:0] rd_addr, wait_t wait_type, int unsigned wait_cycles);

    constraint c_processor_numbers{
`ifdef ONE_CORE // check this def
        mp inside {['d0:'d0]};
        sp1 inside {['d0:'d0]};
        sp2 inside {['d0:'d0]};
        //unique {mp, sp1, sp2};
`elsif DUAL_CORE // ONE_CORE
        mp inside {['d0:'d1]};
        sp1 inside {['d0:'d1]};
        sp2 inside {['d0:'d1]};
        unique {mp, sp1};
`else // TWO_CORE
        mp inside {['d0:'d3]};
        sp1 inside {['d0:'d3]};
        sp2 inside {['d0:'d3]};
        unique {mp, sp1, sp2};
`endif // FOUR_CORE
    }

    function new (string name = "base_vseq");
        super.new(name);
        rand_num_idx = new();
    endfunction

    task pre_body();
        if(starting_phase != null) begin
            starting_phase.raise_objection(this, get_type_name());
            `uvm_info(get_type_name(), "raise_objection", UVM_LOW)
            `uvm_info(get_type_name(), $sformatf("Main Processor=%0d\tSP1=%0d\tSP2=%0d", mp, sp1, sp2), UVM_LOW)
        end
    endtask : pre_body

    task post_body();
        if(starting_phase != null) begin
            starting_phase.drop_objection(this, get_type_name());
            `uvm_info(get_type_name(), "drop_objection", UVM_LOW)
        end
    endtask : post_body

endclass : base_vseq

    // generic task for read/write on any CPU
    task base_vseq::do_on_cpu(core_num_t core_num, request_t req_type, bit [`ADDR_WID_LV1-1:0] rd_addr, wait_t wait_type, int unsigned wait_cycles);
        cpu_transaction_c trans;

        if (wait_type == FIX_WAIT)
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[core_num], {request_type == req_type; address == rd_addr; wait_cycles == wait_cycles;})
        else
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[core_num], {request_type == req_type; address == rd_addr;})
    endtask : do_on_cpu
