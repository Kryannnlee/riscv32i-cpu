`timescale 1ns/1ps
`default_nettype none

module decoder (
    input  logic [31:0] instr,      // 整条指令（取 [6:0] 作为 opcode）
    output logic        reg_write,  // 写寄存器
    output logic        mem_read,   // 读内存 (lw)
    output logic        mem_write,  // 写内存 (sw)
    output logic        alu_src,    // ALU B口：0=rs2, 1=imm
    output logic [1:0]  alu_op,     // 大类：00=访存, 01=分支, 10=R型, 11=I型
    output logic        branch,     // 条件分支
    output logic        jump,       // 跳转 (单周期核心版先给 0)
    output logic [1:0]  result_src  // 写回来源：0=ALU, 1=mem, 2=PC+4
);

    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        // 1. 先赋默认值（防 Latch 好习惯）
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        result_src = 2'b00;

        // 2. 匹配 opcode 查表
        case (opcode)
         7'b0110011: begin // R型
            reg_write  = 1'b1;
            alu_src    = 1'b0;
            alu_op     = 2'b10;
            result_src = 2'b00;
            end
            7'b0010011: begin // I型
            reg_write = 1'b1;
            alu_src  = 1'b1;
            alu_op   = 2'b11;
            result_src = 2'b00;
            end
            7'b0000011: begin // lw
            reg_write  = 1'b1;
            mem_read   = 1'b1;
            alu_src    = 1'b1;
            alu_op     = 2'b00;
            result_src = 2'b01;
            end
            7'b0100011: begin // sw
            mem_write  = 1'b1;
            alu_src    = 1'b1;
            alu_op     = 2'b00;
            end
            7'b1100011: begin // beq/bne
            branch     = 1'b1;
            alu_src    = 1'b0;
            alu_op     = 2'b01;
            end        
        endcase
    end
    endmodule
    `default_nettype wire 