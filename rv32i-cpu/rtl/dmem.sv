`timescale 1ns/1ps
`default_nettype none

module dmem (
    input  logic        clk,
    input  logic        we,        // 写使能
    input  logic [31:0] addr,      // 字节地址（来自 ALU）
    input  logic [31:0] wr_data,   // 要写的数据（来自 rs2）
    output logic [31:0] rd_data    // 读出的数据
);

    // 内部数组：256 个元素，每个 32 位宽（共 1KB）
    logic [31:0] mem [0:255];

    // 1. 读操作：组合逻辑异步读（addr[31:2] 丢弃低 2 位实现字对齐索引）
    assign rd_data = mem[addr[31:2]];

    // 2. 写操作：时序逻辑同步写（仅在时钟上升沿且 we 有效时写入）
    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr[31:2]] <= wr_data;
        end
    end

endmodule

`default_nettype wire