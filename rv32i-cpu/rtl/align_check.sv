`timescale 1ns/1ps
`default_nettype none

// ============================================================
// align_check -- 访存地址对齐检查
//
// RISC-V 规定 load/store 必须**自然对齐**：
//   LB / LBU / SB     任意地址都可以（字节没有对齐概念）
//   LH / LHU / SH     2 字节对齐 → addr[0] 必须为 0
//   LW / SW           4 字节对齐 → addr[1:0] 必须为 00
//
// 不对齐时的标准做法是触发异常（load/store misaligned exception）。
// 但本设计**没有异常机制**（无 mtvec/mepc/mcause），所以这里只做"检测"，
// 把结果引出去让软件/调试逻辑看见 —— 至少不会静默算错。
//
// 为什么必须检测：dmem 只用 addr[13:2] 做字下标、addr[1:0] 只用来选字节/半字，
// 所以非对齐的 lw/sw 会读到/写到**错误的字**，而且不报任何错。
//
// funct3 编码（load 和 store 共用前三个）：
//   000 = lb / sb     001 = lh / sh     010 = lw / sw
//   100 = lbu         101 = lhu
// ============================================================
module align_check (
    input  logic [2:0] funct3,     // 访存指令的 funct3
    input  logic [1:0] addr_lo,    // 地址低 2 位
    input  logic       is_mem,     // 1 = 这条指令真的要访存
    output logic       misaligned  // 1 = 地址不满足对齐要求
);
    logic bad;

    always_comb begin
        case (funct3)
            3'b010:          bad = (addr_lo != 2'b00);   // lw / sw：4 字节对齐
            3'b001, 3'b101:  bad = (addr_lo[0] != 1'b0); // lh / sh / lhu：2 字节对齐
            default:         bad = 1'b0;                 // lb / lbu / sb：无要求
        endcase
    end

    assign misaligned = is_mem & bad;

endmodule
`default_nettype wire
