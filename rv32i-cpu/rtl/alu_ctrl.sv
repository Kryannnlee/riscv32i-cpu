`timescale 1ns/1ps
`default_nettype none

// ============================================================
// alu_ctrl -- ALU 操作译码器
//
// 为什么要两级译码？
//   decoder 只按 opcode 分"大类"（访存 / 分支 / R 型 / I 型），
//   因为同一个 opcode 下还有 add / sub / and / or ... 好几条指令，
//   要靠 funct3（和 R 型的 funct7）才分得出来。
//   把这一步单独拆成模块，decoder 就不用管具体的运算。
//
// alu_op 编码（decoder 给）：
//   00 = 访存  ：ALU 只做加法算地址
//   01 = 分支  ：ALU 做减法，看 zero 判断相不相等
//   10 = R 型  ：具体算什么看 funct3，ADD/SUB 还要看 funct7
//   11 = I 型  ：具体算什么看 funct3
//
// alu_sel 编码（给 alu）：
//   0=ADD  1=SUB  2=AND  3=OR  4=XOR  5=SLT
//
// 注意 ADD 和 SUB 的区分：R 型里 funct3 都是 000，
// 只能靠 funct7 分--0000000 是 add，0100000 是 sub。
// ============================================================
module alu_ctrl (
    input  logic [1:0] alu_op,     // decoder 给的大类
    input  logic [2:0] funct3,     // instr[14:12]
    input  logic [6:0] funct7,     // instr[31:25]
    output logic [3:0] alu_sel     // 给 ALU：0 ADD/1 SUB/2 AND/3 OR/4 XOR/5 SLT
);
    always_comb begin
        case (alu_op)

            // 访存：lw/sw 都是 rs1 + imm 算地址
            2'b00 : alu_sel = 4'd0;

            // 分支：beq/bne 做减法，靠 ALU 的 zero 输出判断两数是否相等
            2'b01 : alu_sel = (funct3 == 3'b000) ? 4'd1 : // beq
                              (funct3 == 3'b001) ? 4'd1 : // bne
                              (funct3 == 3'b100) ? 4'd5 : // blt
                                (funct3 == 3'b101) ? 4'd5 : // bge
                                (funct3 == 3'b110) ? 4'd6 : // bltu
                                (funct3 == 3'b111) ? 4'd6 : // bgeu
                              4'd0;

            // R 型：funct3 定运算，ADD/SUB 还要靠 funct7 区分
            // M 扩展（funct7 = 0000001）：只实现乘法，除法留软件
            2'b10 : alu_sel = (funct7 == 7'b0000001) ? (
                                (funct3 == 3'b000) ? 4'd10 :   // mul
                                (funct3 == 3'b001) ? 4'd11 :   // mulh
                                (funct3 == 3'b010) ? 4'd12 :   // mulhsu
                                (funct3 == 3'b011) ? 4'd13 :   // mulhu
                                4'd14) :                       // div/divu/rem/remu 未实现
                              (funct3 == 3'b000 && funct7 == 7'b0000000) ? 4'd0 : // add
                              (funct3 == 3'b000 && funct7 == 7'b0100000) ? 4'd1 : // sub
                              (funct3 == 3'b111) ? 4'd2 : // and
                              (funct3 == 3'b110) ? 4'd3 : // or
                              (funct3 == 3'b100) ? 4'd4 : // xor
                              (funct3 == 3'b010) ? 4'd5 : // slt
                              (funct3 == 3'b011) ? 4'd6 : // sltu
                                (funct3 == 3'b001) ? 4'd7 : // sll
                                (funct3 == 3'b101 && funct7 == 7'b0000000) ? 4'd8 : // srl
                                (funct3 == 3'b101 && funct7 == 7'b0100000) ? 4'd9 : // sra
                              4'd0;

            // I 型：只有 funct3，没有 funct7（立即数占了高 12 位）
            2'b11 : alu_sel = (funct3 == 3'b000) ? 4'd0 : // addi
                            (funct3 == 3'b001) ? 4'd7 : // slli
                            (funct3 == 3'b101 && funct7 == 7'b0000000) ? 4'd8 : // srli
                            (funct3 == 3'b101 && funct7 == 7'b0100000) ? 4'd9 : // srai
                              (funct3 == 3'b010) ? 4'd5 : // slti
                              (funct3 == 3'b100) ? 4'd4 : // xori
                              (funct3 == 3'b110) ? 4'd3 : // ori
                              (funct3 == 3'b111) ? 4'd2 : // andi
                              4'd0;

            default: alu_sel = 4'd0;
        endcase
    end

endmodule
`default_nettype wire
