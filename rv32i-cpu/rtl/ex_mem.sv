`timescale 1ns/1ps
`default_nettype none

// ============================================================
// ex_mem -- EX/MEM 级间寄存器
//
// 作用：把 EX 级算完的结果存一拍，交给 MEM 级。
//
// * 它还是转发（forward）的第一数据源：
//   当后一条指令在 EX 级需要某个寄存器时，如果上一条正好在 MEM 级，
//   它的结果就躺在这个寄存器里 -- 直接从这里抄近路，
//   不用等它写回寄存器堆。这就是 forward_unit 里 forward_a/b = 01 的来源。
//   也正因为如此，这里的 alu_result 和 rd 必须保留到下一拍末端。
//
// 存什么：
//   alu_result : 算术结果 / lw、sw 的地址
//   rs2_data   : * 已经过转发的 rs2，给 sw 往内存写数据用
//   zero       : 分支比较结果（ALU 做减法后是否为 0）
//   rd / pc4   : 目的寄存器号；pc+4（跳转链接用）
//   控制信号   : reg_write / mem_read / mem_write / branch / jump / result_src
//
// 注意 alu_src 和 alu_op 没有往下传：
//   它们在 EX 级就已经被 alu_ctrl 和 ALUSrc MUX 消费掉了，后面用不到。
//   "行李随行"不是把所有东西都带走，只带后面还要用的。
// ============================================================
module ex_mem (
    input  logic        clk,
    input  logic        rst,
    // flush：1 = 灌气泡。多周期除法器在 EX 里跑时下游不能拿到半成品，
    //        否则会用垃圾值写寄存器/内存。
    input  logic        flush,

    // -- EX 产出 --
    input  logic [31:0] alu_result_in,
    input  logic [31:0] rs2_data_in,   // 给 sw 存数据（已过转发）
    input  logic        zero_in,
    input  logic [4:0]  rd_in,
    input  logic [31:0] pc4_in,
    // funct3 要传到 MEM 级：访存的大小（b/h/w）和有无符号都靠它
    input  logic [2:0]  funct3_in,

    // -- 控制信号（随行）--
    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic        branch_in,
    input  logic        jump_in,
    input  logic [1:0]  result_src_in,

    // -- 给 MEM（输出，同名 _out）--
    output logic [31:0] alu_result_out,
    output logic [31:0] rs2_data_out,
    output logic        zero_out,
    output logic [4:0]  rd_out,
    output logic [31:0] pc4_out,
    output logic [2:0]  funct3_out,
    output logic        reg_write_out,
    output logic        mem_read_out,
    output logic        mem_write_out,
    output logic        branch_out,
    output logic        jump_out,
    output logic [1:0]  result_src_out
);

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            alu_result_out <= 32'b0;
            rs2_data_out   <= 32'b0;
            zero_out       <= 1'b0;
            rd_out         <= 5'b0;
            pc4_out        <= 32'b0;
            funct3_out     <= 3'b0;
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
            funct3_out     <= funct3_in;
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
