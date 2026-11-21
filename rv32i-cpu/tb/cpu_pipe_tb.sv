`timescale 1ns/1ps

module cpu_pipe_tb;
    logic clk = 0;
    logic rst = 1;

    cpu_pipe dut (.clk(clk), .rst(rst), .uart_rx(1'b1));   // rx 空闲为高

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

    // ── 性能计数 ──
    // 两个不同的"指令条数"，别混：
    //   PROG_WORDS   = imem 里写了多少条（静态），含被跳过的毒药
    //   PROG_RETIRED = 真正执行了多少条（动态）= 静态 - 被跳过的
    //
    // 被跳过的 8 条，都是某条跳转落点的前一条：
    //   mem[12] beq@11   | mem[14] bne@13
    //   mem[19] mem[20] jal@18
    //   mem[25] jalr@24  | mem[46] bltu@45
    //   mem[52] bge@51   | mem[55] bgeu@54
    //   57 - 8 = 49。CPI 的分母是 49，不是 57。
    //
    // 以前这里写 57，理想拍数算大了，实测反而"小于理想"，
    // 于是得出了"加法模型不成立"的错误结论。模型其实是准的。
    localparam int PROG_WORDS   = 57;
    localparam int PROG_RETIRED = 49;

    // 交叉验证用的实测值：
    //   最后一条程序指令是 mem[56] addi x18, x0, 888，
    //   它写 x18 的那一拍就是"程序跑完"的时刻。
    //   x18 还被 mem[52]/mem[55] 的毒药写过，但那两条被跳过了，
    //   正常执行只写这一次（写两次说明跳转坏了，check(18,888) 会报）。
    int cycles = 0;
    int cyc_done = 0;
    always @(posedge clk) begin
        if (!rst) begin
            cycles++;
            if (cyc_done == 0 && dut.mem_wb_reg_write && dut.mem_wb_rd == 5'd18)
                cyc_done = cycles;
        end
    end

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

        // 等到最后一条（第 49 条）写回：预测 49 + 4 + 1 + 7x2 = 68 拍，多等一些无妨
        repeat (95) @(negedge clk);
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

        // ---- 字节 / 半字访存 ----
        // sb 两次（0x23@20, 0x01@21）再用 lw 读回，验证小端拼接
        check(26, 32'h0000_0123); // ★ sb + sb + lw
        check(27, 32'hFFFF_FFFF); // ★ lb  符号扩展（0xFF -> -1）
        check(28, 32'h0000_00FF); // ★ lbu 零扩展
        check(29, 32'hFFFF_FFFE); // ★ lh  符号扩展（0xFFFE -> -2）
        check(30, 32'h0000_FFFE); // ★ lhu 零扩展

        // ---- 四条新分支（有符号/无符号结果相反的取值）----
        check(15, 32'd111);       // ★ blt 不该跳（1 < -1 为假）
        check(16, 32'd333);       // ★ bge 不该跳（-1 >= 1 为假）
        check(17, 32'd444);       // ★ bgeu 不该跳（1 >= 42亿 为假）
        check(19, 32'd666);       // ★ bge 该跳（1 >= -1 为真），跳过 555
        check(18, 32'd888);       // ★ bgeu 该跳（42亿 >= 1 为真），跳过 777


        if (stall_count == 1)
            $display("  PASS   stall 次数 = %0d", stall_count);
        else begin
            $display("  FAIL   stall 次数 = %0d，期望 1", stall_count);
            errors++;
        end

        if (redirect_count == 7)
            $display("  PASS   改道次数 = %0d（原 4 次 + 新分支 3 次）", redirect_count);
        else begin
            $display("  FAIL   改道次数 = %0d，期望 7", redirect_count);
            errors++;
        end

        // ── 性能数据：实测拍数 vs 公式预测，两边必须相等 ──
        //   预测拍数 = 退休指令数 + 4（流水线填充）
        //              + 停顿 x1 + 改道 x2（冲刷两级，EX 里插两个气泡）
        begin
            int predicted;
            predicted = PROG_RETIRED + 4 + stall_count + 2 * redirect_count;
            $display("---- 性能 ----");
            $display("  imem 写了 %0d 条，实际执行 %0d 条（跳转跳过 %0d 条）",
                     PROG_WORDS, PROG_RETIRED, PROG_WORDS - PROG_RETIRED);
            $display("  实测 %0d 拍跑完，CPI = %.3f",
                     cyc_done, real'(cyc_done) / real'(PROG_RETIRED));
            $display("  公式预测 = %0d(执行) + 4(填充) + %0d(停顿) + 2x%0d(改道) = %0d 拍",
                     PROG_RETIRED, stall_count, redirect_count, predicted);
            if (cyc_done == predicted)
                $display("  PASS   实测与公式一致（%0d = %0d）", cyc_done, predicted);
            else begin
                $display("  FAIL   实测 %0d 拍，公式预测 %0d 拍", cyc_done, predicted);
                errors++;
            end
        end

        if (errors == 0)
            $display("==== PIPELINE ALL PASS ====");
        else
            $display("==== PIPELINE FAIL: %0d 处错误 ====", errors);

        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
