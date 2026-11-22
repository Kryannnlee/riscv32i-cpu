`timescale 1ns/1ps
`default_nettype none

// ============================================================
// div_unit_tb -- 除法器单元测试
//
// 重点测边界：除零、溢出（INT_MIN/-1）、四种符号组合。
// 正常除法反而不容易错。
// ============================================================
module div_unit_tb;

    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic        start = 1'b0;
    logic        is_signed = 1'b0;
    logic        want_rem = 1'b0;
    logic [31:0] dividend = 32'd0;
    logic [31:0] divisor  = 32'd0;
    logic [31:0] result;
    logic        busy;
    logic        done;

    div_unit dut (
        .clk(clk), .rst(rst), .start(start),
        .is_signed(is_signed), .want_rem(want_rem),
        .dividend(dividend), .divisor(divisor),
        .result(result), .busy(busy), .done(done)
    );

    always #5 clk = ~clk;

    int errors = 0;
    logic [31:0] got;

    task automatic do_div(input logic [31:0] a, input logic [31:0] b,
                          input logic sgn, input logic want_r);
        int t;
        begin
            // 在**下降沿**驱动信号。
            // 如果写成 "start=1; @(posedge clk); start=0;"，
            // tb 和 DUT 的 always_ff 会在同一次边沿被唤醒，
            // 谁先执行不确定 —— 万一 tb 先跑，DUT 就看不到 start=1。
            @(negedge clk);
            dividend  = a;
            divisor   = b;
            is_signed = sgn;
            want_rem  = want_r;
            start     = 1'b1;
            @(negedge clk);
            start = 1'b0;

            // 等 done。边沿之后 #1 再采样：done 是 always_ff 的非阻塞赋值，
            // 边沿那一刻还没更新，而它只高一个周期。
            for (t = 0; t < 200; t++) begin
                @(posedge clk);
                #1;
                if (done) break;
            end

            got = result;
        end
    endtask

    task automatic chk(input logic [31:0] exp_val, input [127:0] name);
        begin
            if (got === exp_val)
                $display("  PASS %0s: 0x%08x", name, got);
            else begin
                $display("  FAIL %0s: 得到 0x%08x，期望 0x%08x", name, got, exp_val);
                errors++;
            end
        end
    endtask

    initial begin
        $display("==== div_unit 测试 ====");

        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;

        // ---- 无符号商 ----
        do_div(32'd42,  32'd5, 1'b0, 1'b0);  chk(32'd8,    "42/5 商");
        do_div(32'd42,  32'd5, 1'b0, 1'b1);  chk(32'd2,    "42%5 余");
        do_div(32'd100, 32'd7, 1'b0, 1'b0);  chk(32'd14,   "100/7 商");
        do_div(32'd100, 32'd7, 1'b0, 1'b1);  chk(32'd2,    "100%7 余");
        do_div(32'd0,   32'd5, 1'b0, 1'b0);  chk(32'd0,    "0/5");
        do_div(32'hFFFF_FFFF, 32'd2, 1'b0, 1'b0); chk(32'h7FFF_FFFF, "0xFFFFFFFF/2 商");
        do_div(32'hFFFF_FFFF, 32'd2, 1'b0, 1'b1); chk(32'd1,          "0xFFFFFFFF/2 余");

        // ---- 除零：商全 1，余数=被除数 ----
        do_div(32'd42, 32'd0, 1'b0, 1'b0);   chk(32'hFFFF_FFFF, "除零 商");
        do_div(32'd42, 32'd0, 1'b0, 1'b1);   chk(32'd42,         "除零 余");

        // ---- 有符号：四种符号组合 ----
        do_div(32'd42,  32'd5,  1'b1, 1'b0); chk(32'd8,          " 42/ 5 商");
        do_div(32'd42,  32'd5,  1'b1, 1'b1); chk(32'd2,          " 42% 5 余");
        do_div(32'hFFFF_FFD6, 32'd5, 1'b1, 1'b0); chk(32'hFFFF_FFF8, "-42/ 5 商");  // -42/5 = -8
        do_div(32'hFFFF_FFD6, 32'd5, 1'b1, 1'b1); chk(32'hFFFF_FFFE, "-42% 5 余");  // 余数符号跟被除数 = -2
        do_div(32'd42,  32'hFFFF_FFFB, 1'b1, 1'b0); chk(32'hFFFF_FFF8, " 42/-5 商"); // = -8
        do_div(32'd42,  32'hFFFF_FFFB, 1'b1, 1'b1); chk(32'd2,          " 42%-5 余"); // 余数符号跟被除数 = +2
        do_div(32'hFFFF_FFD6, 32'hFFFF_FFFB, 1'b1, 1'b0); chk(32'd8,          "-42/-5 商");
        do_div(32'hFFFF_FFD6, 32'hFFFF_FFFB, 1'b1, 1'b1); chk(32'hFFFF_FFFE, "-42%-5 余"); // -2

        // ---- 有符号溢出：INT_MIN / -1 ----
        do_div(32'h8000_0000, 32'hFFFF_FFFF, 1'b1, 1'b0); chk(32'h8000_0000, "INT_MIN/-1 商");
        do_div(32'h8000_0000, 32'hFFFF_FFFF, 1'b1, 1'b1); chk(32'd0,          "INT_MIN/-1 余");

        // ---- 大数：验证 33 位余数没溢出 ----
        do_div(32'hFFFF_FFFE, 32'hFFFF_FFFF, 1'b0, 1'b0); chk(32'd0,          "大数/大数 商");
        do_div(32'hFFFF_FFFE, 32'hFFFF_FFFF, 1'b0, 1'b1); chk(32'hFFFF_FFFE,  "大数%大数 余");

        if (errors == 0) $display("==== DIV_UNIT ALL PASS ====");
        else             $display("==== DIV_UNIT FAIL: %0d 处 ====", errors);

        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
`default_nettype wire
