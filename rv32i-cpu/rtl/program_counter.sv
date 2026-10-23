`timescale 1ns/1ps
`default_nettype none

module program_counter (
    input logic clk,
    input logic rst,
    input logic [31:0] pc_next,
    output logic [31:0] pc
);//pc不能拿来做模块名字，太通用
    always_ff @(posedge clk) begin
        if(rst)begin
         pc <= 32'd0; //for reset, set pc to 0
        end
        else begin
          pc <= pc_next; //for normal operation, update pc to pc_next
        end


    end
    
endmodule
`default_nettype wire