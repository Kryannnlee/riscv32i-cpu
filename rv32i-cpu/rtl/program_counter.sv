`timescale 1ns/1ps
`default_nettype none

// ============================================================
// program_counter -- 程序计数器（PC）
//
// 作用：存"当前取哪条指令"，本质就是一个 32 位 D 触发器组。
//
// 关于因果顺序（常被问到的点）：
//   pc_next 是**组合逻辑算出来的"下一站"**，pc 是**寄存器锁存的"现在"**。
//   每一拍：组合逻辑先算出 pc_next 稳定下来 -> 等时钟上升沿 ->
//   寄存器把 pc_next 采进来变成新的 pc。
//   所以是"先有 pc_next 的计算，后有 pc 的更新"，不是反过来。
//
// 模块名为什么不能叫 pc：
//   pc 太通用，会和信号名撞；而且模块名在整个工程里是全局的，
//   叫 pc 容易和其它模块里的 pc 混淆。所以用 program_counter。
// ============================================================
module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] pc_next,   // 下一条指令的地址（组合逻辑算好送来）
    input  logic        stall,     // 1 = 停住不动（load-use 冒险时）
    output logic [31:0] pc         // 当前指令的地址
);
    // 同步复位：只在时钟沿检查 rst，不会出现异步复位的毛刺问题
    always_ff @(posedge clk) begin
        if (rst)
            pc <= 32'd0;        // 复位后从地址 0 开始取指
        else if (!stall)
            pc <= pc_next;      // 正常：把"下一站"变成"现在"
        // stall=1 时什么都不做 -> pc 保持，IF 重新取同一条指令（无害）
    end

endmodule
`default_nettype wire
