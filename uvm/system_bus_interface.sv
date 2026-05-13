//=====================================================================
// Project: 4 core MESI cache design
// File Name: system_bus_interface.sv
// Description: Basic system bus interface including arbiter
// Designers: Venky & Suru
//=====================================================================

`define LV2_WR_RESP_TIME        10
`define BUS_RD_RDX_RESP_TIME    15
`define INVALID_RESP_TIME       1

interface system_bus_interface(input clk);

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter DATA_WID_LV1        = `DATA_WID_LV1       ;
    parameter ADDR_WID_LV1        = `ADDR_WID_LV1       ;
`ifdef ONE_CORE // check this def
    parameter NUM_CORE            = 1;
`elsif DUAL_CORE // ONE_CORE
    parameter NUM_CORE            = 2;
`else // TWO_CORE
    parameter NUM_CORE            = 4;
`endif // FOUR_CORE


    wire [DATA_WID_LV1 - 1 : 0] data_bus_lv1_lv2     ;
    wire [ADDR_WID_LV1 - 1 : 0] addr_bus_lv1_lv2     ;
    wire                        bus_rd               ;
    wire                        bus_rdx              ;
    wire                        lv2_rd               ;
    wire                        lv2_wr               ;
    wire                        lv2_wr_done          ;
    wire                        cp_in_cache          ;
    wire                        data_in_bus_lv1_lv2  ;

    wire                        shared               ;
    wire                        all_invalidation_done;
    wire                        invalidate           ;

    logic [NUM_CORE - 1  : 0]   bus_lv1_lv2_gnt_proc ;
    logic [NUM_CORE - 1  : 0]   bus_lv1_lv2_req_proc ;
    logic [NUM_CORE - 1  : 0]   bus_lv1_lv2_gnt_snoop;
    logic [NUM_CORE - 1  : 0]   bus_lv1_lv2_req_snoop;
    logic                       bus_lv1_lv2_gnt_lv2  ;
    logic                       bus_lv1_lv2_req_lv2  ;

//Assertions  TO-DO: ADD MORE!!

    //property that checks that signal_1 is asserted in the previous cycle of signal_2 assertion
    property prop_sig1_before_sig2(signal_1,signal_2);
    @(posedge clk)
        signal_2 |-> $past(signal_1);
    endproperty

    // A5: lv2_wr_done should only happen when there is an L2 write in progress or just happened
    property prop_lv2_wr_done_requires_wr;
        @(posedge clk)
        lv2_wr_done |-> lv2_wr || $past(lv2_wr);
    endproperty
    assert_lv2_wr_done: assert property (prop_lv2_wr_done_requires_wr)
    else
        `uvm_error("system_bus_interface",$sformatf("Assertion assert_lv2_wr_done Failed: lv2_wr_done asserted without lv2_wr"))

    // A6: data_in_bus_lv1_lv2 should not appear without a related read request
    property prop_data_in_bus_requires_rd;
        @(posedge clk)
        data_in_bus_lv1_lv2 |-> $past(lv2_rd) || $past(bus_rd) || $past(bus_rdx);
    endproperty
    assert_data_in_bus_requires_rd: assert property (prop_data_in_bus_requires_rd)
    else
        `uvm_error("system_bus_interface",$sformatf("Assertion assert_data_in_bus_requires_rd Failed: data_in_bus_lv1_lv2 asserted without prior read request"))

    // A7: cp_in_cache should only be asserted after a bus read-type request
    property prop_cp_in_cache_requires_bus_rd;
        @(posedge clk)
        cp_in_cache |-> $past(bus_rd) || $past(bus_rdx);
    endproperty
    assert_cp_in_cache_requires_bus_rd: assert property (prop_cp_in_cache_requires_bus_rd)
    else
        `uvm_error("system_bus_interface",$sformatf("Assertion assert_cp_in_cache_requires_bus_rd Failed: cp_in_cache asserted without prior bus_rd or bus_rdx"))

    // Proc side: gnt should not be asserted without corresponding req
    generate
        for (genvar i = 0; i < NUM_CORE; i++)
        begin : assert_proc_req_before_gnt
            assert property (prop_sig1_before_sig2(bus_lv1_lv2_req_proc[i],bus_lv1_lv2_gnt_proc[i]))
            else
            `uvm_error("system_bus_interface",$sformatf("Assertion assert_proc_req_before_gnt Failed: proc_req not asserted before proc_gnt goes high"))
        end
    endgenerate

    // Snoop side: gnt should not be asserted without corresponding req
    generate
        for (genvar i = 0; i < NUM_CORE; i++)
        begin : assert_snoop_req_before_gnt
            assert property (prop_sig1_before_sig2(bus_lv1_lv2_req_snoop[i],bus_lv1_lv2_gnt_snoop[i]))
            else
            `uvm_error("system_bus_interface",$sformatf("Assertion assert_snoop_req_before_gnt Failed: snoop_req not asserted before snoop_gnt goes high"))
        end
    endgenerate

    // Lv2: gnt should not be asserted without corresponding req for proc side
    assert_lv2_req_before_gnt: assert property (prop_sig1_before_sig2(bus_lv1_lv2_req_lv2,bus_lv1_lv2_gnt_lv2))
    else
        `uvm_error("system_bus_interface",$sformatf("Assertion assert_lv2_req_before_gnt Failed: lv2_req not asserted before lv2_gnt goes high"))

    // A8: only one processor-side grant should be active at a time
    property prop_onehot0_proc_gnt;
        @(posedge clk)
        $onehot0(bus_lv1_lv2_gnt_proc);
    endproperty
    assert_onehot0_proc_gnt: assert property (prop_onehot0_proc_gnt)
    else
        `uvm_error("system_bus_interface",$sformatf("Assertion assert_onehot0_proc_gnt Failed: multiple processor grants active simultaneously"))

    // A9: only one snoop-side grant should be active at a time
    property prop_onehot0_snoop_gnt;
        @(posedge clk)
        $onehot0(bus_lv1_lv2_gnt_snoop);
    endproperty
    assert_onehot0_snoop_gnt: assert property (prop_onehot0_snoop_gnt)
    else
        `uvm_error("system_bus_interface",$sformatf("Assertion assert_onehot0_snoop_gnt Failed: multiple snoop grants active simultaneously"))

endinterface
