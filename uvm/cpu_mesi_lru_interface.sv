//=====================================================================
// Project: 4 core MESI cache design
// File Name: cpu_mesi_lru_interface.sv
// Description: Basic interface for CPU MESI state and LRU replacement
//              signals of both I/D-cache
// Designers: Venky & Suru
//=====================================================================

interface cpu_mesi_lru_interface(input clk);

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter MESI_WID_LV1  = `MESI_WID_LV1;
    parameter ASSOC_WID_LV1 = `ASSOC_WID_LV1;

    // Proc and Snoop side MESI state for the cache set accessed
    wire [MESI_WID_LV1 - 1 : 0] current_mesi_proc;
    wire [MESI_WID_LV1 - 1 : 0] current_mesi_snoop;
    wire [MESI_WID_LV1 - 1 : 0] updated_mesi_proc;
    wire [MESI_WID_LV1 - 1 : 0] updated_mesi_snoop;

    wire cpu_rd;
    wire cpu_wr;
    wire bus_rd;
    wire bus_rdx;
    wire invalidate;

    wire [ASSOC_WID_LV1 - 1 : 0] lru_replacement_proc_dl;
    wire [ASSOC_WID_LV1 - 1 : 0] lru_replacement_proc_il;

    wire [ASSOC_WID_LV1 - 1 : 0] blk_accessed_main_dl;
    wire [ASSOC_WID_LV1 - 1 : 0] blk_accessed_main_il;

    wire lru_update_dl;
    wire lru_update_il;

    parameter INVALID   = 2'b00;
    parameter SHARED    = 2'b01;
    parameter EXCLUSIVE = 2'b10;
    parameter MODIFIED  = 2'b11;
    
    // ----------------------------------------------------------------
    // MESI proc-side state and transition coverage
    // ----------------------------------------------------------------
    covergroup mesi_proc_state_transition_cg @(posedge clk);
        option.per_instance = 1;

        cp_current_mesi_proc: coverpoint current_mesi_proc {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            bins exclusive = {EXCLUSIVE};
            bins modified  = {MODIFIED};
        }

        cp_updated_mesi_proc: coverpoint updated_mesi_proc {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            bins exclusive = {EXCLUSIVE};
            bins modified  = {MODIFIED};
        }

        cx_proc_transition: cross cp_current_mesi_proc, cp_updated_mesi_proc {
            // Legal proc-side transitions per MESI FSM:
            //   I -> E  (cpu_rd, !shared)
            //   I -> S  (cpu_rd, shared)
            //   I -> M  (cpu_wr)
            //   S -> S  (cpu_rd / idle)
            //   S -> M  (cpu_wr)
            //   E -> E  (cpu_rd / idle)
            //   E -> M  (cpu_wr)
            //   M -> M  (always on proc side)
            //   I -> I  (idle)
            illegal_bins e_to_s = binsof(cp_current_mesi_proc.exclusive) && binsof(cp_updated_mesi_proc.shared);
            illegal_bins e_to_i = binsof(cp_current_mesi_proc.exclusive) && binsof(cp_updated_mesi_proc.invalid);
            illegal_bins m_to_e = binsof(cp_current_mesi_proc.modified)  && binsof(cp_updated_mesi_proc.exclusive);
            illegal_bins m_to_s = binsof(cp_current_mesi_proc.modified)  && binsof(cp_updated_mesi_proc.shared);
            illegal_bins m_to_i = binsof(cp_current_mesi_proc.modified)  && binsof(cp_updated_mesi_proc.invalid);
            illegal_bins s_to_e = binsof(cp_current_mesi_proc.shared)    && binsof(cp_updated_mesi_proc.exclusive);
            illegal_bins s_to_i = binsof(cp_current_mesi_proc.shared)    && binsof(cp_updated_mesi_proc.invalid);
        }

        cp_proc_trigger: coverpoint {cpu_rd, cpu_wr} {
            bins idle     = {2'b00};
            bins read     = {2'b10};
            bins write    = {2'b01};
            illegal_bins simult = {2'b11};
        }

        cx_state_x_trigger: cross cp_current_mesi_proc, cp_proc_trigger {
            ignore_bins idle_combos = binsof(cp_proc_trigger.idle);
        }
    endgroup

    // ----------------------------------------------------------------
    // MESI snoop-side state and transition coverage
    // ----------------------------------------------------------------
    covergroup mesi_snoop_state_transition_cg @(posedge clk);
        option.per_instance = 1;

        cp_current_mesi_snoop: coverpoint current_mesi_snoop {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            bins exclusive = {EXCLUSIVE};
            bins modified  = {MODIFIED};
        }

        cp_updated_mesi_snoop: coverpoint updated_mesi_snoop {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            bins exclusive = {EXCLUSIVE};
            bins modified  = {MODIFIED};
        }

        cx_snoop_transition: cross cp_current_mesi_snoop, cp_updated_mesi_snoop {
            // Legal snoop-side transitions per MESI FSM:
            //   M -> S  (bus_rd)
            //   M -> I  (bus_rdx)
            //   M -> M  (idle)
            //   E -> S  (bus_rd)
            //   E -> I  (bus_rdx)
            //   E -> E  (idle)
            //   S -> I  (bus_rdx / invalidate)
            //   S -> S  (idle)
            //   I -> I  (always)
            illegal_bins i_to_s = binsof(cp_current_mesi_snoop.invalid)  && binsof(cp_updated_mesi_snoop.shared);
            illegal_bins i_to_e = binsof(cp_current_mesi_snoop.invalid)  && binsof(cp_updated_mesi_snoop.exclusive);
            illegal_bins i_to_m = binsof(cp_current_mesi_snoop.invalid)  && binsof(cp_updated_mesi_snoop.modified);
            illegal_bins s_to_e = binsof(cp_current_mesi_snoop.shared)   && binsof(cp_updated_mesi_snoop.exclusive);
            illegal_bins s_to_m = binsof(cp_current_mesi_snoop.shared)   && binsof(cp_updated_mesi_snoop.modified);
            illegal_bins e_to_m = binsof(cp_current_mesi_snoop.exclusive) && binsof(cp_updated_mesi_snoop.modified);
            illegal_bins m_to_e = binsof(cp_current_mesi_snoop.modified)  && binsof(cp_updated_mesi_snoop.exclusive);
        }

        cp_snoop_trigger: coverpoint {bus_rd, bus_rdx, invalidate} {
            bins idle         = {3'b000};
            bins bus_rd_only  = {3'b100};
            bins bus_rdx_only = {3'b010};
            bins inv_only     = {3'b001};
            // Protocol guarantees at most one bus signal is asserted at a time
            illegal_bins simult_rd_rdx  = {3'b110};
            illegal_bins simult_rd_inv  = {3'b101};
            illegal_bins simult_rdx_inv = {3'b011};
            illegal_bins all_three      = {3'b111};
        }

        cx_snoop_state_x_trigger: cross cp_current_mesi_snoop, cp_snoop_trigger {
            ignore_bins idle_combos = binsof(cp_snoop_trigger.idle);
        }
    endgroup

    // ----------------------------------------------------------------
    // Proc-side MESI sequential transition coverage (cycle-to-cycle)
    // ----------------------------------------------------------------
    logic [MESI_WID_LV1 - 1 : 0] prev_mesi_proc;
    logic                         prev_mesi_proc_valid;

    always @(posedge clk) begin
        if (cpu_rd || cpu_wr) begin
            prev_mesi_proc       <= updated_mesi_proc;
            prev_mesi_proc_valid <= 1'b1;
        end
    end

    initial begin
        prev_mesi_proc       = INVALID;
        prev_mesi_proc_valid = 1'b0;
    end

    covergroup mesi_proc_seq_transition_cg @(posedge clk);
        option.per_instance = 1;

        cp_prev_state: coverpoint prev_mesi_proc iff (prev_mesi_proc_valid && (cpu_rd || cpu_wr)) {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            bins exclusive = {EXCLUSIVE};
            bins modified  = {MODIFIED};
        }

        cp_next_state: coverpoint updated_mesi_proc iff (prev_mesi_proc_valid && (cpu_rd || cpu_wr)) {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            bins exclusive = {EXCLUSIVE};
            bins modified  = {MODIFIED};
        }

        cx_seq_transition: cross cp_prev_state, cp_next_state {
            // Structurally impossible proc-side sequential transitions
            ignore_bins e_to_s = binsof(cp_prev_state.exclusive) && binsof(cp_next_state.shared);
            ignore_bins e_to_i = binsof(cp_prev_state.exclusive) && binsof(cp_next_state.invalid);
            ignore_bins m_to_e = binsof(cp_prev_state.modified)  && binsof(cp_next_state.exclusive);
            ignore_bins m_to_s = binsof(cp_prev_state.modified)  && binsof(cp_next_state.shared);
            ignore_bins m_to_i = binsof(cp_prev_state.modified)  && binsof(cp_next_state.invalid);
            ignore_bins s_to_e = binsof(cp_prev_state.shared)    && binsof(cp_next_state.exclusive);
            ignore_bins s_to_i = binsof(cp_prev_state.shared)    && binsof(cp_next_state.invalid);
            // I→I is unreachable: the iff guard requires cpu_rd||cpu_wr; any
            // cpu_rd on INVALID always produces E or S; cpu_wr always produces M.
            ignore_bins i_to_i = binsof(cp_prev_state.invalid)   && binsof(cp_next_state.invalid);
        }
    endgroup

    // ----------------------------------------------------------------
    // Snoop-side MESI sequential transition coverage (cycle-to-cycle)
    // ----------------------------------------------------------------
    logic [MESI_WID_LV1 - 1 : 0] prev_mesi_snoop;
    logic                         prev_mesi_snoop_valid;

    always @(posedge clk) begin
        if (bus_rd || bus_rdx || invalidate) begin
            prev_mesi_snoop       <= updated_mesi_snoop;
            prev_mesi_snoop_valid <= 1'b1;
        end
    end

    initial begin
        prev_mesi_snoop       = INVALID;
        prev_mesi_snoop_valid = 1'b0;
    end

    covergroup mesi_snoop_seq_transition_cg @(posedge clk);
        option.per_instance = 1;

        cp_prev_state: coverpoint prev_mesi_snoop iff (prev_mesi_snoop_valid && (bus_rd || bus_rdx || invalidate)) {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            // prev can never be E or M: updated_mesi_snoop=E/M only when no bus signal fires,
            // but this CG samples only when bus_rd||bus_rdx||invalidate is asserted.
            ignore_bins exclusive = {EXCLUSIVE};
            ignore_bins modified  = {MODIFIED};
        }

        cp_next_state: coverpoint updated_mesi_snoop iff (prev_mesi_snoop_valid && (bus_rd || bus_rdx || invalidate)) {
            bins invalid   = {INVALID};
            bins shared    = {SHARED};
            // updated_mesi_snoop is never E or M during an active bus event:
            // E/M→E/M only in the FSM 'else' branch which requires no bus signal.
            ignore_bins exclusive = {EXCLUSIVE};
            ignore_bins modified  = {MODIFIED};
        }

        cx_seq_transition: cross cp_prev_state, cp_next_state {
            // Structurally impossible snoop-side sequential transitions
            ignore_bins i_to_s = binsof(cp_prev_state.invalid)   && binsof(cp_next_state.shared);
            ignore_bins i_to_e = binsof(cp_prev_state.invalid)   && binsof(cp_next_state.exclusive);
            ignore_bins i_to_m = binsof(cp_prev_state.invalid)   && binsof(cp_next_state.modified);
            ignore_bins s_to_e = binsof(cp_prev_state.shared)    && binsof(cp_next_state.exclusive);
            ignore_bins s_to_m = binsof(cp_prev_state.shared)    && binsof(cp_next_state.modified);
            ignore_bins e_to_m = binsof(cp_prev_state.exclusive) && binsof(cp_next_state.modified);
            ignore_bins m_to_e = binsof(cp_prev_state.modified)  && binsof(cp_next_state.exclusive);
            // E→E snoop seq: a bus_rd hitting an EXCLUSIVE line forces E→S (not E→E).
            // A non-matching snoop does not trigger the iff guard, so E→E is unreachable.
            ignore_bins e_to_e = binsof(cp_prev_state.exclusive) && binsof(cp_next_state.exclusive);
            // E→S and E→I as SEQUENTIAL transitions: for prev_mesi_snoop=E, a previous bus
            // event must have produced updated_mesi_snoop=E. But updated=E only when
            // current=E AND no bus_rd/rdx fires (only invalidate). Invalidate is only issued
            // for SHARED→M upgrades; an EXCLUSIVE line has no sharers, so invalidate never
            // fires on it. Therefore prev can never be EXCLUSIVE. Unreachable.
            ignore_bins e_to_i = binsof(cp_prev_state.exclusive) && binsof(cp_next_state.invalid);
            ignore_bins e_to_s = binsof(cp_prev_state.exclusive) && binsof(cp_next_state.shared);
            // M→S, M→I, M→M: For prev_mesi_snoop=M, a previous bus event must have produced
            // updated_mesi_snoop=M. updated=M only when current=M and only invalidate fires.
            // Invalidate is issued for SHARED→M upgrades; a MODIFIED line has no sharers so
            // invalidate cannot fire on it. Therefore prev can never be MODIFIED. Unreachable.
            ignore_bins m_to_s = binsof(cp_prev_state.modified) && binsof(cp_next_state.shared);
            ignore_bins m_to_i = binsof(cp_prev_state.modified) && binsof(cp_next_state.invalid);
            ignore_bins m_to_m = binsof(cp_prev_state.modified) && binsof(cp_next_state.modified);
        }
    endgroup

    // ----------------------------------------------------------------
    // LRU replacement and access coverage — Data Cache
    // ----------------------------------------------------------------
    covergroup lru_dl_cg @(posedge clk);
        option.per_instance = 1;

        cp_lru_replacement_dl: coverpoint lru_replacement_proc_dl iff (cpu_rd || cpu_wr) {
            bins way_0 = {2'b00};
            bins way_1 = {2'b01};
            bins way_2 = {2'b10};
            bins way_3 = {2'b11};
        }

        cp_blk_accessed_dl: coverpoint blk_accessed_main_dl iff (lru_update_dl) {
            bins way_0 = {2'b00};
            bins way_1 = {2'b01};
            bins way_2 = {2'b10};
            bins way_3 = {2'b11};
        }

        cp_lru_update_dl: coverpoint lru_update_dl {
            bins no_update = {1'b0};
            bins update    = {1'b1};
        }

        cx_replacement_x_accessed: cross cp_lru_replacement_dl, cp_blk_accessed_dl;
    endgroup

    // ----------------------------------------------------------------
    // LRU replacement and access coverage — Instruction Cache
    // ----------------------------------------------------------------
    covergroup lru_il_cg @(posedge clk);
        option.per_instance = 1;

        cp_lru_replacement_il: coverpoint lru_replacement_proc_il iff (cpu_rd) {
            bins way_0 = {2'b00};
            bins way_1 = {2'b01};
            bins way_2 = {2'b10};
            bins way_3 = {2'b11};
        }

        cp_blk_accessed_il: coverpoint blk_accessed_main_il iff (lru_update_il) {
            bins way_0 = {2'b00};
            bins way_1 = {2'b01};
            bins way_2 = {2'b10};
            bins way_3 = {2'b11};
        }

        cp_lru_update_il: coverpoint lru_update_il {
            bins no_update = {1'b0};
            bins update    = {1'b1};
        }

        cx_replacement_x_accessed: cross cp_lru_replacement_il, cp_blk_accessed_il;
    endgroup

    // ----------------------------------------------------------------
    // Construct all covergroups
    // ----------------------------------------------------------------
    mesi_proc_state_transition_cg   mesi_proc_cg_inst   = new();
    mesi_snoop_state_transition_cg  mesi_snoop_cg_inst  = new();
    mesi_proc_seq_transition_cg     mesi_proc_seq_inst  = new();
    mesi_snoop_seq_transition_cg    mesi_snoop_seq_inst = new();
    lru_dl_cg                       lru_dl_cg_inst      = new();
    lru_il_cg                       lru_il_cg_inst      = new();

endinterface
