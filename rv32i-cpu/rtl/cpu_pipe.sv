`timescale 1ns/1ps
`default_nettype none

// ============================================================
// cpu_pipe -- 五级流水线 CPU 顶层
//
//          IF --[if_id]--> ID --[id_ex]--> EX --[ex_mem]--> MEM --[mem_wb]--> WB
//
// 一条指令要 5 拍走完，但同一时刻有 5 条指令分别处在五级里，所以
// 吞吐量是单周期的 5 倍（理想情况）。代价是要处理三类"冒险"，现已全部解决：
//
//   数据冒险  隔 1/2 条 RAW ：转发（forward_unit + 两个 MUX）
//             隔 3 条 RAW   ：寄存器堆写优先旁路（regfile 的 BYPASS 参数）
//             load-use      ：停一拍（hazard_unit 控 PC/if_id 停住 + id_ex 灌气泡）
//   控制冒险  分支/跳转在 EX 判断，此时已取错 2 条
//             -> 冲刷 if_id 和 id_ex，每次改道罚 2 拍
//
// 指令集：RV32I 常用子集，含 LUI/AUIPC/JAL/JALR、六种分支、全部移位
// 外设  ：MMIO 0x3000 —— 写 = UART 发一个字节，读 = {31'b0, busy}
//
// 每一级的"行李"怎么传：
//   流水线寄存器 = 本级产出 + 后面还要用但没用完的控制信号。
//   所以越往下走越窄：id_ex 最宽（8 个控制信号全在），mem_wb 只剩 2 个。
// ============================================================
module cpu_pipe #(
    parameter bit USE_FILE       = 0,        // 1 = imem 从 sw/prog.hex 加载 C 程序
    parameter int UART_CLK_FREQ  = 50_000_000,
    parameter int UART_BAUD_RATE = 115200
) (
    input logic clk,
    input logic rst,
    // 调试输出：上板点灯用；综合时也让整条数据通路有可观测的结果
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_x1,
    output logic [31:0] dbg_xor_all,
    // 1 = 曾经发生过未对齐的 load/store（粘住不消失）
    // 我们没有异常机制，只能把这件事暴露出来，不能 trap
    output logic        dbg_misalign,
    // UART 发送：向 MMIO 地址 0x3000 写入一个字节，就从这里串行发出
    output logic        uart_tx,
    // UART 接收：串行输入（接 USB-TTL 的 TXD）
    input  logic        uart_rx
);

    // -- IF 段 ----------------------------------------------
    logic [31:0] pc, pc_plus4, next_pc, instr;

    // -- if_id 的输出（给 ID 用）----------------------------
    logic [31:0] if_id_pc, if_id_instr, if_id_pc4;

    // -- ID 段的产出 ----------------------------------------
    logic [31:0] rs1_data, rs2_data, imm;
    logic        reg_write, mem_read, mem_write, alu_src, branch, jump;
    logic [1:0]  alu_op, result_src;
    logic        uses_rs1, uses_rs2;        // ID 指令是否真的读 rs1/rs2
    logic [1:0]  alu_a_src;                 // ALU 的 A 口来源选择

    // -- 冒险控制 -------------------------------------------
    logic        stall;                     // 1 = 停一拍（load-use）

    // -- 控制冒险（分支 / 跳转）-----------------------------
    logic [31:0] branch_target;             // 目标地址 = 分支自己的 PC + B 型立即数
    logic [31:0] jump_target;               // JAL/JALR 的目标（由 ALU 算出，bit0 清零）
    logic [31:0] redirect_target;           // 二选一之后的最终目标
    logic        branch_taken;              // 这条分支跳不跳
    logic        pc_redirect;               // 1 = 已经取错指令，要冲刷

    // -- id_ex 的输出（给 EX 用）----------------------------
    logic [31:0] id_ex_rs1_data, id_ex_rs2_data, id_ex_imm, id_ex_pc, id_ex_pc4;
    logic [4:0]  id_ex_rs1, id_ex_rs2;      // 寄存器编号（转发比较用）
    logic [4:0]  id_ex_rd;
    logic [2:0]  id_ex_funct3;
    logic [6:0]  id_ex_funct7;
    logic        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write, id_ex_alu_src, id_ex_branch, id_ex_jump;
    logic [1:0]  id_ex_alu_op, id_ex_result_src, id_ex_alu_a_src;

    // -- EX 段的产出 ----------------------------------------
    logic [3:0]  alu_sel;
    logic [31:0] alu_a, alu_b, alu_result;
    logic        zero;

    // -- 转发 -----------------------------------------------
    logic [1:0]  forward_a, forward_b;      // 来自 forward_unit 的选择信号
    logic [31:0] ex_rs1, ex_rs2;            // 转发 MUX 之后、真正送进 ALU 的操作数

    // -- ex_mem 的输出（给 MEM 用）--------------------------
    logic [31:0] ex_mem_alu_result, ex_mem_rs2, ex_mem_pc4;
    logic        ex_mem_zero, ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_branch, ex_mem_jump;
    logic [4:0]  ex_mem_rd;
    logic [2:0]  ex_mem_funct3;        // 访存大小/有无符号，MEM 级要用
    logic [1:0]  ex_mem_result_src;

    // -- MEM 段的产出 ---------------------------------------
    logic [31:0] mem_rdata;            // dmem 读出的整字
    logic [31:0] mem_rdata_ext;        // 按 lb/lh/lbu/lhu 提取并扩展后的结果
    logic [3:0]  store_be;             // 写内存时的字节使能
    logic [31:0] store_data;           // 按访存大小对齐后的写数据

    // -- MMIO（内存映射外设）---------------------------------
    // 地址分配（0x8000 页；IMEM 占 0x0000~0x1FFF，DMEM 占 0x4000~0x7FFF）：
    //   0x8000  写 = UART 发一个字节；读 = {31'b0, busy}
    //   0x8004  读 = {31'b0, rx_valid}      有没有新数据
    //   0x8008  读 = {24'b0, rx_data}       取走数据，同时清掉 valid
    //   0x800C  读 = 上电以来的时钟周期数    （基准测试用来计时）
    logic [31:0] mem_rdata_final;      // MMIO 覆盖之后真正送进 MEM/WB 的读数据
    logic        is_mmio_uart;         // 地址落在外设那一页
    logic        is_rx_status;         // 0x4004
    logic        is_rx_data;           // 0x4008
    logic        is_cycle_cnt;         // 0x400C
    logic        uart_we;              // 单拍的发送触发
    logic [7:0]  uart_data;            // 要发的字节
    logic        uart_busy;            // 1 = 上一帧还没发完

    logic [31:0] cycle_cnt;            // 周期计数器，每拍 +1

    logic        rx_pulse;             // uart_rx 收完一帧的单拍脉冲
    logic [7:0]  rx_byte;              // uart_rx 交付的字节
    logic        rx_valid;             // 粘住"有新数据"，读 0x4008 时清掉
    logic [7:0]  rx_data;              // 最近收到的字节

    // -- mem_wb 的输出（给 WB 用）---------------------------
    logic [31:0] mem_wb_alu_result, mem_wb_mem_rdata, mem_wb_pc4;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_reg_write;
    logic [1:0]  mem_wb_result_src;

    // -- WB 段的产出 ----------------------------------------
    logic [31:0] wb_data;

    // ======================== IF 段 =========================
    // 涉及模块：pc、imem、加法器（算 PC+4）
    program_counter pc_reg (.clk(clk), .rst(rst), .stall(stall), .pc_next(next_pc), .pc(pc));

    assign pc_plus4 = pc + 32'd4;

    // 下一条 PC：跳转/分支命中时改道，否则顺序 +4。
    // 决策在 EX 级做出（见下面的 branch_taken / id_ex_jump），这里只是 MUX。
    // * 分支指令进入 EX 时，pc 已经往前跑了 3 条，
    //   所以目标地址要用分支自己的 PC（id_ex_pc），不能用当前 pc。
    assign next_pc  = pc_redirect ? redirect_target : pc_plus4;

    // 指令存储器：给定地址，当拍取出指令
    imem #(.USE_FILE(USE_FILE)) imem_i (.addr(pc), .instr(instr));

    // IF/ID 寄存器：把这一拍取到的指令交给下一拍的 ID 级
    if_id if_id_i (
        .clk(clk), .rst(rst), .stall(stall), .flush(pc_redirect),
        .pc_in(pc), .instr_in(instr), .pc4_in(pc_plus4),
        .pc_out(if_id_pc), .instr_out(if_id_instr), .pc4_out(if_id_pc4)
    );

    // ======================== ID 段 =========================
    // 涉及模块：decoder（主控制）、regfile（读）、imm_gen
    // * ID 段处理的是**上一拍** IF 取到的指令（存在 if_id 里），
    //   不是这一拍 IF 正在取的那条。这是流水线最反直觉的一点。
    decoder decoder_i (
        .instr     (if_id_instr),
        .reg_write (reg_write),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .alu_src   (alu_src),
        .alu_op    (alu_op),
        .branch    (branch),
        .jump      (jump),
        .result_src(result_src),
        .alu_a_src (alu_a_src),
        .uses_rs1  (uses_rs1),
        .uses_rs2  (uses_rs2)
    );

    // 冒险检测：EX 里是 lw，且它的 rd 正好是 ID 这条真正要读的寄存器 -> 停一拍
    // 用用户自己重写的版本（逻辑等价，见 12-rebuild-log.md）
    hazard_unit_mine hazard_unit_i (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (if_id_instr[19:15]),
        .if_id_rs2      (if_id_instr[24:20]),
        .if_id_uses_rs1 (uses_rs1),
        .if_id_uses_rs2 (uses_rs2),
        .stall          (stall)
    );

    // 立即数生成
    imm_gen imm_gen_i (
        .instr (if_id_instr),
        .imm   (imm)
    );

    // 寄存器堆
    //   读口：用**当前 ID 指令**的 rs1/rs2（来自 if_id）
    //   写口：用 **WB 指令**的 rd/数据（来自 mem_wb）***
    //   读写不是同一条指令--这一点写错会导致"写完立刻能读到"的错觉。
    regfile regfile_i (
        .clk      (clk),
        .rst      (rst),
        .rs1      (if_id_instr[19:15]),
        .rs2      (if_id_instr[24:20]),
        .rd       (mem_wb_rd),
        .wr_data  (wb_data),
        .we       (mem_wb_reg_write),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .dbg_x1   (dbg_x1),
        .dbg_xor  (dbg_xor_all)
    );

    assign dbg_pc = pc;

    // ID/EX 寄存器：把 ID 的全部产出 + 8 个控制信号交给 EX
    // 注意 rs1_in / rs2_in 传的是**寄存器编号**，不是数据--
    // 转发单元要靠它跟上游的 rd 比较。
    id_ex id_ex_i (
        .clk(clk), .rst(rst), .flush(stall | pc_redirect),
        .rs1_data_in(rs1_data), .rs2_data_in(rs2_data), .imm_in(imm),
        .pc_in(if_id_pc), .pc4_in(if_id_pc4),
        .rs1_in(if_id_instr[19:15]), .rs2_in(if_id_instr[24:20]),
        .rd_in(if_id_instr[11:7]),
        .funct3_in(if_id_instr[14:12]), .funct7_in(if_id_instr[31:25]),
        .reg_write_in(reg_write), .mem_read_in(mem_read), .mem_write_in(mem_write),
        .alu_src_in(alu_src), .branch_in(branch), .jump_in(jump),
        .alu_op_in(alu_op), .result_src_in(result_src), .alu_a_src_in(alu_a_src),
        .rs1_data_out(id_ex_rs1_data), .rs2_data_out(id_ex_rs2_data),
        .rs1_out(id_ex_rs1), .rs2_out(id_ex_rs2),
        .imm_out(id_ex_imm),
        .pc_out(id_ex_pc), .pc4_out(id_ex_pc4),
        .rd_out(id_ex_rd), .funct3_out(id_ex_funct3), .funct7_out(id_ex_funct7),
        .reg_write_out(id_ex_reg_write), .mem_read_out(id_ex_mem_read),
        .mem_write_out(id_ex_mem_write),
        .alu_src_out(id_ex_alu_src),
        .branch_out(id_ex_branch),
        .jump_out(id_ex_jump),
        .alu_op_out(id_ex_alu_op),
        .result_src_out(id_ex_result_src),
        .alu_a_src_out(id_ex_alu_a_src)
    );

    // ======================== EX 段 =========================
    // 涉及模块：alu_ctrl、AluSrc MUX、ALU、forward_unit、两个转发 MUX

    // 1) 先由 alu_op（大类）+ funct3/funct7 决定具体运算
    alu_ctrl alu_ctrl_i (
        .alu_op (id_ex_alu_op),
        .funct3 (id_ex_funct3),
        .funct7 (id_ex_funct7),
        .alu_sel(alu_sel)
    );

    // 2) 转发单元：只判断"该不该抄近路"，输出选择信号（不搬数据）
    forward_unit forward_unit_i (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    // 3) 转发 MUX -- ALU 的 A 口
    //    00 = 寄存器堆读出来的原值（没人写这个寄存器）
    //    01 = EX/MEM 里的值（上一条刚算完，最新）* 优先级更高
    //    10 = MEM/WB 里的值（上上条的；它还没真正写进寄存器堆，
    //         因为 regfile 是时钟沿同步写，这一拍读到的仍是旧值）
    always_comb begin
        case (forward_a)
            2'b01:   ex_rs1 = ex_mem_alu_result;
            2'b10:   ex_rs1 = wb_data;
            default: ex_rs1 = id_ex_rs1_data;
        endcase
    end

    // 4) 转发 MUX -- rs2 这一路
    //    * 位置很关键：必须在 ALUSrc MUX **之前**。
    //      先得到"转发后的 rs2"，再让 alu_src 决定用 rs2 还是 imm。
    //      如果放到 ALUSrc 之后，addi/lw 这类用立即数的指令也会被"转发"，
    //      等于把某条无关指令的 ALU 结果当成立即数。
    always_comb begin
        case (forward_b)
            2'b01:   ex_rs2 = ex_mem_alu_result;
            2'b10:   ex_rs2 = wb_data;
            default: ex_rs2 = id_ex_rs2_data;
        endcase
    end

    // 5) A 口来源选择（LUI / AUIPC / JAL 需要 PC 或常数 0 当基址）
    //    00 = 转发后的 rs1（绝大多数指令）
    //    01 = 本条指令自己的 PC（AUIPC / JAL）
    //    10 = 常数 0（LUI：0 + imm = imm）
    //    它排在转发**之后**：转发只负责把 rs1 取对，取完再决定用不用它
    always_comb begin
        case (id_ex_alu_a_src)
            2'b01:   alu_a = id_ex_pc;
            2'b10:   alu_a = 32'd0;
            default: alu_a = ex_rs1;
        endcase
    end

    // 6) ALUSrc MUX：决定 B 口吃"转发后的 rs2"还是立即数
    assign alu_b = id_ex_alu_src ? id_ex_imm : ex_rs2;

    // 7) 真正运算
    alu alu_i (
        .a      (alu_a),
        .b      (alu_b),
        .alu_sel(alu_sel),
        .result (alu_result),
        .zero   (zero)
    );

    // 7) 分支判断（控制冒险的核心）
    //    ALU 按分支的具体类型算出比较结果：
    //      beq/bne  ：ALU 做 SUB，看 zero（结果是否为 0）
    //      blt/bge  ：ALU 做 SLT（有符号），看 alu_result[0]
    //      bltu/bgeu：ALU 做 SLTU（无符号），看 alu_result[0]
    //    SLT/SLTU 的结果只有 0 或 1，所以最低位就是"小于"这个答案。
    //    不能用 zero 来判断 blt：zero 表示"结果等于 0"，含义正好反过来。
    //    目标地址 = 分支自己的 PC + B 型立即数
    //    （imm_gen 已经做过符号扩展，bit0 也补成了 0）
    assign branch_target = id_ex_pc + id_ex_imm;

    // 分支条件用**专用比较器**算，不从 ALU 的 alu_result 取。
    //
    // 为什么：ALU 里有乘法器（M 扩展）。若 branch_taken 依赖 alu_result，
    // 综合器无法排除"这条分支指令可能走乘法"，乘法器就会被算进
    // mem_wb → 转发 → ALU → branch_taken → next_pc → PC 这条关键路径，
    // 实测 WNS 从 +4.28ns 掉到 -0.77ns，50MHz 直接不满足。
    //
    // 代价是多一个 32 位比较器（约 100 LUT），换来乘法器与 PC 更新彻底解耦。
    // 这也是常见做法：分支判断本来只需要"相等/大小"，不需要完整 ALU。
    logic br_eq;       // a == b
    logic br_ltu;      // a <  b（无符号）
    logic br_lts;      // a <  b（有符号）

    assign br_eq  = (ex_rs1 == ex_rs2);
    assign br_ltu = (ex_rs1 < ex_rs2);
    assign br_lts = ($signed(ex_rs1) < $signed(ex_rs2));

    always_comb begin
        case (id_ex_funct3)
            3'b000:  branch_taken = id_ex_branch &  br_eq;    // beq
            3'b001:  branch_taken = id_ex_branch & ~br_eq;    // bne
            3'b100:  branch_taken = id_ex_branch &  br_lts;   // blt
            3'b101:  branch_taken = id_ex_branch & ~br_lts;   // bge
            3'b110:  branch_taken = id_ex_branch &  br_ltu;   // bltu
            3'b111:  branch_taken = id_ex_branch & ~br_ltu;   // bgeu

            default: branch_taken = 1'b0;
        endcase
    end

    // 8) 跳转（JAL / JALR）
    //    目标地址单独用加法器算，**不再从 ALU 取**：
    //      JAL ：pc + imm   —— 和 branch_target 是同一个表达式，直接复用
    //      JALR：rs1 + imm  —— 这里补一个专用加法器
    //
    //    为什么要拆出来：
    //      ALU 里有乘法器（M 扩展）。如果跳转目标取自 alu_result，
    //      综合器无法证明"跳转不会走乘法"，就会把乘法器算进 PC 关键路径，
    //      实测 WNS 从 +4.28ns 掉到 -0.77ns，50MHz 不满足。
    //      拆开之后乘法器与 PC 更新完全无关。
    //
    //    bit0 清零：RISC-V 规定 JALR 目标的 bit0 必须为 0。
    logic [31:0] jalr_target;
    assign jalr_target = (ex_rs1 + id_ex_imm) & ~32'd1;

    // alu_a_src=01 表示 A 口吃 PC（即 JAL）；否则是 JALR，基址为 rs1
    assign jump_target = (id_ex_alu_a_src == 2'b01) ? branch_target : jalr_target;

    // 最终改道目标：一条指令不可能既是分支又是跳转，二选一
    assign redirect_target = id_ex_jump ? jump_target : branch_target;

    // 9) 只要改道，就说明后面取的两条指令是错的，要冲刷
    assign pc_redirect = branch_taken | id_ex_jump;

    // EX/MEM 寄存器：存 EX 的产出
    // * rs2_data_in 接的是 ex_rs2（转发后的值），不是 id_ex_rs2_data。
    //   否则 sw 存进去的会是旧值--这是最容易漏的第三处转发入口。
    ex_mem ex_mem_i (
        .clk(clk), .rst(rst),
        .alu_result_in(alu_result), .rs2_data_in(ex_rs2), .pc4_in(id_ex_pc4),
        .funct3_in(id_ex_funct3),
        .zero_in(zero), .rd_in(id_ex_rd),
        .reg_write_in(id_ex_reg_write), .mem_read_in(id_ex_mem_read),
        .mem_write_in(id_ex_mem_write),
        .branch_in(id_ex_branch), .jump_in(id_ex_jump),
        .result_src_in(id_ex_result_src),
        .alu_result_out(ex_mem_alu_result), .rs2_data_out(ex_mem_rs2),
        .pc4_out(ex_mem_pc4),
        .funct3_out(ex_mem_funct3),
        .zero_out(ex_mem_zero), .rd_out(ex_mem_rd),
        .reg_write_out(ex_mem_reg_write),
        .mem_read_out(ex_mem_mem_read),
        .mem_write_out(ex_mem_mem_write),
        .branch_out(ex_mem_branch),
        .jump_out(ex_mem_jump),
        .result_src_out(ex_mem_result_src)
    );

    // ======================== MEM 段 ========================
    // 涉及模块：dmem（写）、load_extend（读）
    // 只有 lw/sw/lb/lh/sb/sh 真正动内存，其它指令空过这一级。
    // 地址用 ALU 算出的 alu_result；写数据用转发后的 rs2（存在 ex_mem_rs2 里）。

    // 字节使能：决定 sw/sh/sb 各写几个字节、写在哪几个位置
    //   sb：只有 addr[1:0] 选中的那一个字节
    //   sh：addr[1] 选中的那一对字节（低半字或高半字）
    //   sw：四个字节全写
    //   其它 funct3（含非访存指令）：一个都不写
    always_comb begin
        case (ex_mem_funct3)
            3'b000:  store_be = 4'b0001 << ex_mem_alu_result[1:0];          // sb
            3'b001:  store_be = ex_mem_alu_result[1] ? 4'b1100 : 4'b0011;   // sh
            3'b010:  store_be = 4'b1111;                                    // sw
            default: store_be = 4'b0000;
        endcase
    end

    // 写数据对齐：
    //   RISC-V 规定 sw/sh/sb 取的都是 rs2 的**低位**，
    //   放到哪个字节位置由地址决定。
    //   所以先把数据"摊"到对应的字节通道上，dmem 里按通道直接拷贝即可。
    //   漏掉这一步的典型症状：sb 写到第 2 个字节时取成了 rs2[15:8]。
    always_comb begin
        case (ex_mem_funct3)
            3'b000:  store_data = {4{ex_mem_rs2[7:0]}};                     // sb：4 个通道都是低字节
            3'b001:  store_data = ex_mem_alu_result[1]
                                 ? {ex_mem_rs2[15:0], 16'd0}                // sh 写高半字
                                 : {16'd0, ex_mem_rs2[15:0]};               // sh 写低半字
            default: store_data = ex_mem_rs2;                               // sw：原样
        endcase
    end

    // ---- MMIO 地址译码 ----
    // 只看高 20 位判断是不是外设页；页内再用 addr[11:2] 分寄存器。
    assign is_mmio_uart = (ex_mem_alu_result[31:12] == 20'h0_0008);
    assign is_rx_status = is_mmio_uart && (ex_mem_alu_result[11:2] == 10'd1);  // 0x8004
    assign is_rx_data   = is_mmio_uart && (ex_mem_alu_result[11:2] == 10'd2);  // 0x8008
    assign is_cycle_cnt = is_mmio_uart && (ex_mem_alu_result[11:2] == 10'd3);  // 0x800C
    assign uart_we      = ex_mem_mem_write & is_mmio_uart;
    assign uart_data    = ex_mem_rs2[7:0];

    // 周期计数器：上电后每拍 +1。基准测试（Dhrystone/CoreMark）靠它算耗时。
    // 32 位 @50MHz 约 86 秒回绕，够跑一次基准。
    always_ff @(posedge clk) begin
        if (rst) cycle_cnt <= 32'd0;
        else     cycle_cnt <= cycle_cnt + 32'd1;
    end

    // ---- 未对齐访存检查 ----
    // 本设计没有异常机制，无法 trap，只能"检测 + 锁存 + 引到 LED"，
    // 至少不会让非对齐的 lw/sw 静默读写错字。
    logic mem_misaligned;
    logic misalign_seen;

    align_check align_check_i (
        .funct3    (ex_mem_funct3),
        .addr_lo   (ex_mem_alu_result[1:0]),
        .is_mem    (ex_mem_mem_read | ex_mem_mem_write),
        .misaligned(mem_misaligned)
    );

    always_ff @(posedge clk) begin
        if (rst)                 misalign_seen <= 1'b0;
        else if (mem_misaligned) misalign_seen <= 1'b1;   // 粘住，方便事后发现
    end

    assign dbg_misalign = misalign_seen;

    dmem #(.USE_FILE(USE_FILE)) dmem_i (
        .clk(clk),
        // 写 MMIO 时不能同时写内存：0x3000 的 addr[11:2] 恰好是 0，
        // 不挡住的话会把 dmem[0] 踩掉。
        .we(ex_mem_mem_write & ~is_mmio_uart),
        .be(store_be),
        .addr(ex_mem_alu_result),
        .wr_data(store_data),
        .rd_data(mem_rdata)
    );

    // MMIO 读优先于 dmem
    always_comb begin
        if (is_cycle_cnt && ex_mem_mem_read)
            mem_rdata_final = cycle_cnt;                // 0x800C: 周期计数
        else if (is_rx_status && ex_mem_mem_read)
            mem_rdata_final = {31'd0, rx_valid};        // 0x8004: 有新数据吗
        else if (is_rx_data && ex_mem_mem_read)
            mem_rdata_final = {24'd0, rx_data};         // 0x8008: 取数据
        else if (is_mmio_uart && ex_mem_mem_read)
            mem_rdata_final = {31'd0, uart_busy};       // 0x8000: 发送忙
        else
            mem_rdata_final = mem_rdata;
    end

    // 读数据提取：lb/lh 符号扩展，lbu/lhu 零扩展，lw 原样通过
    load_extend_mine load_extend_i (
        .word    (mem_rdata_final),
        .addr_lo (ex_mem_alu_result[1:0]),
        .funct3  (ex_mem_funct3),
        .data    (mem_rdata_ext)
    );

    // UART 发送端：send 是单拍脉冲（模块内部有上升沿检测）
    uart_tx #(
        .CLK_FREQ (UART_CLK_FREQ),
        .BAUD_RATE(UART_BAUD_RATE)
    ) uart_tx_i (
        .clk  (clk),
        .rst  (rst),
        .data (uart_data),
        .send (uart_we),
        .tx   (uart_tx),
        .busy (uart_busy)
    );

    // UART 接收端：异步输入 + 五点多数表决（见 uart_rx.sv 头注释）
    uart_rx #(
        .CLK_FREQ (UART_CLK_FREQ),
        .BAUD_RATE(UART_BAUD_RATE)
    ) uart_rx_i (
        .clk  (clk),
        .rst  (rst),
        .rx   (uart_rx),
        .data (rx_byte),
        .valid(rx_pulse),
        .busy ()
    );

    // 收完一帧就置 valid（粘住，直到软件读走）；
    // 读 0x3008 的同时清掉，相当于"取走数据"。
    always_ff @(posedge clk) begin
        if (rst) begin
            rx_valid <= 1'b0;
            rx_data  <= 8'd0;
        end else if (rx_pulse) begin
            rx_data  <= rx_byte;
            rx_valid <= 1'b1;
        end else if (is_rx_data && ex_mem_mem_read) begin
            rx_valid <= 1'b0;
        end
    end

    // MEM/WB 寄存器：只带 rd、两个候选写回值和 2 个控制信号
    mem_wb mem_wb_i (
        .clk(clk), .rst(rst),
        .alu_result_in(ex_mem_alu_result), .mem_rdata_in(mem_rdata_ext),
        .pc4_in(ex_mem_pc4),
        .rd_in(ex_mem_rd),
        .reg_write_in(ex_mem_reg_write),
        .result_src_in(ex_mem_result_src),
        .alu_result_out(mem_wb_alu_result),
        .mem_rdata_out(mem_wb_mem_rdata),
        .pc4_out(mem_wb_pc4),
        .rd_out(mem_wb_rd),
        .reg_write_out(mem_wb_reg_write),
        .result_src_out(mem_wb_result_src)
    );

    // ======================== WB 段 =========================
    // 写回来源选择（2 位，三种来源）：
    //   00 = ALU 结果（算术/逻辑/地址）
    //   01 = 内存读出的数据（lw）
    //   10 = PC+4（jal/jalr 的返回地址）
    // * 以前只判了 result_src[0]，所以 10 和 00 会混在一起；现在按完整两位译码。
    //   注意 wb_data 同时也被上面的转发 MUX 当 MEM/WB 源使用，
    //   所以这里必须选对--否则转发的也是错值。
    always_comb begin
        case (mem_wb_result_src)
            2'b01:   wb_data = mem_wb_mem_rdata;
            2'b10:   wb_data = mem_wb_pc4;
            default: wb_data = mem_wb_alu_result;
        endcase
    end

endmodule

`default_nettype wire
