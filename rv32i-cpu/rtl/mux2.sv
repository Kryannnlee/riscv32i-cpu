`timescale 1ns/1ps
`default_nettype none

module mux2 #(parameter WIDTH = 32) (
    input  logic             sel,        // 选择：0 选 d0，1 选 d1
    input  logic [WIDTH-1:0] d0,         // 输入 0
    input  logic [WIDTH-1:0] d1,         // 输入 1
    output logic [WIDTH-1:0] y           // 输出
);//"#"() = 参数(常量/规格),() = 端口(信号/连线)

    assign y = sel ? d1 : d0;

endmodule

`default_nettype wire