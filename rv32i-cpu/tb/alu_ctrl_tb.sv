`timescale 1ns/1ps

module alu_ctrl_tb;
    logic [1:0] alu_op;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [3:0] alu_sel;

    alu_ctrl dut (.alu_op(alu_op), .funct3(funct3), .funct7(funct7), .alu_sel(alu_sel));

    task automatic check(input [1:0] op, input [2:0] f3, input [6:0] f7, input [3:0] e);
        alu_op = op; funct3 = f3; funct7 = f7; #1;
        if (alu_sel === e) $display("PASS: op=%b f3=%b f7=%b -> %0d", op, f3, f7, alu_sel);
        else               $display("FAIL: op=%b f3=%b f7=%b -> %0d, expect %0d", op, f3, f7, alu_sel, e);
    endtask

initial begin
        $dumpfile("sim/alu_ctrl.vcd");
        $dumpvars(0, alu_ctrl_tb);

        // 1. 基础测试：load/store 与 branch
        check(2'b00, 3'b000, 7'h00, 4'd0);   // load/store → ADD (0)
        check(2'b01, 3'b000, 7'h00, 4'd1);   // branch → SUB (1)
       
        // 2. R 型指令 (alu_op = 2'b10) 测试
        // 算术/逻辑运算：加减、异或、或、与、小于置位、移位等
        check(2'b10, 3'b000, 7'b0000000, 4'd0); // ADD  (0)
        check(2'b10, 3'b000, 7'b0100000, 4'd1); // SUB  (1)
        check(2'b10, 3'b010, 7'b0000000, 4'd5); // SLT  (5)
        check(2'b10, 3'b100, 7'b0000000, 4'd4); // XOR  (4)
        check(2'b10, 3'b110, 7'b0000000, 4'd3); // OR   (3)
        check(2'b10, 3'b111, 7'b0000000, 4'd2); // AND  (2)
     
        // 3. I 型指令 (alu_op = 2'b11) 测试
        // 立即数运算（通常 I 型的 funct7 大部分为 0，除了 SRAI 等）
        check(2'b11, 3'b000, 7'b0000000, 4'd0); // ADDI → ADD (0)
        check(2'b11, 3'b010, 7'b0000000, 4'd5); // SLTI → SLT (5)
        check(2'b11, 3'b100, 7'b0000000, 4'd4); // XORI → XOR (4)
        check(2'b11, 3'b110, 7'b0000000, 4'd3); // ORI  → OR  (3)
        check(2'b11, 3'b111, 7'b0000000, 4'd2); // ANDI → AND (2)

        $finish;
    end
    endmodule