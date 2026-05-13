//=====================================================================
// Project: 4 core MESI cache design
// File Name: sbus_packet.sv
// Description: basic pakcet class sent from sbus monitor to scoreboard
// Designers: Venky & Suru
//=====================================================================

typedef enum {BUS_RD, BUS_RDX, INVALIDATE, ICACHE_RD} bus_req_t;
typedef enum int {REQ_PROC0=0, REQ_PROC1=1, REQ_PROC2=2, REQ_PROC3=3} bus_req_proc_t;
//typedef enum int {REQ_SNOOP0=0, REQ_SNOOP1=1, REQ_SNOOP2=2, REQ_SNOOP3=3, REQ_SNOOP_NONE=-1} bus_req_snoop_t;
typedef enum int {SERV_SNOOP0=0, SERV_SNOOP1=1, SERV_SNOOP2=2, SERV_SNOOP3=3, SERV_L2=5, SERV_NONE=-1} serv_by_t;

class sbus_packet_c extends uvm_sequence_item;

    parameter DATA_WID_LV1      = `DATA_WID_LV1;
    parameter ADDR_WID_LV1      = `ADDR_WID_LV1;

    // fields for communication between sys bus monitor and scoreboard
    bus_req_t                   bus_req_type;
    bus_req_proc_t              bus_req_proc_num;
    bit [ADDR_WID_LV1-1 : 0]    req_address;
    //bus_req_snoop_t             bus_req_snoop_num;
    bit[3:0]                    bus_req_snoop; //which processors have requested for snoop access
    serv_by_t                   req_serviced_by;
    //indicates all the processors that can service the request through snoop
    //value of 'b1100 indicates processors 3 and 2 can service the request
    //bit [3:0]                   req_can_be_serviced_by;
    //This is captured by bus_req_snoop. Therefore, redundant field has been removed

    bit [DATA_WID_LV1-1 : 0]    rd_data;
    bit [DATA_WID_LV1-1 : 0]    wr_data_snoop;
    bit                         snoop_wr_req_flag;
    bit                         cp_in_cache;
    bit                         shared;
    int                         service_time;

    // fields related to dirty block eviction
    bit [ADDR_WID_LV1-1 : 0]    proc_evict_dirty_blk_addr;
    bit [DATA_WID_LV1-1 : 0]    proc_evict_dirty_blk_data;
    bit                         proc_evict_dirty_blk_flag;

    // UVM macros for built-in automation
    `uvm_object_utils_begin(sbus_packet_c)
        `uvm_field_enum(bus_req_t, bus_req_type, UVM_ALL_ON)
        `uvm_field_enum(bus_req_proc_t, bus_req_proc_num, UVM_ALL_ON)
        `uvm_field_int(req_address, UVM_ALL_ON)
        //`uvm_field_enum(bus_req_snoop_t, bus_req_snoop_num, UVM_ALL_ON)
        `uvm_field_int(bus_req_snoop, UVM_NOCOMPARE)
        `uvm_field_enum(serv_by_t, req_serviced_by, UVM_NOCOMPARE)
        `uvm_field_int(rd_data, UVM_ALL_ON)
        `uvm_field_int(wr_data_snoop, UVM_ALL_ON)
        `uvm_field_int(snoop_wr_req_flag, UVM_ALL_ON)
        `uvm_field_int(cp_in_cache, UVM_ALL_ON)
        `uvm_field_int(shared, UVM_ALL_ON)
        `uvm_field_int(service_time, UVM_NOCOMPARE)
        `uvm_field_int(proc_evict_dirty_blk_addr, UVM_ALL_ON)
        `uvm_field_int(proc_evict_dirty_blk_data, UVM_ALL_ON)
        `uvm_field_int(proc_evict_dirty_blk_flag, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constructor
    function new (string name = "sbus_packet_c");
        super.new(name);

        this.bus_req_type           = BUS_RD;
        this.bus_req_proc_num       = REQ_PROC0;
        this.req_address            = {ADDR_WID_LV1{1'b0}};
        //this.bus_req_snoop_num      = REQ_SNOOP_NONE;
        this.bus_req_snoop          = 4'h0;
        this.req_serviced_by        = SERV_NONE;
        this.rd_data                = {DATA_WID_LV1{1'b0}};
        this.wr_data_snoop          = {DATA_WID_LV1{1'b0}};
        this.snoop_wr_req_flag      = 1'b0;
        this.service_time           = 0;
        this.cp_in_cache            = 1'b0;
        this.shared                 = 1'b0;
        this.proc_evict_dirty_blk_addr = {ADDR_WID_LV1{1'b0}};
        this.proc_evict_dirty_blk_data    = {DATA_WID_LV1{1'b0}};
        this.proc_evict_dirty_blk_flag = 1'b0;

    endfunction : new

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        sbus_packet_c rec;
        bit eq;
        int i;
        if(!$cast(rec, rhs)) `uvm_fatal("sbus_packet_c", "ILLEGAL do_compare() cast")
        eq = super.do_compare(rhs, comparer);
        if (this.req_serviced_by == SERV_NONE) begin
            i = rec.req_serviced_by;
            if(i == SERV_NONE) begin
                eq &= (this.bus_req_snoop == 4'h0);
                if(!eq)
                    `uvm_error(get_type_name(), $sformatf("Request is can be serviced by snoop processor, but it is not done"))
            end else if (i>=0 && i<=3) begin
                eq &= (this.bus_req_snoop[i] == 1'b1);
                if(!eq)
                    `uvm_error(get_type_name(), $sformatf("Request cannot be serviced by this snoop processor"))
            end else begin
                `uvm_error(get_type_name(), $sformatf("Request is serviced by Level2. This is not Expected"))
                return 0;
            end
        end else begin
            eq &= (this.req_serviced_by == rec.req_serviced_by);
            if(!eq)
                `uvm_error(get_type_name(), $sformatf("Request is not serviced by expected block on system bus"))
        end
        return(eq);
    endfunction

endclass : sbus_packet_c

