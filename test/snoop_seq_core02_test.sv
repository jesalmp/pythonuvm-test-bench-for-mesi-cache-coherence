//=====================================================================
// Project: 4 core MESI cache design
// File Name: snoop_seq_core02_test.sv
// Description: Targeted test to cover missing mesi_snoop_seq_transition
//   bins specifically on lru_if[0] and lru_if[2] (cores 0 and 2).
//
//   Root cause of gap: previous tests may use cores 0 and 2 as the
//   REQUESTING cores, so they never hold M or E lines that get snooped
//   by other cores.
//
//   Fix: Role-reverse all scenarios so cores 0 and 2 are the VICTIMS
//   (line holders) and cores 1 and 3 are the requestors.
//
//   Bins targeted per core:
//     Core 0 and Core 2 snoop-side sequential transitions:
//       E→S : Core holds E; another core reads → bus_rd hits → E→S
//       E→I : Core holds E; another core writes → bus_rdx hits → E→I
//       M→S : Core holds M; another core reads → bus_rd hits → M→S
//       M→I : Core holds M; another core writes → bus_rdx hits → M→I
//       S→I : Core holds S; another core writes → invalidate → S→I
//       S→S : Core holds S; another core reads → bus_rd hits → S→S
//       I→I : already covered by ignore_bin
//=====================================================================

class snoop_seq_core02_seq extends base_vseq;
    `uvm_object_utils(snoop_seq_core02_seq)

    cpu_transaction_c trans;

    // Fresh address space to avoid interference with other snoop tests
    bit [`ADDR_WID_LV1-1:0] addr_es0  = 32'hD000_0100; // E→S for Core0
    bit [`ADDR_WID_LV1-1:0] addr_ei0  = 32'hD000_0200; // E→I for Core0
    bit [`ADDR_WID_LV1-1:0] addr_ms0  = 32'hD000_0300; // M→S for Core0
    bit [`ADDR_WID_LV1-1:0] addr_mi0  = 32'hD000_0400; // M→I for Core0
    bit [`ADDR_WID_LV1-1:0] addr_si0  = 32'hD000_0500; // S→I for Core0
    bit [`ADDR_WID_LV1-1:0] addr_ss0  = 32'hD000_0600; // S→S for Core0

    bit [`ADDR_WID_LV1-1:0] addr_es2  = 32'hD001_0100; // E→S for Core2
    bit [`ADDR_WID_LV1-1:0] addr_ei2  = 32'hD001_0200; // E→I for Core2
    bit [`ADDR_WID_LV1-1:0] addr_ms2  = 32'hD001_0300; // M→S for Core2
    bit [`ADDR_WID_LV1-1:0] addr_mi2  = 32'hD001_0400; // M→I for Core2
    bit [`ADDR_WID_LV1-1:0] addr_si2  = 32'hD001_0500; // S→I for Core2
    bit [`ADDR_WID_LV1-1:0] addr_ss2  = 32'hD001_0600; // S→S for Core2

    function new(string name = "snoop_seq_core02_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "=== snoop_seq_core02_seq START ===", UVM_LOW)

        // ===================================================================
        // CORE 0 as victim
        // ===================================================================

        // --- E→S on Core0: Core0 gets E, Core1 reads → Core0 snoop E→S ---
        `uvm_info(get_type_name(), "Core0 E→S: Core0 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es0;
        })
        `uvm_info(get_type_name(), "Core0 E→S: Core1 read (Core0 snoop E→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es0;
        })

        // --- E→I on Core0: Core0 gets E, Core3 writes → Core0 snoop E→I ---
        `uvm_info(get_type_name(), "Core0 E→I: Core0 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ei0;
        })
        `uvm_info(get_type_name(), "Core0 E→I: Core3 write (Core0 snoop E→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ei0;
        })

        // --- M→S on Core0: Core0 writes → M, Core1 reads → Core0 snoop M→S ---
        `uvm_info(get_type_name(), "Core0 M→S: Core0 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ms0;
        })
        `uvm_info(get_type_name(), "Core0 M→S: Core1 read (Core0 snoop M→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ms0;
        })

        // --- M→I on Core0: Core0 writes → M, Core3 writes → Core0 snoop M→I ---
        `uvm_info(get_type_name(), "Core0 M→I: Core0 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi0;
        })
        `uvm_info(get_type_name(), "Core0 M→I: Core3 write (Core0 snoop M→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi0;
        })

        // --- S→I on Core0: Core0+Core1 share, Core3 writes → Core0 snoop S→I ---
        `uvm_info(get_type_name(), "Core0 S→I: Core0 read then Core1 read to create shared line", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si0;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si0;
        })
        `uvm_info(get_type_name(), "Core0 S→I: Core3 write (Core0 snoop S→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_si0;
        })

        // --- S→S on Core0: Core0+Core1 share, then Core3 reads, Core2 reads → S→S ---
        `uvm_info(get_type_name(), "Core0 S→S: Core0 read then Core1 read to create shared line", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss0;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss0;
        })
        // First bus_rd from Core3 → Core0 snoop S→S / updates prev
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss0;
        })
        // Second bus_rd from Core2 → Core0 snoop seq: prev=S, next=S → S→S covered
        `uvm_info(get_type_name(), "Core0 S→S: Core2 read (Core0 snoop S→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss0;
        })

        // ===================================================================
        // CORE 2 as victim
        // ===================================================================

        // --- E→S on Core2: Core2 gets E, Core3 reads → Core2 snoop E→S ---
        `uvm_info(get_type_name(), "Core2 E→S: Core2 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es2;
        })
        `uvm_info(get_type_name(), "Core2 E→S: Core3 read (Core2 snoop E→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es2;
        })

        // --- E→I on Core2: Core2 gets E, Core1 writes → Core2 snoop E→I ---
        `uvm_info(get_type_name(), "Core2 E→I: Core2 read (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ei2;
        })
        `uvm_info(get_type_name(), "Core2 E→I: Core1 write (Core2 snoop E→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ei2;
        })

        // --- M→S on Core2: Core2 writes → M, Core3 reads → Core2 snoop M→S ---
        `uvm_info(get_type_name(), "Core2 M→S: Core2 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ms2;
        })
        `uvm_info(get_type_name(), "Core2 M→S: Core3 read (Core2 snoop M→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ms2;
        })

        // --- M→I on Core2: Core2 writes → M, Core1 writes → Core2 snoop M→I ---
        `uvm_info(get_type_name(), "Core2 M→I: Core2 write (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi2;
        })
        `uvm_info(get_type_name(), "Core2 M→I: Core1 write (Core2 snoop M→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi2;
        })

        // --- S→I on Core2: Core2+Core3 share, Core1 writes → Core2 snoop S→I ---
        `uvm_info(get_type_name(), "Core2 S→I: Core2 read then Core3 read to create shared line", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si2;
        })
        `uvm_info(get_type_name(), "Core2 S→I: Core1 write (Core2 snoop S→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_si2;
        })

        // --- S→S on Core2: Core2+Core3 share, then Core1 reads, Core0 reads → S→S ---
        `uvm_info(get_type_name(), "Core2 S→S: Core2 read then Core3 read to create shared line", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss2;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss2;
        })
        // First bus_rd from Core1 → Core2 snoop S→S / updates prev
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss2;
        })
        // Second bus_rd from Core0 → Core2 snoop seq: prev=S, next=S → S→S covered
        `uvm_info(get_type_name(), "Core2 S→S: Core0 read (Core2 snoop S→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss2;
        })

        `uvm_info(get_type_name(), "=== snoop_seq_core02_seq DONE ===", UVM_LOW)
    endtask

endclass : snoop_seq_core02_seq


class snoop_seq_core02_test extends base_test;
    `uvm_component_utils(snoop_seq_core02_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                snoop_seq_core02_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing snoop_seq_core02_test", UVM_LOW)
    endtask: run_phase

endclass : snoop_seq_core02_test