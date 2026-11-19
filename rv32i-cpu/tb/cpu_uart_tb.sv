`timescale 1ns/1ps
`default_nettype none

// ============================================================
// cpu_uart_tb -- 端到端验证：C 程序 -> MMIO -> UART -> 串行解码
//
// 链路上每一环都参与：
//   sw/prog.hex 里的 C 程序  ->  CPU 执行  ->  写 0x3000
//   ->  uart_tx 发送  ->  tx 串行波形  ->  本 testbench 解码回字节
//
// 波特率参数故意调小（CLK_FREQ/BAUD = 8），否则一位要 434 拍，
// 仿真会跑很久。真实上板用 50MHz/115200。
// ============================================================
module cpu_uart_tb;

    localparam int CPB = 8;         // = UART_CLK_FREQ / UART_BAUD_RATE

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
        .uart_tx     (uart_tx)
    );

    always #5 clk = ~clk;           // 100MHz 仿真时钟

    // 期望收到的 8 个字节："SUM=55" + CR + LF
    localparam int NBYTES = 8;
    logic [7:0] expect_bytes [0:NBYTES-1];
    logic [7:0] got_bytes    [0:NBYTES-1];

    int errors = 0;
    int n, k;
    logic [7:0] b;
    bit finished = 0;

    // 超时看门狗：C 程序不发数据的话，接收循环会永远等下去
    initial begin
        #500_000;
        if (!finished) begin
            $display("  FAIL   超时：%0d ns 内只收到 %0d 个字节", 500_000, n);
            $display("==== UART PROGRAM FAIL ====");
            $finish;
        end
    end

    initial begin
        expect_bytes[0] = 8'h53;  // 'S'
        expect_bytes[1] = 8'h55;  // 'U'
        expect_bytes[2] = 8'h4D;  // 'M'
        expect_bytes[3] = 8'h3D;  // '='
        expect_bytes[4] = 8'h35;  // '5'
        expect_bytes[5] = 8'h35;  // '5'
        expect_bytes[6] = 8'h0D;  // CR
        expect_bytes[7] = 8'h0A;  // LF

        $display("==== UART 端到端仿真（sw/prog.hex）====");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;

        for (n = 0; n < NBYTES; n++) begin
            @(negedge uart_tx);                  // 起始位开始
            repeat (CPB + CPB/2) @(posedge clk); // 走到 bit0 的中点

            for (k = 0; k < 8; k++) begin
                b[k] = uart_tx;
                repeat (CPB) @(posedge clk);
            end
            got_bytes[n] = b;
            repeat (CPB/2) @(posedge clk);       // 越过停止位

            if (got_bytes[n] === expect_bytes[n])
                $display("  PASS   第 %0d 字节 = 0x%02x ('%s')",
                         n, got_bytes[n], (got_bytes[n] >= 8'h20) ? got_bytes[n] : ".");
            else begin
                $display("  FAIL   第 %0d 字节 = 0x%02x，期望 0x%02x",
                         n, got_bytes[n], expect_bytes[n]);
                errors++;
            end
        end

        finished = 1;
        if (errors == 0)
            $display("==== UART PROGRAM PASS ====");
        else
            $display("==== UART PROGRAM FAIL（%0d 个字节不对）====", errors);
        $finish;
    end

endmodule
`default_nettype wire
