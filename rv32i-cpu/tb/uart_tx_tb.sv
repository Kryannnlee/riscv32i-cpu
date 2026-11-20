`timescale 1ns/1ps

// UART 发送端 testbench
//
// 思路：不看波形，直接把 tx 线上的串行流"解码"回字节。
//   1. 等 tx 变低（起始位）
//   2. 等半个位周期，采样确认是 0
//   3. 之后每隔一个位周期采样一次，取 8 位（LSB 先）
//   4. 最后采样一次，确认停止位是 1
//
// 两个仿真细节（踩过）：
//   - tx 是组合输出，时钟沿后要过 delta 才稳定，采样前加 #1
//   - 用 while 等 tx 变低，不能用 @(negedge tx)：如果 tx 已经是低电平，
//     等下降沿会永远等不到（全 1 字节就会卡死）
module uart_tx_tb;

    localparam int CLK_FREQ  = 1000;
    localparam int BAUD_RATE = 100;
    localparam int CPB       = CLK_FREQ / BAUD_RATE;   // 每位 10 拍

    logic       clk = 0;
    logic       rst = 1;
    logic [7:0] data = 0;
    logic       send = 0;
    logic       tx;
    logic       busy;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .rst(rst),
        .data(data), .send(send),
        .tx(tx), .busy(busy)
    );

    always #5 clk = ~clk;      // 10ns 一拍

    int errors = 0;

    task automatic send_byte(input logic [7:0] b);
        logic [7:0] got;

        // 发一帧
        @(negedge clk);
        data = b; send = 1;
        @(negedge clk);
        send = 0;

        // 等起始位拉低（用 while，不用 @(negedge tx)）
        while (tx !== 1'b0) @(posedge clk);
        #1;

        // 起始位中间
        repeat (CPB/2) @(posedge clk); #1;
        if (tx !== 1'b0) begin
            $display("  FAIL 起始位不是 0");
            errors++;
        end

        // 8 个数据位，取中间采样
        got = 8'h00;
        for (int i = 0; i < 8; i++) begin
            repeat (CPB) @(posedge clk); #1;
            got[i] = tx;              // LSB 先
        end

        // 停止位
        repeat (CPB) @(posedge clk); #1;
        if (tx !== 1'b1) begin
            $display("  FAIL 停止位不是 1（收到 %b）", tx);
            errors++;
        end

        if (got === b) $display("  PASS 发送 %h -> 收到 %h", b, got);
        else begin
            $display("  FAIL 发送 %h -> 收到 %h", b, got);
            errors++;
        end

        // 等这一帧彻底发完（busy 落下）再返回。
        // 只在停止位中间采样完就返回的话，DUT 还在 STOP 状态，
        // 下一帧的 send 脉冲会被吞掉——表现为测试卡死。
        while (busy !== 1'b0) @(posedge clk);
        #1;
    endtask

    initial begin
        $dumpfile("sim/uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);

        @(negedge clk); @(negedge clk);
        rst = 0;
        @(negedge clk);

        // 空闲时 tx 必须是高
        #1;
        if (tx === 1'b1) $display("  PASS 空闲时 tx = 1");
        else begin $display("  FAIL 空闲时 tx = %b（应为 1）", tx); errors++; end

        $display("---- 单帧收发 ----");
        send_byte(8'h55);   // 0101_0101，位交替
        send_byte(8'hA3);   // 1010_0011
        send_byte(8'h00);   // 全 0，暴露停止位问题
        send_byte(8'hFF);   // 全 1，暴露起始位问题
        send_byte(8'h01);   // 只有最低位是 1，验 LSB first

        // 发完之后必须回到空闲
        repeat (CPB*2) @(posedge clk); #1;
        if (busy === 1'b0 && tx === 1'b1)
            $display("  PASS 发完回到空闲（busy=0, tx=1）");
        else begin
            $display("  FAIL 发完没回空闲（busy=%b, tx=%b）", busy, tx);
            errors++;
        end

        if (errors == 0) $display("==== UART_TX ALL PASS ====");
        else             $display("==== UART_TX FAIL: %0d ====", errors);

        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
