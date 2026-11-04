`timescale 1ns/1ps
`default_nettype none

// ============================================================
// 转发单元（forwarding / bypass）
//
// 解决的问题：后一条指令要用的操作数，前一条指令还没写回寄存器堆。
// 办法：不等写回，直接从流水线中间的寄存器里把值抄近路送回 EX 段。
//
// 数据在 EX 段有两个可能的来源：
//   EX/MEM 寄存器 -- 上一条指令在上一拍算完的结果（新）
//   MEM/WB 寄存器 -- 上上条指令的结果           （旧）
//
// 本模块只输出"选哪一路"，不搬运数据；数据选择在 cpu_pipe 的 MUX 里做。
// 这样它是一个纯组合逻辑模块，好单独测。
// ============================================================

module forward_unit (
    // 当前在 EX 的指令要读的两个寄存器号（由 id_ex 锁存下来）
    input  logic [4:0] id_ex_rs1,
    input  logic [4:0] id_ex_rs2,

    // 上一条指令的目的寄存器（EX/MEM 寄存器里的 rd）
    input  logic [4:0] ex_mem_rd,
    input  logic       ex_mem_reg_write,
    // 上上条指令的目的寄存器（MEM/WB 寄存器里的 rd）
    input  logic [4:0] mem_wb_rd,
    input  logic       mem_wb_reg_write,

    output logic [1:0] forward_a,   // ALU 的 A 口：00=原值 01=EX/MEM 10=MEM/WB
    output logic [1:0] forward_b    // ALU 的 B 口：同上
);

    // ------------------------------------------------------------
    // A 口
    //
    // 三个条件必须同时成立，缺一不可：
    //   1. 上游确实要写寄存器（reg_write）
    //      反例：sw 是 S 型，没有 rd 字段，instr[11:7] 里装的是立即数
    //            的低 5 位。sw x1, 4(x2) 的 instr[11:7] 正好是 4，
    //            看起来就像在写 x4--不查 reg_write 就会把存储器地址
    //            转发给后面读 x4 的指令。
    //   2. rd 不是 x0（x0 恒为 0，写它等于没写）
    //      反例：addi x0, x0, 5 会让 ALU 算出 5，如果转发过去，
    //            后面读 x0 的指令就拿到 5，x0 不再是 0。
    //   3. 编号相等
    //
    // 优先级：EX/MEM 在前。两条指令都写同一个寄存器时，后来的那条
    //         才是对的答案，而它正躺在 EX/MEM 里。
    //         用 if / else if 的顺序天然表达优先级，不要写成两个
    //         独立 if，否则两条通路同时命中时后写的会覆盖先写的。
    // ------------------------------------------------------------
    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b01;          // 上一条 -> EX/MEM
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b10;          // 上上条 -> MEM/WB
        else
            forward_a = 2'b00;          // 没人写它，用寄存器堆读出来的原值
    end

    // B 口：逻辑与 A 口完全相同，只是比较的寄存器号换成 rs2。
    // 这个信号同时管两处（ALU 的 B 口、sw 要存的数据），因为两者
    // 的来源都是 rs2。
    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b01;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b10;
        else
            forward_b = 2'b00;
    end

endmodule

`default_nettype wire
