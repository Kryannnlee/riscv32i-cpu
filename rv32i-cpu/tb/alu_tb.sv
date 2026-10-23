`timescale 1ns/1ps

module alu_tb;

    logic [31:0] a, b;
    logic [3:0]  alu_sel;
    logic [31:0] result;
    logic        zero;

    alu dut (
        .a(a), .b(b), .alu_sel(alu_sel),
        .result(result), .zero(zero)
    );

    initial begin
        $dumpfile("sim/alu.vcd");
        $dumpvars(0, alu_tb);

        // 测试1：ADD  2+3=5
        a = 32'd2; b = 32'd3; alu_sel = 4'd0; #1;
        if (result === 32'd5) $display("PASS ADD: %0d", result);
        else                  $display("FAIL ADD: got %0d", result);
                      

        // 测试2：SUB  7-2=5        ← 你补
         a=32'd7;b=32'd2;alu_sel=4'd1;#1;
        if (result === 32'd5) $display("PASS SUB: %0d",result);
        else                    $display("FAIL SUB: got %0d", result);
         // 测试3：AND  1010&1100=1000
        a=32'b1010; b=32'b1100; alu_sel=4'd2; #1;
        if (result === 32'b1000) $display("PASS AND: %0b",result);
        else                  $display("FAIL AND: got %0b", result);
        // 测试4：OR   1010|1100=1110
        a=32'b1010; b=32'b1100; alu_sel=4'd3; #1;  
        if(result === 32'b1110) $display("PASS OR: %0b",result);
        else                  $display("FAIL OR: got %0b", result);
        // 测试5：XOR  1010^1100=0110
        a=32'b1010; b=32'b1100; alu_sel=4'd4; #1;
        if(result === 32'b0110) $display("PASS XOR: %0b",result);
        else                  $display("FAIL XOR: got %0b", result);
        // 测试6：SLT  2<3=1 / 7<2=0 / -1<1=1
        a=32'd2; b=32'd3; alu_sel=4'd5; #1;
        if(result === 32'd1) $display("PASS SLT: %0d",result);
        else                  $display("FAIL SLT: got %0d", result);
        a=32'd7; b=32'd2; alu_sel=4'd5; #1;
        if(result === 32'd0) $display("PASS SLT: %0d",result);
        else                  $display("FAIL SLT: got %0d", result);
        a=-32'd1; b=32'd1; alu_sel=4'd5; #1;
        if(result === 32'd1) $display("PASS SLT: %0d",result);
        else                  $display("FAIL SLT: got %0d", result);
        // 测试7：zero 5-5=0 时 zero 应为 1
        a=32'd5; b=32'd5; alu_sel=4'd1; #1;
        if(zero === 1'b1) $display("PASS ZERO: %0b",zero);
        else                  $display("FAIL ZERO: got %0b", zero);
        $finish;
    end

endmodule