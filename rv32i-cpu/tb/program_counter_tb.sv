`timescale 1ns/1ps

module pc_tb;
    logic        clk, rst, stall;
    logic [31:0] pc_next, pc;

    program_counter dut (.clk(clk), .rst(rst), .stall(stall), .pc_next(pc_next), .pc(pc));

    initial clk = 0;
    always #5 clk = ~clk;          // 周期 10ns，100MHz

    initial begin
        $dumpfile("sim/pc.vcd");
        $dumpvars(0, pc_tb);

        stall = 0;

        // 1) 复位 → pc 应为 0
        rst = 1; pc_next = 32'd0;
        @(negedge clk); @(negedge clk);
        if (pc === 32'd0) $display("PASS: reset -> pc=%h", pc);
        else              $display("FAIL: reset -> pc=%h", pc);
        rst = 0;

        // 2) 给 pc_next=4，过一个时钟沿后 pc 应变 4
        @(negedge clk); pc_next = 32'd4;
        @(negedge clk); #1;
        if (pc === 32'd4) $display("PASS: pc=%h", pc);
        else              $display("FAIL: pc=%h", pc);

        // 3) 再给 pc_next=32'h10，验证 pc 变成 10
        @(negedge clk); pc_next = 32'h10;
        @(negedge clk); #1;
        if (pc === 32'h10) $display("PASS: pc=%h", pc);
        else               $display("FAIL: pc=%h", pc);

        // 4) stall=1 时 pc 必须保持不动（load-use 冒险靠这个）
        @(negedge clk); pc_next = 32'h20; stall = 1;
        @(negedge clk); #1;
        if (pc === 32'h10) $display("PASS: stall -> pc 保持 %h", pc);
        else               $display("FAIL: stall -> pc=%h（应为 10）", pc);

        // 5) stall 撤销后，pc 才追上去
        stall = 0;
        @(negedge clk); #1;
        if (pc === 32'h20) $display("PASS: 撤销 stall -> pc=%h", pc);
        else               $display("FAIL: 撤销 stall -> pc=%h（应为 20）", pc);

        // 6) 复位优先（rst=1 时 pc 立刻清 0）
        rst = 1; pc_next = 32'hBEEF;
        @(negedge clk); #1;
        if (pc === 32'd0) $display("PASS: reset -> pc=%h", pc);
        else              $display("FAIL: reset -> pc=%h", pc);
        $finish;
    end

endmodule
