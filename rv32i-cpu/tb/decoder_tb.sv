`timescale 1ns/1ps

module decoder_tb;
    logic [31:0] instr;
    logic        reg_write, mem_read, mem_write, alu_src, branch, jump;
    logic [1:0]  alu_op, result_src, alu_a_src;
    logic        uses_rs1, uses_rs2;

    decoder dut (
        .instr(instr), .reg_write(reg_write), .mem_read(mem_read),
        .mem_write(mem_write), .alu_src(alu_src), .alu_op(alu_op),
        .branch(branch), .jump(jump), .result_src(result_src),
        .alu_a_src(alu_a_src),
        .uses_rs1(uses_rs1), .uses_rs2(uses_rs2)
    );

    task automatic check(
        input [6:0] op,
        input       exp_reg_write, exp_mem_read, exp_mem_write, exp_alu_src,
        input [1:0] exp_alu_op,
        input       exp_branch, exp_jump,
        input [1:0] exp_result_src, exp_alu_a_src,
        input       exp_uses_rs1, exp_uses_rs2,
        input [80*8:1] name
    );
        instr = {25'b0, op}; #1;
        if (reg_write  === exp_reg_write  &&
            mem_read   === exp_mem_read   &&
            mem_write  === exp_mem_write  &&
            alu_src    === exp_alu_src    &&
            alu_op     === exp_alu_op     &&
            branch     === exp_branch     &&
            jump       === exp_jump       &&
            result_src === exp_result_src &&
            alu_a_src  === exp_alu_a_src  &&
            uses_rs1   === exp_uses_rs1   &&
            uses_rs2   === exp_uses_rs2)
            $display("[PASS] %s (opcode=%b)", name, op);
        else begin
            $display("[FAIL] %s (opcode=%b)", name, op);
            $display("       got: rw=%b mr=%b mw=%b as=%b op=%b br=%b jp=%b rs=%b a_src=%b u1=%b u2=%b",
                     reg_write, mem_read, mem_write, alu_src, alu_op,
                     branch, jump, result_src, alu_a_src, uses_rs1, uses_rs2);
        end
    endtask

    initial begin
        $dumpfile("sim/decoder.vcd");
        $dumpvars(0, decoder_tb);

        //                  opcode   rw mr mw as  alu_op br jp  rs     a_src  u1 u2  名字
        check(7'b0110011,            1, 0, 0, 0, 2'b10, 0, 0, 2'b00, 2'b00, 1, 1, "R-type");
        check(7'b0010011,            1, 0, 0, 1, 2'b11, 0, 0, 2'b00, 2'b00, 1, 0, "I-arith");
        check(7'b0000011,            1, 1, 0, 1, 2'b00, 0, 0, 2'b01, 2'b00, 1, 0, "LW");
        check(7'b0100011,            0, 0, 1, 1, 2'b00, 0, 0, 2'b00, 2'b00, 1, 1, "SW");
        check(7'b1100011,            0, 0, 0, 0, 2'b01, 1, 0, 2'b00, 2'b00, 1, 1, "BEQ/BNE");
        check(7'b0110111,            1, 0, 0, 1, 2'b00, 0, 0, 2'b00, 2'b10, 0, 0, "LUI");
        check(7'b0010111,            1, 0, 0, 1, 2'b00, 0, 0, 2'b00, 2'b01, 0, 0, "AUIPC");
        check(7'b1101111,            1, 0, 0, 1, 2'b00, 0, 1, 2'b10, 2'b01, 0, 0, "JAL");
        check(7'b1100111,            1, 0, 0, 1, 2'b00, 0, 1, 2'b10, 2'b00, 1, 0, "JALR");
        check(7'b0000000,            0, 0, 0, 0, 2'b00, 0, 0, 2'b00, 2'b00, 0, 0, "Default");

        $finish;
    end

endmodule
