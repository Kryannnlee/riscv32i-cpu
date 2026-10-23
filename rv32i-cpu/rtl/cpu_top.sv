`timescale 1ns/1ps
`default_nettype none

module cpu_top (
    input logic clk,
    input logic rst
    // 以后可以在这里扩展 UART 或其他外设接口
);

    // 1. 声明内部线网 (Signals & Wires)
    logic [31:0] pc, pc_next, pc_plus4, pc_branch;
    logic [31:0] instr, imm;
    logic [31:0] rs1_data, rs2_data, alu_b;
    logic [31:0] alu_result, mem_rdata, wb_data;
    
    logic [3:0]  alu_sel;
    logic [1:0]  alu_op, result_src;
    logic        reg_write, mem_read, mem_write, alu_src, branch, jump;
    logic        zero, branch_taken;

    // 2. 模块实例化与连线

    // 程序计数器 (PC)
    program_counter pc_reg (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    // 指令存储器 (IMEM)
    imem instruction_mem (
        .addr  (pc),
        .instr (instr)
    );

    // 控制器 / 译码器 (Decoder)
    decoder main_decoder (
        .instr      (instr),
        .reg_write  (reg_write),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .alu_src    (alu_src),
        .alu_op     (alu_op),
        .branch     (branch),
        .jump       (jump),
        .result_src (result_src)
    );

    // 立即数生成器 (ImmGen)
    imm_gen immediate_generator (
        .instr (instr),
        .imm   (imm)
    );

    // 寄存器堆 (RegFile)
    regfile register_file (
        .clk      (clk),
        .rst      (rst),
        .we       (reg_write),
        .rs1      (instr[19:15]),
        .rs2      (instr[24:20]),
        .rd       (instr[11:7]),
        .wr_data  (wb_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ALU 控制器 (ALU Control)
    alu_ctrl alu_control (
        .alu_op  (alu_op),
        .funct3  (instr[14:12]),
        .funct7  (instr[31:25]),
        .alu_sel (alu_sel)
    );

    // ALU 的 B 口选择多路选择器 (ALUSrc MUX)
    // alu_src = 0 选 rs2_data，alu_src = 1 选 imm
    assign alu_b = alu_src ? imm : rs2_data;

    // 算术逻辑单元 (ALU)
    alu arithmetic_logic_unit (
        .a       (rs1_data),
        .b       (alu_b),
        .alu_sel (alu_sel),
        .result  (alu_result),
        .zero    (zero)
    );

    // 数据存储器 (DMEM)
    dmem data_mem (
        .clk     (clk),
        .we      (mem_write),
        .addr    (alu_result),
        .wr_data (rs2_data),
        .rd_data (mem_rdata)
    );

    // 写回寄存器堆的数据选择多路选择器 (WB MUX)
    // result_src[0] = 0 选 alu_result，result_src[0] = 1 选 mem_rdata
    assign wb_data = result_src[0] ? mem_rdata : alu_result;

    // 3. 地址计算逻辑 (PC + 4 与 Branch 目标地址)
    assign pc_plus4  = pc + 32'd4;
    assign pc_branch = pc + imm;

    // 4. 分支判断逻辑 (Branch Logic)
    // BEQ (funct3=000): zero=1 时跳转；BNE (funct3=001): zero=0 时跳转
    assign branch_taken = branch & (instr[14:12] == 3'b000 ? zero : ~zero);

    // 5. 下一条 PC 选择多路选择器 (PC_next MUX)
    assign pc_next = branch_taken ? pc_branch : pc_plus4;

endmodule
`default_nettype wire