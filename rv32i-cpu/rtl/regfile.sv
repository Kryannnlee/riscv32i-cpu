`timescale 1ns/1ps
`default_nettype none

// ============================================================
// regfile -- 通用寄存器堆（32 个 32 位寄存器）
//
// 结构：2 个读口 + 1 个写口（RISC-V 规范要求的形式）
//   读：组合逻辑，地址一变数据立刻出来（同一拍就能用）
//   写：时序逻辑，只在时钟上升沿写
//
// * 这个"读组合、写时序"的差异，是后面所有冒险问题的根源：
//   当一条指令在 WB 级"写"的时候，同一拍里另一条指令"读"到的
//   仍然是旧值--因为写入要等这一拍结束的时钟沿才落地。
//   所以流水线里即使上游在 WB，下游也还得靠转发（forward）拿值。
//
// x0 的处理（两处都要，少一处就出 bug）：
//   读：rs == 0 时直接输出 0，不去读数组
//   写：rd == 0 时忽略写使能，永远不写
//   只做其中一处也能"看起来能用"，但会掩盖错误，两处都写才是规范做法。
// 写优先旁路开关 BYPASS：
//   流水线里必须打开（救"隔 3 条"的 RAW，见 cases/case-20）。
//   单周期里必须关闭——单周期的 wr_data 直接来自当拍 ALU 结果，
//   打开会形成组合环：alu_result -> wb_data -> rs1_data -> alu_a -> alu_result，
//   仿真器会死循环。单周期也不存在距离 3 的相关（一拍就做完一条）。
// ============================================================
module regfile #(parameter bit BYPASS = 1) (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  rs1,       // 读地址 1
    input  logic [4:0]  rs2,       // 读地址 2
    input  logic [4:0]  rd,        // 写地址
    input  logic [31:0] wr_data,   // 写数据
    input  logic        we,        // 写使能
    output logic [31:0] rs1_data,  // 读数据 1
    output logic [31:0] rs2_data,  // 读数据 2
    // 调试用：把 x1 引出来。上板时点灯 / 综合时防止整个寄存器堆被当作死代码优化掉
    output logic [31:0] dbg_x1,
    // 调试用：所有寄存器的按位异或。让每个寄存器都有下游，
    // 否则综合器会把"只被写、没人读"的寄存器整片删掉，资源统计就不准了
    output logic [31:0] dbg_xor
);
    // 32 个寄存器，每个 32 位。综合后是分布式 RAM 或触发器阵列。
    logic [31:0] regs [0:31];

    // 两个读口：组合读，地址给进去当拍就出数据
    // x0 特判：无论数组里存了什么，读出来永远是 0
    //
    // 写优先旁路（write-first bypass）：
    //   同一拍里既在写 rd、又有人读同一个 rd 时，读口直接返回 wr_data。
    //   没有这一条的话，"隔 3 条"的 RAW 会读到旧值：
    //     第 N 条在 WB 写寄存器（时钟沿生效）
    //     第 N+3 条在 ID 读同一个寄存器（同一拍，沿之前）→ 读到旧值
    //   EX 级转发救不了，因为第 N 条这时已经离开 MEM/WB 了。
    assign rs1_data = (rs1 == 5'd0) ? 32'd0 :
                      ((BYPASS && we && (rd == rs1)) ? wr_data : regs[rs1]);
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 :
                      ((BYPASS && we && (rd == rs2)) ? wr_data : regs[rs2]);

    // 调试：x1 直出。综合时这条连线让寄存器堆有可观测的输出，不会被优化掉
    assign dbg_x1 = regs[1];

    // 调试：所有寄存器的异或。每一位寄存器都参与，综合器无法删掉任何一个
    always_comb begin
        dbg_xor = 32'd0;
        for (int i = 1; i < 32; i++)
            dbg_xor = dbg_xor ^ regs[i];
    end

    // 写口：同步写，只有时钟上升沿才会真正改数组
    always_ff @(posedge clk) begin
        if (rst) begin
            // 复位：所有寄存器清零（仿真里能看到确定值，综合时可能被优化）
            for (int i = 0; i < 32; i++)
                regs[i] <= 32'd0;
        end else if (we && rd != 5'd0) begin
            // 写使能有效且目标不是 x0 才写。x0 永远保持 0。
            regs[rd] <= wr_data;
        end
    end

endmodule
`default_nettype wire
