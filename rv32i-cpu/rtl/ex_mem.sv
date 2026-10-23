`timescale 1ns/1ps
`default_nettype none


module ex_mem (
    input  logic        clk,
    input  logic        rst,
    //EX 用掉的 alu_src、alu_op 不再往下了(它们在 EX 就消费掉了)
    // ── EX 产出 ──
    input  logic [31:0] alu_result_in,
    input  logic [31:0] rs2_data_in,   // 给 SW 存数据
    input  logic        zero_in,
    input  logic [4:0]  rd_in,
    input  logic [31:0] pc4_in,

    // ── 控制信号（随行）──
    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic        branch_in,
    input  logic        jump_in,
    input  logic [1:0]  result_src_in,

    // ── 给 MEM（输出，同名 _out）──
    output logic [31:0] alu_result_out,
    output logic [31:0] rs2_data_out,
    output logic        zero_out,
    output logic [4:0]  rd_out,
    output logic [31:0] pc4_out,
    output logic        reg_write_out,
    output logic        mem_read_out,
    output logic        mem_write_out,
    output logic        branch_out,
    output logic        jump_out,
    output logic [1:0]  result_src_out
);
    
    // EX/MEM 寄存器
    always_ff @(posedge clk) begin
        if (rst) begin
            alu_result_out <= 32'b0;
            rs2_data_out   <= 32'b0;
            zero_out       <= 1'b0;
            rd_out         <= 5'b0;
            pc4_out        <= 32'b0;
            reg_write_out  <= 1'b0;
            mem_read_out   <= 1'b0;
            mem_write_out  <= 1'b0;
            branch_out     <= 1'b0;
            jump_out       <= 1'b0;
            result_src_out <= 2'b0;
        end else begin
            alu_result_out <= alu_result_in;
            rs2_data_out   <= rs2_data_in;
            zero_out       <= zero_in;
            rd_out         <= rd_in;
            pc4_out        <= pc4_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            branch_out     <= branch_in;
            jump_out       <= jump_in;
            result_src_out <= result_src_in;
        end
    end

endmodule
`default_nettype wire