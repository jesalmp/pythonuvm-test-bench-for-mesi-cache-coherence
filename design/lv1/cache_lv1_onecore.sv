//=====================================================================
// Project : 1 core MESI cache design
// File Name : cache_lv1_onecore.sv
// Description : lv1 cache for 1 core
// Designer : Yuhao Yang
//=====================================================================
// Notable Change History:
// Date By   Version Change Description
// 2016/4/23  1.0     Initial Release
//=====================================================================

module cache_lv1_onecore #(
                            parameter ASSOC              = `ASSOC_LV1              ,
                            parameter ASSOC_WID          = `ASSOC_WID_LV1          ,
                            parameter DATA_WID           = `DATA_WID_LV1           ,
                            parameter ADDR_WID           = `ADDR_WID_LV1           ,
                            parameter INDEX_MSB          = `INDEX_MSB_LV1          ,
                            parameter INDEX_LSB          = `INDEX_LSB_LV1          ,
                            parameter TAG_MSB            = `TAG_MSB_LV1            ,
                            parameter TAG_LSB            = `TAG_LSB_LV1            ,
                            parameter OFFSET_MSB         = `OFFSET_MSB_LV1         ,
                            parameter OFFSET_LSB         = `OFFSET_LSB_LV1         ,
                            parameter CACHE_DATA_WID     = `CACHE_DATA_WID_LV1     ,
                            parameter CACHE_TAG_MSB      = `CACHE_TAG_MSB_LV1      ,
                            parameter CACHE_TAG_LSB      = `CACHE_TAG_LSB_LV1      ,
                            parameter CACHE_DEPTH        = `CACHE_DEPTH_LV1        ,
                            parameter CACHE_MESI_MSB     = `CACHE_MESI_MSB_LV1     ,
                            parameter CACHE_MESI_LSB     = `CACHE_MESI_LSB_LV1     ,
                            parameter CACHE_TAG_MESI_WID = `CACHE_TAG_MESI_WID_LV1 ,
                            parameter MESI_WID           = `MESI_WID_LV1           ,
                            parameter OFFSET_WID         = `OFFSET_WID_LV1         ,
                            parameter LRU_VAR_WID        = `LRU_VAR_WID_LV1        ,
                            parameter NUM_OF_SETS        = `NUM_OF_SETS_LV1        ,
                            parameter TAG_WID            = `TAG_WID_LV1            ,
                            parameter IL_DL_ADDR_BOUND   = `IL_DL_ADDR_BOUND
                             )
                             (
                             input                           clk                     ,
                             input                           resetn                  ,
                             inout  [DATA_WID - 1       : 0] data_bus_lv1_lv2        ,
                             output [ADDR_WID - 1       : 0] addr_bus_lv1_lv2        ,
                             inout  [DATA_WID - 1       : 0] data_bus_cpu_lv1_0      ,
                             input  [ADDR_WID - 1       : 0] addr_bus_cpu_lv1_0      ,
                             inout  [DATA_WID - 1       : 0] data_bus_cpu_lv1_1      ,
                             input  [ADDR_WID - 1       : 0] addr_bus_cpu_lv1_1      ,
                             inout  [DATA_WID - 1       : 0] data_bus_cpu_lv1_2      ,
                             input  [ADDR_WID - 1       : 0] addr_bus_cpu_lv1_2      ,
                             inout  [DATA_WID - 1       : 0] data_bus_cpu_lv1_3      ,
                             input  [ADDR_WID - 1       : 0] addr_bus_cpu_lv1_3      ,
                             output                          lv2_rd                  ,
                             output                          lv2_wr                  ,
                             input                           lv2_wr_done             ,
                             output                          cp_in_cache             ,
                             input  [           3       : 0] cpu_rd                  ,
                             input  [           3       : 0] cpu_wr                  ,
                             input  [           3       : 0] cpu_rden                ,
                             input  [           3       : 0] cpu_wren                ,
                             output [           3       : 0] cpu_wr_done             ,
                             input  [           3       : 0] bus_lv1_lv2_gnt_proc    ,
                             output [           3       : 0] bus_lv1_lv2_req_proc    ,
                             input  [           3       : 0] bus_lv1_lv2_gnt_snoop   ,
                             output [           3       : 0] bus_lv1_lv2_req_snoop   ,
                             output [           3       : 0] data_in_bus_cpu_lv1     ,
                             inout                           data_in_bus_lv1_lv2

                         );

    wire         pclk;
    wire         presetn;
    wire [3 : 0] psel;
    wire [3 : 0] penable;
    wire [3 : 0] pwrite;
    wire [3 : 0] pslverr;
    wire [3 : 0] pready;

    wire [ADDR_WID - 1 : 0] paddr_0;
    wire [ADDR_WID - 1 : 0] paddr_1;
    wire [ADDR_WID - 1 : 0] paddr_2;
    wire [ADDR_WID - 1 : 0] paddr_3;
    wire [DATA_WID - 1 : 0] pwdata_0;
    wire [DATA_WID - 1 : 0] pwdata_1;
    wire [DATA_WID - 1 : 0] pwdata_2;
    wire [DATA_WID - 1 : 0] pwdata_3;
    reg  [DATA_WID - 1 : 0] prdata_0;
    reg  [DATA_WID - 1 : 0] prdata_1;
    reg  [DATA_WID - 1 : 0] prdata_2;
    reg  [DATA_WID - 1 : 0] prdata_3;

    assign pclk                = clk;
    assign presetn             = resetn;
    assign paddr_0             = addr_bus_cpu_lv1_0;
    assign paddr_1             = addr_bus_cpu_lv1_1;
    assign paddr_2             = addr_bus_cpu_lv1_2;
    assign paddr_3             = addr_bus_cpu_lv1_3;
    assign psel[0]             = ((addr_bus_cpu_lv1_0 > IL_DL_ADDR_BOUND) ? cpu_wr[0] : 1'b0) | cpu_rd[0];
    assign psel[1]             = ((addr_bus_cpu_lv1_1 > IL_DL_ADDR_BOUND) ? cpu_wr[1] : 1'b0) | cpu_rd[1];
    assign psel[2]             = ((addr_bus_cpu_lv1_2 > IL_DL_ADDR_BOUND) ? cpu_wr[2] : 1'b0) | cpu_rd[2];
    assign psel[3]             = ((addr_bus_cpu_lv1_3 > IL_DL_ADDR_BOUND) ? cpu_wr[3] : 1'b0) | cpu_rd[3];
    assign penable[0]          = ((addr_bus_cpu_lv1_0 > IL_DL_ADDR_BOUND) ? (cpu_wren[0] & cpu_wr[0]) : 1'b0) | (cpu_rden[0] & cpu_rd[0]);
    assign penable[1]          = ((addr_bus_cpu_lv1_1 > IL_DL_ADDR_BOUND) ? (cpu_wren[1] & cpu_wr[1]) : 1'b0) | (cpu_rden[1] & cpu_rd[1]);
    assign penable[2]          = ((addr_bus_cpu_lv1_2 > IL_DL_ADDR_BOUND) ? (cpu_wren[2] & cpu_wr[2]) : 1'b0) | (cpu_rden[2] & cpu_rd[2]);
    assign penable[3]          = ((addr_bus_cpu_lv1_3 > IL_DL_ADDR_BOUND) ? (cpu_wren[3] & cpu_wr[3]) : 1'b0) | (cpu_rden[3] & cpu_rd[3]);
    assign pwrite[0]           = (addr_bus_cpu_lv1_0 > IL_DL_ADDR_BOUND) ? cpu_wr[0] : 1'b0;
    assign pwrite[1]           = (addr_bus_cpu_lv1_1 > IL_DL_ADDR_BOUND) ? cpu_wr[1] : 1'b0;
    assign pwrite[2]           = (addr_bus_cpu_lv1_2 > IL_DL_ADDR_BOUND) ? cpu_wr[2] : 1'b0;
    assign pwrite[3]           = (addr_bus_cpu_lv1_3 > IL_DL_ADDR_BOUND) ? cpu_wr[3] : 1'b0;
    assign pwdata_0            = ((addr_bus_cpu_lv1_0 > IL_DL_ADDR_BOUND) & cpu_wr[0]) ? data_bus_cpu_lv1_0 : 32'hz;
    assign pwdata_1            = ((addr_bus_cpu_lv1_1 > IL_DL_ADDR_BOUND) & cpu_wr[1]) ? data_bus_cpu_lv1_1 : 32'hz;
    assign pwdata_2            = ((addr_bus_cpu_lv1_2 > IL_DL_ADDR_BOUND) & cpu_wr[2]) ? data_bus_cpu_lv1_2 : 32'hz;
    assign pwdata_3            = ((addr_bus_cpu_lv1_3 > IL_DL_ADDR_BOUND) & cpu_wr[3]) ? data_bus_cpu_lv1_3 : 32'hz;
    assign cpu_wr_done[0]      = (addr_bus_cpu_lv1_0 > IL_DL_ADDR_BOUND) ? (pready[0] & cpu_wren[0]) : 1'b0;
    assign cpu_wr_done[1]      = (addr_bus_cpu_lv1_1 > IL_DL_ADDR_BOUND) ? (pready[1] & cpu_wren[1]) : 1'b0;
    assign cpu_wr_done[2]      = (addr_bus_cpu_lv1_2 > IL_DL_ADDR_BOUND) ? (pready[2] & cpu_wren[2]) : 1'b0;
    assign cpu_wr_done[3]      = (addr_bus_cpu_lv1_3 > IL_DL_ADDR_BOUND) ? (pready[3] & cpu_wren[3]) : 1'b0;
    assign data_in_bus_cpu_lv1 = pready & cpu_rden;
    assign data_bus_cpu_lv1_0  = data_in_bus_cpu_lv1[0] ? prdata_0 : 32'hz;
    assign data_bus_cpu_lv1_1  = data_in_bus_cpu_lv1[1] ? prdata_1 : 32'hz;
    assign data_bus_cpu_lv1_2  = data_in_bus_cpu_lv1[2] ? prdata_2 : 32'hz;
    assign data_bus_cpu_lv1_3  = data_in_bus_cpu_lv1[3] ? prdata_3 : 32'hz;

    wire [3 : 0] lv2_rd_uni;
    wire [3 : 0] lv2_wr_uni;
    wire [3 : 0] cp_in_cache_uni;
    wire [3 : 0] shared_local;
    wire         shared;
    wire         bus_rd;
    wire         bus_rdx;
    wire [3 : 0] invalidation_done;
    wire         all_invalidation_done;
    wire         invalidate;

    assign lv2_rd                = lv2_rd_uni[0];
    assign lv2_wr                = lv2_wr_uni[0];
    assign shared                = shared_local[0];
    assign all_invalidation_done = invalidation_done[0] | bus_lv1_lv2_gnt_proc[0];
    assign cp_in_cache           = cp_in_cache_uni[0];

    cache_lv1_unicore #(
                        .ASSOC(ASSOC),
                        .ASSOC_WID(ASSOC_WID),
                        .DATA_WID(DATA_WID),
                        .ADDR_WID(ADDR_WID),
                        .INDEX_MSB(INDEX_MSB),
                        .INDEX_LSB(INDEX_LSB),
                        .TAG_MSB(TAG_MSB),
                        .TAG_LSB(TAG_LSB),
                        .OFFSET_MSB(OFFSET_MSB),
                        .OFFSET_LSB(OFFSET_LSB),
                        .CACHE_DATA_WID(CACHE_DATA_WID),
                        .CACHE_TAG_MSB(CACHE_TAG_MSB),
                        .CACHE_TAG_LSB(CACHE_TAG_LSB),
                        .CACHE_DEPTH(CACHE_DEPTH),
                        .CACHE_MESI_MSB(CACHE_MESI_MSB),
                        .CACHE_MESI_LSB(CACHE_MESI_LSB),
                        .CACHE_TAG_MESI_WID(CACHE_TAG_MESI_WID),
                        .MESI_WID(MESI_WID),
                        .OFFSET_WID(OFFSET_WID),
                        .LRU_VAR_WID(LRU_VAR_WID),
                        .NUM_OF_SETS(NUM_OF_SETS),
                        .TAG_WID(TAG_WID),
                        .IL_DL_ADDR_BOUND(IL_DL_ADDR_BOUND)
                    )
                     inst_cache_lv1_unicore_0 (
                                                .core_id(2'b00),
                                                .pclk(pclk),
                                                .presetn(presetn),
                                                .paddr(paddr_0),
                                                .psel(psel[0]),
                                                .penable(penable[0]),
                                                .pwrite(pwrite[0]),
                                                .pwdata(pwdata_0),
                                                .pready(pready[0]),
                                                .prdata(prdata_0),
                                                .pslverr(pslverr[0]),
                                                .data_bus_lv1_lv2(data_bus_lv1_lv2),
                                                .addr_bus_lv1_lv2(addr_bus_lv1_lv2),
                                                .lv2_rd(lv2_rd_uni[0]),
                                                .lv2_wr(lv2_wr_uni[0]),
                                                .lv2_wr_done(lv2_wr_done),
                                                .bus_rd(bus_rd),
                                                .bus_rdx(bus_rdx),
                                                .bus_lv1_lv2_gnt_proc(bus_lv1_lv2_gnt_proc[0]),
                                                .bus_lv1_lv2_req_proc(bus_lv1_lv2_req_proc[0]),
                                                .bus_lv1_lv2_gnt_snoop(bus_lv1_lv2_gnt_snoop[0]),
                                                .bus_lv1_lv2_req_snoop(bus_lv1_lv2_req_snoop[0]),
                                                .data_in_bus_lv1_lv2(data_in_bus_lv1_lv2),
                                                .invalidate(invalidate),
                                                .all_invalidation_done(all_invalidation_done),
                                                .shared(shared),
                                                .shared_local(shared_local[0]),
                                                .cp_in_cache(cp_in_cache_uni[0]),
                                                .invalidation_done(invalidation_done[0])
                                            );


endmodule
