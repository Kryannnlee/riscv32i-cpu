`timescale 1ns/1ps
`default_nettype none

// ============================================================
// fpga_top -- 上板用的顶层（BX71 / XC7Z020CLG400-2I）
//
// 和仿真顶层 cpu_pipe 的区别：
//   1. 有真正的输出（LED + UART TX），否则综合器会把整个设计优化成空
//   2. 复位有两个来源：上电计数器 + 板上按键
//   3. CPU 从 sw/prog.hex 加载 C 程序（USE_FILE=1）
//
// 引脚（来自 fpga/rv32i.xdc）：clk=U18  rst_n=T19  led[0]=T10  uart_tx=K19
// 板载只有 1 个 LED，其余在 GPIO 排针上，不接线看不到
// ============================================================
module fpga_top (
    input  logic       clk,      // 50MHz，U18
    input  logic       rst_n,    // 复位按键，低有效，T19
    output logic [3:0] led,
    output logic       uart_tx,  // 串口发送，K19（接 USB-TTL 的 RX）
    input  logic       uart_rx,  // 串口接收，J19（接 USB-TTL 的 TX）
    // 所有寄存器的异或（单比特）。没有任何实际用途，
    // 存在的目的是让 32 个通用寄存器全部"可观测"，
    // 否则综合器会把没人读的寄存器当死代码删掉，资源统计就不准了
    output logic       dbg_alive
);

    // -- 上电复位：前 256 拍保持复位 --
    logic [7:0] rst_cnt = 8'd0;
    logic       rst_por;

    always_ff @(posedge clk)
        if (!rst_cnt[7])
            rst_cnt <= rst_cnt + 8'd1;

    assign rst_por = ~rst_cnt[7];

    // 上电复位 或 按下按键，都是复位
    logic rst;
    assign rst = rst_por | ~rst_n;

    // -- CPU --
    logic [31:0] dbg_pc, dbg_x1, dbg_xor_all;

    cpu_pipe #(
        .USE_FILE      (1),               // 从 sw/prog.hex 加载 C 程序
        .UART_CLK_FREQ (50_000_000),
        .UART_BAUD_RATE(115200)
    ) u_cpu (
        .clk         (clk),
        .rst         (rst),
        .dbg_pc      (dbg_pc),
        .dbg_x1      (dbg_x1),
        .dbg_xor_all (dbg_xor_all),
        .uart_tx     (uart_tx),
        .uart_rx     (uart_rx)
    );

    // -- 调试输出 --
    // led[0]：诊断用心跳。用独立计数器，每 2^24 拍翻转一次
    //         50MHz -> 约 1.5Hz，肉眼明显可见。
    //         它和 CPU 无关：只要时钟在跑，灯就一定闪。
    //         灯闪 = 时钟和引脚都对，后面再查 CPU 内部。
    // led[3:1]：x1 的低 3 位，需要外接 GPIO LED 才看得到
    logic [24:0] blink_cnt = 25'd0;
    always_ff @(posedge clk)
        blink_cnt <= blink_cnt + 25'd1;

    // led[0]：心跳。只要时钟在跑就闪，证明设计活着。
    // C 程序的运行结果从 UART 输出，不再用 LED 编码。
    assign led[0]   = blink_cnt[24];
    assign led[3:1] = dbg_x1[2:0];

    // 把所有寄存器异或成一比特。纯粹为了"保住"整个数据通路不被优化
    assign dbg_alive = ^dbg_xor_all;

endmodule

`default_nettype wire
