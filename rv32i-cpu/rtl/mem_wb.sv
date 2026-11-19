`timescale 1ns/1ps
`default_nettype none

// ============================================================
// mem_wb -- MEM/WB 级间寄存器
//
// 作用：把 MEM 级的结果"存一拍"，交给 WB 级写回。
//
// 存什么（原则：本级的产出 + 后面还要用但没用完的控制信号）：
//   alu_result    : 算术指令的结果；lw 时它是地址，用不到但要往下传
//   mem_rdata     : lw 从内存读出的数据
//   rd            : 要写哪个寄存器
//   reg_write     : WB 级用，决定到底写不写
//   result_src    : WB 级用，决定写回 ALU 结果还是内存数据
//
// 到这里控制信号只剩 2 个了：
//   alu_src / alu_op 在 EX 就消费完了
//   mem_read / mem_write 在 MEM 消费完了
//   branch / jump 送给 PC 逻辑，不往下走
//   -> 所以这个寄存器比 id_ex 窄很多，这也是流水线"行李随行"的实际样子
//
// 注意 result_src 是 2 位：0=ALU 1=mem 2=PC+4（跳转链接用）。
//   cpu_pipe 的 WB MUX 按完整两位译码，三种来源都生效。
// ============================================================
module mem_wb (
    input  logic        clk,
    input  logic        rst,

    // -- MEM 产出 --
    input  logic [31:0] alu_result_in,   // EX 算的结果（穿过 EX/MEM 到这）
    input  logic [31:0] mem_rdata_in,    // MEM 读出的数据
    input  logic [31:0] pc4_in,          // pc+4：JAL/JALR 的返回地址
    input  logic [4:0]  rd_in,

    // -- 控制信号（随行）--
    input  logic        reg_write_in,
    input  logic [1:0]  result_src_in,

    // -- 给 WB（输出，同名 _out）--
    output logic [31:0] alu_result_out,
    output logic [31:0] mem_rdata_out,
    output logic [31:0] pc4_out,
    output logic [4:0]  rd_out,
    output logic        reg_write_out,
    output logic [1:0]  result_src_out
);

    always_ff @(posedge clk) begin
        if (rst) begin
            // 复位时清空，避免流水线里残留 X
            alu_result_out  <= 32'b0;
            mem_rdata_out   <= 32'b0;
            pc4_out         <= 32'b0;
            rd_out          <= 5'b0;
            reg_write_out   <= 1'b0;
            result_src_out  <= 2'b0;
        end else begin
            alu_result_out  <= alu_result_in;
            mem_rdata_out   <= mem_rdata_in;
            pc4_out         <= pc4_in;
            rd_out          <= rd_in;
            reg_write_out   <= reg_write_in;
            result_src_out  <= result_src_in;
        end
    end

endmodule
`default_nettype wire
