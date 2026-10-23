`timescale 1ns/1ps

module decoder_tb;
    logic [31:0] instr;
    logic        reg_write, mem_read, mem_write, alu_src, branch, jump;
    logic [1:0]  alu_op, result_src;

    decoder dut (
        .instr(instr), .reg_write(reg_write), .mem_read(mem_read),
        .mem_write(mem_write), .alu_src(alu_src), .alu_op(alu_op),
        .branch(branch), .jump(jump), .result_src(result_src)
    );

    task automatic check(
        input [6:0] op,
        input       exp_reg_write, exp_mem_read, exp_mem_write, exp_alu_src,
        input [1:0] exp_alu_op,
        input       exp_branch,
        input [1:0] exp_result_src,
        input [80*8:1] name
    );
        instr = {25'b0, op}; #1;
        if (reg_write  === exp_reg_write &&
            mem_read   === exp_mem_read  &&
            mem_write  === exp_mem_write &&
            alu_src    === exp_alu_src   &&
            alu_op     === exp_alu_op    &&
            branch     === exp_branch    &&
            result_src === exp_result_src)
            $display("[PASS] %s (opcode=%b)", name, op);
        else
            $display("[FAIL] %s (opcode=%b)", name, op);
    endtask

    initial begin
        $dumpfile("sim/decoder.vcd");
        $dumpvars(0, decoder_tb);

        check(7'b0110011, 1,0,0,0, 2'b10, 0, 2'b00, "R-type");
        check(7'b0010011, 1,0,0,1, 2'b11, 0, 2'b00, "I-arith");
        check(7'b0000011, 1,1,0,1, 2'b00, 0, 2'b01, "LW");
        check(7'b0100011, 0,0,1,1, 2'b00, 0, 2'b00, "SW");
        check(7'b1100011, 0,0,0,0, 2'b01, 1, 2'b00, "BEQ/BNE");
        check(7'b0000000, 0,0,0,0, 2'b00, 0, 2'b00, "Default");

        $finish;
    end

endmodule