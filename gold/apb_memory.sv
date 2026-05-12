//=====================================================================
// Project : 4 core MESI cache design
// File Name : apb_memory.sv
// Description : main memory ABP IP
// Designer : MDQ
//=====================================================================
// Notable Change History:
// Date By   Version Change Description
// 2024/11/20  1.0     Initial Release
//=====================================================================
module apb_memory #( 
                  parameter DATA_WID        = 32 ,
                  parameter ADDR_WID        = 32 
              )(
                input                           pclk                  ,
                input                           presetn               ,
                input      [ADDR_WID - 1   : 0] paddr                 ,
                input                           psel                  ,
                input                           penable               ,
                input                           pwrite                ,
                input      [DATA_WID - 1   : 0] pwdata                ,
                output reg                      pready                ,
                output reg [DATA_WID - 1   : 0] prdata                ,
                output reg                      pslverr
               );

    reg [DATA_WID - 1 : 0] mem[int];

    wire mem_rd;
    wire mem_wr;
    wire [ADDR_WID - 1 : 0] addr_bus_lv2_mem_in;
    wire [DATA_WID - 1 : 0] data_bus_lv2_mem_in;
    wire [DATA_WID - 1 : 0] data_bus_lv2_mem_out;
    wire data_in_bus_lv2_mem;
    wire mem_wr_done;
    wire mem_err;

    assign mem_rd = psel & !pwrite;
    assign mem_wr = psel & pwrite;
    assign addr_bus_lv2_mem_in = paddr;
    assign data_bus_lv2_mem_in = pwdata;
    assign pready = data_in_bus_lv2_mem | mem_wr_done;
    assign prdata = data_in_bus_lv2_mem ? data_bus_lv2_mem_out : 32'h0;
    assign pslverr = pready & mem_err;
    
    //Out of Reset logic

    reg out_of_reset;
    always_ff @(posedge pclk or negedge presetn) begin : flops
      if (!presetn) begin
        out_of_reset <= 1'b1;
      end
      else if (presetn && out_of_reset) begin
        out_of_reset <= 1'b0;
      end
      else begin
        out_of_reset <= out_of_reset;
      end
    end

    //Current APB bus state

    typedef enum bit[1:0] {IDLE, SETUP, ACCESS, ERROR} apb_states_e;
    apb_states_e state;

    assign state = (!psel & !penable) ? IDLE   :
                   ( psel & !penable) ? SETUP  :
                   ( psel &  penable) ? ACCESS :
                                        ERROR  ;
    wire idle_state   = (state == IDLE);
    wire setup_state  = (state == SETUP);
    wire access_state = (state == ACCESS);
    wire error_state  = (state == ERROR);

    always @(posedge pclk) begin
        data_bus_lv2_mem_out <= 32'h0;
        data_in_bus_lv2_mem  <= 1'b0;
        mem_wr_done          <= 1'b0;
        mem_err              <= 1'b0;
        
        if(mem_rd & access_state) begin   // read
            if(mem.exists(addr_bus_lv2_mem_in)) begin
                data_bus_lv2_mem_out <= mem[addr_bus_lv2_mem_in];
                data_in_bus_lv2_mem  <= 1'b1;
            end                
            else begin 
                data_bus_lv2_mem_out <= addr_bus_lv2_mem_in[3] ? 32'h5555_aaaa : 32'haaaa_5555;
                data_in_bus_lv2_mem  <= 1'b1; 
            end                                     
        end
        else if(mem_wr & access_state) begin 
            mem[addr_bus_lv2_mem_in] = data_bus_lv2_mem_in;
            mem_wr_done              <= 1'b1;
        end
    end

endmodule    

