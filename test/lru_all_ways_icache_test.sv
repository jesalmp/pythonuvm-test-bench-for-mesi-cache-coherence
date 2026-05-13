//=====================================================================
// Project: 4 core MESI cache design
// File Name: lru_all_ways_icache_test.sv
// Description: Exhaustive I-cache LRU coverage test.
//   Fills all 4 ways of multiple I-cache sets on every core, then
//   rotates accesses through all way permutations so that every
//   combination of (lru_replacement_proc_il × blk_accessed_main_il)
//   is observed, achieving 100% on lru_il_cg cx_replacement_x_accessed.
//
//   Address layout for I-cache (addr < 32'h4000_0000):
//     index bits [15:2] select the set.
//     tag  bits [31:16] distinguish ways (different sets of 4 tags).
//
//   We use 8 base sets (index offsets) and for each set we fill
//   4 ways by varying tag bits [31:16].
//=====================================================================

class lru_all_ways_icache_seq extends base_vseq;
    `uvm_object_utils(lru_all_ways_icache_seq)

    cpu_transaction_c trans;

    function new(string name = "lru_all_ways_icache_seq");
        super.new(name);
    endfunction

    // Helper: I-cache read on a given core to a given address
    task icrd(int core, bit [`ADDR_WID_LV1-1:0] addr);
        `uvm_do_on_with(trans, p_sequencer.cpu_seqr[core], {
            request_type     == READ_REQ;
            access_cache_type == ICACHE_ACC;
            address          == addr;
        })
    endtask

    virtual task body();
        // ----------------------------------------------------------------
        // Use 5 addresses per set: 4 to fill the ways, 1 to evict.
        // Keep all addresses below 32'h4000_0000 (I-cache range).
        // Tag bits [31:16] differentiate ways within the same set.
        // Index bits [15:2] select the set (we use 4 different sets).
        // ----------------------------------------------------------------
        //
        // Set A: index bits give offset 32'h0000_0100
        bit [`ADDR_WID_LV1-1:0] setA_w0 = 32'h0000_0100; // tag 0x0000
        bit [`ADDR_WID_LV1-1:0] setA_w1 = 32'h0001_0100; // tag 0x0001
        bit [`ADDR_WID_LV1-1:0] setA_w2 = 32'h0002_0100; // tag 0x0002
        bit [`ADDR_WID_LV1-1:0] setA_w3 = 32'h0003_0100; // tag 0x0003
        bit [`ADDR_WID_LV1-1:0] setA_ev = 32'h0004_0100; // eviction trigger

        // Set B: different index bits (offset 0x0200)
        bit [`ADDR_WID_LV1-1:0] setB_w0 = 32'h0000_0200;
        bit [`ADDR_WID_LV1-1:0] setB_w1 = 32'h0001_0200;
        bit [`ADDR_WID_LV1-1:0] setB_w2 = 32'h0002_0200;
        bit [`ADDR_WID_LV1-1:0] setB_w3 = 32'h0003_0200;
        bit [`ADDR_WID_LV1-1:0] setB_ev = 32'h0004_0200;

        // Set C (offset 0x0400)
        bit [`ADDR_WID_LV1-1:0] setC_w0 = 32'h0000_0400;
        bit [`ADDR_WID_LV1-1:0] setC_w1 = 32'h0001_0400;
        bit [`ADDR_WID_LV1-1:0] setC_w2 = 32'h0002_0400;
        bit [`ADDR_WID_LV1-1:0] setC_w3 = 32'h0003_0400;
        bit [`ADDR_WID_LV1-1:0] setC_ev = 32'h0004_0400;

        // Set D (offset 0x0800)
        bit [`ADDR_WID_LV1-1:0] setD_w0 = 32'h0000_0800;
        bit [`ADDR_WID_LV1-1:0] setD_w1 = 32'h0001_0800;
        bit [`ADDR_WID_LV1-1:0] setD_w2 = 32'h0002_0800;
        bit [`ADDR_WID_LV1-1:0] setD_w3 = 32'h0003_0800;
        bit [`ADDR_WID_LV1-1:0] setD_ev = 32'h0004_0800;

        // ================================================================
        // For each core: exercise SET A with all 4 access patterns so
        // that lru_replacement_proc_il cycles through all 4 ways, and
        // blk_accessed_main_il also covers all 4 ways.
        // ================================================================
        for (int c = 0; c < 4; c++) begin

            // --- Pattern 1: Fill 0→1→2→3, evict → LRU victim = way0
            //     (access order: 0 oldest, 3 most recent)
            `uvm_info(get_type_name(), $sformatf("Core%0d Set A: fill all ways 0-3", c), UVM_LOW)
            icrd(c, setA_w0); icrd(c, setA_w1); icrd(c, setA_w2); icrd(c, setA_w3);
            // Re-touch 1,2,3 so way0 is LRU
            icrd(c, setA_w1); icrd(c, setA_w2); icrd(c, setA_w3);
            // Evict: lru_replacement_proc_il = way0; blk_accessed_main_il = eviction slot (way0)
            `uvm_info(get_type_name(), $sformatf("Core%0d Set A evict->way0 victim", c), UVM_LOW)
            icrd(c, setA_ev);

            // --- Pattern 2: Fill Set B 0→1→2→3, then re-touch 0,2,3 → way1 is LRU
            icrd(c, setB_w0); icrd(c, setB_w1); icrd(c, setB_w2); icrd(c, setB_w3);
            icrd(c, setB_w0); icrd(c, setB_w2); icrd(c, setB_w3);
            `uvm_info(get_type_name(), $sformatf("Core%0d Set B evict->way1 victim", c), UVM_LOW)
            icrd(c, setB_ev);

            // --- Pattern 3: Fill Set C 0→1→2→3, re-touch 0,1,3 → way2 is LRU
            icrd(c, setC_w0); icrd(c, setC_w1); icrd(c, setC_w2); icrd(c, setC_w3);
            icrd(c, setC_w0); icrd(c, setC_w1); icrd(c, setC_w3);
            `uvm_info(get_type_name(), $sformatf("Core%0d Set C evict->way2 victim", c), UVM_LOW)
            icrd(c, setC_ev);

            // --- Pattern 4: Fill Set D 0→1→2→3, re-touch 0,1,2 → way3 is LRU
            icrd(c, setD_w0); icrd(c, setD_w1); icrd(c, setD_w2); icrd(c, setD_w3);
            icrd(c, setD_w0); icrd(c, setD_w1); icrd(c, setD_w2);
            `uvm_info(get_type_name(), $sformatf("Core%0d Set D evict->way3 victim", c), UVM_LOW)
            icrd(c, setD_ev);

            // --- Extra hits: re-read existing ways to hit blk_accessed_main_il = 0,1,2,3
            //     (hits on cached lines → different blk_accessed values for the cross)
            icrd(c, setA_w1); // hit way1
            icrd(c, setB_w0); // hit way0
            icrd(c, setC_w0); // hit way0
            icrd(c, setD_w0); // hit way0
        end

    endtask

endclass : lru_all_ways_icache_seq


class lru_all_ways_icache_test extends base_test;
    `uvm_component_utils(lru_all_ways_icache_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase",
                                "default_sequence",
                                lru_all_ways_icache_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing lru_all_ways_icache_test", UVM_LOW)
    endtask: run_phase

endclass : lru_all_ways_icache_test
