`timescale 1ns/1ps
`default_nettype none

// ============================================================
// if_id -- IF/ID 级间寄存器
//
// 作用：把 IF 级取到的指令"存一拍"，交给 ID 级译码。
// 没有它，IF 和 ID 会被迫在同一拍里串行工作，流水线就塌回单周期了。
//
// 存三个东西：
//   pc      : 这条指令自己的地址（分支目标计算、调试定位都要用）
//   instr   : 32 位指令本身
//   pc4     : pc+4，跳转链接（jal/jalr）时要写回 rd 的返回地址
//
// 为什么 pc 和 pc4 都要存：
//   看起来 pc4 = pc + 4 随时能算，但到了 ID/EX 级，pc 已经变成
//   "下一条指令的 pc" 了。流水线里每级的 pc 都不同，所以必须各存一份。
//
// 两个控制输入：
//   stall -- load-use 冒险时保持不动，让指令留在 ID 级等一拍
//   flush -- 分支跳转时清空，丢掉取错的指令
// 优先级：flush > stall（实际不会同时发生，分支和 lw 不可能同时在 EX）
// ============================================================
module if_id (
    input  logic        clk,
    input  logic        rst,
    input  logic        stall,     // 1 = 保持不动
    input  logic        flush,     // 1 = 清空（灌气泡）
    // IF 的产出（输入）
    input  logic [31:0] pc_in,
    input  logic [31:0] instr_in,
    input  logic [31:0] pc4_in,
    // 给 ID（输出）
    output logic [31:0] pc_out,
    output logic [31:0] instr_out,
    output logic [31:0] pc4_out
);

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            // 复位或冲刷：清空。
            // instr_out 清 0 后 decoder 译不出来 -> 所有控制信号为 0 -> 气泡
            pc_out     <= 32'b0;
            instr_out  <= 32'b0;
            pc4_out    <= 32'b0;
        end else if (!stall) begin
            // 正常：接受 IF 级这一拍的产出
            pc_out     <= pc_in;
            instr_out  <= instr_in;
            pc4_out    <= pc4_in;
        end
        // stall=1 时保持原值 -> 这条指令继续留在 ID 级等一拍
    end

endmodule
`default_nettype wire
