`timescale 1ns/1ps
`default_nettype none

// ============================================================
// cpu_c_tb -- C 程序的通用冒烟测试
//
// 故意**不依赖具体程序内容**，只查两件事：
//   1. PC 不出现 X（说明取指通路是干净的，不是从没初始化的地方取指令）
//   2. PC 始终落在 IMEM 范围内（说明没有跑飞）
//
// 为什么不查"程序跑完"：C 程序结尾是 `j .`，而流水线的跳转有 2 拍冲刷，
// 所以 `j .` 每 3 拍才执行一次，PC 在 {j, j+4, j+8} 之间循环，永远不会"停住"。
//
// 功能正确性由各自的专门 testbench 验证（例如 cpu_uart_tb 解码串口输出）。
// 这个测试的价值：改 main.c 以后不用改它，能一直当"没跑飞"的守门员。
// ============================================================
module cpu_c_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] dbg_pc, dbg_x1, dbg_xor_all;
    logic        uart_tx;

    cpu_pipe #(
        .USE_FILE      (1),
        .UART_CLK_FREQ (8_000_000),
        .UART_BAUD_RATE(1_000_000)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .dbg_pc      (dbg_pc),
        .dbg_x1      (dbg_x1),
        .dbg_xor_all (dbg_xor_all),
        .uart_tx     (uart_tx),
        .uart_rx     (1'b1)          // 本 tb 不测接收，让线上保持空闲高电平
    );

    always #5 clk = ~clk;

    localparam int TIMEOUT      = 20000;
    localparam logic [31:0] IMEM_TOP = 32'h0000_1000;   // IMEM 4KB

    int errors = 0;
    int i;
    int max_pc = 0;

    initial begin
        $display("==== C 程序冒烟测试（sw/prog.hex）====");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;

        for (i = 0; i < TIMEOUT; i++) begin
            @(posedge clk);

            if (^dut.pc === 1'bx) begin
                $display("  FAIL   第 %0d 拍 PC 出现 X", i);
                errors++;
                break;
            end

            if (dut.pc >= IMEM_TOP) begin
                $display("  FAIL   第 %0d 拍 PC=0x%08x 跑出 IMEM（>= 0x%08x）",
                         i, dut.pc, IMEM_TOP);
                errors++;
                break;
            end

            if (dut.pc > max_pc) max_pc = dut.pc;
        end

        if (errors == 0) begin
            $display("  PASS   %0d 拍内无 X、PC 未越界，最大 PC = 0x%08x",
                     TIMEOUT, max_pc);
            $display("==== C SMOKE PASS ====");
        end else begin
            $display("==== C SMOKE FAIL ====");
        end
        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
`default_nettype wire
