`timescale 1ns/1ps
`default_nettype none

module id_ex (
    input  logic        clk,
    input  logic        rst,

    // ── 数据（ID 产出）──
    input  logic [31:0] rs1_data_in,
    input  logic [31:0] rs2_data_in,
    input  logic [31:0] imm_in,
    input  logic [4:0]  rd_in,
    input  logic [31:0] pc_in,
    input  logic [31:0] pc4_in,
    input  logic [2:0]  funct3_in,
    input  logic [6:0]  funct7_in,

    // ── 控制信号（ID 产出）──
    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic        alu_src_in,
    input  logic [1:0]  alu_op_in,
    input  logic        branch_in,
    input  logic        jump_in,
    input  logic [1:0]  result_src_in,

    // ── 给 EX（输出）── 同名的 _out
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,
    output logic [31:0] imm_out,
    output logic [4:0]  rd_out,
    output logic [31:0] pc_out,
    output logic [31:0] pc4_out,
    output logic [2:0]  funct3_out,
    output logic [6:0]  funct7_out,
    output logic        reg_write_out,
    output logic        mem_read_out,
    output logic        mem_write_out,
    output logic        alu_src_out,
    output logic [1:0]  alu_op_out,
    output logic        branch_out,
    output logic        jump_out,
    output logic [1:0]  result_src_out
);

    // ID/EX 寄存器
    always_ff @(posedge clk) begin
        if (rst) begin
            rs1_data_out  <= 32'b0;
            rs2_data_out  <= 32'b0;
            imm_out       <= 32'b0;
            rd_out        <= 5'b0;
            pc_out        <= 32'b0;
            pc4_out       <= 32'b0;
            funct3_out    <= 3'b0;
            funct7_out    <= 7'b0;
            reg_write_out <= 1'b0;
            mem_read_out  <= 1'b0;
            mem_write_out <= 1'b0;
            alu_src_out   <= 1'b0;
            alu_op_out    <= 2'b0;
            branch_out    <= 1'b0;
            jump_out      <= 1'b0;
            result_src_out<= 2'b0;
        end else begin
            rs1_data_out  <= rs1_data_in;
            rs2_data_out  <= rs2_data_in;
            imm_out       <= imm_in;
            rd_out        <= rd_in;
            pc_out        <= pc_in;
            pc4_out       <= pc4_in;
            funct3_out    <= funct3_in;
            funct7_out    <= funct7_in;
            reg_write_out <= reg_write_in;
            mem_read_out  <= mem_read_in;
            mem_write_out <= mem_write_in;
            alu_src_out   <= alu_src_in;
            alu_op_out    <= alu_op_in;
            branch_out    <= branch_in;
            jump_out      <= jump_in;
            result_src_out<= result_src_in;
        end
    end

    endmodule
    `default_nettype wire