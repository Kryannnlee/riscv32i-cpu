`timescale 1ns/1ps

module adder_tb;
    logic [31:0] a, b, sum;

    adder dut (.a(a), .b(b), .sum(sum));

    task automatic check(input [31:0] in_a, input [31:0] in_b, input [31:0] exp_sum);
        a = in_a; b = in_b; #1;
        if (sum === exp_sum) $display("PASS: %h + %h = %h", a, b, sum);
        else                 $display("FAIL: %h + %h = %h, expect %h", a, b, sum, exp_sum);
    endtask

    initial begin
        $dumpfile("sim/adder.vcd");
        $dumpvars(0, adder_tb);

        // 1. 普通相加
        check(32'd10, 32'd20, 32'd30);
        // 2. PC + 4
        check(32'h0000_0000, 32'd4, 32'h0000_0004);
        // 3. 负数补码偏移 (PC 回跳)
        check(32'h0000_0010, -32'd4, 32'h0000_000C);//hex 10 = 16 hex F = 15,-32'd4=-4,hex 0C = 12
        // 4. 溢出截断
        check(32'hFFFF_FFFF, 32'd1, 32'h0000_0000);

        $finish;
    end
endmodule