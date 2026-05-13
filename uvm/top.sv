//=====================================================================
// Project: 4 core MESI cache design
// File Name: top.sv
// Description: testbench for cache top with environment
// Designers: Venky & Suru
//=====================================================================
// Notable Change History:
// Date By   Version Change Description
// 2016/12/01  1.0     Initial Release
// 2016/12/02  2.0     Added CPU MESI and LRU interface
//=====================================================================

`ifdef ONE_CORE
    `define INST_TOP_CORE inst_cache_lv1_onecore
`elsif DUAL_CORE // ONE_CORE
    `define INST_TOP_CORE inst_cache_lv1_dualcore
    `define DUAL_or_MULTI_CORE
`else // TWO_CORE
    `define INST_TOP_CORE inst_cache_lv1_multicore
    `define DUAL_or_MULTI_CORE
    `define MULTI_CORE
`endif // FOUR_CORE

module top;

//Import the UVM library
    import uvm_pkg::*;
//Include the UVM macros
    `include "uvm_macros.svh"
    
    // import the CPU package
    import cpu_pkg::*;

    //include the environment
    `include "env.sv"

    // include the test library
    `include "test_lib.svh"
    
    parameter DATA_WID_LV1           = `DATA_WID_LV1       ;
    parameter ADDR_WID_LV1           = `ADDR_WID_LV1       ;
    parameter DATA_WID_LV2           = `DATA_WID_LV2       ;
    parameter ADDR_WID_LV2           = `ADDR_WID_LV2       ;

    reg                           clk;
    reg                           resetn;
    reg                           lv2_rd;
    reg                           lv2_rd_reg;
    reg                           lv2_rd_ps;
    reg                           lv2_rd_px;
    reg                           lv2_rd_pe;
    reg                           lv2_wr;
    reg                           lv2_wr_reg;
    reg                           lv2_wren;
    reg                           cp_in_cache;
    reg                           cp_in_cache_reg;
    reg                           cp_in_cacheen;
    wire [DATA_WID_LV2 - 1   : 0] data_bus_lv2_mem;
    wire [ADDR_WID_LV2 - 1   : 0] addr_bus_lv2_mem;
    wire                          data_in_bus_lv2_mem;
    wire                          mem_rd;
    wire                          mem_wr;
    wire                          mem_wr_done;

    wire [3:0]                    cpu_lv1_if_cpu_rd;
    wire [3:0]                    cpu_lv1_if_cpu_wr;
    wire [3:0]                    cpu_lv1_if_cpu_rden;
    wire [3:0]                    cpu_lv1_if_cpu_wren;
    wire [3:0]                    cpu_lv1_if_cpu_wr_done;
    wire [3:0]                    cpu_lv1_if_data_in_bus_cpu_lv1;

    // Instantiate the interfaces
    cpu_lv1_interface       inst_cpu_lv1_if[0:3](clk);
    system_bus_interface    inst_system_bus_if(clk);
    cpu_mesi_lru_interface  inst_cpu_mesi_lru_if[0:3](clk);
    cpu_apb_interface       inst_cpu_apb_if[0:3](clk);
    lv2_apb_interface       inst_lv2_apb_if(clk);

    // Assign internal signals of the System Bus interface
    assign inst_system_bus_if.data_bus_lv1_lv2      = inst_cache_top.data_bus_lv1_lv2;
    assign inst_system_bus_if.addr_bus_lv1_lv2      = inst_cache_top.addr_bus_lv1_lv2;
    assign inst_system_bus_if.data_in_bus_lv1_lv2   = inst_cache_top.data_in_bus_lv1_lv2;
    assign inst_system_bus_if.lv2_rd                = inst_cache_top.lv2_rd;
    assign inst_system_bus_if.lv2_wr                = inst_cache_top.lv2_wr;
    assign inst_system_bus_if.lv2_wr_done           = inst_cache_top.lv2_wr_done;
    assign inst_system_bus_if.cp_in_cache           = inst_cache_top.cp_in_cache;
    assign inst_system_bus_if.shared                = inst_cache_top.`INST_TOP_CORE.shared;
    assign inst_system_bus_if.all_invalidation_done = inst_cache_top.`INST_TOP_CORE.all_invalidation_done;
    assign inst_system_bus_if.invalidate            = inst_cache_top.`INST_TOP_CORE.invalidate;
    assign inst_system_bus_if.bus_rd                = inst_cache_top.`INST_TOP_CORE.bus_rd;
    assign inst_system_bus_if.bus_rdx               = inst_cache_top.`INST_TOP_CORE.bus_rdx;

    // Assign internal signals of the LV2 APB interface
    assign inst_lv2_apb_if.presetn      = inst_cache_top.presetn;
    assign inst_lv2_apb_if.paddr        = inst_cache_top.paddr;
    assign inst_lv2_apb_if.psel         = inst_cache_top.psel;
    assign inst_lv2_apb_if.penable      = inst_cache_top.penable;
    assign inst_lv2_apb_if.pwrite       = inst_cache_top.pwrite;
    assign inst_lv2_apb_if.pwdata       = inst_cache_top.pwdata;
    assign inst_lv2_apb_if.pready       = inst_cache_top.pready;
    assign inst_lv2_apb_if.prdata       = inst_cache_top.prdata;
    assign inst_lv2_apb_if.pslverr      = inst_cache_top.pslverr;

    // Assign internal signals of the Cache MESI state and LRU interface and APB interface for CPU0
    // Assign internal signals of the CPU0 MESI and LRU interface
    assign inst_cpu_mesi_lru_if[0].current_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_proc;
    assign inst_cpu_mesi_lru_if[0].current_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_snoop;
    assign inst_cpu_mesi_lru_if[0].updated_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_proc;
    assign inst_cpu_mesi_lru_if[0].updated_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_snoop;
    assign inst_cpu_mesi_lru_if[0].cpu_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_rd;
    assign inst_cpu_mesi_lru_if[0].cpu_wr                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_wr;
    assign inst_cpu_mesi_lru_if[0].bus_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rd;
    assign inst_cpu_mesi_lru_if[0].bus_rdx                 = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rdx;
    assign inst_cpu_mesi_lru_if[0].invalidate              = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.invalidate;
    assign inst_cpu_mesi_lru_if[0].lru_replacement_proc_dl = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[0].lru_replacement_proc_il = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[0].blk_accessed_main_dl    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[0].blk_accessed_main_il    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[0].lru_update_dl           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_update;
    assign inst_cpu_mesi_lru_if[0].lru_update_il           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_0.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_update;
    // Assign internal signals of the CPU0 APB interface
    assign inst_cpu_apb_if[0].presetn      = inst_cache_top.`INST_TOP_CORE.presetn;
    assign inst_cpu_apb_if[0].paddr        = inst_cache_top.`INST_TOP_CORE.paddr_0;
    assign inst_cpu_apb_if[0].psel         = inst_cache_top.`INST_TOP_CORE.psel[0];
    assign inst_cpu_apb_if[0].penable      = inst_cache_top.`INST_TOP_CORE.penable[0];
    assign inst_cpu_apb_if[0].pwrite       = inst_cache_top.`INST_TOP_CORE.pwrite[0];
    assign inst_cpu_apb_if[0].pwdata       = inst_cache_top.`INST_TOP_CORE.pwdata_0;
    assign inst_cpu_apb_if[0].pready       = inst_cache_top.`INST_TOP_CORE.pready[0];
    assign inst_cpu_apb_if[0].prdata       = inst_cache_top.`INST_TOP_CORE.prdata_0;
    assign inst_cpu_apb_if[0].pslverr      = inst_cache_top.`INST_TOP_CORE.pslverr[0];

`ifdef DUAL_or_MULTI_CORE
    // Assign internal signals of the Cache MESI state and LRU interface and APB interface for CPU1
    // Assign internal signals of the CPU1 MESI and LRU interface
    assign inst_cpu_mesi_lru_if[1].current_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_proc;
    assign inst_cpu_mesi_lru_if[1].current_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_snoop;
    assign inst_cpu_mesi_lru_if[1].updated_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_proc;
    assign inst_cpu_mesi_lru_if[1].updated_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_snoop;
    assign inst_cpu_mesi_lru_if[1].cpu_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_rd;
    assign inst_cpu_mesi_lru_if[1].cpu_wr                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_wr;
    assign inst_cpu_mesi_lru_if[1].bus_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rd;
    assign inst_cpu_mesi_lru_if[1].bus_rdx                 = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rdx;
    assign inst_cpu_mesi_lru_if[1].invalidate              = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.invalidate;
    assign inst_cpu_mesi_lru_if[1].lru_replacement_proc_dl = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[1].lru_replacement_proc_il = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[1].blk_accessed_main_dl    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[1].blk_accessed_main_il    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[1].lru_update_dl           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_update;
    assign inst_cpu_mesi_lru_if[1].lru_update_il           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_1.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_update;
    // Assign internal signals of the CPU1 APB interface
    assign inst_cpu_apb_if[1].presetn      = inst_cache_top.`INST_TOP_CORE.presetn;
    assign inst_cpu_apb_if[1].paddr        = inst_cache_top.`INST_TOP_CORE.paddr_1;
    assign inst_cpu_apb_if[1].psel         = inst_cache_top.`INST_TOP_CORE.psel[1];
    assign inst_cpu_apb_if[1].penable      = inst_cache_top.`INST_TOP_CORE.penable[1];
    assign inst_cpu_apb_if[1].pwrite       = inst_cache_top.`INST_TOP_CORE.pwrite[1];
    assign inst_cpu_apb_if[1].pwdata       = inst_cache_top.`INST_TOP_CORE.pwdata_1;
    assign inst_cpu_apb_if[1].pready       = inst_cache_top.`INST_TOP_CORE.pready[1];
    assign inst_cpu_apb_if[1].prdata       = inst_cache_top.`INST_TOP_CORE.prdata_1;
    assign inst_cpu_apb_if[1].pslverr      = inst_cache_top.`INST_TOP_CORE.pslverr[1];
`endif

`ifdef MULTI_CORE
    // Assign internal signals of the Cache MESI state and LRU interface and APB interface for CPU2
    // Assign internal signals of the CPU2 MESI and LRU interface
    assign inst_cpu_mesi_lru_if[2].current_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_proc;
    assign inst_cpu_mesi_lru_if[2].current_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_snoop;
    assign inst_cpu_mesi_lru_if[2].updated_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_proc;
    assign inst_cpu_mesi_lru_if[2].updated_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_snoop;
    assign inst_cpu_mesi_lru_if[2].cpu_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_rd;
    assign inst_cpu_mesi_lru_if[2].cpu_wr                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_wr;
    assign inst_cpu_mesi_lru_if[2].bus_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rd;
    assign inst_cpu_mesi_lru_if[2].bus_rdx                 = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rdx;
    assign inst_cpu_mesi_lru_if[2].invalidate              = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.invalidate;
    assign inst_cpu_mesi_lru_if[2].lru_replacement_proc_dl = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[2].lru_replacement_proc_il = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[2].blk_accessed_main_dl    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[2].blk_accessed_main_il    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[2].lru_update_dl           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_update;
    assign inst_cpu_mesi_lru_if[2].lru_update_il           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_2.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_update;
    // Assign internal signals of the CPU2 APB interface
    assign inst_cpu_apb_if[2].presetn      = inst_cache_top.`INST_TOP_CORE.presetn;
    assign inst_cpu_apb_if[2].paddr        = inst_cache_top.`INST_TOP_CORE.paddr_2;
    assign inst_cpu_apb_if[2].psel         = inst_cache_top.`INST_TOP_CORE.psel[2];
    assign inst_cpu_apb_if[2].penable      = inst_cache_top.`INST_TOP_CORE.penable[2];
    assign inst_cpu_apb_if[2].pwrite       = inst_cache_top.`INST_TOP_CORE.pwrite[2];
    assign inst_cpu_apb_if[2].pwdata       = inst_cache_top.`INST_TOP_CORE.pwdata_2;
    assign inst_cpu_apb_if[2].pready       = inst_cache_top.`INST_TOP_CORE.pready[2];
    assign inst_cpu_apb_if[2].prdata       = inst_cache_top.`INST_TOP_CORE.prdata_2;
    assign inst_cpu_apb_if[2].pslverr      = inst_cache_top.`INST_TOP_CORE.pslverr[2];

    // Cache MESI state and LRU interface and APB interface for CPU3
    // Assign internal signals of the CPU3 MESI and LRU interface
    assign inst_cpu_mesi_lru_if[3].current_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_proc;
    assign inst_cpu_mesi_lru_if[3].current_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.current_mesi_snoop;
    assign inst_cpu_mesi_lru_if[3].updated_mesi_proc       = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_proc;
    assign inst_cpu_mesi_lru_if[3].updated_mesi_snoop      = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.updated_mesi_snoop;
    assign inst_cpu_mesi_lru_if[3].cpu_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_rd;
    assign inst_cpu_mesi_lru_if[3].cpu_wr                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.cpu_wr;
    assign inst_cpu_mesi_lru_if[3].bus_rd                  = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rd;
    assign inst_cpu_mesi_lru_if[3].bus_rdx                 = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.bus_rdx;
    assign inst_cpu_mesi_lru_if[3].invalidate              = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_block_lv1_dl.invalidate;
    assign inst_cpu_mesi_lru_if[3].lru_replacement_proc_dl = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[3].lru_replacement_proc_il = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_replacement_proc;
    assign inst_cpu_mesi_lru_if[3].blk_accessed_main_dl    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[3].blk_accessed_main_il    = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.blk_accessed_main;
    assign inst_cpu_mesi_lru_if[3].lru_update_dl           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_dl.inst_cache_controller_lv1_dl.inst_lru_block_lv1.lru_update;
    assign inst_cpu_mesi_lru_if[3].lru_update_il           = inst_cache_top.`INST_TOP_CORE.inst_cache_lv1_unicore_3.inst_cache_wrapper_lv1_il.inst_cache_controller_lv1_il.inst_lru_block_lv1.lru_update;
    // Assign internal signals of the CPU3 APB interface
    assign inst_cpu_apb_if[3].presetn      = inst_cache_top.`INST_TOP_CORE.presetn;
    assign inst_cpu_apb_if[3].paddr        = inst_cache_top.`INST_TOP_CORE.paddr_3;
    assign inst_cpu_apb_if[3].psel         = inst_cache_top.`INST_TOP_CORE.psel[3];
    assign inst_cpu_apb_if[3].penable      = inst_cache_top.`INST_TOP_CORE.penable[3];
    assign inst_cpu_apb_if[3].pwrite       = inst_cache_top.`INST_TOP_CORE.pwrite[3];
    assign inst_cpu_apb_if[3].pwdata       = inst_cache_top.`INST_TOP_CORE.pwdata_3;
    assign inst_cpu_apb_if[3].pready       = inst_cache_top.`INST_TOP_CORE.pready[3];
    assign inst_cpu_apb_if[3].prdata       = inst_cache_top.`INST_TOP_CORE.prdata_3;
    assign inst_cpu_apb_if[3].pslverr      = inst_cache_top.`INST_TOP_CORE.pslverr[3];
`endif


    // instantiate memory golden model
    memory #(
            .DATA_WID(DATA_WID_LV2),
            .ADDR_WID(ADDR_WID_LV2)
            )
             inst_memory (
                            .clk                (clk                ),
                            .data_bus_lv2_mem   (data_bus_lv2_mem   ),
                            .addr_bus_lv2_mem   (addr_bus_lv2_mem   ),
                            .mem_rd             (mem_rd             ),
                            .mem_wr             (mem_wr             ),
                            .mem_wr_done        (mem_wr_done        ),
                            .data_in_bus_lv2_mem(data_in_bus_lv2_mem)
                         );


    // instantiate arbiter golden model
    lrs_arbiter  inst_arbiter (
                                    .clk(clk),
                                    .bus_lv1_lv2_gnt_proc (inst_system_bus_if.bus_lv1_lv2_gnt_proc ),
                                    .bus_lv1_lv2_req_proc (inst_system_bus_if.bus_lv1_lv2_req_proc ),
                                    .bus_lv1_lv2_gnt_snoop(inst_system_bus_if.bus_lv1_lv2_gnt_snoop),
                                    .bus_lv1_lv2_req_snoop(inst_system_bus_if.bus_lv1_lv2_req_snoop),
                                    .bus_lv1_lv2_gnt_lv2  (inst_system_bus_if.bus_lv1_lv2_gnt_lv2  ),
                                    .bus_lv1_lv2_req_lv2  (inst_system_bus_if.bus_lv1_lv2_req_lv2  )
                               );


    assign cpu_lv1_if_cpu_rd                = {inst_cpu_lv1_if[3].cpu_rd,inst_cpu_lv1_if[2].cpu_rd,
                                               inst_cpu_lv1_if[1].cpu_rd,inst_cpu_lv1_if[0].cpu_rd};
    assign cpu_lv1_if_cpu_wr                = {inst_cpu_lv1_if[3].cpu_wr,inst_cpu_lv1_if[2].cpu_wr,
                                               inst_cpu_lv1_if[1].cpu_wr,inst_cpu_lv1_if[0].cpu_wr};
    assign cpu_lv1_if_cpu_rden              = {inst_cpu_lv1_if[3].cpu_rden,inst_cpu_lv1_if[2].cpu_rden,
                                               inst_cpu_lv1_if[1].cpu_rden,inst_cpu_lv1_if[0].cpu_rden};
    assign cpu_lv1_if_cpu_wren              = {inst_cpu_lv1_if[3].cpu_wren,inst_cpu_lv1_if[2].cpu_wren,
                                               inst_cpu_lv1_if[1].cpu_wren,inst_cpu_lv1_if[0].cpu_wren};

    assign {inst_cpu_lv1_if[3].cpu_wr_done,inst_cpu_lv1_if[2].cpu_wr_done,inst_cpu_lv1_if[1].cpu_wr_done,inst_cpu_lv1_if[0].cpu_wr_done} = cpu_lv1_if_cpu_wr_done;

    assign {inst_cpu_lv1_if[3].data_in_bus_cpu_lv1,inst_cpu_lv1_if[2].data_in_bus_cpu_lv1,inst_cpu_lv1_if[1].data_in_bus_cpu_lv1,inst_cpu_lv1_if[0].data_in_bus_cpu_lv1} = cpu_lv1_if_data_in_bus_cpu_lv1;


    // instantiate DUT (L1 and L2)
    cache_top inst_cache_top (
                                .clk(clk),
                                .resetn(resetn),
                                .lv2_rd_ps(lv2_rd_ps),
                                .lv2_rd_pe(lv2_rd_pe),
                                .lv2_wren(lv2_wren),
                                .cp_in_cacheen(cp_in_cacheen),
                                .data_bus_cpu_lv1_0     (inst_cpu_lv1_if[0].data_bus_cpu_lv1              ),
                                .addr_bus_cpu_lv1_0     (inst_cpu_lv1_if[0].addr_bus_cpu_lv1              ),
                                .data_bus_cpu_lv1_1     (inst_cpu_lv1_if[1].data_bus_cpu_lv1              ),
                                .addr_bus_cpu_lv1_1     (inst_cpu_lv1_if[1].addr_bus_cpu_lv1              ),
                                .data_bus_cpu_lv1_2     (inst_cpu_lv1_if[2].data_bus_cpu_lv1              ),
                                .addr_bus_cpu_lv1_2     (inst_cpu_lv1_if[2].addr_bus_cpu_lv1              ),
                                .data_bus_cpu_lv1_3     (inst_cpu_lv1_if[3].data_bus_cpu_lv1              ),
                                .addr_bus_cpu_lv1_3     (inst_cpu_lv1_if[3].addr_bus_cpu_lv1              ),
                                .cpu_rd                 (cpu_lv1_if_cpu_rd                          ),
                                .cpu_wr                 (cpu_lv1_if_cpu_wr                          ),
                                .cpu_rden               (cpu_lv1_if_cpu_rden                        ),
                                .cpu_wren               (cpu_lv1_if_cpu_wren                        ),
                                .cpu_wr_done            (cpu_lv1_if_cpu_wr_done                     ),
                                .bus_lv1_lv2_gnt_proc   (inst_system_bus_if.bus_lv1_lv2_gnt_proc    ),
                                .bus_lv1_lv2_req_proc   (inst_system_bus_if.bus_lv1_lv2_req_proc    ),
                                .bus_lv1_lv2_gnt_snoop  (inst_system_bus_if.bus_lv1_lv2_gnt_snoop   ),
                                .bus_lv1_lv2_req_snoop  (inst_system_bus_if.bus_lv1_lv2_req_snoop   ),
                                .data_in_bus_cpu_lv1    (cpu_lv1_if_data_in_bus_cpu_lv1             ),
                                .data_bus_lv2_mem       (data_bus_lv2_mem                           ),
                                .addr_bus_lv2_mem       (addr_bus_lv2_mem                           ),
                                .mem_rd                 (mem_rd                                     ),
                                .mem_wr                 (mem_wr                                     ),
                                .mem_wr_done            (mem_wr_done                                ),
                                .bus_lv1_lv2_gnt_lv2    (inst_system_bus_if.bus_lv1_lv2_gnt_lv2     ),
                                .bus_lv1_lv2_req_lv2    (inst_system_bus_if.bus_lv1_lv2_req_lv2     ),
                                .data_in_bus_lv2_mem    (data_in_bus_lv2_mem                        )
                            );

    // VCD dump for waveform analysis
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, top);
    end

    // System clock generation
    initial begin
        clk = 1'b0;
        forever
            #5 clk = ~clk;
    end

    // System reset generation
    initial begin
        resetn = 1'b0;
        #10 resetn = 1'b1;
    end

    // lv2_rd_ps generation (used by LV2 SysBus to APB Interface logic)
    always @(posedge clk) begin
        lv2_rd_reg = inst_cache_top.lv2_rd;
        lv2_rd_ps = lv2_rd_reg;
    end

    // lv2_rd_pe generation (used by LV2 SysBus to APB Interface logic)
    always @(posedge clk) begin
        lv2_rd_px = inst_cache_top.lv2_rd_ps;
        lv2_rd_pe = lv2_rd_px;
    end

    // lv2_wren generation (used by LV2 SysBus to APB Interface logic)
    always @(posedge clk) begin
        lv2_wr_reg = inst_cache_top.lv2_wr;
        lv2_wren = lv2_wr_reg;
    end

    // cp_in_cacheen generation (used by LV2 SysBus to APB Interface logic)
    always @(posedge clk) begin
        cp_in_cache_reg = inst_cache_top.cp_in_cache;
        cp_in_cacheen = cp_in_cache_reg;
    end

//TB inital setup
    initial begin
        `uvm_info("TOP","Starting UVM test", UVM_LOW)
//Set Virtual Interface,
        uvm_config_db#(virtual interface cpu_lv1_interface)::set(null,"*.tb.cpu[0].*","vif",inst_cpu_lv1_if[0]);
        uvm_config_db#(virtual interface cpu_lv1_interface)::set(null,"*.tb.cpu[1].*","vif",inst_cpu_lv1_if[1]);
        uvm_config_db#(virtual interface cpu_lv1_interface)::set(null,"*.tb.cpu[2].*","vif",inst_cpu_lv1_if[2]);
        uvm_config_db#(virtual interface cpu_lv1_interface)::set(null,"*.tb.cpu[3].*","vif",inst_cpu_lv1_if[3]);
        uvm_config_db#(virtual interface system_bus_interface)::set(null,"*.tb.*","v_sbus_if",inst_system_bus_if);
        uvm_config_db#(virtual interface cpu_mesi_lru_interface)::set(null,"*.tb.cpu[0].*","v_mesi_lru_if",inst_cpu_mesi_lru_if[0]);
        uvm_config_db#(virtual interface cpu_mesi_lru_interface)::set(null,"*.tb.cpu[1].*","v_mesi_lru_if",inst_cpu_mesi_lru_if[1]);
        uvm_config_db#(virtual interface cpu_mesi_lru_interface)::set(null,"*.tb.cpu[2].*","v_mesi_lru_if",inst_cpu_mesi_lru_if[2]);
        uvm_config_db#(virtual interface cpu_mesi_lru_interface)::set(null,"*.tb.cpu[3].*","v_mesi_lru_if",inst_cpu_mesi_lru_if[3]);
        uvm_config_db#(virtual interface cpu_apb_interface)::set(null,"*.tb.cpu[0].*","vif",inst_cpu_apb_if[0]);
        uvm_config_db#(virtual interface cpu_apb_interface)::set(null,"*.tb.cpu[1].*","vif",inst_cpu_apb_if[1]);
        uvm_config_db#(virtual interface cpu_apb_interface)::set(null,"*.tb.cpu[2].*","vif",inst_cpu_apb_if[2]);
        uvm_config_db#(virtual interface cpu_apb_interface)::set(null,"*.tb.cpu[3].*","vif",inst_cpu_apb_if[3]);
        uvm_config_db#(virtual interface lv2_apb_interface)::set(null,"*.tb.*","v_lv2_apb_if",inst_lv2_apb_if);
        run_test();
        `uvm_info("TOP", "DONE", UVM_LOW)
    end

endmodule
