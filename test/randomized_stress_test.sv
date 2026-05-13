//=====================================================================
// Project: 4 core MESI cache design
// File Name: randomized_stress_test.sv
// Description: Randomized stress test to aggressively hit cross coverage
//              and remaining code coverage branches.
//=====================================================================

class randomized_stress_test extends base_test;

    `uvm_component_utils(randomized_stress_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        uvm_config_wrapper::set(this, "tb.vsequencer.run_phase", "default_sequence", randomized_stress_seq::type_id::get());
        super.build_phase(phase);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Executing randomized_stress_test" , UVM_LOW)
    endtask: run_phase

endclass : randomized_stress_test


class randomized_stress_seq extends base_vseq;

    `uvm_object_utils(randomized_stress_seq)

    cpu_transaction_c trans;

    function new (string name="randomized_stress_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        int num_trans = 500; // Large number of transactions for stress testing
        int core_id;
        int req_type_int;
        int cache_type_int;
        bit [`ADDR_WID_LV1-1:0] rand_addr;
        
        // Define a small pool of addresses to ensure high contention/sharing
        bit [`ADDR_WID_LV1-1:0] addr_pool [10] = '{
            32'h4000_1000, 32'h4000_1004, 32'h4000_2000, 32'h4000_3000,
            32'h4000_4000, 32'h4001_1000, 32'h4002_1000, 32'h4003_1000,
            32'h4004_1000, 32'h4005_1000
        };

        for (int i = 0; i < num_trans; i++) begin
            core_id = $urandom_range(0, 3);
            req_type_int = $urandom_range(0, 1);
            cache_type_int = $urandom_range(0, 1);
            
            // 80% chance to pick from the contended pool, 20% completely random
            if ($urandom_range(0, 99) < 80) begin
                rand_addr = addr_pool[$urandom_range(0, 9)];
            end else begin
                rand_addr = $urandom();
            end
            
            // Align address to word boundary
            rand_addr = {rand_addr[31:2], 2'b00};
            
            // If I-Cache, force read request and valid address space
            if (cache_type_int == 0) begin // ICACHE_ACC
                req_type_int = 0; // READ_REQ
                rand_addr = {2'b00, rand_addr[29:0]}; // Ensure < 32'h3FFF_FFFF
            end else begin
                rand_addr = {2'b01, rand_addr[29:0]}; // Ensure D-cache range
            end

            `uvm_do_on_with(trans, p_sequencer.cpu_seqr[core_id], {
                request_type == (req_type_int == 0 ? READ_REQ : WRITE_REQ);
                access_cache_type == (cache_type_int == 0 ? ICACHE_ACC : DCACHE_ACC);
                address == rand_addr;
            })
        end
    endtask

endclass : randomized_stress_seq
