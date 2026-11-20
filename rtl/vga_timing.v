// 640x480 @ ~59.5 Hz. H: 640/16/96/48 = 800, V: 480/10/2/33 = 525. 25 MHz pix_en from 50 MHz clk.

module vga_timing #(
    parameter H_VISIBLE = 640,
    parameter H_FRONT   = 16,
    parameter H_SYNC    = 96,
    parameter H_BACK    = 48,
    parameter V_VISIBLE = 480,
    parameter V_FRONT   = 10,
    parameter V_SYNC    = 2,
    parameter V_BACK    = 33
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       pix_en,        // one clk-wide pulse per pixel
    output reg  [9:0] x,             // 0 .. 799
    output reg  [9:0] y,             // 0 .. 524
    output wire       hsync,         // active low
    output wire       vsync,         // active low
    output wire       active,        // high while (x, y) is a visible pixel
    output wire       frame_start    // one clk pulse at the first pixel of vertical blanking
);

    localparam H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;   // 800
    localparam V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;   // 525

    always @(posedge clk) begin
        if (rst) begin
            x <= 10'd0;
            y <= 10'd0;
        end else if (pix_en) begin
            if (x == H_TOTAL - 1) begin
                x <= 10'd0;
                if (y == V_TOTAL - 1) y <= 10'd0;
                else                  y <= y + 10'd1;
            end else begin
                x <= x + 10'd1;
            end
        end
    end

    assign hsync  = ~((x >= H_VISIBLE + H_FRONT) && (x < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync  = ~((y >= V_VISIBLE + V_FRONT) && (y < V_VISIBLE + V_FRONT + V_SYNC));
    assign active = (x < H_VISIBLE) && (y < V_VISIBLE);

    assign frame_start = pix_en && (x == 10'd0) && (y == V_VISIBLE);

endmodule
