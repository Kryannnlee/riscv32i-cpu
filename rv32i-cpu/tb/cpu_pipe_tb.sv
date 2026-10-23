`timescale 1ns/1ps

module cpu_pipe_tb;
    logic clk = 0;
    logic rst = 1;

    cpu_pipe dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;          // 周期 10ns

    // 程序（imem 内，互相独立）：
    //   addi x1, x0, 5 → 5
    //   addi x2, x0, 3 → 3
    //   addi x3, x0, 8 → 8
    //   addi x4, x0, 2 → 2

    initial begin
        $dumpfile("sim/cpu_pipe.vcd");
        $dumpvars(0, cpu_pipe_tb);

        @(negedge clk); @(negedge clk);
        rst = 0;

        repeat (10) @(negedge clk);   // 多跑几拍让流水线走完
        #1;

        $display("x1=%0d (期望 5)", dut.regfile_i.regs[1]);
        $display("x2=%0d (期望 10)", dut.regfile_i.regs[2]);
        $display("x3=%0d (期望 8)", dut.regfile_i.regs[3]);
        $display("x4=%0d (期望 2)", dut.regfile_i.regs[4]);

        if (dut.regfile_i.regs[1]===32'd5 &&
            dut.regfile_i.regs[2]===32'd10 &&
            dut.regfile_i.regs[3]===32'd8 &&
            dut.regfile_i.regs[4]===32'd2)
            $display("==== PIPELINE ALL PASS ====");
        else
            $display("==== PIPELINE FAIL ====");

        $finish;
    end

endmodule
