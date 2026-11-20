// Self-checking monitor model: sync timing, active window, test card pixel-exact,
// box animation, freeze. Dumps out/frame_testcard.ppm and out/frame_box.ppm.

`timescale 1ns/1ps
module tb_vga;

    reg        clk = 0, rst = 1;
    reg  [1:0] mode = 2'd0;
    reg        paint_enable = 1'b1;
    wire [3:0] r, g, b;
    wire       hs, vs, act, frame_start;

    vga_core dut (
        .clk(clk), .rst(rst), .mode(mode), .paint_enable(paint_enable),
        .vga_r(r), .vga_g(g), .vga_b(b), .vga_hs(hs), .vga_vs(vs),
        .vga_active(act), .frame_start(frame_start)
    );

    always #10 clk = ~clk;          // 50 MHz

    integer errors = 0;
    integer checks = 0;

    integer hpos = 0;               // position of the previous pixel: pixels since hsync fell
    integer vcnt = 0;               // hsync pulses since vsync fell
    integer cur_h, cur_v;           // the same two numbers for the pixel being looked at now
    integer frame = 0;              // vsync pulses seen so far
    integer hs_low = 0, vs_low = 0; // widths being measured
    integer frame_pixels = 0;       // pixels since vsync fell
    integer active_count = 0;
    integer orange_count = 0, orange_x = -1, orange_y = -1;
    integer box_x_c = 0, box_y_c = 0, box_x_d = 0, box_y_d = 0, box_x_e = 0, box_y_e = 0;
    integer hash = 0, hash_e = 0;
    integer fd = 0;
    reg     hs_q = 1, vs_q = 1;
    reg     synced = 0;             // set once the first vsync has been seen
    integer sx, sy;
    reg     exp_active;

    task check(input cond, input [8*70:1] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                if (errors <= 20) $display("  FAIL @%0t (hpos=%0d vcnt=%0d): %0s", $time, cur_h, cur_v, msg);
            end
        end
    endtask

    function [11:0] testcard(input integer fx, input integer fy);
        integer grey;
        begin
            if (fx == 0 || fx == 319 || fy == 0 || fy == 239) testcard = 12'hFFF;
            else if (fy >= 180) begin
                grey = (fx / 16) % 16;
                testcard = grey * 12'h111;
            end else begin
                case (fx / 40)
                    0: testcard = 12'hFFF;
                    1: testcard = 12'hFF0;
                    2: testcard = 12'h0FF;
                    3: testcard = 12'h0F0;
                    4: testcard = 12'hF0F;
                    5: testcard = 12'hF00;
                    6: testcard = 12'h00F;
                    default: testcard = 12'h000;
                endcase
            end
        end
    endfunction

    // sample on pix_en == 0 edges, outputs are settled
    wire sample = !rst && !dut.pix_en;

    always @(posedge clk) if (sample) begin
        hs_q <= hs;
        vs_q <= vs;

        cur_h = (hs_q && !hs) ? 0 : hpos + 1;
        cur_v = (vs_q && !vs) ? 0 : ((hs_q && !hs) ? vcnt + 1 : vcnt);

        if (hs_q && !hs) begin                                  // hsync falling edge
            if (synced) check(hpos == 799, "line is not 800 pixels long");
            hs_low <= 1;
        end else if (!hs) begin
            hs_low <= hs_low + 1;
        end
        if (!hs_q && hs && synced)                              // hsync rising edge
            check(hs_low == 96, "hsync pulse is not 96 pixels wide");

        frame_pixels <= frame_pixels + 1;
        if (!vs) vs_low <= vs_low + 1;
        if (!vs_q && vs && synced)                              // vsync rising edge
            check(vs_low == 2 * 800, "vsync pulse is not 2 lines long");

        if (vs_q && !vs) begin                                  // vsync falling edge: new frame
            if (synced) begin
                check(frame_pixels == 800 * 525 - 1, "frame is not 525 lines of 800 pixels");
                check(active_count == 640 * 480, "frame does not have 640 x 480 active pixels");
            end
            end_of_frame;
            synced       <= 1;
            frame        <= frame + 1;
            vs_low       <= 1;
            frame_pixels <= 0;
            active_count <= 0;
            orange_count <= 0;
            orange_x     <= -1;
            hash         <= 0;
        end

        hpos <= cur_h;
        vcnt <= cur_v;

        if (synced) begin
            sx = cur_h - 144;
            sy = cur_v - 35;
            exp_active = (sx >= 0) && (sx < 640) && (sy >= 0) && (sy < 480);

            check(act === exp_active, "active video is in the wrong place");
            if (act) active_count <= active_count + 1;
            if (!act) check({r, g, b} === 12'h000, "colour must be black during blanking");

            if (exp_active) begin
                // frame 1: the test card, compared pixel by pixel
                if (frame == 1)
                    check({r, g, b} === testcard(sx / 2, sy / 2), "test card pixel has the wrong colour");

                // simple running hash of the whole picture (used by the freeze check)
                hash <= (hash * 31 + {r, g, b} + sx) & 32'h7FFFFFFF;

                if ({r, g, b} === 12'hFA0) begin
                    orange_count <= orange_count + 1;
                    if (orange_x == -1) begin
                        orange_x <= sx;
                        orange_y <= sy;
                    end
                end

                if (fd != 0) $fwrite(fd, "%0d %0d %0d\n", r * 17, g * 17, b * 17);
            end
        end
    end

    // mode/paint_enable changes show up two frames later
    task end_of_frame;
        begin
            if (fd != 0) begin
                $fclose(fd);
                fd = 0;
            end
            case (frame)
                1: begin
                    $display("[vga] frame 1: sync timing and test card checked (%0d checks so far)", checks);
                    mode = 2'd2;                           // ask for the animation
                end
                3: begin
                    box_x_c = orange_x; box_y_c = orange_y;
                    check(orange_count == 64 * 64, "box should cover 64 x 64 screen pixels");
                    $display("[vga] frame 3: box at screen (%0d, %0d), %0d orange pixels", orange_x, orange_y, orange_count);
                end
                4: begin
                    box_x_d = orange_x; box_y_d = orange_y;
                    check(orange_count == 64 * 64, "box should cover 64 x 64 screen pixels");
                    check(box_x_d == box_x_c + 4 && box_y_d == box_y_c + 2,
                          "box should move 4 screen pixels right and 2 down per frame");
                    $display("[vga] frame 4: box at screen (%0d, %0d)", orange_x, orange_y);
                    paint_enable = 1'b0;                   // freeze
                end
                5: begin
                    box_x_e = orange_x; box_y_e = orange_y; hash_e = hash;
                    check(box_x_e == box_x_d + 4 && box_y_e == box_y_d + 2, "box should have moved once more");
                    $display("[vga] frame 5: box at screen (%0d, %0d), painter now frozen", orange_x, orange_y);
                end
                6: begin
                    check(orange_x == box_x_e && orange_y == box_y_e, "frozen picture: box must not move");
                    check(hash == hash_e, "frozen picture: every pixel must be identical");
                    $display("[vga] frame 6: identical to frame 5 (read straight from memory)");
                    $display("");
                    $display("  frame rate: %0.2f Hz", 1.0e9 / (800.0 * 525.0 * 40.0));
                    $display("  checks run: %0d", checks);
                    if (errors == 0) $display("ALL TESTS PASSED");
                    else             $display("%0d CHECK(S) FAILED", errors);
                    $finish;
                end
                default: ;
            endcase
            // open an image file for the frame that is about to start
            if (frame == 0) begin
                fd = $fopen("out/frame_testcard.ppm", "w");
                if (fd != 0) $fwrite(fd, "P3\n640 480\n255\n");
            end
            if (frame == 4) begin
                fd = $fopen("out/frame_box.ppm", "w");
                if (fd != 0) $fwrite(fd, "P3\n640 480\n255\n");
            end
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst = 0;
    end

    initial begin
        #(200_000_000);
        $display("FAIL: testbench timed out");
        $finish;
    end

endmodule
