//=====================================================================
// Project: 4 core MESI cache design
// File Name: exhaustive_interface_test.sv
// Description: Deterministic sequence hitting all core pairings
//              to exercise all local and snoop interfaces.
//=====================================================================

class exhaustive_interface_test extends base_test;

    `uvm_component_utils(exhaustive_interface_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", exhaustive_interface_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing exhaustive_interface_test" , UVM_LOW)
    endtask: run_phase

endclass : exhaustive_interface_test


class exhaustive_interface_seq extends base_vseq;

    `uvm_object_utils(exhaustive_interface_seq)

    cpu_transaction_c trans;

    function new (string name="exhaustive_interface_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        bit [`ADDR_WID_LV1-1:0] addr;
        int addr_offset = 0;

        // Iterate through all permutations of 4 cores
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                if (i != j) begin
                    // Assign a unique base address for this pair's tests to avoid
                    // interference with residual cache states from earlier loops
                    addr = 32'h4000_0000 + (addr_offset << 5);
                    addr_offset++;

                    // 1. Core I reads (I->E transition)
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[i], {
                        request_type == READ_REQ;
                        access_cache_type == DCACHE_ACC;
                        address == addr;
                    })
                    
                    // 2. Core I writes (E->M transition)
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[i], {
                        request_type == WRITE_REQ;
                        access_cache_type == DCACHE_ACC;
                        address == addr;
                    })

                    // 3. Core J reads (M->S on Core I, I->S on Core J)
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[j], {
                        request_type == READ_REQ;
                        access_cache_type == DCACHE_ACC;
                        address == addr;
                    })

                    // 4. Core J writes (S->I on Core I, S->M on Core J)
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[j], {
                        request_type == WRITE_REQ;
                        access_cache_type == DCACHE_ACC;
                        address == addr;
                    })
                    
                    // 5. I-cache read on Core I to hit instruction cache paths
                    `uvm_do_on_with(trans, p_sequencer.cpu_seqr[i], {
                        request_type == READ_REQ;
                        access_cache_type == ICACHE_ACC;
                        // Keep I-Cache accesses in lower address bound typical for instructions
                        address == {2'b00, addr[29:0]} + 32'h0001_0000;
                    })
                end
            end
        end
    endtask

endclass : exhaustive_interface_seq
