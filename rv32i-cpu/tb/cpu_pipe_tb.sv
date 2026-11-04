`timescale 1ns/1ps

module cpu_pipe_tb;
    logic clk = 0;
    logic rst = 1;

    cpu_pipe dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;          // 周期 10ns

    // 程序写在 rtl/imem.sv 里，分三段：
    //   mem[0..5]   转发      x1=5 x2=10 x3=8 x4=18 x6=99
    //   mem[6..9]   load-use  x5=18 x7=36 x10=18 x9=10
    //   mem[10..17] 分支      x11=3 x12=2
    //                beq 跳过 mem[12]，bne 跳过 mem[14]，最后一条 bne 不该跳
    //   mem[18..27] 跳转/U型  x1=76 x23=1 x21=104 x24=1 x20=0x12345000
    //                jal 跳过 mem[19..20]，jalr 跳过 mem[25]，lui 测 U 型立即数

    int errors = 0;
    int stall_count = 0;
    int redirect_count = 0;

    // 停了几拍：6b 误停修没修好的证据
    always @(posedge clk)
        if (!rst && dut.stall) stall_count++;

    // 跳了几次：6d 分支冲刷是否真的发生
    always @(posedge clk)
        if (!rst && dut.pc_redirect) redirect_count++;

    task automatic check(input int idx, input logic [31:0] exp);
        logic [31:0] got;
        got = dut.regfile_i.regs[idx];
        if (got === exp)
            $display("  PASS   x%0d = %0d", idx, got);
        else begin
            $display("  FAIL   x%0d = %0d   期望 %0d", idx, got, exp);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("sim/cpu_pipe.vcd");
        $dumpvars(0, cpu_pipe_tb);

        @(negedge clk); @(negedge clk);
        rst = 0;

        // 28 条指令 + 5 级填充 + 1 拍停顿 + 4 次改道各罚 2 拍 ≈ 38 拍
        repeat (50) @(negedge clk);
        #1;

        $display("---- 转发 / 停顿 / 分支 / 跳转 ----");
        // x1 最后会被 jal 覆盖成返回地址，所以不单独检查 x1 = 5；
        // 但 x2 = x1+x1 = 10 依赖它，已经间接覆盖了第一条指令。
        check(2,  32'd10);      // 6a 时这里是 0
        check(3,  32'd8);
        check(4,  32'd18);      // EX/MEM + MEM/WB 同时用到
        check(6,  32'd99);
        check(5,  32'd18);      // sw → DMEM → lw 一整圈
        check(7,  32'd36);      // ★ load-use：不停拍会算错
        check(10, 32'd18);
        check(9,  32'd10);      // ★ 假相关：不该因此停拍
        check(11, 32'd3);       // ★ 三条毒药都被跳过
        check(12, 32'd2);       // ★ 最后一条 bne 不该跳
        check(1,  32'd76);      // ★ jal 写回的返回地址 = 72+4
        check(23, 32'd1);       // ★ jal 落在正确的位置
        check(21, 32'd104);     // ★ auipc + addi 算出 88+16
        check(24, 32'd1);       // ★ jalr 跳到 104
        check(20, 32'h12345000); // ★ lui：20 位立即数搬到高位

        if (stall_count == 1)
            $display("  PASS   stall 次数 = %0d", stall_count);
        else begin
            $display("  FAIL   stall 次数 = %0d，期望 1", stall_count);
            errors++;
        end

        if (redirect_count == 4)
            $display("  PASS   改道次数 = %0d（2 分支 + 1 JAL + 1 JALR）", redirect_count);
        else begin
            $display("  FAIL   改道次数 = %0d，期望 4", redirect_count);
            errors++;
        end

        if (errors == 0)
            $display("==== PIPELINE ALL PASS ====");
        else
            $display("==== PIPELINE FAIL: %0d 处错误 ====", errors);

        $finish;
    end

endmodule
