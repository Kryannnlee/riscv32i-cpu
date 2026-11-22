`timescale 1ns/1ps
`default_nettype none

// ============================================================
// cpu_bench_tb -- 跑基准测试时不看期望值，只把串口输出转印到终端
//
// 和 cpu_uart_tb 的区别：那个逐字节断言，这个是"监视器"。
// 基准测试输出的是数字，事先算不出正确值，只能人眼看合理性。
//
// 超时给得比较宽：Dhrystone 500 轮在仿真里要跑上百万拍。
// ============================================================
module cpu_bench_tb;

    localparam int CPB    = 8;      // UART_CLK_FREQ / UART_BAUD_RATE
    localparam int RUN_NS = 40_000_000;   // 40ms 仿真时间，约 400 万拍

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
        .uart_rx     (1'b1)
    );

    always #5 clk = ~clk;           // 100MHz 仿真时钟

    int nbytes = 0;
    logic [7:0] b;
    int k;

    initial begin
        $display("==== Dhrystone 仿真（串口监视）====");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;

        forever begin
            @(negedge uart_tx);                      // 起始位
            repeat (CPB + CPB/2) @(posedge clk);     // 走到 bit0 中点
            for (k = 0; k < 8; k++) begin
                b[k] = uart_tx;
                repeat (CPB) @(posedge clk);
            end
            // 等停止位（线路变高）再找下一帧的下降沿。
            // 固定 repeat(CPB/2) 在背靠背发送时会正好踩在下一帧起始沿上，漏字节。
            while (!uart_tx) @(posedge clk);
            nbytes++;
            // 可打印字符直接输出，回车换行也照做
            if (b == 8'h0A) $write("\n");
            else if (b == 8'h0D) ;                   // CR 忽略
            else if (b >= 8'h20) $write("%c", b);
        end
    end

    // 看门狗：到点就收工
    initial begin
        #(RUN_NS);
        $display("\n==== 仿真结束：共收到 %0d 字节 ====", nbytes);
        if (nbytes == 0)
            $display("==== 失败：串口没有任何输出 ====");
        $finish;
    end

endmodule
`default_nettype wire
