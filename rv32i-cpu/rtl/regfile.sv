`timescale 1ns/1ps
`default_nettype none

module regfile (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  rs1,       // 读地址 1
    input  logic [4:0]  rs2,       // 读地址 2
    input  logic [4:0]  rd,        // 写地址
    input  logic [31:0] wr_data,   // 写数据
    input  logic        we,        // 写使能
    output logic [31:0] rs1_data,  // 读数据 1
    output logic [31:0] rs2_data   // 读数据 2
);
    logic [31:0] regs [0:31];
    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= 32'd0;
            end
        end else if (we && rd != 5'd0) begin
            regs[rd] <= wr_data;
        end
    end
    endmodule
    `default_nettype wire