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
    logic        uart_rx_line = 1'b1;   // 空闲时线上为高，由本 tb 驱动

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
        .uart_rx     (uart_rx_line)  // 由下面的 send_byte 驱动
    );

    always #5 clk = ~clk;           // 100MHz 仿真时钟

    // 期望收到 41 个字节：
    //   "Hello!\r\n" + "A=42\r\n" + "B=8\r\n" + "C=2\r\n" + "beef ok!\r\n" + "got K\r\n"
    localparam int NBYTES = 41;
    logic [7:0] expect_bytes [0:NBYTES-1];
    logic [7:0] got_bytes    [0:NBYTES-1];

    int errors = 0;
    int n, k;
    logic [7:0] b;
    bit finished = 0;

    // 向 CPU 发一个字节。
    // 每位 8 拍，和 DUT 的 UART_CLK_FREQ/UART_BAUD_RATE = 8MHz/1MHz 一致。
    // 参数名不能叫 b（模块级已有同名变量），也不能叫 expect（SV 关键字）。
    int j;
    task automatic send_byte(input logic [7:0] byte_v);
        begin
            uart_rx_line = 1'b0;                      // 起始位
            repeat (8) @(posedge clk);
            for (j = 0; j < 8; j++) begin
                uart_rx_line = byte_v[j];             // 低位先发
                repeat (8) @(posedge clk);
            end
            uart_rx_line = 1'b1;                      // 停止位
            repeat (8) @(posedge clk);
        end
    endtask

    // 给 CPU 发一个 'K'，它收到后会回显 "got K"。
    // 必须放独立 initial：send_byte 要占 10×8 拍，
    // 如果串在接收循环前面，这期间 CPU 已经开始打印，开头的字节会被错过。
    // （软件除法时代程序启动慢，没撞上；换成硬件除法后启动快了，才暴露。）
    initial begin
        repeat (24) @(posedge clk);
        send_byte(8'h4B);
    end

    // 超时看门狗：C 程序不发数据的话，接收循环会永远等下去
    initial begin
        #2_000_000;      // 软件除法是 32 次移位循环，比原来慢很多，余量给足
        if (!finished) begin
            $display("  FAIL   超时：%0d ns 内只收到 %0d 个字节", 2_000_000, n);
            $display("==== UART PROGRAM FAIL ====");
            $finish;
        end
    end

    initial begin
        // "Hello!\r\n" —— 这 8 个字节来自 .rodata，读得到就说明数据段加载成功
        expect_bytes[0]  = 8'h48;  // 'H'
        expect_bytes[1]  = 8'h65;  // 'e'
        expect_bytes[2]  = 8'h6C;  // 'l'
        expect_bytes[3]  = 8'h6C;  // 'l'
        expect_bytes[4]  = 8'h6F;  // 'o'
        expect_bytes[5]  = 8'h21;  // '!'
        expect_bytes[6]  = 8'h0D;  // CR
        expect_bytes[7]  = 8'h0A;  // LF
        expect_bytes[8]  = 8'h41;  // 'A'
        expect_bytes[9]  = 8'h3D;  // '='
        expect_bytes[10] = 8'h34;  // '4'
        expect_bytes[11] = 8'h32;  // '2'
        expect_bytes[12] = 8'h0D;  // CR
        expect_bytes[13] = 8'h0A;  // LF
        expect_bytes[14] = 8'h42;  // 'B'
        expect_bytes[15] = 8'h3D;  // '='
        expect_bytes[16] = 8'h38;  // '8'
        expect_bytes[17] = 8'h0D;  // CR
        expect_bytes[18] = 8'h0A;  // LF
        expect_bytes[19] = 8'h43;  // 'C'
        expect_bytes[20] = 8'h3D;  // '='
        expect_bytes[21] = 8'h32;  // '2'
        expect_bytes[22] = 8'h0D;  // CR
        expect_bytes[23] = 8'h0A;  // LF
        // "beef ok!\r\n" —— 来自 printf_ 的 %x %s %c
        expect_bytes[24] = 8'h62;  // 'b'
        expect_bytes[25] = 8'h65;  // 'e'
        expect_bytes[26] = 8'h65;  // 'e'
        expect_bytes[27] = 8'h66;  // 'f'
        expect_bytes[28] = 8'h20;  // ' '
        expect_bytes[29] = 8'h6F;  // 'o'
        expect_bytes[30] = 8'h6B;  // 'k'
        expect_bytes[31] = 8'h21;  // '!'
        expect_bytes[32] = 8'h0D;  // CR
        expect_bytes[33] = 8'h0A;  // LF
        // "got K\r\n" —— CPU 从串口收到 'K' 后回显，验证接收通路
        expect_bytes[34] = 8'h67;  // 'g'
        expect_bytes[35] = 8'h6F;  // 'o'
        expect_bytes[36] = 8'h74;  // 't'
        expect_bytes[37] = 8'h20;  // ' '
        expect_bytes[38] = 8'h4B;  // 'K'  ← 就是 tb 发过去的那个字节
        expect_bytes[39] = 8'h0D;  // CR
        expect_bytes[40] = 8'h0A;  // LF

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

            // 等停止位（线路回到高电平），再回到循环开头等下一帧的下降沿。
            // 不能写固定的 repeat(CPB/2)：背靠背发送时那正好落在下一帧的
            // 起始沿上，会漏掉一个字节（以前 CPU 慢、字符间有空隙才没暴露）。
            while (!uart_tx) @(posedge clk);

            if (got_bytes[n] === expect_bytes[n])
                $display("  PASS   第 %0d 字节 = 0x%02x ('%s')",
                         n, got_bytes[n], (got_bytes[n] >= 8'h20) ? got_bytes[n] : ".");
            else begin
                $display("  FAIL   第 %0d 字节 = 0x%02x，期望 0x%02x",
                         n, got_bytes[n], expect_bytes[n]);
                errors++;
            end
        end

        // 顺带验证：整个 C 程序跑下来，不该出现任何未对齐访存
        if (dut.dbg_misalign !== 1'b0) begin
            $display("  FAIL 程序运行期间出现过未对齐的 load/store");
            errors++;
        end else begin
            $display("  PASS 全程没有未对齐访存");
        end

        finished = 1;
        if (errors == 0)
            $display("==== UART PROGRAM PASS ====");
        else
            $display("==== UART PROGRAM FAIL（%0d 个字节不对）====", errors);
        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
`default_nettype wire
