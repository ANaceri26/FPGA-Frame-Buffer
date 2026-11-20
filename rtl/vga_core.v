// Timing + frame buffer + painter. Sync/active delayed 2 stages to match RAM read latency.
// Each buffer pixel is drawn as 2x2 (320x240 -> 640x480).

module vga_core (
    input  wire       clk,           // 50 MHz
    input  wire       rst,
    input  wire [1:0] mode,          // which picture the painter draws
    input  wire       paint_enable,  // 0 = freeze: the display keeps showing the stored frame
    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b,
    output reg        vga_hs,
    output reg        vga_vs,
    output reg        vga_active,    // not a VGA pin: handy for testbenches and debugging
    output wire       frame_start
);

    reg pix_en;
    always @(posedge clk) begin
        if (rst) pix_en <= 1'b0;
        else     pix_en <= ~pix_en;
    end

    wire [9:0] x, y;
    wire       hsync, vsync, active;

    vga_timing u_timing (
        .clk(clk), .rst(rst), .pix_en(pix_en),
        .x(x), .y(y), .hsync(hsync), .vsync(vsync), .active(active),
        .frame_start(frame_start)
    );

    // buffer address = row * 320 + column, and 320 = 256 + 64, so no multiplier is needed
    wire [8:0]  fb_col  = x[9:1];
    wire [8:0]  fb_row  = y[9:1];
    wire [16:0] rd_addr = {fb_row, 8'b0} + {2'b0, fb_row, 6'b0} + {8'b0, fb_col};

    wire        wr_en;
    wire [16:0] wr_addr;
    wire [11:0] wr_data;

    pixel_painter u_painter (
        .clk(clk), .rst(rst), .start(frame_start), .enable(paint_enable), .mode(mode),
        .we(wr_en), .waddr(wr_addr), .wdata(wr_data), .busy()
    );

    wire [11:0] rd_data;

    frame_buffer u_fb (
        .clk(clk),
        .we(wr_en), .waddr(wr_addr), .wdata(wr_data),
        .re(pix_en && active), .raddr(rd_addr), .rdata(rd_data)   // only read visible pixels
    );

    reg hsync_d1, vsync_d1, active_d1;
    always @(posedge clk) begin
        if (rst) begin
            hsync_d1  <= 1'b1;
            vsync_d1  <= 1'b1;
            active_d1 <= 1'b0;
        end else if (pix_en) begin
            hsync_d1  <= hsync;
            vsync_d1  <= vsync;
            active_d1 <= active;
        end
    end

    // black during blanking
    always @(posedge clk) begin
        if (rst) begin
            vga_r      <= 4'd0;
            vga_g      <= 4'd0;
            vga_b      <= 4'd0;
            vga_hs     <= 1'b1;
            vga_vs     <= 1'b1;
            vga_active <= 1'b0;
        end else if (pix_en) begin
            vga_r      <= active_d1 ? rd_data[11:8] : 4'd0;
            vga_g      <= active_d1 ? rd_data[7:4]  : 4'd0;
            vga_b      <= active_d1 ? rd_data[3:0]  : 4'd0;
            vga_hs     <= hsync_d1;
            vga_vs     <= vsync_d1;
            vga_active <= active_d1;
        end
    end

endmodule
