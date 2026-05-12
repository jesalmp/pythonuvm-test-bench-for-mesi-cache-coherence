//=====================================================================
// Project: 4 core MESI cache design
// File Name: snoop_seq_core13_test.sv
// Description: Targeted test to cover missing mesi_snoop_seq_transition
//   bins specifically on lru_if[1] and lru_if[3] (cores 1 and 3).
//
//   Root cause of gap: snoop_seq_chain_test uses cores 1 and 3 as the
//   REQUESTING cores (proc-side writers/readers), so they never hold
//   M or E lines that get snooped by other cores.
//
//   Fix: Role-reverse all scenarios so cores 1 and 3 are the VICTIMS
//   (line holders) and cores 0 and 2 are the requestors.
//
//   Bins targeted per core:
//     Core 1 and Core 3 snoop-side sequential transitions:
//       E→S : Core holds E; another core reads → bus_rd hits → E→S
//       E→I : Core holds E; another core writes → bus_rdx hits → E→I
//       M→S : Core holds M; another core reads → bus_rd hits → M→S
//       M→I : Core holds M; another core writes → bus_rdx hits → M→I
//       S→I : Core holds S; another core writes → invalidate → S→I
//       S→S : Core holds S; another core reads → bus_rd hits → S→S (×2)
//       I→I : already covered by ignore_bin
//=====================================================================

class snoop_seq_core13_seq extends base_vseq;
    `uvm_object_utils(snoop_seq_core13_seq)

    cpu_transaction_c trans;

    // Fresh address space to avoid interference with snoop_seq_chain_test
    bit [`ADDR_WID_LV1-1:0] addr_es1  = 32'hC000_0100; // E→S for Core1
    bit [`ADDR_WID_LV1-1:0] addr_ei1  = 32'hC000_0200; // E→I for Core1
    bit [`ADDR_WID_LV1-1:0] addr_ms1  = 32'hC000_0300; // M→S for Core1
    bit [`ADDR_WID_LV1-1:0] addr_mi1  = 32'hC000_0400; // M→I for Core1
    bit [`ADDR_WID_LV1-1:0] addr_si1  = 32'hC000_0500; // S→I for Core1
    bit [`ADDR_WID_LV1-1:0] addr_ss1  = 32'hC000_0600; // S→S for Core1

    bit [`ADDR_WID_LV1-1:0] addr_es3  = 32'hC001_0100; // E→S for Core3
    bit [`ADDR_WID_LV1-1:0] addr_ei3  = 32'hC001_0200; // E→I for Core3
    bit [`ADDR_WID_LV1-1:0] addr_ms3  = 32'hC001_0300; // M→S for Core3
    bit [`ADDR_WID_LV1-1:0] addr_mi3  = 32'hC001_0400; // M→I for Core3
    bit [`ADDR_WID_LV1-1:0] addr_si3  = 32'hC001_0500; // S→I for Core3
    bit [`ADDR_WID_LV1-1:0] addr_ss3  = 32'hC001_0600; // S→S for Core3

    function new(string name = "snoop_seq_core13_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "=== snoop_seq_core13_seq START ===", UVM_LOW)

        // ===================================================================
        // CORE 1 as victim
        // ===================================================================

        // --- E→S on Core1: Core1 gets E, Core0 reads → Core1 snoop E→S ---
        `uvm_info(get_type_name(), "Core1 E→S: Core1 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es1;
        })
        `uvm_info(get_type_name(), "Core1 E→S: Core0 read (Core1 snoop E→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es1;
        })

        // --- E→I on Core1: Core1 gets E, Core2 writes → Core1 snoop E→I ---
        `uvm_info(get_type_name(), "Core1 E→I: Core1 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ei1;
        })
        `uvm_info(get_type_name(), "Core1 E→I: Core2 write (Core1 snoop E→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ei1;
        })

        // --- M→S on Core1: Core1 writes → M, Core0 reads → Core1 snoop M→S ---
        `uvm_info(get_type_name(), "Core1 M→S: Core1 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ms1;
        })
        `uvm_info(get_type_name(), "Core1 M→S: Core2 read (Core1 snoop M→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ms1;
        })

        // --- M→I on Core1: Core1 writes → M, Core2 writes → Core1 snoop M→I ---
        `uvm_info(get_type_name(), "Core1 M→I: Core1 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi1;
        })
        `uvm_info(get_type_name(), "Core1 M→I: Core0 write (Core1 snoop M→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi1;
        })

        // --- S→I on Core1: Core1+Core0 share, Core2 writes → Core1 snoop S→I ---
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si1;
        })
        `uvm_info(get_type_name(), "Core1 S→I: Core3 write (Core1 snoop S→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_si1;
        })

        // --- S→S on Core1: Core1+Core2 share, Core0 reads twice → Core1 snoop S→S ---
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss1;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss1;
        })
        // First bus_rd from Core0 → Core1 snoop: first event sets prev_mesi_snoop=S, valid=1
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss1;
        })
        // Second bus_rd from Core3 → Core1 snoop seq: prev=S, next=S → S→S covered
        `uvm_info(get_type_name(), "Core1 S→S: Core3 read (Core1 snoop S→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss1;
        })

        // ===================================================================
        // CORE 3 as victim
        // ===================================================================

        // --- E→S on Core3: Core3 gets E, Core2 reads → Core3 snoop E→S ---
        `uvm_info(get_type_name(), "Core3 E→S: Core3 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es3;
        })
        `uvm_info(get_type_name(), "Core3 E→S: Core1 read (Core3 snoop E→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es3;
        })

        // --- E→I on Core3: Core3 gets E, Core0 writes → Core3 snoop E→I ---
        `uvm_info(get_type_name(), "Core3 E→I: Core3 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ei3;
        })
        `uvm_info(get_type_name(), "Core3 E→I: Core0 write (Core3 snoop E→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ei3;
        })

        // --- M→S on Core3: Core3 writes → M, Core1 reads → Core3 snoop M→S ---
        `uvm_info(get_type_name(), "Core3 M→S: Core3 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ms3;
        })
        `uvm_info(get_type_name(), "Core3 M→S: Core0 read (Core3 snoop M→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ms3;
        })

        // --- M→I on Core3: Core3 writes → M, Core1 writes → Core3 snoop M→I ---
        `uvm_info(get_type_name(), "Core3 M→I: Core3 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi3;
        })
        `uvm_info(get_type_name(), "Core3 M→I: Core2 write (Core3 snoop M→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi3;
        })

        // --- S→I on Core3: Core3+Core1 share, Core0 writes → Core3 snoop S→I ---
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si3;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si3;
        })
        `uvm_info(get_type_name(), "Core3 S→I: Core2 write (Core3 snoop S→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_si3;
        })

        // --- S→S on Core3: Core3+Core0 share, then Core1 reads, Core2 reads → S→S ---
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss3;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss3;
        })
        // First bus_rd from Core1 → sets prev_mesi_snoop on Core3 = S, valid=1
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss3;
        })
        // Second bus_rd from Core2 → Core3 snoop seq: prev=S, next=S → S→S
        `uvm_info(get_type_name(), "Core3 S→S: Core2 read (Core3 snoop S→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss3;
        })

        `uvm_info(get_type_name(), "=== snoop_seq_core13_seq DONE ===", UVM_LOW)
    endtask

endclass : snoop_seq_core13_seq


class snoop_seq_core13_test extends base_test;
    `uvm_component_utils(snoop_seq_core13_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                snoop_seq_core13_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing snoop_seq_core13_test", UVM_LOW)
    endtask: run_phase

endclass : snoop_seq_core13_test
