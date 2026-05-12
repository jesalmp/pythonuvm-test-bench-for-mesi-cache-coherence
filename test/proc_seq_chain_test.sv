//=====================================================================
// Project: 4 core MESI cache design
// File Name: proc_seq_chain_test.sv
// Description: Targeted test for missing proc-side sequential
//   transitions in mesi_proc_seq_transition_cg.
//
//   Missing bins targeted (after I→I ignore_bin added):
//
//     E→E : Core reads an address (I→E). Core reads the same address
//            again (E→E hit, state stays EXCLUSIVE). The sequential CG
//            samples the second access: prev=E, next=E.
//
//     S→S : Core0 and Core1 both have addr in SHARED state. Core0
//            reads again (S→S hit). Sequential CG: prev=S, next=S.
//
//     I→S : Core0 reads addr when another core already has it (shared).
//            Forces I→S on Core0.
//
//     I→M : Core writes a new address (cold miss, write allocate → I→M).
//
//   All other transitions (I→E, S→M, E→M, M→M) should already be
//   covered by existing tests. This test focuses on E→E and S→S.
//=====================================================================

class proc_seq_chain_seq extends base_vseq;
    `uvm_object_utils(proc_seq_chain_seq)

    cpu_transaction_c trans;

    // Fresh addresses to avoid residual state from other tests
    bit [`ADDR_WID_LV1-1:0] addr_ee  = 32'hB000_0100; // E→E scenario
    bit [`ADDR_WID_LV1-1:0] addr_ss  = 32'hB000_0200; // S→S scenario
    bit [`ADDR_WID_LV1-1:0] addr_is  = 32'hB000_0300; // I→S scenario
    bit [`ADDR_WID_LV1-1:0] addr_im  = 32'hB000_0400; // I→M scenario

    function new(string name = "proc_seq_chain_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "=== proc_seq_chain_seq START ===", UVM_LOW)

        // ---------------------------------------------------------------
        // Scenario 1: E→E (repeated read-hit on EXCLUSIVE line)
        // Core0 reads addr_ee → I→E (cold miss, no other sharer)
        // Core0 reads addr_ee again → E→E (read-hit, stays EXCLUSIVE)
        // The sequential CG captures: prev_mesi_proc=E, updated=E
        // Repeat across all 4 cores to ensure all instances are covered.
        // ---------------------------------------------------------------
        for (int c = 0; c < 4; c++) begin
            bit [`ADDR_WID_LV1-1:0] a;
            a = addr_ee + (c << 8); // unique address per core to avoid sharing
            `uvm_info(get_type_name(), $sformatf("E→E: Core%0d first read (I→E)", c), UVM_LOW)
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == a;
            })
            `uvm_info(get_type_name(), $sformatf("E→E: Core%0d second read (E→E hit)", c), UVM_LOW)
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == a;
            })
            // Third read for good measure
            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[c], {
                request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == a;
            })
        end

        // ---------------------------------------------------------------
        // Scenario 2: S→S (repeated read-hit on SHARED line)
        // Core0 reads addr_ss → I→E
        // Core1 reads addr_ss → Core0 E→S, Core1 I→S
        // Core0 reads addr_ss again → S→S (read-hit on Core0 shared line)
        // Core1 reads addr_ss again → S→S (read-hit on Core1 shared line)
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "S→S: Core0 read addr_ss (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        `uvm_info(get_type_name(), "S→S: Core1 read addr_ss (E→S on Core0, I→S on Core1)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        // Now hit the SHARED line again on Core0
        `uvm_info(get_type_name(), "S→S: Core0 re-read addr_ss (S→S hit)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        // And Core1
        `uvm_info(get_type_name(), "S→S: Core1 re-read addr_ss (S→S hit)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        // Add Core2 and Core3 to share too, then re-read
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        // Re-read all cores for more S→S samples
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })

        // ---------------------------------------------------------------
        // Scenario 3: I→S (cold read when another core already has shared)
        // First establish a shared state: Core0 reads addr_is (I→E),
        // Core1 reads addr_is (E→S), then Core2 reads (I→S).
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "I→S: Core0 read addr_is (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_is;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_is;
        })
        `uvm_info(get_type_name(), "I→S: Core2 read addr_is (I→S, shared already present)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_is;
        })

        // ---------------------------------------------------------------
        // Scenario 4: I→M (cold write miss)
        // Core3 writes a fresh address that was never accessed → I→M.
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "I→M: Core3 write addr_im (I→M cold write miss)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_im;
        })

        `uvm_info(get_type_name(), "=== proc_seq_chain_seq DONE ===", UVM_LOW)
    endtask

endclass : proc_seq_chain_seq


class proc_seq_chain_test extends base_test;
    `uvm_component_utils(proc_seq_chain_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                proc_seq_chain_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing proc_seq_chain_test", UVM_LOW)
    endtask: run_phase

endclass : proc_seq_chain_test
