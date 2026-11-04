`timescale 1ns/1ps
`default_nettype none

// ============================================================
// imm_gen -- 立即数生成器（立即数"解压器"）
//
// 问题：RISC-V 是定长 32 位指令，但不同指令格式把立即数拆得七零八落。
//      I 型好办，立即数连在一起；B 型 / J 型为了省编码空间，
//      把立即数**切碎**塞进几个不连续的位置。
//      本模块的工作就是按 opcode 判断格式，把碎片拼回一个 32 位数。
//
// 为什么要符号扩展：
//   立即数是有符号的（offset / 常量都可能为负）。
//   把最高位 instr[31] 复制到高位，负数才会保持为负。
//   I 型 12 位 -> 补 20 个符号位；J 型 20 位 -> 补 11 个符号位。
//
// 为什么 B 型和 J 型的 bit0 恒为 0：
//   分支/跳转的目标地址一定是 2 字节对齐（RV32I 里更是 4 字节对齐）。
//   bit0 永远是 0，没必要存，编码时省掉，这里用 1'b0 补回来。
//   这也意味着它们能表示的跳转范围翻倍（以 2 字节为单位）。
//
// 各格式立即数落在哪：
//   I 型  imm[11:0] = instr[31:20]
//   S 型  imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
//   B 型  imm[12]=31, imm[11]=7, imm[10:5]=30:25, imm[4:1]=11:8, imm[0]=0
//   J 型  imm[20]=31, imm[19:12]=19:12, imm[11]=20, imm[10:1]=30:21, imm[0]=0
//   U 型  imm[31:12] = instr[31:12], 低 12 位填 0
// ============================================================
module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    // 先取出来单独一根线，避免 everywhere 写 instr[6:0]（也让 iverilog 少报 sorry 警告）
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        case (opcode)

            //  I 型：addi / andi / ori / xori / slti（算术）
            7'b0010011: imm = {{20{instr[31]}}, instr[31:20]};

            //  I 型：lw（访存读）
            7'b0000011: imm = {{20{instr[31]}}, instr[31:20]};

            //  I 型：jalr -- 格式和 I 型相同，也是 rs1 + imm
            7'b1100111: imm = {{20{instr[31]}}, instr[31:20]};

            //  S 型：sw -- 立即数被拆成高 7 位 + 低 5 位两段
            //  高段 instr[31:25] 符号扩展 20 位，低段 instr[11:7] 原样接在后面
            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            //  B 型：beq/bne -- 13 位有符号偏移，bit0 恒 0
            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            //  J 型：jal -- 21 位有符号偏移，bit0 恒 0
            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            //  U 型：lui -- 高 20 位直接搬到结果高位，低 12 位清零
            7'b0110111: imm = {instr[31:12], 12'h0};

            //  U 型：auipc -- 格式同上，只是它加的是 PC 而不是 rs1
            7'b0010111: imm = {instr[31:12], 12'h0};

            //  当前子集之外的指令：给 0，避免出现 X 在仿真里到处传
            default:    imm = 32'd0;
        endcase
    end

endmodule

`default_nettype wire
