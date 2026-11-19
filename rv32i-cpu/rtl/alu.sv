`timescale 1ns/1ps
`default_nettype none

// ============================================================
// alu -- 算术逻辑单元
//
// CPU 的"计算器"：算术、逻辑、比较全在这里发生。
// 纯组合逻辑，结果在同一拍内出来，不存状态。
//
// alu_sel 由 alu_ctrl 产生（它看 opcode 大类 + funct3/funct7）：
//   0=ADD  1=SUB  2=AND  3=OR  4=XOR  5=SLT
//
// 关于 zero：
//   它是"result == 0"，不是"a == b"。
//   只有 ALU 在做减法时它才有比较意义--beq 就是靠 sub 之后看 zero。
//   做加法时 zero=1 只代表两数之和为 0，跟相等没关系。
//
// 关于 SLT：
//   "Set Less Than" -- 比较结果**放进寄存器**，不是跳转。
//   a < b 就写 1，否则写 0。用 $signed 是因为 RV32I 的 slt 是有符号比较
//   （无符号版本是 sltu，见下面的 ALU_SLTU；两者差别只在有没有 $signed）。
// ============================================================
module alu(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_sel,
    output logic [31:0] result,
    output logic        zero
);
    // 用 localparam 给操作编号起名字，写 case 时一眼能看懂
    localparam logic [3:0] ALU_ADD = 4'd0;
    localparam logic [3:0] ALU_SUB = 4'd1;
    localparam logic [3:0] ALU_AND = 4'd2;
    localparam logic [3:0] ALU_OR  = 4'd3;
    localparam logic [3:0] ALU_XOR = 4'd4;
    localparam logic [3:0] ALU_SLT = 4'd5;
    localparam logic [3:0] ALU_SLTU = 4'd6;  
    localparam logic [3:0] ALU_SLL = 4'd7;
    localparam logic [3:0] ALU_SRL = 4'd8;
    localparam logic [3:0] ALU_SRA = 4'd9;
       

    // 组合输出：只要 result 变化就跟着变
    assign zero = (result == 32'd0);

    always_comb begin
        case (alu_sel)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;          // 实际是 a + (~b) + 1
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            // 有符号比较：高位被当成符号位，所以 -1 < 0 成立
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;  // 无符号比较
            ALU_SLL: result = a << b[4:0];     // 只取低 5 位作为移位数
            ALU_SRL: result = a >> b[4:0];     // 逻辑右移，高位补 0
            ALU_SRA: result = $signed(a) >>> b[4:0];  // 算术右移，高位补符号位
            default: result = 32'd0;          // 兜底，防止综合出锁存器
        endcase
    end

endmodule

`default_nettype wire
