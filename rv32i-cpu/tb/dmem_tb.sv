`timescale 1ns/1ps

module dmem_tb;
    logic        clk;
    logic        we;
    logic [31:0] addr;
    logic [31:0] wr_data;
    logic [31:0] rd_data;

    // 实例化数据存储器 (DUT)
    dmem dut (
        .clk(clk),
        .we(we),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data)
    );

    // 生成 100MHz 时钟
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/dmem.vcd");
        $dumpvars(0, dmem_tb);

        // 初始化信号
        we = 0;
        addr = 32'd0;
        wr_data = 32'd0;
        @(negedge clk);

        // 1) 测试写入与读取：向字节地址 16 (字地址 4) 写入数据 32'hDEADBEEF
        addr    = 32'd16;
        wr_data = 32'hDEADBEEF;
        we      = 1;
        @(negedge clk); // 等待上升沿完成写入

        // 关闭写使能，保持地址不变，验证读出的数据
        we = 0;
        #1; // 组合逻辑读出，稍作延迟采样
        if (rd_data === 32'hDEADBEEF) 
            $display("PASS: write & read -> addr=%h, data=%h", addr, rd_data);
        else 
            $display("FAIL: write & read -> addr=%h, data=%h", addr, rd_data);

        // 2) 测试 we=0 时写保护：尝试向地址 16 写入新数据，但保持 we=0
        addr    = 32'd16;
        wr_data = 32'h12345678;
        we      = 0;
        @(negedge clk); // 经过时钟沿

        #1;
        if (rd_data === 32'hDEADBEEF) 
            $display("PASS: we=0 protection -> data remains %h", rd_data);
        else 
            $display("FAIL: we=0 protection -> data changed to %h", rd_data);

        $finish;
    end

endmodule