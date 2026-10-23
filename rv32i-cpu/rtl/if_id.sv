`timescale 1ns/1ps
`default_nettype none

module if_id (
    input  logic        clk,
    input  logic        rst,
    // IF 的产出（输入）
    input  logic [31:0] pc_in,
    input  logic [31:0] instr_in,
    input  logic [31:0] pc4_in,
    // 给 ID（输出）
    output logic [31:0] pc_out,
    output logic [31:0] instr_out,
    output logic [31:0] pc4_out
);

    // IF/ID 寄存器
    always_ff @(posedge clk) begin
        if (rst) begin
            pc_out     <= 32'b0;
            instr_out  <= 32'b0;
            pc4_out    <= 32'b0;
        end else begin
            pc_out     <= pc_in;
            instr_out  <= instr_in;
            pc4_out    <= pc4_in;
        end
    end

    endmodule
    `default_nettype wire