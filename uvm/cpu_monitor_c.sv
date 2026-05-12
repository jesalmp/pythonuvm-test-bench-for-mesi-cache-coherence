//=====================================================================
// Project: 4 core MESI cache design
// File Name: cpu_monitor_c.sv
// Description: cpu monitor component
// Designers: Venky & Suru
//=====================================================================

class cpu_monitor_c extends uvm_monitor;
    //component macro
    `uvm_component_utils(cpu_monitor_c)
    cpu_mon_packet_c packet;
    uvm_analysis_port #(cpu_mon_packet_c) mon_out;

    // Virtual interface of used to drive and observe CPU-LV1 interface signals
    virtual interface cpu_lv1_interface vi_cpu_lv1_if;
    // Virtual interface for monitor cache snoop/proc side MESI state and LRU replacement way number
    virtual interface cpu_mesi_lru_interface vi_cpu_mesi_lru_if;

    int count_cycles;//integer to keep count of cylces to service a request
    bit count_en;//bit to enable the count

    covergroup cover_cpu_packet;
        option.per_instance = 1;
        option.name = "cover_cpu_packets";
        REQUEST: coverpoint packet.request_type;
        ADDRESS_TYPE: coverpoint packet.addr_type;
        DATA: coverpoint packet.dat{
            option.auto_bin_max = 20;
        }
        ADDRESS: coverpoint packet.address{
            option.auto_bin_max = 20;
        }
        ILLEGAL: coverpoint packet.illegal;
    endgroup

    //constructor
    function new (string name, uvm_component parent);
        super.new(name, parent);
        mon_out = new ("mon_out", this);
        this.cover_cpu_packet = new();
    endfunction : new

    //UVM build phase ()
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // throw error if virtual interface is not set
        if (!uvm_config_db#(virtual cpu_lv1_interface)::get(this, "","vif", vi_cpu_lv1_if))
            `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"})
        if (!uvm_config_db#(virtual cpu_mesi_lru_interface)::get(this, "","v_mesi_lru_if", vi_cpu_mesi_lru_if))
            `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".v_mesi_lru_if"})
    endfunction: build_phase

    //UVM run phase()
    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "RUN Phase", UVM_LOW)
        fork
            count();
        join_none
        forever begin
            @(posedge vi_cpu_lv1_if.cpu_rd or posedge vi_cpu_lv1_if.cpu_wr)
            packet = cpu_mon_packet_c::type_id::create("packet", this);
            count_en = 1;
            count_cycles = 0;
            if(vi_cpu_lv1_if.cpu_rd === 1'b1) begin
                packet.request_type = READ_REQ;
            end else if (vi_cpu_lv1_if.cpu_wr === 1'b1) begin
                packet.request_type = WRITE_REQ;
            end
            packet.address = vi_cpu_lv1_if.addr_bus_cpu_lv1;
            packet.addr_type = (packet.address > `IL_DL_ADDR_BOUND)? DCACHE : ICACHE;
            if(packet.request_type === WRITE_REQ && packet.addr_type === ICACHE) begin
                packet.dat = vi_cpu_lv1_if.data_bus_cpu_lv1;
                packet.illegal = 1;
                count_en = 0;
                mon_out.write(packet);
                cover_cpu_packet.sample();
                continue;
            end
            @(posedge vi_cpu_lv1_if.data_in_bus_cpu_lv1 or posedge vi_cpu_lv1_if.cpu_wr_done)
            @(posedge vi_cpu_lv1_if.clk) //wait till next clk pos edge to be in middle of window
            packet.dat = vi_cpu_lv1_if.data_bus_cpu_lv1;
            count_en = 0;
            @(negedge vi_cpu_lv1_if.cpu_rd or negedge vi_cpu_lv1_if.cpu_wr)
            packet.num_cycles = count_cycles;
            // wait for complete handshake before sending the packet
            @(negedge vi_cpu_lv1_if.data_in_bus_cpu_lv1 or negedge vi_cpu_lv1_if.cpu_wr_done);
            mon_out.write(packet);
            cover_cpu_packet.sample();
        end
    endtask : run_phase

    task count();
        forever begin
            @(posedge vi_cpu_lv1_if.clk)
            if(count_en == 1)
                count_cycles++;
        end
    endtask

endclass : cpu_monitor_c
