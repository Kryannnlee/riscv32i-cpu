`timescale 1ns/1ps
`default_nettype none

// ============================================================
// hazard_unit -- 冒险检测单元
//
// 目前只做一件事：检测 **load-use 冒险**，输出 stall。
// 6d 的控制冒险冲刷（flush）后续加进来，所以这模块是留着扩展的。
//
// -- load-use 为什么转发救不了 --
//   lw 的数据要到 MEM 级结束才被造出来。
//   下游指令在 EX 那拍，EX/MEM 里躺的还是 lw 的**地址**，
//   MEM/WB 里是更早指令的东西，寄存器堆还是旧值--三个地方都没有。
//   只能停一拍，等数据锁进 MEM/WB，再由转发送过去。
//
// -- 判断发生在 ID 级 --
//   此时 lw 在 id_ex 里（EX 级），要停的指令还在 if_id 里（ID 级）。
//   所以比较的是 id_ex_rd（lw 要写的号）和 if_id 的 rs1/rs2。
//
// -- 三个条件 --
//   1. id_ex_mem_read   -- 只有 lw 的数据会晚到；ALU 结果上一拍就有了
//   2. id_ex_rd != 0    -- x0 不算相关
//   3. 编号相等         -- 而且是**真正用到**的那个源寄存器
//
// -- 为什么需要 uses_rs1 / uses_rs2 --
//   I 型的 instr[24:20] 是立即数的低 5 位，不是 rs2。
//   比如 `addi x9, x0, 10` 的 instr[24:20] = 10，
//   如果前一条正好是 `lw x10, ...`，光比编号会误判成相关，白停一拍。
//   结果仍然正确（只是多花一个周期），但没必要。
//   加上 uses_* 之后，只有真正读的源才参与比较。
// ============================================================
module hazard_unit (
    // -- 上游（EX 级）--
    input  logic       id_ex_mem_read,   // EX 级的指令是不是 lw
    input  logic [4:0] id_ex_rd,         // 它要写的寄存器号

    // -- 下游（ID 级）--
    input  logic [4:0] if_id_rs1,        // 指令里的 rs1 字段
    input  logic [4:0] if_id_rs2,        // 指令里的 rs2 字段
    input  logic       if_id_uses_rs1,   // 它是否真的读 rs1（decoder 给）
    input  logic       if_id_uses_rs2,   // 它是否真的读 rs2

    // -- 输出 --
    output logic       stall             // 1 = 停一拍
);

    assign stall = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                   ( (if_id_uses_rs1 && (id_ex_rd == if_id_rs1)) ||
                     (if_id_uses_rs2 && (id_ex_rd == if_id_rs2)) );

endmodule
`default_nettype wire
