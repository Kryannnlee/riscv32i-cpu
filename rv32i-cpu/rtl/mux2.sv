`timescale 1ns/1ps
`default_nettype none

// ============================================================
// mux2 -- 参数化二选一多路选择器
//
// 语法说明（初学者最容易卡住的地方）：
//   module mux2 #(parameter WIDTH = 32) ( ... );
//                 ^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^
//                 #() 是"参数表"--常量/规格，决定这个模块造多大
//                 ()  是"端口表"--信号/连线，是真正接进接出的东西
//
// 例化时用 #() 传参数：
//   mux2 #(.WIDTH(32)) m (.sel(s), .d0(a), .d1(b), .y(y));
// 不传就用默认值。参数化一次，32 位、5 位、1 位的多路器都能复用。
//
// 注意：本模块目前没有在任何地方被例化--cpu_top / cpu_pipe 里
//      都用三目运算符 `sel ? d1 : d0` 直接写了。两者综合结果相同。
// ============================================================
module mux2 #(parameter WIDTH = 32) (
    input  logic             sel,        // 选择：0 选 d0，1 选 d1
    input  logic [WIDTH-1:0] d0,         // 输入 0
    input  logic [WIDTH-1:0] d1,         // 输入 1
    output logic [WIDTH-1:0] y           // 输出
);

    // 三目运算符就是多路器：sel=0 取 d0，sel=1 取 d1
    assign y = sel ? d1 : d0;

endmodule

`default_nettype wire
