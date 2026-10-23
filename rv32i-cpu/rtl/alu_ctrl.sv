`timescale 1ns/1ps
`default_nettype none

module alu_ctrl (
    input  logic [1:0] alu_op,     // decoder 给的大类
    input  logic [2:0] funct3,     // instr[14:12]
    input  logic [6:0] funct7,     // instr[31:25]
    output logic [3:0] alu_sel     // 给 ALU：0 ADD/1 SUB/2 AND/3 OR/4 XOR/5 SLT
);
    always_comb begin
        case (alu_op)
            2'b00 : alu_sel = 4'd0; // Load/Store: ADD
            2'b01 : alu_sel = 4'd1; // Branch: SUB
            2'b10 : alu_sel = (funct3 == 3'b000 && funct7 == 7'b0000000) ? 4'd0 : // ADD
                      (funct3 == 3'b000 && funct7 == 7'b0100000) ? 4'd1 : // SUB
                      (funct3 == 3'b111) ? 4'd2 : // AND
                      (funct3 == 3'b110) ? 4'd3 : // OR
                      (funct3 == 3'b100) ? 4'd4 : // XOR
                      (funct3 == 3'b010) ? 4'd5 : // SLT
                      4'd0;
            2'b11: alu_sel = (funct3 == 3'b000) ? 4'd0 :  // ADDI → ADD
                 (funct3 == 3'b010) ? 4'd5 :  // SLTI → SLT
                 (funct3 == 3'b100) ? 4'd4 :  // XORI → XOR
                 (funct3 == 3'b110) ? 4'd3 :  // ORI  → OR
                 (funct3 == 3'b111) ? 4'd2 :  // ANDI → AND
                                      4'd0;
            default: alu_sel = 4'd0; // Default case
        endcase
    end

endmodule
`default_nettype wire