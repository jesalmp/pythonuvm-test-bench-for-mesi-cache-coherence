module top_tb;

    reg clk;
    reg resetn;

    wire [31:0] data_bus_cpu_lv1_0;
    wire [31:0] data_bus_cpu_lv1_1;
    wire [31:0] data_bus_cpu_lv1_2;
    wire [31:0] data_bus_cpu_lv1_3;

    reg [31:0] data_bus_cpu_lv1_0_reg;
    reg [31:0] data_bus_cpu_lv1_1_reg;
    reg [31:0] data_bus_cpu_lv1_2_reg;
    reg [31:0] data_bus_cpu_lv1_3_reg;

    reg [31:0] addr_bus_cpu_lv1_0;
    reg [31:0] addr_bus_cpu_lv1_1;
    reg [31:0] addr_bus_cpu_lv1_2;
    reg [31:0] addr_bus_cpu_lv1_3;

    reg [3:0] cpu_rd;
    reg [3:0] cpu_wr;
    reg [3:0] cpu_rden;
    reg [3:0] cpu_wren;

    wire [3:0] cpu_wr_done;
    wire [3:0] data_in_bus_cpu_lv1;

    wire [31:0] data_bus_lv2_mem;
    wire [31:0] addr_bus_lv2_mem;
    wire mem_rd;
    wire mem_wr;
    wire mem_wr_done;
    wire data_in_bus_lv2_mem;

    wire [3:0] bus_lv1_lv2_gnt_proc;
    wire [3:0] bus_lv1_lv2_req_proc;
    wire [3:0] bus_lv1_lv2_gnt_snoop;
    wire [3:0] bus_lv1_lv2_req_snoop;
    wire bus_lv1_lv2_gnt_lv2;
    wire bus_lv1_lv2_req_lv2;

    reg lv2_rd_ps;
    reg lv2_rd_pe;
    reg lv2_wren;
    reg cp_in_cacheen;

    reg lv2_rd_reg;
    reg lv2_rd_px;
    reg lv2_wr_reg;
    reg cp_in_cache_reg;

    assign data_bus_cpu_lv1_0 = data_bus_cpu_lv1_0_reg;
    assign data_bus_cpu_lv1_1 = data_bus_cpu_lv1_1_reg;
    assign data_bus_cpu_lv1_2 = data_bus_cpu_lv1_2_reg;
    assign data_bus_cpu_lv1_3 = data_bus_cpu_lv1_3_reg;

    cache_top inst_cache_top(
        .clk(clk),
        .resetn(resetn),
        .data_bus_cpu_lv1_0(data_bus_cpu_lv1_0),
        .addr_bus_cpu_lv1_0(addr_bus_cpu_lv1_0),
        .data_bus_cpu_lv1_1(data_bus_cpu_lv1_1),
        .addr_bus_cpu_lv1_1(addr_bus_cpu_lv1_1),
        .data_bus_cpu_lv1_2(data_bus_cpu_lv1_2),
        .addr_bus_cpu_lv1_2(addr_bus_cpu_lv1_2),
        .data_bus_cpu_lv1_3(data_bus_cpu_lv1_3),
        .addr_bus_cpu_lv1_3(addr_bus_cpu_lv1_3),
        .cpu_rd(cpu_rd),
        .cpu_wr(cpu_wr),
        .cpu_rden(cpu_rden),
        .cpu_wren(cpu_wren),
        .cpu_wr_done(cpu_wr_done),
        .bus_lv1_lv2_gnt_proc(bus_lv1_lv2_gnt_proc),
        .bus_lv1_lv2_req_proc(bus_lv1_lv2_req_proc),
        .bus_lv1_lv2_gnt_snoop(bus_lv1_lv2_gnt_snoop),
        .bus_lv1_lv2_req_snoop(bus_lv1_lv2_req_snoop),
        .data_in_bus_cpu_lv1(data_in_bus_cpu_lv1),
        .data_bus_lv2_mem(data_bus_lv2_mem),
        .addr_bus_lv2_mem(addr_bus_lv2_mem),
        .mem_rd(mem_rd),
        .mem_wr(mem_wr),
        .mem_wr_done(mem_wr_done),
        .bus_lv1_lv2_gnt_lv2(bus_lv1_lv2_gnt_lv2),
        .bus_lv1_lv2_req_lv2(bus_lv1_lv2_req_lv2),
        .data_in_bus_lv2_mem(data_in_bus_lv2_mem),
        .lv2_rd_ps(lv2_rd_ps),
        .lv2_rd_pe(lv2_rd_pe),
        .lv2_wren(lv2_wren),
        .cp_in_cacheen(cp_in_cacheen)
    );

    memory inst_memory(
        .clk(clk),
        .data_bus_lv2_mem(data_bus_lv2_mem),
        .addr_bus_lv2_mem(addr_bus_lv2_mem),
        .mem_rd(mem_rd),
        .mem_wr(mem_wr),
        .mem_wr_done(mem_wr_done),
        .data_in_bus_lv2_mem(data_in_bus_lv2_mem)
    );

    lrs_arbiter inst_arbiter(
        .clk(clk),
        .bus_lv1_lv2_gnt_proc(bus_lv1_lv2_gnt_proc),
        .bus_lv1_lv2_req_proc(bus_lv1_lv2_req_proc),
        .bus_lv1_lv2_gnt_snoop(bus_lv1_lv2_gnt_snoop),
        .bus_lv1_lv2_req_snoop(bus_lv1_lv2_req_snoop),
        .bus_lv1_lv2_gnt_lv2(bus_lv1_lv2_gnt_lv2),
        .bus_lv1_lv2_req_lv2(bus_lv1_lv2_req_lv2)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        resetn = 0;
        #20 resetn = 1;
    end

    initial begin
        cpu_rd = 4'b0; cpu_wr = 4'b0; cpu_rden = 4'b0; cpu_wren = 4'b0;
        addr_bus_cpu_lv1_0 = 32'hz; addr_bus_cpu_lv1_1 = 32'hz;
        addr_bus_cpu_lv1_2 = 32'hz; addr_bus_cpu_lv1_3 = 32'hz;
        data_bus_cpu_lv1_0_reg = 32'hz; data_bus_cpu_lv1_1_reg = 32'hz;
        data_bus_cpu_lv1_2_reg = 32'hz; data_bus_cpu_lv1_3_reg = 32'hz;
    end

    always @(posedge clk) begin
        lv2_rd_reg = inst_cache_top.cache_wrapper_lv2_inst.lv2_rd;
        lv2_rd_ps = lv2_rd_reg;
    end

    always @(posedge clk) begin
        lv2_rd_px = inst_cache_top.cache_wrapper_lv2_inst.lv2_rd;
        lv2_rd_pe = lv2_rd_px;
    end

    always @(posedge clk) begin
        lv2_wr_reg = inst_cache_top.cache_wrapper_lv2_inst.lv2_wr;
        lv2_wren = lv2_wr_reg;
    end

    always @(posedge clk) begin
        cp_in_cache_reg = inst_cache_top.cache_wrapper_lv2_inst.cp_in_cache;
        cp_in_cacheen = cp_in_cache_reg;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top_tb);
    end

endmodule
