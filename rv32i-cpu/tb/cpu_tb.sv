`timescale 1ns/1ps

module cpu_tb;
    logic clk = 0;
    logic rst = 1;

    cpu_top dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;          // 周期 10ns

    // 程序写在 rtl/imem.sv 里，和 cpu_pipe_tb 用的是同一份。
    // 单周期没有冒险问题，流水线有——两边跑同一程序、比同一份结果，
    // 就是一个免费的等价性检查：流水线加转发之后必须和单周期结果一致。
    //   addi x1, x0, 5     x1 = 5
    //   add  x2, x1, x1    x2 = 10
    //   addi x3, x0, 8     x3 = 8
    //   add  x4, x2, x3    x4 = 18
    //   sw   x4, 0(x3)     DMEM[8] = 18
    //   addi x6, x0, 99    x6 = 99
    //   lw   x5, 0(x3)     x5 = 18
    //   add  x7, x5, x5    x7 = 36   ← 流水线里这一条要停一拍，单周期不用
    //   lw   x10, 0(x3)    x10 = 18
    //   addi x9, x0, 10    x9 = 10
    //   addi x11, x0, 3    x11 = 3
    //   beq  x1, x1, +8    跳过下一条（毒药）
    //   addi x11, x0, 111  应被跳过
    //   bne  x1, x2, +8    5≠10，跳过下一条（毒药）
    //   addi x11, x0, 222  应被跳过
    //   addi x12, x0, 1    x12 = 1
    //   bne  x1, x1, +8    相等，不该跳
    //   addi x12, x0, 2    x12 = 2

    int errors = 0;

    task automatic check(input int idx, input logic [31:0] exp);
        logic [31:0] got;
        got = dut.register_file.regs[idx];
        if (got === exp)
            $display("  PASS   x%0d = %0d", idx, got);
        else begin
            $display("  FAIL   x%0d = %0d   期望 %0d", idx, got, exp);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("sim/cpu.vcd");
        $dumpvars(0, cpu_tb);

        @(negedge clk); @(negedge clk);
        rst = 0;

        repeat (70) @(negedge clk);   // 41 条指令，单周期每拍一条，留余量
        #1;

        $display("---- 单周期 CPU 测试 ----");
        check(2,  32'd10);
        check(3,  32'd8);
        check(4,  32'd18);
        check(6,  32'd99);
        check(5,  32'd18);
        check(7,  32'd36);
        check(10, 32'd18);
        check(9,  32'd10);
        check(11, 32'd3);       // 五条毒药都没执行
        check(12, 32'd2);       // 最后一条 bne 没跳
        check(1,  32'd76);      // jal 的返回地址
        check(23, 32'd1);
        check(21, 32'd104);
        check(24, 32'd1);
        check(20, 32'h12345000);
        check(26, 32'h0000_0123); // sb + sb + lw
        check(27, 32'hFFFF_FFFF); // lb
        check(28, 32'h0000_00FF); // lbu
        check(29, 32'hFFFF_FFFE); // lh
        check(30, 32'h0000_FFFE); // lhu
        check(15, 32'd111);
        check(16, 32'd333);
        check(17, 32'd444);
        check(19, 32'd666);
        check(18, 32'd888);

        if (errors == 0)
            $display("==== ALL PASS ====");
        else
            $display("==== FAIL: %0d 处错误 ====", errors);

        $finish;
    end

endmodule
