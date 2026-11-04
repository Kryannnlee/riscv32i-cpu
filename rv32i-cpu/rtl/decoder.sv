`timescale 1ns/1ps
`default_nettype none

// ============================================================
// decoder -- 主控制单元（指令 -> 控制信号）
//
// 一句话：看 opcode（instr[6:0]），吐出 8 个控制信号，
//        告诉数据通路"这条指令该怎么走"。
//
// 控制信号一览：
//   reg_write   1=写回寄存器堆
//   mem_read    1=读数据内存（只有 lw）
//   mem_write   1=写数据内存（只有 sw）
//   alu_src     0=ALU 的 B 口用 rs2，1=用立即数
//   alu_op      大类：00=访存 01=分支 10=R型 11=I型
//   branch      1=条件分支
//   jump        1=跳转（JAL/JALR）
//   result_src  写回来源：0=ALU 结果 1=内存读出的数据 2=PC+4
//
// 为什么先给默认值：`always_comb` 里如果某个分支漏赋值，
//   综合器会认为"要保持上一次的值"，于是生成一个锁存器（latch）。
//   先统一赋 0 再按需覆盖，就不会有这个问题。
//
// 已覆盖 RV32I 里本设计用到的 9 种 opcode：
//   R 型 / I 型算术 / lw / sw / 条件分支 / LUI / AUIPC / JAL / JALR
// 其余 opcode 走 default，全部得到 0 -> 等于 NOP。
//
// 还没做的（跑 C 程序之前可能要补）：
//   FENCE / ECALL / EBREAK / CSR 系列
//   以及 B 型里除 beq/bne 之外的 blt/bge/bltu/bgeu
// ============================================================
module decoder (
    input  logic [31:0] instr,      // 整条指令（取 [6:0] 作为 opcode）
    output logic        reg_write,  // 写寄存器
    output logic        mem_read,   // 读内存 (lw)
    output logic        mem_write,  // 写内存 (sw)
    output logic        alu_src,    // ALU B口：0=rs2, 1=imm
    output logic [1:0]  alu_op,     // 大类：00=访存, 01=分支, 10=R型, 11=I型
    output logic        branch,     // 条件分支
    output logic        jump,       // 跳转（目前恒为 0，见文件头说明）
    output logic [1:0]  result_src, // 写回来源：0=ALU, 1=mem, 2=PC+4
    // ALU 的 A 口从哪来：00=rs1（转发后） 01=本条指令的 PC 10=常数 0
    //   LUI   ：0 + imm      = imm
    //   AUIPC ：pc + imm     = pc 相对地址
    //   JAL   ：pc + imm     = 跳转目标
    //   JALR  ：rs1 + imm    = 跳转目标（所以 JALR 用 00）
    output logic [1:0]  alu_a_src,
    // * 这两根是给冒险检测用的：告诉 hazard_unit"我这条到底读不读 rs1/rs2"。
    //   只看寄存器编号不够--I 型的 instr[24:20] 是立即数，不是 rs2，
    //   拿它去比会误判成相关、白停一拍。
    output logic        uses_rs1,
    output logic        uses_rs2
);

    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin

        // -- 1. 先给所有输出一个安全默认值（防锁存器）----------
        //    默认 = "什么都不做"，即 NOP
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        result_src = 2'b00;
        uses_rs1   = 1'b0;
        uses_rs2   = 1'b0;
        alu_a_src  = 2'b00;

        // -- 2. 按 opcode 查表，只覆盖与默认值不同的项 ---------
        case (opcode)

            // R 型：两个寄存器运算，写回 ALU 结果
            7'b0110011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b0;      // B 口用 rs2
                alu_op     = 2'b10;     // 交给 alu_ctrl 按 funct3/funct7 细分
                result_src = 2'b00;
                uses_rs1   = 1'b1;
                uses_rs2   = 1'b1;
            end

            // I 型算术：rs1 与立即数运算，写回 ALU 结果
            7'b0010011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;      // B 口改用立即数
                alu_op     = 2'b11;
                result_src = 2'b00;
                uses_rs1   = 1'b1;      // 只读 rs1，不读 rs2
            end

            // lw：ALU 算地址（rs1+imm），MEM 读内存，写回的是内存数据
            7'b0000011: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;     // 只做加法算地址
                result_src = 2'b01;     // * 写回来源是内存，不是 ALU
                uses_rs1   = 1'b1;      // 只读 rs1（基址）
            end

            // sw：只写内存，不写寄存器 -- 注意 reg_write 保持 0
            7'b0100011: begin
                mem_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;     // 只做加法算地址
                uses_rs1   = 1'b1;      // rs1 算地址
                uses_rs2   = 1'b1;      // rs2 是要存的数据
            end

            // 条件分支：ALU 做减法，结果不写回，zero 给 PC 逻辑用
            7'b1100011: begin
                branch     = 1'b1;
                alu_src    = 1'b0;
                alu_op     = 2'b01;     // 减法
                uses_rs1   = 1'b1;      // 两个操作数都要读
                uses_rs2   = 1'b1;
            end

            // -- U 型 ------------------------------------------
            // LUI：把 20 位立即数搬到 rd 高位，低 12 位补 0
            //   做法：ALU 算 0 + imm。A 口选常数 0，B 口选立即数
            7'b0110111: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;     // 加法
                result_src = 2'b00;     // 写回 ALU 结果（就是 imm）
                alu_a_src  = 2'b10;     // A 口 = 0
            end

            // AUIPC：rd = 本条指令的 PC + 20 位立即数<<12
            //   用来构造 pc 相对地址（和 JALR 配合是标准写法）
            7'b0010111: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;
                result_src = 2'b00;
                alu_a_src  = 2'b01;     // A 口 = 自己的 PC
            end

            // -- 跳转 ------------------------------------------
            // JAL：rd = pc+4（返回地址），PC = pc + imm
            //   目标地址由 ALU 算（A=pc, B=imm），所以 A 口选 PC
            7'b1101111: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;
                result_src = 2'b10;     // * 写回 PC+4，不是 ALU 结果
                alu_a_src  = 2'b01;     // A 口 = 自己的 PC
            end

            // JALR：rd = pc+4，PC = (rs1 + imm) & ~1
            //   目标和 JAL 一样由 ALU 算，但基址是 rs1，所以 A 口用默认的 00
            7'b1100111: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;
                result_src = 2'b10;     // * 写回 PC+4
                uses_rs1   = 1'b1;      // 要读 rs1 当基址
            end

            // 其余 opcode 保持默认值 = NOP
        endcase
    end

endmodule
`default_nettype wire
