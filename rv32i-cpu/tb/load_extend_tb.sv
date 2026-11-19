`timescale 1ns/1ps

module load_extend_tb;
    logic [31:0] word;
    logic [1:0]  addr_lo;
    logic [2:0]  funct3;
    logic [31:0] data;

    load_extend dut (
        .word   (word),
        .addr_lo(addr_lo),
        .funct3 (funct3),
        .data   (data)
    );

    int errors = 0;

    task automatic check(input [31:0] exp, input [127:0] msg);
        #1;
        if (data === exp)
            $display("PASS: %0s -> %h", msg, data);
        else begin
            $display("FAIL: %0s -> %h  (期望 %h)", msg, data, exp);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("sim/load_extend.vcd");
        $dumpvars(0, load_extend_tb);

        // 小端：word = DEADBEEF
        //   byte0 = EF, byte1 = BE, byte2 = AD, byte3 = DE
        //   half0 = BEEF, half1 = DEAD
        word = 32'hDEADBEEF;

        // ---- lb（符号扩展）----
        funct3 = 3'b000;
        addr_lo = 2'd0;  check(32'hFFFF_FFEF, "lb  byte0");
        addr_lo = 2'd1;  check(32'hFFFF_FFBE, "lb  byte1");
        addr_lo = 2'd2;  check(32'hFFFF_FFAD, "lb  byte2");
        addr_lo = 2'd3;  check(32'hFFFF_FFDE, "lb  byte3");

        // ---- lbu（零扩展）----
        funct3 = 3'b100;
        addr_lo = 2'd0;  check(32'h0000_00EF, "lbu byte0");
        addr_lo = 2'd3;  check(32'h0000_00DE, "lbu byte3");

        // ---- lh（符号扩展）----
        funct3 = 3'b001;
        addr_lo = 2'd0;  check(32'hFFFF_BEEF, "lh  低半字");
        addr_lo = 2'd2;  check(32'hFFFF_DEAD, "lh  高半字");

        // ---- lhu（零扩展）----
        funct3 = 3'b101;
        addr_lo = 2'd0;  check(32'h0000_BEEF, "lhu 低半字");
        addr_lo = 2'd2;  check(32'h0000_DEAD, "lhu 高半字");

        // ---- lw（原样）----
        funct3 = 3'b010;
        addr_lo = 2'd0;  check(32'hDEAD_BEEF, "lw");
        addr_lo = 2'd3;  check(32'hDEAD_BEEF, "lw  忽略 addr_lo");

        // ---- 正数场景：确认 lb 不会错误地扩展出高位 ----
        word = 32'h0000_007F;
        funct3 = 3'b000; addr_lo = 2'd0;
        check(32'h0000_007F, "lb  正数 0x7F 不扩展");

        if (errors == 0) $display("==== LOAD_EXTEND ALL PASS ====");
        else             $display("==== LOAD_EXTEND FAIL: %0d ====", errors);

        $finish;
    end

endmodule
