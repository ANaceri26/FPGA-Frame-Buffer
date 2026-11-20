// 320x240 RGB444 dual-port frame buffer (76,800 x 12 bits, M9K). Synchronous read, 1-cycle latency.

module frame_buffer #(
    parameter ADDR_W = 17,
    parameter DATA_W = 12,
    parameter DEPTH  = 76800
) (
    input  wire              clk,
    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [DATA_W-1:0] wdata,
    input  wire              re,
    input  wire [ADDR_W-1:0] raddr,
    output reg  [DATA_W-1:0] rdata
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
    end

    always @(posedge clk) begin
        if (re) rdata <= mem[raddr];
    end

endmodule
