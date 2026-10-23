`timescale 1ns/1ps
`default_nettype none

module cpu_pipe (
    input logic clk,
    input logic rst
);

    // ── IF 段 ──
    logic [31:0] pc, pc_plus4, next_pc, instr;

    // ── if_id 的输出（给 ID 用）──
    logic [31:0] if_id_pc, if_id_instr, if_id_pc4;

    // ── ID 段的产出 ──
    logic [31:0] rs1_data, rs2_data, imm;
    logic        reg_write, mem_read, mem_write, alu_src, branch, jump;
    logic [1:0]  alu_op, result_src;

    // ── id_ex 的输出（给 EX 用）──
    logic [31:0] id_ex_rs1, id_ex_rs2, id_ex_imm, id_ex_pc, id_ex_pc4;
    logic [4:0]  id_ex_rd;
    logic [2:0]  id_ex_funct3;
    logic [6:0]  id_ex_funct7;
    logic        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write, id_ex_alu_src, id_ex_branch, id_ex_jump;
    logic [1:0]  id_ex_alu_op, id_ex_result_src;

    // ── EX 段的产出 ──
    logic [3:0]  alu_sel;
    logic [31:0] alu_b, alu_result;
    logic        zero;

    // ── ex_mem 的输出（给 MEM 用）──
    logic [31:0] ex_mem_alu_result, ex_mem_rs2, ex_mem_pc4;
    logic        ex_mem_zero, ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_branch, ex_mem_jump;
    logic [4:0]  ex_mem_rd;
    logic [1:0]  ex_mem_result_src;

    // ── MEM 段的产出 ──
    logic [31:0] mem_rdata;

    // ── mem_wb 的输出（给 WB 用）──
    logic [31:0] mem_wb_alu_result, mem_wb_mem_rdata;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_reg_write;
    logic [1:0]  mem_wb_result_src;

    // ── WB 段的产出 ──
    logic [31:0] wb_data;

    // ================= IF 段 =================
    program_counter pc_reg (.clk(clk), .rst(rst), .pc_next(next_pc), .pc(pc));
    assign pc_plus4 = pc + 32'd4;
    assign next_pc  = pc_plus4;              // 阶段5：先只做 PC+4（分支留到阶段6）

    //**涉及模块**：`pc`、`imem`、`adder`(算 PC+4)。

    imem imem_i (.addr(pc), .instr(instr));//imem_i (i for instance)，顶层模块不"自带"任何子模块。你要用哪个,就得造一个实例 + 接线:

    if_id if_id_i (
        .clk(clk), .rst(rst),
        .pc_in(pc), .instr_in(instr), .pc4_in(pc_plus4),
        .pc_out(if_id_pc), .instr_out(if_id_instr), .pc4_out(if_id_pc4)
    );

    // （下面留空，等下一步写 ID/EX/MEM/WB）
    // ================= ID 段 =================
//ID 段处理的是上一拍 IF 取到的指令(存在 if_id 里),不是当拍 IF 正在取的那条。
    decoder decoder_i(.instr(if_id_instr),
    .reg_write(reg_write), 
    .mem_read(mem_read),
     .mem_write(mem_write),
      .alu_src(alu_src),
       .alu_op(alu_op),
        .branch(branch),
         .jump(jump),
          .result_src(result_src));

    // 立即数生成
    imm_gen imm_gen_i (
        .instr (if_id_instr),
        .imm   (imm)
    );

 //**涉及模块**：`decoder`(主控制)、`regfile`(读)、`imm_gen`。

    regfile regfile_i(
        .clk(clk), .rst(rst),
        .rs1(if_id_instr[19:15]), .rs2(if_id_instr[24:20]),
        // // 写口：来自 WB 段当前的指令（mem_wb_*）★★★ 不是 if_id_instr
         .rd(mem_wb_rd),
        .wr_data(wb_data), .we(mem_wb_reg_write),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );
    //id_ex:`rs1_data`、`rs2_data`、`imm`、`rd`、`pc`、`pc_plus4`、`funct3`、`funct7` + **全部 8 个控制信号**
    id_ex id_ex_i(
        .clk(clk), .rst(rst),
        .rs1_data_in(rs1_data), .rs2_data_in(rs2_data), .imm_in(imm), .pc_in(if_id_pc), .pc4_in(if_id_pc4),
        .rd_in(if_id_instr[11:7]), .funct3_in(if_id_instr[14:12]), .funct7_in(if_id_instr[31:25]),
        .reg_write_in(reg_write), .mem_read_in(mem_read), .mem_write_in(mem_write),
        .alu_src_in(alu_src), .branch_in(branch), .jump_in(jump),
        .alu_op_in(alu_op), .result_src_in(result_src),
        .rs1_data_out(id_ex_rs1), .rs2_data_out(id_ex_rs2), .imm_out(id_ex_imm), 
        .pc_out(id_ex_pc), .pc4_out(id_ex_pc4),
        .rd_out(id_ex_rd), .funct3_out(id_ex_funct3), .funct7_out(id_ex_funct7),
        .reg_write_out(id_ex_reg_write), .mem_read_out(id_ex_mem_read), 
        .mem_write_out(id_ex_mem_write),
        .alu_src_out(id_ex_alu_src), 
        .branch_out(id_ex_branch), 
        .jump_out(id_ex_jump),
        .alu_op_out(id_ex_alu_op), 
        .result_src_out(id_ex_result_src)
    );
//-----EX---------
//**涉及模块**：`alu`、`alu_ctrl`、ALUSrc MUX
    // 1) 先生成 alu_sel
    alu_ctrl alu_ctrl_i (
        .alu_op (id_ex_alu_op),
        .funct3 (id_ex_funct3),
        .funct7 (id_ex_funct7),
        .alu_sel(alu_sel)
    );

    // 2) ALUSrc mux：选第二个操作数
    assign alu_b = id_ex_alu_src ? id_ex_imm : id_ex_rs2;

    // 3) 再真正运算
    alu alu_i (
        .a      (id_ex_rs1),
        .b      (alu_b),
        .alu_sel(alu_sel),
        .result (alu_result),
        .zero   (zero)
    );

    ex_mem ex_mem_i (
        .clk(clk), .rst(rst),
        .alu_result_in(alu_result), .rs2_data_in(id_ex_rs2), .pc4_in(id_ex_pc4),
        .zero_in(zero), .rd_in(id_ex_rd),
        .reg_write_in(id_ex_reg_write), .mem_read_in(id_ex_mem_read), 
        .mem_write_in(id_ex_mem_write),
        .branch_in(id_ex_branch), .jump_in(id_ex_jump),
        .result_src_in(id_ex_result_src),
        .alu_result_out(ex_mem_alu_result), .rs2_data_out(ex_mem_rs2), 
        .pc4_out(ex_mem_pc4),
        .zero_out(ex_mem_zero), .rd_out(ex_mem_rd),
        .reg_write_out(ex_mem_reg_write), 
        .mem_read_out(ex_mem_mem_read), 
        .mem_write_out(ex_mem_mem_write),
        .branch_out(ex_mem_branch), 
        .jump_out(ex_mem_jump),
        .result_src_out(ex_mem_result_src)
    );
//-----MEM---------
//涉及模块：dmem 输出：mem_rdata
        dmem dmem_i (
        .clk(clk),
        .we(ex_mem_mem_write),        // 只有 we，没有 mem_read/mem_write
        .addr(ex_mem_alu_result),
        .wr_data(ex_mem_rs2),
        .rd_data(mem_rdata)
    );

    mem_wb mem_wb_i (
        .clk(clk), .rst(rst),
        .alu_result_in(ex_mem_alu_result), .mem_rdata_in(mem_rdata),
        .rd_in(ex_mem_rd),
        .reg_write_in(ex_mem_reg_write),
        .result_src_in(ex_mem_result_src),
        .alu_result_out(mem_wb_alu_result), 
        .mem_rdata_out(mem_wb_mem_rdata),
        .rd_out(mem_wb_rd),
        .reg_write_out(mem_wb_reg_write),
        .result_src_out(mem_wb_result_src)
    );

//-----WB---------
    // WB mux：选写回结果
    assign wb_data = mem_wb_result_src[0] ? mem_wb_mem_rdata : mem_wb_alu_result;
    
endmodule

`default_nettype wire