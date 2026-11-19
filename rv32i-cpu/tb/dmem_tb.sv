`timescale 1ns/1ps

module dmem_tb;
    logic        clk;
    logic        we;
    logic [3:0]  be;
    logic [31:0] addr;
    logic [31:0] wr_data;
    logic [31:0] rd_data;

    dmem dut (
        .clk(clk),
        .we(we),
        .be(be),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    int errors = 0;

    task automatic check(input [31:0] exp, input [127:0] msg);
        if (rd_data === exp)
            $display("PASS: %0s -> %h", msg, rd_data);
        else begin
            $display("FAIL: %0s -> %h  (期望 %h)", msg, rd_data, exp);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("sim/dmem.vcd");
        $dumpvars(0, dmem_tb);

        we = 0; be = 4'b0000; addr = 32'd0; wr_data = 32'd0;
        @(negedge clk);

        // ---- 1) 整字写读 ----
        addr = 32'd16; wr_data = 32'hDEADBEEF; we = 1; be = 4'b1111;
        @(negedge clk);
        we = 0; #1;
        check(32'hDEADBEEF, "整字写读");

        // ---- 2) we=0 写保护 ----
        addr = 32'd16; wr_data = 32'h12345678; we = 0; be = 4'b1111;
        @(negedge clk); #1;
        check(32'hDEADBEEF, "we=0 写保护");

        // ---- 3) 字节写：只改最低字节 ----
        // 原值 DEADBEEF，写 0xAA 到 byte0 -> DEADBEAA
        addr = 32'd16; wr_data = 32'h000000AA; we = 1; be = 4'b0001;
        @(negedge clk);
        we = 0; #1;
        check(32'hDEADBEAA, "sb 写最低字节");

        // ---- 4) 半字写：只改低半字 ----
        // 原值 DEADBEAA，写 0x5678 到低半字 -> DEAD5678
        addr = 32'd16; wr_data = 32'h12345678; we = 1; be = 4'b0011;
        @(negedge clk);
        we = 0; #1;
        check(32'hDEAD5678, "sh 写低半字");

        // ---- 5) 半字写：只改高半字（地址 +2，addr[1]=1）----
        // 原值 DEAD5678，写 0x1234 到高半字 -> 12345678
        addr = 32'd18; wr_data = 32'h12345678; we = 1; be = 4'b1100;
        @(negedge clk);
        we = 0; #1;
        check(32'h12345678, "sh 写高半字");

        if (errors == 0) $display("==== DMEM ALL PASS ====");
        else             $display("==== DMEM FAIL: %0d ====", errors);

        $finish;
    end

endmodule
