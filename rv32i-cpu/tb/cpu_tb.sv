`timescale 1ns/1ps

module cpu_tb;
    logic clk = 0;
    logic rst = 1;

    cpu_top dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;          // 周期 10ns

    // 程序（写在 imem 里）：
    //   addi x1, x0, 5    → x1 = 5
    //   addi x2, x0, 3    → x2 = 3
    //   add  x3, x1, x2   → x3 = 8
    //   sub  x4, x1, x2   → x4 = 2

    initial begin
        $dumpfile("sim/cpu.vcd");
        $dumpvars(0, cpu_tb);

        // 复位
        @(negedge clk); @(negedge clk);
        rst = 0;

        // 跑足够多周期让 4 条指令执行完
        repeat (8) @(negedge clk);
        #1;

        $display("x1=%0d (期望 5)", dut.register_file.regs[1]);
        $display("x2=%0d (期望 3)", dut.register_file.regs[2]);
        $display("x3=%0d (期望 8)", dut.register_file.regs[3]);
        $display("x4=%0d (期望 2)", dut.register_file.regs[4]);

        if (dut.register_file.regs[1]===32'd5 &&
            dut.register_file.regs[2]===32'd3 &&
            dut.register_file.regs[3]===32'd8 &&
            dut.register_file.regs[4]===32'd2)
            $display("==== ALL PASS ====");
        else
            $display("==== FAIL ====");

        $finish;
    end

endmodule
