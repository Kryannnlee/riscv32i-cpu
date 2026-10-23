`timescale 1ns/1ps
`default_nettype none

module alu(
    input logic[31:0] a,
    input logic[31:0] b,
    input logic [3:0] alu_sel,
    output logic [31:0] result,
    output logic zero
);
    localparam logic [3:0] ALU_ADD = 4'd0;
    localparam logic [3:0] ALU_SUB = 4'd1;
    localparam logic [3:0] ALU_AND = 4'd2;
    localparam logic [3:0] ALU_OR = 4'd3;
    localparam logic [3:0] ALU_XOR = 4'd4;
    localparam logic [3:0] ALU_SLT = 4'd5;
    assign zero = (result == 32'd0);
    always_comb begin
        case (alu_sel)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;  
        endcase
    end   
endmodule

`default_nettype wire