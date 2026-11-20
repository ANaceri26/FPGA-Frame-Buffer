// Writes one full frame per start pulse (issued at vblank), 1 pixel/clk.
// Modes: 0 test card, 1 gradient, 2 bouncing box, 3 checkerboard.

module pixel_painter #(
    parameter FB_W = 320,
    parameter FB_H = 240,
    parameter BOX  = 32
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,        // one pulse per frame
    input  wire        enable,       // 0 = leave the frame buffer alone (freeze)
    input  wire [1:0]  mode,
    output reg         we,
    output reg  [16:0] waddr,
    output reg  [11:0] wdata,
    output reg         busy
);

    reg [8:0]  px;                   // 0 .. 319
    reg [7:0]  py;                   // 0 .. 239
    reg [16:0] addr;

    reg [8:0]  box_x;
    reg [7:0]  box_y;
    reg        box_right, box_down;  // direction of travel
    reg [1:0]  mode_q;               // mode is sampled once per frame

    wire on_border = (px == 9'd0) || (px == FB_W - 1) || (py == 8'd0) || (py == FB_H - 1);
    wire in_box    = (px >= box_x) && (px < box_x + BOX) && (py >= box_y) && (py < box_y + BOX);

    reg [11:0] bar_colour;
    always @(*) begin
        if      (px <  9'd40)  bar_colour = 12'hFFF;   // white
        else if (px <  9'd80)  bar_colour = 12'hFF0;   // yellow
        else if (px <  9'd120) bar_colour = 12'h0FF;   // cyan
        else if (px <  9'd160) bar_colour = 12'h0F0;   // green
        else if (px <  9'd200) bar_colour = 12'hF0F;   // magenta
        else if (px <  9'd240) bar_colour = 12'hF00;   // red
        else if (px <  9'd280) bar_colour = 12'h00F;   // blue
        else                   bar_colour = 12'h000;   // black
    end

    reg [11:0] colour;
    always @(*) begin
        case (mode_q)
            2'd0: begin
                if (on_border)        colour = 12'hFFF;
                else if (py >= 8'd180) colour = {3{px[7:4]}};          // grey ramp
                else                   colour = bar_colour;
            end
            2'd1:    colour = {px[7:4], py[7:4], px[7:4] ^ py[7:4]};
            2'd2: begin
                if (in_box)                                   colour = 12'hFA0;   // orange box
                else if (px[4:0] == 5'd0 || py[4:0] == 5'd0)  colour = 12'h446;   // grid line
                else                                          colour = 12'h002;   // dark blue
            end
            default: colour = (px[4] ^ py[4]) ? 12'hFFF : 12'h000;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            busy      <= 1'b0;
            we        <= 1'b0;
            waddr     <= 17'd0;
            wdata     <= 12'd0;
            px        <= 9'd0;
            py        <= 8'd0;
            addr      <= 17'd0;
            box_x     <= 9'd40;
            box_y     <= 8'd30;
            box_right <= 1'b1;
            box_down  <= 1'b1;
            mode_q    <= 2'd0;
        end else begin
            we    <= busy;
            waddr <= addr;
            wdata <= colour;

            if (!busy) begin
                if (start && enable) begin
                    busy   <= 1'b1;
                    px     <= 9'd0;
                    py     <= 8'd0;
                    addr   <= 17'd0;
                    mode_q <= mode;

                    if (box_right) begin
                        if (box_x >= FB_W - BOX - 2) begin box_x <= FB_W - BOX; box_right <= 1'b0; end
                        else                               box_x <= box_x + 9'd2;
                    end else begin
                        if (box_x <= 9'd2) begin box_x <= 9'd0; box_right <= 1'b1; end
                        else                     box_x <= box_x - 9'd2;
                    end
                    if (box_down) begin
                        if (box_y >= FB_H - BOX - 1) begin box_y <= FB_H - BOX; box_down <= 1'b0; end
                        else                               box_y <= box_y + 8'd1;
                    end else begin
                        if (box_y <= 8'd1) begin box_y <= 8'd0; box_down <= 1'b1; end
                        else                     box_y <= box_y - 8'd1;
                    end
                end
            end else begin
                addr <= addr + 17'd1;
                if (px == FB_W - 1) begin
                    px <= 9'd0;
                    if (py == FB_H - 1) busy <= 1'b0;      // last pixel written
                    else                py   <= py + 8'd1;
                end else begin
                    px <= px + 9'd1;
                end
            end
        end
    end

endmodule
