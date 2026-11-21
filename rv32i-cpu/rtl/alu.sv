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

    // ---- M 扩展：乘法（序号 10~13）--------------------------------
    // 除法（div/divu/rem/remu）**故意不实现**：
    //   实测 32 位组合除法器最长路径 82.6ns（WNS -62.6ns @20ns），
    //   50MHz 跑不动，要做得改成多周期。软件用 -mno-div 走库函数。
    localparam logic [3:0] ALU_MUL    = 4'd10;   // 低 32 位（有/无符号结果相同）
    localparam logic [3:0] ALU_MULH   = 4'd11;   // 高 32 位：有符号 × 有符号
    localparam logic [3:0] ALU_MULHSU = 4'd12;   // 高 32 位：有符号 × 无符号
    localparam logic [3:0] ALU_MULHU  = 4'd13;   // 高 32 位：无符号 × 无符号

    // 未实现的编号落这里，返回显眼哨兵值。
    // 比 default 返回 0 强：0 太"正常"，错误会被当成正确结果。
    localparam logic [3:0] ALU_ILL    = 4'd14;

    // 64 位乘法中间结果。必须用 64 位变量接，
    // 否则 `a * b >> 32` 会按 32 位宽度算，高半部分全丢。
    logic [63:0] mul_uu, mul_ss, mul_su;


    // 组合输出：只要 result 变化就跟着变
    assign zero = (result == 32'd0);

    always_comb begin
        // 三个乘法器无条件算好，下面按 alu_sel 取低半或高半。
        // 用 64 位变量接住，才有完整的乘积。
        mul_uu = a * b;                            // 无符号 × 无符号
        mul_ss = $signed(a) * $signed(b);          // 有符号 × 有符号
        mul_su = $signed(a) * $signed({1'b0, b});  // 有符号 × 无符号
        //                            ↑ 先补 0 再当有符号看，等价于"把 b 零扩展"

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
            // ---- M 扩展：乘法 ----
            ALU_MUL:    result = mul_uu[31:0];   // mul    低 32 位
            ALU_MULH:   result = mul_ss[63:32];  // mulh   有符号高半
            ALU_MULHSU: result = mul_su[63:32];  // mulhsu 有符号×无符号高半
            ALU_MULHU:  result = mul_uu[63:32];  // mulhu  无符号高半
            // 没实现的运算：给个一眼能认出来的错值，别用 0 冒充
            ALU_ILL:    result = 32'hDEAD_BEEF;
            default:    result = 32'd0;          // 兜底，防止综合出锁存器
        endcase
    end

endmodule

`default_nettype wire
