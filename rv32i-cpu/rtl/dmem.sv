`timescale 1ns/1ps
`default_nettype none

// ============================================================
// dmem -- 数据存储器（1KB，256 个 32 位字）
//
// 为什么和 imem 分开：
//   指令和数据在 RV32I 里是两条独立通路（哈佛结构简化版）。
//   分开之后 IF 和 MEM 可以同时访问，不会互相挡路。
//   上板时两者分别映射到 BRAM，合起来才是冯.诺依曼的统一内存。
//
// 地址怎么用：
//   CPU 给出的是**字节地址**（每 4 字节一条指令/一个字），
//   但数组是按**字**编号的，所以要丢掉低 2 位：addr[31:2] 等价于 addr/4。
//   这就是为什么 RISC-V 要求访存地址 4 字节对齐。
//
// 读组合、写时序：
//   读是异步的（地址给进去，当拍出数据）；
//   写在时钟上升沿才真正落地。
//   这决定了 lw 的数据要到 MEM 级结束才可靠--也正是 load-use 冒险的由来。
//
// 仿真注意：数组没初始化时是 X。上板时 BRAM 初始值是 0 或不关心，
//   但仿真里必须显式初始化，否则读未写过的地址会得到 X 并扩散。
// ============================================================
module dmem (
    input  logic        clk,
    input  logic        we,        // 写使能（只有 sw 会置 1）
    input  logic [31:0] addr,      // 字节地址（来自 ALU 的 rs1+imm）
    input  logic [31:0] wr_data,   // 要写的数据（来自 rs2，已过转发）
    output logic [31:0] rd_data    // 读出的数据（给 WB 级）
);

    // 256 个 32 位字 = 1KB
    // ram_style=distributed 强制用 LUTRAM 实现。
    // 不加的话 Vivado 会把它推断成 Block RAM，而 BRAM 只能同步读，
    // 行为和这里的组合读差一拍，上板会错。
    (* ram_style = "distributed" *) logic [31:0] mem [0:255];

    // -- 读：组合逻辑，异步 --
    // addr[31:2] 丢弃低 2 位，把字节地址换算成字下标
    assign rd_data = mem[addr[31:2]];

    // -- 写：时序逻辑，同步 --
    // 只有时钟上升沿且 we=1 才写入；写口和读口用同一个地址线
    always_ff @(posedge clk) begin
        if (we)
            mem[addr[31:2]] <= wr_data;
    end

endmodule

`default_nettype wire
