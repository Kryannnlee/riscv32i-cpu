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
        // 测试8：SLTU 无符号比较——和有符号 SLT 结果相反的场景
        // -1 当作无符号是 0xFFFFFFFF（42 亿），比 1 大
        a=-32'd1; b=32'd1; alu_sel=4'd6; #1;
        if(result === 32'd0) $display("PASS SLTU: -1 <u 1 = %0d",result);
        else                  $display("FAIL SLTU: -1 <u 1 got %0d (应为 0)", result);

        // 1 比 0xFFFFFFFF 小
        a=32'd1; b=-32'd1; alu_sel=4'd6; #1;
        if(result === 32'd1) $display("PASS SLTU: 1 <u -1 = %0d",result);
        else                  $display("FAIL SLTU: 1 <u -1 got %0d (应为 1)", result);

        // 两个都正数时，有符号无符号结果相同
        a=32'd2; b=32'd3; alu_sel=4'd6; #1;
        if(result === 32'd1) $display("PASS SLTU: 2 <u 3 = %0d",result);
        else                  $display("FAIL SLTU: 2 <u 3 got %0d", result);

        // 0x80000000 有符号是最小负数（< 0），无符号是 21 亿（> 0）
        a=32'h8000_0000; b=32'd0; alu_sel=4'd6; #1;
        if(result === 32'd0) $display("PASS SLTU: 0x80000000 <u 0 = %0d",result);
        else                  $display("FAIL SLTU: 0x80000000 <u 0 got %0d (应为 0)", result);
        a=32'h8000_0000; b=32'd0; alu_sel=4'd5; #1;
        if(result === 32'd1) $display("PASS SLT : 0x80000000 <s 0 = %0d",result);
        else                  $display("FAIL SLT : 0x80000000 <s 0 got %0d (应为 1)", result);

        // 测试9：移位 SLL / SRL / SRA
        // 这三个运算以前落到 default 返回 0（静默错误），必须单独测
        a=32'd1; b=32'd4; alu_sel=4'd7; #1;
        if(result === 32'd16) $display("PASS SLL: 1<<4 = %0d",result);
        else                  $display("FAIL SLL: got %0d (应为 16)", result);

        // 移出去的高位直接丢掉
        a=32'hFFFF_FFFF; b=32'd31; alu_sel=4'd7; #1;
        if(result === 32'h8000_0000) $display("PASS SLL: 0xFFFFFFFF<<31 = 0x%08x",result);
        else                         $display("FAIL SLL: got 0x%08x (应为 0x80000000)", result);

        // 移位量只取低 5 位：1 << 32 等价于 1 << 0
        a=32'd1; b=32'd32; alu_sel=4'd7; #1;
        if(result === 32'd1) $display("PASS SLL: 移位量只取低5位 (1<<32 = %0d)",result);
        else                  $display("FAIL SLL: got %0d (应为 1)", result);

        // SRL 逻辑右移：高位补 0
        a=32'h8000_0000; b=32'd4; alu_sel=4'd8; #1;
        if(result === 32'h0800_0000) $display("PASS SRL: 0x80000000>>4 = 0x%08x",result);
        else                         $display("FAIL SRL: got 0x%08x (应为 0x08000000)", result);

        // SRA 算术右移：高位补符号位 1 —— 同一个输入，结果必须和 SRL 不同
        a=32'h8000_0000; b=32'd4; alu_sel=4'd9; #1;
        if(result === 32'hF800_0000) $display("PASS SRA: 0x80000000>>>4 = 0x%08x",result);
        else                         $display("FAIL SRA: got 0x%08x (应为 0xF8000000)", result);

        // 全 1 时两者才能看出来：SRL 高位补 0，SRA 保持全 1
        a=32'hFFFF_FFFF; b=32'd4; alu_sel=4'd8; #1;
        if(result === 32'h0FFF_FFFF) $display("PASS SRL: 0xFFFFFFFF>>4 = 0x%08x",result);
        else                         $display("FAIL SRL: got 0x%08x (应为 0x0FFFFFFF)", result);
        a=32'hFFFF_FFFF; b=32'd4; alu_sel=4'd9; #1;
        if(result === 32'hFFFF_FFFF) $display("PASS SRA: 0xFFFFFFFF>>>4 = 0x%08x",result);
        else                         $display("FAIL SRA: got 0x%08x (应为 0xFFFFFFFF)", result);

        // 测试7：zero 5-5=0 时 zero 应为 1
        a=32'd5; b=32'd5; alu_sel=4'd1; #1;
        if(zero === 1'b1) $display("PASS ZERO: %0b",zero);
        else                  $display("FAIL ZERO: got %0b", zero);
        $finish;
    end

endmodule