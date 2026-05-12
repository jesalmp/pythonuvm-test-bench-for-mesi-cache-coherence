//=====================================================================
// Project: 4 core MESI cache design
// File Name: cpu_lv1_interface.sv
// Description: Basic CPU-LV1 interface with assertions
// Designers: Venky & Suru
//=====================================================================

`define CPU_RD_RESP_TIME    100
`define CPU_WR_RESP_TIME    100

interface cpu_lv1_interface(input clk);

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter DATA_WID_LV1           = `DATA_WID_LV1       ;
    parameter ADDR_WID_LV1           = `ADDR_WID_LV1       ;

    reg   [DATA_WID_LV1 - 1   : 0] data_bus_cpu_lv1_reg = 32'hz ;

    wire  [DATA_WID_LV1 - 1   : 0] data_bus_cpu_lv1        ;
    logic [ADDR_WID_LV1 - 1   : 0] addr_bus_cpu_lv1        ;
    logic                          cpu_rd                  ;
    logic                          cpu_wr                  ;
    logic                          cpu_rden                ;
    logic                          cpu_wren                ;
    logic                          cpu_wr_done             ;
    logic                          data_in_bus_cpu_lv1     ;

    assign data_bus_cpu_lv1 = data_bus_cpu_lv1_reg ;

    // initialization
    initial begin
      cpu_rd   = 1'b0;
      cpu_wr   = 1'b0;
      cpu_rden = 1'b0;
      cpu_wren = 1'b0;
    end

    //Assertions  TO-DO:  ADD MORE!!

    // cpu_wr and cpu_rd should not be asserted at the same clock cycle
    property prop_simult_cpu_wr_rd;
        @(posedge clk)
          not(cpu_rd && cpu_wr);
    endproperty

    assert_simult_cpu_wr_rd: assert property (prop_simult_cpu_wr_rd)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_simult_cpu_wr_rd Failed: cpu_wr and cpu_rd asserted simultaneously"))

    // property that checks that signal_1 is asserted in the previous cycle of signal_2 assertion
    property prop_sig1_before_sig2(signal_1,signal_2);
    @(posedge clk)
        signal_2 |-> $past(signal_1);
    endproperty

    // cpu_wr_done should not be asserted without cpu_wr being asserted in previous cycle
    assert_cpu_wr_done: assert property (prop_sig1_before_sig2(cpu_wr,cpu_wr_done))
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_cpu_wr_done Failed: cpu_wr_done asserted without cpu_wr"))

    // data_in_bus_cpu_lv1 should not be asserted without cpu_rd being asserted in previous cycle
    assert_data_in_bus_cpu_rd: assert property (prop_sig1_before_sig2(cpu_rd,data_in_bus_cpu_lv1))
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_data_in_bus_cpu_rd Failed: data_in_bus_cpu_lv1 asserted without cpu_rd"))

    // property that checks that signal_2 needs to be legal(should not have x's or z's) when signal_1 is asserted
    property prop_legal(signal_1,signal_2);
    @(posedge clk)
        signal_1  |-> not($isunknown(signal_2));
    endproperty

    assert_data_bus_legal: assert property (prop_legal({cpu_wr | data_in_bus_cpu_lv1},data_bus_cpu_lv1))
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_data_bus_legal Failed: data_bus_cpu_lv1 not legal when either cpu_wr or data_in_bus_cpu_lv1 are high"))

    assert_addr_bus_legal: assert property (prop_legal({cpu_rd | cpu_wr},addr_bus_cpu_lv1))
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_addr_bus_legal Failed: addr_bus_cpu_lv1 is not legal value when either cpu_rd or cpu_wr is high"))

    // cpu_rd must stay asserted until data_in_bus_cpu_lv1 response
    property prop_rd_stable_until_response;
        @(posedge clk)
          ($rose(cpu_rd)) |-> (cpu_rd throughout data_in_bus_cpu_lv1[->1]);
    endproperty

    assert_rd_stable_until_response: assert property (prop_rd_stable_until_response)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_rd_stable_until_response Failed: cpu_rd deasserted before data_in_bus_cpu_lv1 response"))

    // cpu_wr must stay asserted until cpu_wr_done response
    property prop_wr_stable_until_done;
        @(posedge clk)
          ($rose(cpu_wr)) |-> (cpu_wr throughout cpu_wr_done[->1]);
    endproperty

    assert_wr_stable_until_done: assert property (prop_wr_stable_until_done)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_wr_stable_until_done Failed: cpu_wr deasserted before cpu_wr_done response"))

    // Address must remain stable throughout a read transaction
    property prop_addr_stable_on_rd;
        @(posedge clk)
          (cpu_rd && !data_in_bus_cpu_lv1 && $past(cpu_rd)) |-> ($stable(addr_bus_cpu_lv1));
    endproperty

    assert_addr_stable_on_rd: assert property (prop_addr_stable_on_rd)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_addr_stable_on_rd Failed: addr_bus_cpu_lv1 changed during pending read"))

    // Address must remain stable throughout a write transaction
    property prop_addr_stable_on_wr;
        @(posedge clk)
          (cpu_wr && !cpu_wr_done && $past(cpu_wr)) |-> ($stable(addr_bus_cpu_lv1));
    endproperty

    assert_addr_stable_on_wr: assert property (prop_addr_stable_on_wr)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_addr_stable_on_wr Failed: addr_bus_cpu_lv1 changed during pending write"))

    // Read transaction must complete within timeout
    property prop_rd_timeout;
        @(posedge clk)
          ($rose(cpu_rd)) |-> ##[1:`CPU_RD_RESP_TIME] data_in_bus_cpu_lv1;
    endproperty

    assert_rd_timeout: assert property (prop_rd_timeout)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_rd_timeout Failed: read did not get response within %0d cycles", `CPU_RD_RESP_TIME))

    // Write transaction must complete within timeout
    property prop_wr_timeout;
        @(posedge clk)
          ($rose(cpu_wr)) |-> ##[1:`CPU_WR_RESP_TIME] cpu_wr_done;
    endproperty

    assert_wr_timeout: assert property (prop_wr_timeout)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_wr_timeout Failed: write did not get cpu_wr_done within %0d cycles", `CPU_WR_RESP_TIME))

    // data_in_bus_cpu_lv1 must not assert when cpu_wr is active (no read response during write)
    property prop_no_rd_resp_during_wr;
        @(posedge clk)
          cpu_wr |-> !data_in_bus_cpu_lv1;
    endproperty

    assert_no_rd_resp_during_wr: assert property (prop_no_rd_resp_during_wr)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_no_rd_resp_during_wr Failed: data_in_bus_cpu_lv1 asserted while cpu_wr is active"))

    // cpu_wr_done must not assert when cpu_rd is active (no write ack during read)
    property prop_no_wr_done_during_rd;
        @(posedge clk)
          cpu_rd |-> !cpu_wr_done;
    endproperty

    assert_no_wr_done_during_rd: assert property (prop_no_wr_done_during_rd)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_no_wr_done_during_rd Failed: cpu_wr_done asserted while cpu_rd is active"))

    // Data bus must be valid (not X/Z) when writing
    property prop_data_valid_on_wr;
        @(posedge clk)
          cpu_wr |-> !$isunknown(data_bus_cpu_lv1);
    endproperty

    assert_data_valid_on_wr: assert property (prop_data_valid_on_wr)
    else
        `uvm_error("cpu_lv1_interface",$sformatf("Assertion assert_data_valid_on_wr Failed: data_bus_cpu_lv1 is unknown during cpu_wr"))

endinterface