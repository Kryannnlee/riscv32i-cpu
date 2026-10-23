`timescale 1ns/1ps

module pc_tb;
    logic        clk, rst;
    logic [31:0] pc_next, pc;

    program_counter dut (.clk(clk), .rst(rst), .pc_next(pc_next), .pc(pc));

    initial clk = 0;
    always #5 clk = ~clk;          // #5：表示延时 5 个时间单位（结合前面的timescale 1ns/1ps，即 5ns）每隔 5ns 翻转一次电平，因此一个完整的时钟周期5ns*2=10ns，频率为 100MHz

    initial begin
        $dumpfile("sim/pc.vcd");
        $dumpvars(0, pc_tb);

        // 1) 复位 → pc 应为 0
        rst = 1; pc_next = 32'd0;
        @(negedge clk); @(negedge clk);// 拉高复位信号 rst，给定 pc_next，等待 2 个时钟周期后检查 pc 是否清零
        if (pc === 32'd0) $display("PASS: reset -> pc=%h", pc);
        else              $display("FAIL: reset -> pc=%h", pc);
        rst = 0;

        // 2) 给 pc_next=4，过一个时钟沿后 pc 应变 4
        @(negedge clk); pc_next = 32'd4;
        @(negedge clk); #1;          // 中间经过 posedge，pc 更新
        if (pc === 32'd4) $display("PASS: pc=%h", pc);
        else              $display("FAIL: pc=%h", pc);

        // 3) 再给 pc_next=32'h10，验证 pc 变成 10
        @(negedge clk); pc_next = 32'h10;
        @(negedge clk); #1;          // 中间经过 posedge，pc 更新
        if (pc === 32'h10) $display("PASS: pc=%h", pc);
        else               $display("FAIL: pc=%h", pc);
        // 4) 验证复位优先（rst=1 时 pc 立刻清 0）
        rst = 1; pc_next = 32'hBEEF;//”吃牛肉“
                @(negedge clk); #1;          // 中间经过 posedge，pc    
        if (pc === 32'd0) $display("PASS: reset -> pc=%h", pc);
        else              $display("FAIL: reset -> pc=%h", pc);
        $finish;
    end

endmodule