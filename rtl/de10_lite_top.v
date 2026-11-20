// DE10-Lite top. SW[1:0] picture mode, SW[9] freeze, KEY[0] reset, LEDR[0] heartbeat, LEDR[9] frozen.

module de10_lite_top (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS
);

    wire clk = MAX10_CLK1_50;

    // Reset synchroniser: assert immediately, release in step with the clock.
    wire      key0_n = KEY[0];
    reg [1:0] rst_ff;
    always @(posedge clk or negedge key0_n) begin
        if (!key0_n) rst_ff <= 2'b11;
        else         rst_ff <= {rst_ff[0], 1'b0};
    end
    wire rst = rst_ff[1];

    // Two-flop synchronisers for the asynchronous switches.
    reg [9:0] sw_meta, sw_sync;
    always @(posedge clk) begin
        sw_meta <= SW;
        sw_sync <= sw_meta;
    end

    wire frame_start;

    vga_core u_vga (
        .clk(clk), .rst(rst),
        .mode(sw_sync[1:0]), .paint_enable(~sw_sync[9]),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B),
        .vga_hs(VGA_HS), .vga_vs(VGA_VS), .vga_active(),
        .frame_start(frame_start)
    );

    reg [4:0] frame_cnt;
    reg       heartbeat;
    always @(posedge clk) begin
        if (rst) begin
            frame_cnt <= 5'd0;
            heartbeat <= 1'b0;
        end else if (frame_start) begin
            if (frame_cnt == 5'd29) begin
                frame_cnt <= 5'd0;
                heartbeat <= ~heartbeat;
            end else begin
                frame_cnt <= frame_cnt + 5'd1;
            end
        end
    end

    assign LEDR[0]   = heartbeat;
    assign LEDR[8:1] = 8'b0;
    assign LEDR[9]   = sw_sync[9];

endmodule
