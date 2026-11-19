`timescale 1ns/1ps
`default_nettype none

module imem_tb;
    logic [31:0] addr, instr;
    imem dut (.addr(addr), .instr(instr));

    // 期望内容必须和 rtl/imem.sv 里的程序保持一致。
    // 注意：这说明 imem_tb 和"仿真程序"耦合了——改程序就得改这里。
    logic [31:0] expected [0:56];
    int i;
    int errors = 0;

    initial begin
        $dumpfile("sim/imem.vcd");
        $dumpvars(0, imem_tb);

        expected[0] = 32'h00500093;  // addi x1, x0, 5
        expected[1] = 32'h00108133;  // add  x2, x1, x1
        expected[2] = 32'h00800193;  // addi x3, x0, 8
        expected[3] = 32'h00310233;  // add  x4, x2, x3
        expected[4] = 32'h0041A023;  // sw   x4, 0(x3)
        expected[5] = 32'h06300313;  // addi x6, x0, 99
        expected[6] = 32'h0001A283;  // lw   x5, 0(x3)
        expected[7] = 32'h005283B3;  // add  x7, x5, x5     ★ 真 load-use
        expected[8] = 32'h0001A503;  // lw   x10, 0(x3)
        expected[9]  = 32'h00A00493;  // addi x9, x0, 10     ★ 假相关（instr[24:20]=10=x10）
        expected[10] = 32'h00300593;  // addi x11, x0, 3
        expected[11] = 32'h00108463;  // beq  x1, x1, +8     跳
        expected[12] = 32'h06F00593;  // addi x11, x0, 111   毒药
        expected[13] = 32'h00209463;  // bne  x1, x2, +8     跳
        expected[14] = 32'h0DE00593;  // addi x11, x0, 222   毒药
        expected[15] = 32'h00100613;  // addi x12, x0, 1
        expected[16] = 32'h00109463;  // bne  x1, x1, +8     不跳
        expected[17] = 32'h00200613;  // addi x12, x0, 2
        expected[18] = 32'h00C000EF;  // jal  x1, +12
        expected[19] = 32'h22B00593;  // addi x11, x0, 555   毒药
        expected[20] = 32'h22C00593;  // addi x11, x0, 556   毒药
        expected[21] = 32'h00100B93;  // addi x23, x0, 1
        expected[22] = 32'h00000A97;  // auipc x21, 0
        expected[23] = 32'h010A8A93;  // addi x21, x21, 16
        expected[24] = 32'h000A8067;  // jalr x0, 0(x21)
        expected[25] = 32'h30900593;  // addi x11, x0, 777   毒药
        expected[26] = 32'h00100C13;  // addi x24, x0, 1
        expected[27] = 32'h12345A37;  // lui  x20, 0x12345
        expected[28] = 32'h02300C93;  // addi x25, x0, 0x23
        expected[29] = 32'h01900A23;  // sb   x25, 20(x0)
        expected[30] = 32'h00100C93;  // addi x25, x0, 1
        expected[31] = 32'h01900AA3;  // sb   x25, 21(x0)
        expected[32] = 32'h01402D03;  // lw   x26, 20(x0)
        expected[33] = 32'hFFF00C93;  // addi x25, x0, -1
        expected[34] = 32'h01900B23;  // sb   x25, 22(x0)
        expected[35] = 32'h01600D83;  // lb   x27, 22(x0)
        expected[36] = 32'h01604E03;  // lbu  x28, 22(x0)
        expected[37] = 32'hFFE00C93;  // addi x25, x0, -2
        expected[38] = 32'h01901C23;  // sh   x25, 24(x0)
        expected[39] = 32'h01801E83;  // lh   x29, 24(x0)
        expected[40] = 32'h01805F03;  // lhu  x30, 24(x0)
        expected[41] = 32'h00100693;  // addi x13, x0, 1
        expected[42] = 32'hFFF00713;  // addi x14, x0, -1
        expected[43] = 32'h00E6C463;  // blt  x13, x14, +8
        expected[44] = 32'h06F00793;  // addi x15, x0, 111
        expected[45] = 32'h00E6E463;  // bltu x13, x14, +8
        expected[46] = 32'h0DE00793;  // addi x15, x0, 222
        expected[47] = 32'h00D75463;  // bge  x14, x13, +8
        expected[48] = 32'h14D00813;  // addi x16, x0, 333
        expected[49] = 32'h00E6F463;  // bgeu x13, x14, +8
        expected[50] = 32'h1BC00893;  // addi x17, x0, 444
        expected[51] = 32'h00E6D463;  // bge  x13, x14, +8
        expected[52] = 32'h22B00913;  // addi x18, x0, 555
        expected[53] = 32'h29A00993;  // addi x19, x0, 666
        expected[54] = 32'h00D77463;  // bgeu x14, x13, +8
        expected[55] = 32'h30900913;  // addi x18, x0, 777
        expected[56] = 32'h37800913;  // addi x18, x0, 888

        // 用字节地址 0/4/8/... 去读，顺带验证 addr[31:2] 的字对齐索引
        for (i = 0; i < 57; i++) begin
            addr = i * 4;
            #1;
            if (instr === expected[i])
                $display("PASS  addr=%0d", addr);
            else begin
                $display("FAIL  addr=%0d -> %h   期望 %h", addr, instr, expected[i]);
                errors++;
            end
        end

        if (errors == 0) $display("==== IMEM ALL PASS ====");
        else             $display("==== IMEM FAIL: %0d 处错误 ====", errors);

        $finish;
    end
endmodule

`default_nettype wire
