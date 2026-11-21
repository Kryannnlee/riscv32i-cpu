`timescale 1ns/1ps
`default_nettype none

// ============================================================
// uart_rx_tb -- 往接收端灌串行波形，看能不能解回原字节
//
// 测试内容：
//   1. 正常字节：00 / 55 / A3 / FF / 01（覆盖全 0、全 1、交替）
//   2. 假起始位：线上掉低 3 拍又回高（毛刺），不应该产生 valid
//
// 参数取 CLK_FREQ/BAUD = 16，让每位只有 16 个时钟周期，仿真快。
// 真实上板是 434。
// ============================================================
module uart_rx_tb;

    localparam int CPB = 16;          // = CLK_FREQ / BAUD_RATE

    logic       clk = 1'b0;
    logic       rst = 1'b1;
    logic       rx  = 1'b1;           // 空闲时线上是高
    logic [7:0] data;
    logic       valid;
    logic       busy;

    uart_rx #(
        .CLK_FREQ (16_000_000),
        .BAUD_RATE(1_000_000)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .rx   (rx),
        .data (data),
        .valid(valid),
        .busy (busy)
    );

    always #5 clk = ~clk;             // 100MHz 仿真时钟

    // 捕获 valid 那一刻的数据
    logic [7:0] got;
    int         got_cnt = 0;

    always @(posedge clk)
        if (valid) begin
            got <= data;
            got_cnt <= got_cnt + 1;
        end

    int errors = 0;
    int i;

    // 发一个字节：起始位 + 8 数据位（低位先）+ 停止位
    task automatic send_byte(input logic [7:0] b);
        begin
            rx = 1'b0;                          // 起始位
            repeat (CPB) @(posedge clk);
            for (i = 0; i < 8; i++) begin
                rx = b[i];                      // LSB first
                repeat (CPB) @(posedge clk);
            end
            rx = 1'b1;                          // 停止位
            repeat (CPB) @(posedge clk);
        end
    endtask

    // 注意：参数名不能叫 expect —— 那是 SystemVerilog 关键字（见 cases/case-07）
    task automatic check(input logic [7:0] exp_val);
        begin
            if (got_cnt == 0) begin
                $display("  FAIL: 没有收到字节（期望 0x%02x）", exp_val);
                errors++;
            end else if (got === exp_val) begin
                $display("  PASS: 收到 0x%02x", got);
            end else begin
                $display("  FAIL: 收到 0x%02x，期望 0x%02x", got, exp_val);
                errors++;
            end
            got_cnt = 0;
        end
    endtask

    initial begin
        $display("==== UART RX 仿真（CPB=%0d）====", CPB);

        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // ---- 正常字节 ----
        send_byte(8'h00);  repeat (2*CPB) @(posedge clk);  check(8'h00);
        send_byte(8'h55);  repeat (2*CPB) @(posedge clk);  check(8'h55);
        send_byte(8'hA3);  repeat (2*CPB) @(posedge clk);  check(8'hA3);
        send_byte(8'hFF);  repeat (2*CPB) @(posedge clk);  check(8'hFF);
        send_byte(8'h01);  repeat (2*CPB) @(posedge clk);  check(8'h01);

        // ---- 假起始位：只掉低 3 拍就回高 ----
        got_cnt = 0;
        rx = 1'b0;
        repeat (3) @(posedge clk);
        rx = 1'b1;
        repeat (12*CPB) @(posedge clk);       // 等足够长，看会不会误收
        if (got_cnt == 0)
            $display("  PASS 假起始位: 正确忽略，没有产生 valid");
        else begin
            $display("  FAIL 假起始位: 误收到 0x%02x", got);
            errors++;
        end

        // ---- 假起始位之后仍能正常收 ----
        send_byte(8'h3C);  repeat (2*CPB) @(posedge clk);  check(8'h3C);

        if (errors == 0)
            $display("==== UART RX ALL PASS ====");
        else
            $display("==== UART RX FAIL: %0d 处 ====", errors);

        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
`default_nettype wire
