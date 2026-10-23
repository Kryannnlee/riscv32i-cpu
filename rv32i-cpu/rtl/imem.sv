`timescale 1ns/1ps
`default_nettype none

module imem (
    input  logic [31:0] addr,     // 字节地址（来自 PC）
    output logic [31:0] instr     // 取出的 32 位指令
);
    logic [31:0] mem [0:255];     // 声明内存数组，共有 256 个元素，每个元素 32 位宽，
                                  // 也就是 256*4=1024 字节（1KB）大小
    assign instr = mem[addr[31:2]];   // addr[31:2] 就是 addr/4                              
     initial begin                  // 测试程序（仿真用；上板时改用 $readmemh）
    // 阶段6a：制造“数据冒险”（x2 依赖 x1，但 x1 还没写回）
    mem[0] = 32'h00500093;   // addi x1, x0, 5    → x1 = 5
    mem[1] = 32'h00108133;   // add  x2, x1, x1   → 期望 x2 = 10（冒险会拿到 0）
    mem[2] = 32'h00800193;   // addi x3, x0, 8    → x3 = 8
    mem[3] = 32'h00200213;   // addi x4, x0, 2    → x4 = 2
end           
endmodule                
`default_nettype wire
