`timescale 1ns/1ps
`default_nettype none

// ============================================================
// dmem -- 数据存储器（4KB，1024 个 32 位字）
//
// 为什么和 imem 分开：
//   指令和数据在 RV32I 里是两条独立通路（哈佛结构简化版）。
//   分开之后 IF 和 MEM 可以同时访问，不会互相挡路。
//   上板时两者分别映射到 BRAM，合起来才是冯.诺依曼的统一内存。
//
// 地址怎么用：
//   CPU 给出的是**字节地址**（每 4 字节一条指令/一个字），
//   但数组是按**字**编号的，所以要丢掉低 2 位：addr[11:2] 等价于 addr/4。
//   这就是为什么 RISC-V 要求访存地址 4 字节对齐。
//
// 地址范围（和 sw/link.ld 的 DMEM 段一致）：
//   0x1000 ~ 0x1FFF  ->  mem[0] ~ mem[1023]
//   链接脚本把 .data/.bss 放在 0x1000，栈顶在 0x2000 向下生长。
//
// 读组合、写时序：
//   读是异步的（地址给进去，当拍出数据）；
//   写在时钟上升沿才真正落地。
//   这决定了 lw 的数据要到 MEM 级结束才可靠--也正是 load-use 冒险的由来。
//
// 仿真注意：数组没初始化时是 X。上板时 BRAM 初始值是 0 或不关心，
//   但仿真里必须显式初始化，否则读未写过的地址会得到 X 并扩散。
// ============================================================
module dmem #(
    parameter bit USE_FILE = 0        // 1 = 从 sw/prog_data.hex 预载 .rodata/.data
) (
    input  logic        clk,
    input  logic        we,        // 写使能：只有 sw/sh/sb 会置 1
    input  logic [3:0]  be,        // 字节写使能：be[i]=1 才写第 i 个字节
    input  logic [31:0] addr,      // 字节地址（来自 ALU 的 rs1+imm）
    input  logic [31:0] wr_data,   // 要写的数据（来自 rs2，已过转发）
    output logic [31:0] rd_data    // 读出的**整字**（扩展由 load_extend 做）
);

    // 1024 个 32 位字 = 4KB
    // ram_style=distributed 强制用 LUTRAM 实现。
    // 不加的话 Vivado 会把它推断成 Block RAM，而 BRAM 只能同步读，
    // 行为和这里的组合读差一拍，上板会错。
    // 4096 个 32 位字 = 16KB
    (* ram_style = "distributed" *) logic [31:0] mem [0:4095];

    // 复位：全部清零。
    // 和 imem 一个道理（cases/case-17）：不初始化的话读出来是 X，
    // 而且"只写了某几个字节、其余字节没写"时，lw 读整字会得到 X。
    // 真实程序里这一步由 crt0 清零 .bss 完成；仿真/上板这里直接给初值。
    initial begin
        for (int i = 0; i < 4096; i++)
            mem[i] = 32'd0;

        // 跑 C 程序时，把 .rodata/.data 的初始值装进来。
        // 没有这一步，C 里的字符串常量读到的是全 0（见 cases/case-23）。
        // 文件由 sw/build.sh 用 objcopy 抽出 0x1000 起的字节再转成 hex。
        if (USE_FILE)
            $readmemh("sw/prog_data.hex", mem);
    end

    // -- 读：组合逻辑，异步 --
    // addr[11:2] 丢弃低 2 位，把字节地址换算成字下标
    assign rd_data = mem[addr[13:2]];

    // -- 写：时序逻辑，同步，支持按字节写 --
    // be 的每一位控制一个字节。sw 四位全 1，sh 两位，sb 一位。
    //
    // 为什么不用 we 直接写整字：sb 只能改 1 个字节，其余 3 个字节必须保持原值。
    // 所以要么按字节分别赋值（下面这种），要么读出旧字 -> 改字节 -> 写回。
    // 按字节赋值更直接，也能让综合器推断出带字节使能的 RAM。
    always_ff @(posedge clk) begin
        if (we) begin
            if (be[0]) mem[addr[13:2]][7:0]   <= wr_data[7:0];
            if (be[1]) mem[addr[13:2]][15:8]  <= wr_data[15:8];
            if (be[2]) mem[addr[13:2]][23:16] <= wr_data[23:16];
            if (be[3]) mem[addr[13:2]][31:24] <= wr_data[31:24];
        end
    end

endmodule

`default_nettype wire
