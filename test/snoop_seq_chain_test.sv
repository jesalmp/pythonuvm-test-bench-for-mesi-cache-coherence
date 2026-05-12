//=====================================================================
// Project: 4 core MESI cache design
// File Name: snoop_seq_chain_test.sv
// Description: Targeted test for missing snoop-side sequential
//   transitions in mesi_snoop_seq_transition_cg.
//
//   Missing bins targeted:
//     S→S : Two consecutive bus_rds while line is SHARED — the second
//            bus_rd on a SHARED line leaves it SHARED (FSM: SHARED+bus_rd
//            → SHARED per mesi_fsm_lv1.sv lines 91-94 which has the
//            bus_rdx/invalidate → SHARED bug, but bus_rd alone leaves
//            current state). To get S→S in the *sequential* CG we need:
//            step1: snoop that transitions line to SHARED (e.g., E→S)
//            step2: another bus_rd on the same line (S→S on snoop side).
//
//     M→M : Core writes an address twice with no competing bus activity
//            on that address in between. The snoop side of that core
//            stays MODIFIED across two consecutive proc-side write hits.
//            For the *snoop* sequential CG, we need a snoop event while
//            state is M, followed immediately by another snoop event
//            that keeps it M. Since a bus_rd on M forces M→S and
//            bus_rdx on M forces M→I, the only way to get M→M on the
//            snoop CG is if the snoop fires on a *different* cache line
//            in the same set. However, the MESI interface taps a single
//            line's state; if the bus_rd misses this core, the snoop
//            guard (blk_hit_snoop) is 0 and current_mesi_snoop doesn't
//            update, so the iff guard prevents sampling. Therefore M→M
//            requires: two consecutive proc writes (M→M on proc seq CG)
//            plus a snoop that hits this M line twice in a row with
//            bus_rd, transitioning M→S both times — which gives M→S not
//            M→M. M→M on snoop seq is only achievable if bus_rd or
//            bus_rdx hit the same line while already in M and the FSM
//            stays in M — which contradicts the FSM. Therefore M→M snoop
//            seq is structurally unreachable (covered by ignore_bins).
//
//   Achievable via this test:
//     S→S  via: Core0+Core1 share addr A → both go S.
//               Core2 reads addr A → bus_rd snoops Core0&Core1 (S→S).
//               Core3 reads addr A → bus_rd snoops Core0&Core1 again (S→S).
//
//   Also drives I→I (bus_rd on non-cached line), E→I (bus_rdx eviction),
//   M→S (bus_rd on Modified line), M→I (bus_rdx on Modified line).
//=====================================================================

class snoop_seq_chain_seq extends base_vseq;
    `uvm_object_utils(snoop_seq_chain_seq)

    cpu_transaction_c trans;

    // Addresses for the test — all D-cache range (>= 32'h4000_0000)
    // Use unique addresses per scenario to avoid residual state conflicts.
    bit [`ADDR_WID_LV1-1:0] addr_ss  = 32'hA000_0100; // S→S scenario
    bit [`ADDR_WID_LV1-1:0] addr_ms  = 32'hA000_0200; // M→S scenario
    bit [`ADDR_WID_LV1-1:0] addr_mi  = 32'hA000_0300; // M→I scenario
    bit [`ADDR_WID_LV1-1:0] addr_ei  = 32'hA000_0400; // E→I scenario
    bit [`ADDR_WID_LV1-1:0] addr_es  = 32'hA000_0500; // E→S scenario (same as main test but fresh addr)
    bit [`ADDR_WID_LV1-1:0] addr_si  = 32'hA000_0600; // S→I scenario

    function new(string name = "snoop_seq_chain_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "=== snoop_seq_chain_seq START ===", UVM_LOW)

        // ---------------------------------------------------------------
        // Scenario 1: S → S (repeated bus_rd on SHARED line)
        // Core0 reads addr_ss → I→E
        // Core1 reads addr_ss → Core0 E→S (snoop), Core1 I→S
        // Core2 reads addr_ss → Core0 snoop: S→S, Core1 snoop: S→S
        // Core3 reads addr_ss → Again S→S on all sharing cores
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "S→S: Core0 read addr_ss (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        `uvm_info(get_type_name(), "S→S: Core1 read addr_ss (Core0 E→S snoop)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        `uvm_info(get_type_name(), "S→S: Core2 read addr_ss (Core0,1 snoop S→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })
        `uvm_info(get_type_name(), "S→S: Core3 read addr_ss (Core0,1,2 snoop S→S again)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ss;
        })

        // ---------------------------------------------------------------
        // Scenario 2: M → S (bus_rd on MODIFIED line)
        // Core0 writes addr_ms → I→M
        // Core1 reads  addr_ms → Core0 snoop M→S, Core1 I→S
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "M→S: Core0 write addr_ms (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ms;
        })
        `uvm_info(get_type_name(), "M→S: Core1 read addr_ms (Core0 snoop M→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ms;
        })
        // Do it again on a different core to get another M→S sample
        `uvm_info(get_type_name(), "M→S (again): Core2 write addr_ms, Core3 read", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ms;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ms;
        })

        // ---------------------------------------------------------------
        // Scenario 3: M → I (bus_rdx on MODIFIED line)
        // Core0 writes addr_mi → I→M
        // Core1 writes addr_mi → Core0 snoop M→I (bus_rdx invalidates)
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "M→I: Core0 write addr_mi (I→M)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi;
        })
        `uvm_info(get_type_name(), "M→I: Core1 write addr_mi (Core0 snoop M→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi;
        })
        // And once more with core2→core3
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi;
        })
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_mi;
        })

        // ---------------------------------------------------------------
        // Scenario 4: E → I (bus_rdx on EXCLUSIVE line)
        // Core0 reads  addr_ei → I→E (exclusive, no sharing)
        // Core1 writes addr_ei → Core0 snoop E→I (bus_rdx)
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "E→I: Core0 read addr_ei (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_ei;
        })
        `uvm_info(get_type_name(), "E→I: Core1 write addr_ei (Core0 snoop E→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_ei;
        })

        // ---------------------------------------------------------------
        // Scenario 5: E → S (bus_rd on EXCLUSIVE line)  [re-confirm]
        // Core2 reads addr_es → I→E
        // Core3 reads addr_es → Core2 snoop E→S
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "E→S: Core2 read addr_es (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es;
        })
        `uvm_info(get_type_name(), "E→S: Core3 read addr_es (Core2 snoop E→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[3], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_es;
        })

        // ---------------------------------------------------------------
        // Scenario 6: S → I (bus_rdx / invalidate on SHARED line)
        // Core0+Core1 share addr_si (both SHARED)
        // Core2 writes addr_si → invalidate → Core0,Core1 snoop S→I
        // ---------------------------------------------------------------
        `uvm_info(get_type_name(), "S→I: Core0 read addr_si (I→E)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[0], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si;
        })
        `uvm_info(get_type_name(), "S→I: Core1 read addr_si (E→S)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[1], {
            request_type == READ_REQ; access_cache_type == DCACHE_ACC; address == addr_si;
        })
        `uvm_info(get_type_name(), "S→I: Core2 write addr_si (Core0,Core1 snoop S→I)", UVM_LOW)
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[2], {
            request_type == WRITE_REQ; access_cache_type == DCACHE_ACC; address == addr_si;
        })

        `uvm_info(get_type_name(), "=== snoop_seq_chain_seq DONE ===", UVM_LOW)
    endtask

endclass : snoop_seq_chain_seq


class snoop_seq_chain_test extends base_test;
    `uvm_component_utils(snoop_seq_chain_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                snoop_seq_chain_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing snoop_seq_chain_test", UVM_LOW)
    endtask: run_phase

endclass : snoop_seq_chain_test
