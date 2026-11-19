`timescale 1ns/1ps
`default_nettype none

// ============================================================
// cpu_top -- 单周期 CPU 顶层
//
// 一条指令的所有五个阶段（取指/译码/执行/访存/写回）在**同一拍**内串行走完，
// 下一拍时钟沿一到，PC 直接跳到下一条。
//
// 为什么留着它：
//   它是流水线的"标准答案"。流水线加了转发、暂停、冲刷之后，
//   结果必须和单周期完全一致。两个 testbench（cpu_tb / cpu_pipe_tb）
//   现在跑同一份程序、比同一份寄存器结果，这就成了一次免费的等价性检查。
//
// 数据通路（从左到右）：
//   PC -> IMEM -> Decoder/ImmGen/RegFile(读) -> ALU -> DMEM -> WB MUX -> RegFile(写)
//                                                     ^
//                                              PC_next MUX（分支时改道）
//
// 本文件已知局限：
//   分支只认 beq/bne，用 `funct3 == 000 ? zero : ~zero` 简化成
//   "不是 beq 就当 bne"，完整版要按 funct3 分别处理 blt/bge/bltu/bgeu。
// ============================================================
module cpu_top (
    input logic clk,
    input logic rst
    // 以后可以在这里扩展 UART 或其他外设接口
);

    // -- 1. 内部连线声明 ------------------------------------
    // 地址相关
    logic [31:0] pc, pc_next, pc_plus4, pc_branch;
    // 指令与立即数
    logic [31:0] instr, imm;
    // 数据通路
    logic [31:0] rs1_data, rs2_data, alu_b;
    logic [31:0] alu_result, mem_rdata, mem_rdata_ext, wb_data;
    logic [3:0]  store_be;
    logic [31:0] store_data;
    logic [31:0] alu_a, jump_target;
    // 控制信号
    logic [3:0]  alu_sel;
    logic [1:0]  alu_op, result_src, alu_a_src;
    logic        reg_write, mem_read, mem_write, alu_src, branch, jump;
    // 分支
    logic        zero, branch_taken;

    // -- 2. 模块实例化与连线 --------------------------------

    // 程序计数器：存当前指令地址
    // 单周期没有流水线，不存在 load-use 停顿，stall 固定接 0。
    // （不接的话是 Z，`!stall` 变成 X，PC 会卡住不动）
    program_counter pc_reg (
        .clk     (clk),
        .rst     (rst),
        .stall   (1'b0),
        .pc_next (pc_next),
        .pc      (pc)
    );

    // 指令存储器：PC -> 指令
    imem instruction_mem (
        .addr  (pc),
        .instr (instr)
    );

    // 主控制：opcode -> 8 个控制信号
    decoder main_decoder (
        .instr      (instr),
        .reg_write  (reg_write),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .alu_src    (alu_src),
        .alu_op     (alu_op),
        .branch     (branch),
        .jump       (jump),
        .result_src (result_src),
        .alu_a_src  (alu_a_src),
        .uses_rs1   (),
        .uses_rs2   ()
    );

    // 立即数生成：按指令格式把碎片拼回 32 位立即数
    imm_gen immediate_generator (
        .instr (instr),
        .imm   (imm)
    );

    // 寄存器堆：注意这里是单周期写法--
    //   读地址和写地址都直接取**当前 instr**（同一拍完成读和写）
    // 单周期关掉写优先旁路：否则 wr_data 会绕回 ALU 形成组合环
    regfile #(.BYPASS(0)) register_file (
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

    // ALU 控制：alu_op（大类）+ funct3/funct7 -> 具体运算
    alu_ctrl alu_control (
        .alu_op  (alu_op),
        .funct3  (instr[14:12]),
        .funct7  (instr[31:25]),
        .alu_sel (alu_sel)
    );

    // ALU 的 A 口来源：00=rs1 01=本条 PC 10=常数 0
    //   单周期里 pc 就是"正在执行的这条指令"的地址，直接用
    always_comb begin
        case (alu_a_src)
            2'b01:   alu_a = pc;
            2'b10:   alu_a = 32'd0;
            default: alu_a = rs1_data;
        endcase
    end

    // ALUSrc MUX：决定 ALU 的 B 口吃 rs2 还是立即数
    assign alu_b = alu_src ? imm : rs2_data;

    // ALU：算结果 / 算地址 / 比大小
    alu arithmetic_logic_unit (
        .a       (alu_a),
        .b       (alu_b),
        .alu_sel (alu_sel),
        .result  (alu_result),
        .zero    (zero)
    );

    // 数据存储器：地址来自 ALU（sw 时还要用 rs2 作写数据）
    // 字节使能：sb 一个字节，sh 两个，sw 四个
    always_comb begin
        case (instr[14:12])
            3'b000:  store_be = 4'b0001 << alu_result[1:0];          // sb
            3'b001:  store_be = alu_result[1] ? 4'b1100 : 4'b0011;   // sh
            3'b010:  store_be = 4'b1111;                             // sw
            default: store_be = 4'b0000;
        endcase
    end

    // 写数据对齐：sb/sh 取的都是 rs2 低位，摊到对应字节通道上
    always_comb begin
        case (instr[14:12])
            3'b000:  store_data = {4{rs2_data[7:0]}};                       // sb
            3'b001:  store_data = alu_result[1]
                                 ? {rs2_data[15:0], 16'd0}                  // sh 高半字
                                 : {16'd0, rs2_data[15:0]};                 // sh 低半字
            default: store_data = rs2_data;                                 // sw
        endcase
    end

    dmem data_mem (
        .clk     (clk),
        .we      (mem_write),
        .be      (store_be),
        .addr    (alu_result),
        .wr_data (store_data),
        .rd_data (mem_rdata)
    );

    // 读数据提取：lb/lh 符号扩展，lbu/lhu 零扩展，lw 原样
    load_extend_mine load_extend_i (
        .word    (mem_rdata),
        .addr_lo (alu_result[1:0]),
        .funct3  (instr[14:12]),
        .data    (mem_rdata_ext)
    );

    // WB MUX：写回来源 0=ALU 1=内存 2=PC+4（jal/jalr 的返回地址）
    always_comb begin
        case (result_src)
            2'b01:   wb_data = mem_rdata_ext;
            2'b10:   wb_data = pc_plus4;
            default: wb_data = alu_result;
        endcase
    end

    // -- 3. 地址计算 ---------------------------------------
    assign pc_plus4  = pc + 32'd4;   // 顺序执行 / 返回地址
    assign pc_branch = pc + imm;     // 分支目标：当前 PC + B 型立即数
    // 跳转目标由 ALU 算出（JAL: pc+imm，JALR: rs1+imm），bit0 必须清零
    assign jump_target = {alu_result[31:1], 1'b0};

    // -- 4. 分支判断 ---------------------------------------
    // 六种分支的条件判断
    //   beq/bne：ALU 做 SUB，看 zero
    //   blt/bge：ALU 做 SLT（有符号），看 alu_result[0]
    //   bltu/bgeu：ALU 做 SLTU（无符号），看 alu_result[0]
    // 单周期里 funct3 直接取 instr[14:12]，控制信号是 branch（不是 id_ex_branch）
    always_comb begin
        case (instr[14:12])
            3'b000:  branch_taken = branch &  zero;          // beq
            3'b001:  branch_taken = branch & ~zero;          // bne
            3'b100:  branch_taken = branch &  alu_result[0]; // blt
            3'b101:  branch_taken = branch & ~alu_result[0]; // bge
            3'b110:  branch_taken = branch &  alu_result[0]; // bltu
            3'b111:  branch_taken = branch & ~alu_result[0]; // bgeu
            default: branch_taken = 1'b0;
        endcase
    end
    // -- 5. 下一条 PC 选择 ---------------------------------
    // 优先级：跳转 > 分支 > 顺序 +4
    assign pc_next = jump         ? jump_target
                   : branch_taken ? pc_branch
                   :                pc_plus4;

endmodule
`default_nettype wire
