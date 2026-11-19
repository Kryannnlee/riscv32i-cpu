`timescale 1ns/1ps
`default_nettype none

// ============================================================
// load_extend -- 访存读数据的提取与扩展
//
// 问题：dmem 一次读出一个 32 位整字，但 lb/lh 只要其中一个字节/半字，
//      而且 lb/lh 要**符号扩展**，lbu/lhu 要**零扩展**。
//      这一步在 MEM 级完成，结果再锁进 MEM/WB。
//
// 指令和 funct3 的对应（opcode = 0000011）：
//   funct3 = 000  lb    取低 2 位地址选中的字节，符号扩展
//   funct3 = 001  lh    取 addr[1] 选中的半字，符号扩展
//   funct3 = 010  lw    整字，不处理
//   funct3 = 100  lbu   字节，零扩展
//   funct3 = 101  lhu   半字，零扩展
//
// 注意 RISC-V 是**小端**：地址最低的那个字节在 word[7:0]。
//   addr_lo=0 → word[7:0]    addr_lo=1 → word[15:8]
//   addr_lo=2 → word[23:16]  addr_lo=3 → word[31:24]
// ============================================================
module load_extend (
    input  logic [31:0] word,      // dmem 读出的整字
    input  logic [1:0]  addr_lo,   // 地址最低两位（字节偏移）
    input  logic [2:0]  funct3,    // 决定取多少、怎么扩展
    output logic [31:0] data       // 处理后的结果，送去写回
);

    logic [15:0] half;
    logic [7:0]  byte_sel;

    // 先按 addr[1] 选出半字
    assign half = addr_lo[1] ? word[31:16] : word[15:0];

    // 再按 addr[0] 从半字里选出字节
    assign byte_sel = addr_lo[0] ? half[15:8] : half[7:0];

    always_comb begin
        case (funct3)
            3'b000:  data = {{24{byte_sel[7]}}, byte_sel};   // lb  符号扩展
            3'b100:  data = {24'd0, byte_sel};               // lbu 零扩展
            3'b001:  data = {{16{half[15]}}, half};          // lh  符号扩展
            3'b101:  data = {16'd0, half};                   // lhu 零扩展
            default: data = word;                            // lw（010）及其它
        endcase
    end

endmodule
`default_nettype wire
