// Checks 1-cycle read latency of frame_buffer.

`timescale 1ns/1ps
module tb_frame_buffer;

    reg         clk = 0;
    reg         we = 0, re = 0;
    reg  [16:0] waddr = 0, raddr = 0;
    reg  [11:0] wdata = 0;
    wire [11:0] rdata;
    integer     errors = 0;
    integer     i;

    frame_buffer dut (.clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
                      .re(re), .raddr(raddr), .rdata(rdata));

    always #10 clk = ~clk;

    task check(input cond, input [8*60:1] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("  FAIL @%0t: %0s", $time, msg);
            end
        end
    endtask

    task write(input [16:0] a, input [11:0] d);
        begin
            @(negedge clk); we = 1; waddr = a; wdata = d;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        $display("[fb] 1. write a few cells, including the first and the last");
        write(17'd0,     12'hABC);
        write(17'd1,     12'h123);
        write(17'd76799, 12'hFED);
        write(17'd40000, 12'h5A5);

        $display("[fb] 2. read latency is exactly one clock");
        @(negedge clk); re = 1; raddr = 17'd0;
        @(negedge clk);                               // one rising edge has passed
        check(rdata === 12'hABC, "data should be valid one clock after the address");
        raddr = 17'd1;
        #1 check(rdata === 12'hABC, "output must not change before the next clock edge");
        @(negedge clk);
        check(rdata === 12'h123, "second read");
        raddr = 17'd76799;
        @(negedge clk);
        check(rdata === 12'hFED, "last cell");

        $display("[fb] 3. with re low the output holds its value");
        re = 0; raddr = 17'd40000;
        @(negedge clk);
        check(rdata === 12'hFED, "output changed although re was low");
        re = 1;
        @(negedge clk);
        check(rdata === 12'h5A5, "read after re returns");

        $display("[fb] 4. the two ports work at the same time on different cells");
        @(negedge clk); we = 1; waddr = 17'd500; wdata = 12'h777; re = 1; raddr = 17'd1;
        @(negedge clk); we = 0;
        check(rdata === 12'h123, "read disturbed by a write to another cell");
        raddr = 17'd500;
        @(negedge clk);
        check(rdata === 12'h777, "the simultaneous write did not land");

        $display("[fb] 5. streaming: a new address every clock gives a new word every clock");
        for (i = 0; i < 64; i = i + 1) write(17'd1000 + i, 12'h800 + i);
        @(negedge clk); re = 1; raddr = 17'd1000;
        for (i = 0; i < 64; i = i + 1) begin
            @(negedge clk);
            check(rdata === 12'h800 + i, "streaming read");
            raddr = 17'd1001 + i;
        end

        if (errors == 0) $display("[fb] ALL TESTS PASSED");
        else             $display("[fb] %0d CHECK(S) FAILED", errors);
        $finish;
    end
endmodule
