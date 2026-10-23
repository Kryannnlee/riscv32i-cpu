`timescale 1ns/1ps
`default_nettype none

module mem_wb (
    input  logic        clk,
    input  logic        rst,

    // ── MEM 产出 ──
    input  logic [31:0] alu_result_in,   // EX 算的结果（穿过 EX/MEM 到这）
    input  logic [31:0] mem_rdata_in,    // MEM 读出的数据
    input  logic [4:0]  rd_in,

    // ── 控制信号（随行）──
    input  logic        reg_write_in,
    input  logic [1:0]  result_src_in,

    // ── 给 WB（输出，同名 _out）──
    output logic [31:0] alu_result_out,
    output logic [31:0] mem_rdata_out,
    output logic [4:0]  rd_out,
    output logic        reg_write_out,
    output logic [1:0]  result_src_out
);

    // MEM/WB 寄存器
    always_ff @(posedge clk) begin
        if (rst) begin
            alu_result_out  <= 32'b0;
            mem_rdata_out   <= 32'b0;
            rd_out          <= 5'b0;
            reg_write_out   <= 1'b0;
            result_src_out  <= 2'b0;
        end else begin
            alu_result_out  <= alu_result_in;
            mem_rdata_out   <= mem_rdata_in;
            rd_out          <= rd_in;
            reg_write_out   <= reg_write_in;
            result_src_out  <= result_src_in;
        end
    end

    endmodule
`default_nettype wire