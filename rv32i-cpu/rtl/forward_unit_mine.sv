`timescale 1ns/1ps
`default_nettype none

// ============================================================
// forward_unit_mine -- 用户自己重写的转发单元（等价性验证用）
//
// 功能和 rtl/forward_unit.sv 完全相同：判断 EX 段该从哪拿操作数。
//   00 = 寄存器堆原值
//   01 = EX/MEM（上一条刚算完的，优先）
//   10 = MEM/WB（上上条的）
//
// 三个条件缺一不可：
//   1. 上游确实要写寄存器（reg_write）-- sw 的 rd 字段是立即数，不能信
//   2. rd != 0                        -- x0 恒为 0，不能被转发污染
//   3. 编号相等
//
// 优先级：EX/MEM 在前（if / else if 的顺序即优先级）
// ============================================================
module forward_unit_mine (
    input  logic [4:0] id_ex_rs1,
    input  logic [4:0] id_ex_rs2,
    input  logic [4:0] ex_mem_rd,
    input  logic       ex_mem_reg_write,
    input  logic [4:0] mem_wb_rd,
    input  logic       mem_wb_reg_write,
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b01;          // 上一条 -> EX/MEM
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b10;          // 上上条 -> MEM/WB
        else
            forward_a = 2'b00;          // 没人写它，用寄存器堆读出来的原值
    end

    always_comb begin
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b01;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b10;
        else
            forward_b = 2'b00;
    end

endmodule

`default_nettype wire
