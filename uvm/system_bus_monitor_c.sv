//=====================================================================
// Project: 4 core MESI cache design
// File Name: system_bus_monitor_c.sv
// Description: system bus monitor component
// Designers: Venky & Suru
//=====================================================================

`include "sbus_packet_c.sv"

class system_bus_monitor_c extends uvm_monitor;
    //component macro
    `uvm_component_utils(system_bus_monitor_c)

    uvm_analysis_port #(sbus_packet_c) sbus_out;
    sbus_packet_c       s_packet;

    //Covergroup to monitor all the points within sbus_packet
    covergroup cover_sbus_packet;
        option.per_instance = 1;
        option.name = "cover_system_bus";
        REQUEST_TYPE: coverpoint  s_packet.bus_req_type;
        REQUEST_PROCESSOR: coverpoint s_packet.bus_req_proc_num;
        REQUEST_ADDRESS: coverpoint s_packet.req_address{
            option.auto_bin_max = 20;
        }
        SNOOP_REQUEST: coverpoint s_packet.bus_req_snoop{
            ignore_bins illegal_snoop = {4'd15};
        }
        REQUEST_SERVICED_BY: coverpoint s_packet.req_serviced_by{
            ignore_bins illegal_service = {SERV_NONE};
        }
        READ_DATA: coverpoint s_packet.rd_data{
            option.auto_bin_max = 20;
        }
        SNOOP_WRITE_DATA: coverpoint s_packet.wr_data_snoop{
            option.auto_bin_max = 10;
        }
        SNOOP_WRITE_REQUEST: coverpoint s_packet.snoop_wr_req_flag;
        CP_IN_CACHE: coverpoint s_packet.cp_in_cache;
        SHARED: coverpoint s_packet.shared;
        EVICT_DIRTY: coverpoint s_packet.proc_evict_dirty_blk_flag;
        EVICT_DIRTY_DATA: coverpoint s_packet.proc_evict_dirty_blk_data{
            option.auto_bin_max = 10;
        }
        EVICT_DIRTY_ADDR: coverpoint s_packet.proc_evict_dirty_blk_addr{
            //option.auto_bin_max = 10;
	    ignore_bins  NO_EVICT = {32'h00000000};
	    illegal_bins ICACHE   = {[32'h00000001:32'h3fffffff]};
	    bins         DCACHE_0 = {[32'h40000000:32'h5fffffff]};
	    bins         DCACHE_1 = {[32'h60000000:32'h7fffffff]};
	    bins         DCACHE_2 = {[32'h80000000:32'h9fffffff]};
	    bins         DCACHE_3 = {[32'ha0000000:32'hbfffffff]};
	    bins         DCACHE_4 = {[32'hc0000000:32'hdfffffff]};
	    bins         DCACHE_5 = {[32'he0000000:32'hffffffff]};
        }
        //cross coverage

        //ensure each processor has read miss, write miss, invalidate, etc.
        X_PROC__REQ_TYPE: cross REQUEST_TYPE, REQUEST_PROCESSOR;
        X_PROC__ADDRESS: cross REQUEST_PROCESSOR, REQUEST_ADDRESS;
        X_PROC__DATA: cross REQUEST_PROCESSOR, READ_DATA;
        //ensure that every processor is serviced by every other processor/L2
        X_PROC__SNOOP: cross REQUEST_PROCESSOR, REQUEST_SERVICED_BY{
            ignore_bins REQ_IS_SNOOP = X_PROC__SNOOP with (REQUEST_PROCESSOR == REQUEST_SERVICED_BY);
        }
        X_PROC__SNOOP_WR: cross REQUEST_PROCESSOR, SNOOP_WRITE_REQUEST;
        X_SNOOP__WR_REQ: cross REQUEST_SERVICED_BY, SNOOP_WRITE_REQUEST{
            ignore_bins SERVICE_BY_L2 = X_SNOOP__WR_REQ with(REQUEST_SERVICED_BY == SERV_L2);
        }
        X_PROC__CP_IN_CACHE: cross REQUEST_PROCESSOR, CP_IN_CACHE;
        X_PROC__SHARED: cross REQUEST_PROCESSOR, SHARED;
        X_PROC__EVICT: cross REQUEST_PROCESSOR, EVICT_DIRTY;
        X_SNOOP__CP_IN_CACHE: cross REQUEST_SERVICED_BY, CP_IN_CACHE{
            ignore_bins SNOOP_CP_IN_CACHE_LOW = X_SNOOP__CP_IN_CACHE with (REQUEST_SERVICED_BY >= SERV_SNOOP0 && REQUEST_SERVICED_BY <= SERV_SNOOP3 && CP_IN_CACHE == 0);
        }
        X_SNOOP__SHARED: cross REQUEST_SERVICED_BY, SHARED{
            ignore_bins SNOOP_SHARED_LOW = X_SNOOP__SHARED with (REQUEST_SERVICED_BY >= SERV_SNOOP0 && REQUEST_SERVICED_BY <= SERV_SNOOP3 && SHARED == 0);
            ignore_bins SNOOP_L2_SHARED_HIGH = X_SNOOP__SHARED with (REQUEST_SERVICED_BY == SERV_L2 && SHARED == 1);
        }
        X_SNOOP__EVICT: cross REQUEST_SERVICED_BY, EVICT_DIRTY;
    endgroup

    // Virtual interface of used to observe system bus interface signals
    virtual interface system_bus_interface vi_sbus_if;

    //constructor
    function new (string name, uvm_component parent);
        super.new(name, parent);
        sbus_out = new("sbus_out", this);
        this.cover_sbus_packet = new();
    endfunction : new

    //UVM build phase ()
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // throw error if virtual interface is not set
        if (!uvm_config_db#(virtual system_bus_interface)::get(this, "","v_sbus_if", vi_sbus_if))
            `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vi_sbus_if"})
    endfunction: build_phase

    //UVM run phase()
    task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "RUN Phase", UVM_LOW)
        forever begin
            // trigger point for creating the packet
            @(posedge (|vi_sbus_if.bus_lv1_lv2_gnt_proc));

            //wait(|vi_sbus_if.bus_lv1_lv2_gnt_proc);
            `uvm_info(get_type_name(), "Packet creation triggered", UVM_LOW)
            s_packet = sbus_packet_c::type_id::create("s_packet", this);

            // populate the fields of the packet
            fork: check_for_dirty_data_serv_counter
                // start counter
                begin
                    `uvm_info(get_type_name(), "Counter started", UVM_LOW)
                    forever
                    begin
                        @(posedge vi_sbus_if.clk) s_packet.service_time++;
                    end
                end
                // wait and check for dirty data
                begin
                    // dirty block eviction done when a proc has bus grant, but asserts
                    // lv2_wr without driving either of bus_rd,bus_rdx or invalidate to high
                    wait(vi_sbus_if.lv2_wr & !(vi_sbus_if.bus_rd | vi_sbus_if.bus_rdx | vi_sbus_if.invalidate));
                    s_packet.proc_evict_dirty_blk_addr  = vi_sbus_if.addr_bus_lv1_lv2;
                    s_packet.proc_evict_dirty_blk_data  = vi_sbus_if.data_bus_lv1_lv2;
                    s_packet.proc_evict_dirty_blk_flag  = 1'b1;
                end
            join_none: check_for_dirty_data_serv_counter

            // wait for assertion of either bus_rd, bus_rdx or invalidate before monitoring other bus activities
            // lv2_rd for I-cache cases
            @(posedge(vi_sbus_if.bus_rd | vi_sbus_if.bus_rdx | vi_sbus_if.invalidate | vi_sbus_if.lv2_rd));
            fork
                begin: cp_in_cache_check
                    // check for cp_in_cache assertion
                    @(posedge vi_sbus_if.cp_in_cache) s_packet.cp_in_cache = 1;
                end : cp_in_cache_check
                begin: shared_check
                    // check for shared signal assertion when data_in_bus_lv1_lv2 is also high
                    wait(vi_sbus_if.shared & vi_sbus_if.data_in_bus_lv1_lv2) s_packet.shared = 1;
                end : shared_check
            join_none

            // bus request type
            if (vi_sbus_if.bus_rd === 1'b1)
                s_packet.bus_req_type = BUS_RD;
            else if (vi_sbus_if.bus_rdx === 1'b1)
                s_packet.bus_req_type = BUS_RDX;
            else if (vi_sbus_if.invalidate === 1'b1)
                s_packet.bus_req_type = INVALIDATE;
            else if (vi_sbus_if.lv2_rd === 1'b1)
                s_packet.bus_req_type = ICACHE_RD;

            // proc which requested the bus access
            case (1'b1)
                vi_sbus_if.bus_lv1_lv2_gnt_proc[0]: s_packet.bus_req_proc_num = REQ_PROC0;
                vi_sbus_if.bus_lv1_lv2_gnt_proc[1]: s_packet.bus_req_proc_num = REQ_PROC1;
                vi_sbus_if.bus_lv1_lv2_gnt_proc[2]: s_packet.bus_req_proc_num = REQ_PROC2;
                vi_sbus_if.bus_lv1_lv2_gnt_proc[3]: s_packet.bus_req_proc_num = REQ_PROC3;
            endcase

            // address requested
            s_packet.req_address = vi_sbus_if.addr_bus_lv1_lv2;

            // fork and call tasks
            fork: update_info

                // to determine if any snoop requested bus access
                begin: bus_req_snoop
                    @(posedge vi_sbus_if.bus_lv1_lv2_req_snoop[0] or posedge vi_sbus_if.bus_lv1_lv2_req_snoop[1] or posedge vi_sbus_if.bus_lv1_lv2_req_snoop[2] or posedge vi_sbus_if.bus_lv1_lv2_req_snoop[3]);    //ALL cores are identical, therfeore they must generate requests at the same time
                    //capture all the cores that requested for snoop access
                    s_packet.bus_req_snoop = vi_sbus_if.bus_lv1_lv2_req_snoop;

                    @(posedge vi_sbus_if.bus_lv1_lv2_gnt_snoop[0] or posedge vi_sbus_if.bus_lv1_lv2_gnt_snoop[1] or posedge vi_sbus_if.bus_lv1_lv2_gnt_snoop[2] or posedge vi_sbus_if.bus_lv1_lv2_gnt_snoop[3]);

                    `uvm_info(get_type_name(), "Snoop is granted access", UVM_LOW)
                    // check if any snoop requested bus access
                    //case (1'b1)
                    //    vi_sbus_if.bus_lv1_lv2_gnt_snoop[0]: s_packet.bus_req_snoop_num = REQ_SNOOP0;
                    //    vi_sbus_if.bus_lv1_lv2_gnt_snoop[1]: s_packet.bus_req_snoop_num = REQ_SNOOP1;
                    //    vi_sbus_if.bus_lv1_lv2_gnt_snoop[2]: s_packet.bus_req_snoop_num = REQ_SNOOP2;
                    //    vi_sbus_if.bus_lv1_lv2_gnt_snoop[3]: s_packet.bus_req_snoop_num = REQ_SNOOP3;
                    //endcase

                    // update write data by snoop if requested access to change from modify to shared/invalid
                    @(vi_sbus_if.lv2_wr);
                    `uvm_info(get_type_name(), "Snoop wrote some data", UVM_LOW)
                    s_packet.snoop_wr_req_flag = 1'b1;
                    s_packet.wr_data_snoop = vi_sbus_if.data_bus_lv1_lv2;
                end: bus_req_snoop

                // to determine which of snoops or L2 serviced read miss
                begin: req_service_check
                    if ((s_packet.bus_req_type == BUS_RD) || (s_packet.bus_req_type == BUS_RDX) || (s_packet.bus_req_type == ICACHE_RD))
                    begin
                        @(posedge vi_sbus_if.data_in_bus_lv1_lv2);
                        `uvm_info(get_type_name(), "Bus read or bus readX successful", UVM_LOW)
                        @(posedge vi_sbus_if.clk) //wait till next clk pos edge to be in middle of window
                        s_packet.rd_data = vi_sbus_if.data_bus_lv1_lv2;
                        // check which had grant asserted
                        case (1'b1)
                            vi_sbus_if.bus_lv1_lv2_gnt_snoop[0]: s_packet.req_serviced_by = SERV_SNOOP0;
                            vi_sbus_if.bus_lv1_lv2_gnt_snoop[1]: s_packet.req_serviced_by = SERV_SNOOP1;
                            vi_sbus_if.bus_lv1_lv2_gnt_snoop[2]: s_packet.req_serviced_by = SERV_SNOOP2;
                            vi_sbus_if.bus_lv1_lv2_gnt_snoop[3]: s_packet.req_serviced_by = SERV_SNOOP3;
                            vi_sbus_if.bus_lv1_lv2_gnt_lv2     : s_packet.req_serviced_by = SERV_L2;
                        endcase
                    end
                end: req_service_check

            join_none : update_info

            // wait until request is processed and send data
            @(negedge vi_sbus_if.bus_lv1_lv2_req_proc[0] or negedge vi_sbus_if.bus_lv1_lv2_req_proc[1] or negedge vi_sbus_if.bus_lv1_lv2_req_proc[2] or negedge vi_sbus_if.bus_lv1_lv2_req_proc[3]);

            // for I-cache read is serviced by sysbus when lv2_rd is driven low
            if(s_packet.bus_req_type == ICACHE_RD)
                @(negedge(vi_sbus_if.lv2_rd));
            // for D-cache related requests, when either bus_rd, bus_rdx or invalidate goes low => request serviced
            else
                @(negedge(vi_sbus_if.bus_rd | vi_sbus_if.bus_rdx | vi_sbus_if.invalidate));

            `uvm_info(get_type_name(), "Packet to be written", UVM_LOW)

            // disable all spawned child processes from fork
            disable fork;

            // write into scoreboard after population of the packet fields
            sbus_out.write(s_packet);
            cover_sbus_packet.sample();

            //reset service time
            s_packet.service_time = 0;
        end
    endtask : run_phase

endclass : system_bus_monitor_c
