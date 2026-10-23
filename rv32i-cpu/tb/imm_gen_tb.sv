`timescale 1ns/1ps

module imm_gen_tb;
    logic [31:0] instr, imm;
    
    imm_gen dut (.instr(instr), .imm(imm));

    task automatic check(input [31:0] i, input [31:0] e);
        instr = i; #1;
        if (imm === e) $display("PASS: %h -> %h", i, imm);
        else           $display("FAIL: %h -> %h, expect %h", i, imm, e);
    endtask

    initial begin
        $dumpfile("sim/imm_gen.vcd");
        $dumpvars(0, imm_gen_tb);

        // 基础测试
        check(32'h00A30293, 32'h0000000A);   // addi  10
        check(32'h00832283, 32'h00000008);   // lw    8

        // 已补全的测试用例
        check(32'h00532423, 32'h00000008);   // sw   0x00532423 -> 0x00000008
        check(32'h00628463, 32'h00000008);   // beq  0x00628463 -> 0x00000008
        check(32'h123452B7, 32'h12345000);   // lui  0x123452B7 -> 0x12345000
        check(32'h008000EF, 32'h00000008);   // jal  0x008000EF -> 0x00000008
        check(32'h008302E7, 32'h00000008);   // jalr 0x008302E7 -> 0x00000008
        check(32'hFFF30293, 32'hFFFFFFFF);   // addi -1  0xFFF30293 -> 0xFFFFFFFF
        check(32'hFFC32283, 32'hFFFFFFFC);   // lw -4    0xFFC32283 -> 0xFFFFFFFC

        $finish;
    end
endmodule