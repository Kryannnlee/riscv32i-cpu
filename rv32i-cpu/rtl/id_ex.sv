`timescale 1ns/1ps
`default_nettype none

// ============================================================
// id_ex -- ID/EX 级间寄存器（流水线里最"宽"的一个）
//
// 作用：把 ID 级译码出的全部信息存一拍，交给 EX 级。
//
// 为什么它最宽：
//   (1) ID 是唯一"生产控制信号"的地方。8 个控制信号在这里产生，
//      后面的 MEM、WB 都还要用，所以必须全部带着走（行李随行）。
//   (2) ID 还要把寄存器堆读出的两个操作数、立即数、各种字段都交出去。
//
// 存什么：
//   数据类
//     rs1_data / rs2_data : 从寄存器堆读出的原值（可能是旧值！见下）
//     rs1 / rs2           : * 寄存器编号，转发单元靠它跟上游 rd 比较
//     imm                 : 立即数
//     rd                  : 目的寄存器号
//     pc / pc4            : 本条指令地址、pc+4（跳转链接用）
//     funct3 / funct7     : 给 alu_ctrl 细分运算
//   控制类
//     reg_write / mem_read / mem_write / alu_src / alu_op
//     branch / jump / result_src
//
// * 为什么要专门存 rs1 / rs2 编号：
//   rs1_data 是 ID 级从寄存器堆读出来的值，可能是**旧的**--
//   因为上游指令可能还没写回。转发单元要判断"我这条要读的号，
//   是不是上一条要写的号"，光有数据没法比，所以编号也得存一份下来。
//   这正是阶段6b 补上的那个缺口。
//
// * 为什么 rs2_data 已经过 EX 的转发 MUX 还要在这里存：
//   这里存的是"没转发过的原值"。转发是在 EX 级用 MUX 现场选的，
//   所以原值必须保留，不能被覆盖。
// ============================================================
module id_ex (
    input  logic        clk,
    input  logic        rst,
    // 1 = 灌一个"气泡"进去：控制信号全清 0，等于插入一条 NOP。
    // load-use 冒险时用它，让 EX 这一拍什么都不做。
    input  logic        flush,

    // -- 数据（ID 产出）--
    input  logic [31:0] rs1_data_in,
    input  logic [31:0] rs2_data_in,
    input  logic [4:0]  rs1_in,          // 寄存器编号：转发时比较用
    input  logic [4:0]  rs2_in,
    input  logic [31:0] imm_in,
    input  logic [4:0]  rd_in,
    input  logic [31:0] pc_in,
    input  logic [31:0] pc4_in,
    input  logic [2:0]  funct3_in,
    input  logic [6:0]  funct7_in,

    // -- 控制信号（ID 产出）--
    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic        alu_src_in,
    input  logic [1:0]  alu_op_in,
    input  logic        branch_in,
    input  logic        jump_in,
    input  logic [1:0]  result_src_in,
    input  logic [1:0]  alu_a_src_in,

    // -- 给 EX（输出）-- 同名的 _out
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,
    output logic [4:0]  rs1_out,
    output logic [4:0]  rs2_out,
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
    output logic [1:0]  result_src_out,
    output logic [1:0]  alu_a_src_out
);

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            // 复位或冲刷：全部清零。控制信号清 0 特别重要--
            // 否则会有"幽灵指令"把垃圾写进寄存器堆或内存。
            // flush 时数据位也一起清掉，纯粹为了波形好看，不影响功能。
            rs1_data_out  <= 32'b0;
            rs2_data_out  <= 32'b0;
            rs1_out       <= 5'b0;
            rs2_out       <= 5'b0;
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
            alu_a_src_out <= 2'b0;
        end else begin
            rs1_data_out  <= rs1_data_in;
            rs2_data_out  <= rs2_data_in;
            rs1_out       <= rs1_in;
            rs2_out       <= rs2_in;
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
            alu_a_src_out <= alu_a_src_in;
        end
    end

endmodule
`default_nettype wire
