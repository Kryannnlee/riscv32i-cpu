`timescale 1ns/1ps

module regfile_tb;

    logic        clk, rst, we;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] wr_data, rs1_data, rs2_data;

    regfile dut (
        .clk(clk), .rst(rst), .we(we),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .wr_data(wr_data),
        .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    initial clk = 0;
    always #5 clk = ~clk;          // 周期 10ns

    // 一个"写寄存器"的小工具：摆好信号，过一个时钟沿写入
    task automatic write_reg(input [4:0] r, input [31:0] d);
        @(negedge clk);
        rd = r; wr_data = d; we = 1;
        @(negedge clk);
        we = 0;
    endtask

    initial begin
        $dumpfile("sim/regfile.vcd");
        $dumpvars(0, regfile_tb);

        // 复位
        rst = 1; we = 0; rs1 = 0; rs2 = 0; rd = 0; wr_data = 0;
        @(negedge clk); @(negedge clk);
        rst = 0;

        // 测试1：写 x5=0x1234，读回
        write_reg(5'd5, 32'h1234);
        rs1 = 5'd5; #1;
        if (rs1_data === 32'h1234) $display("PASS x5 = %h", rs1_data);
        else                       $display("FAIL x5 = %h, expect 1234", rs1_data);

        // 测试2 TODO：写 x0 = 0xFFFF，读 x0 应仍为 0
        write_reg(5'd0, 32'hFFFF);
        rs1 = 5'd0; #1;
        if (rs1_data === 32'd0) $display("PASS x0 = %h", rs1_data);
        else                       $display("FAIL x0 = %h, expect 0", rs1_data);

        // 测试3 TODO：写 x5/x6 两个不同值，同时读 rs1/rs2 应互不干扰
        write_reg(5'd5, 32'hAAAA);
        write_reg(5'd6, 32'h5555); 
        rs1 = 5'd5; rs2 = 5'd6; #1;
        if (rs1_data === 32'hAAAA && rs2_data === 32'h5555) $display("PASS x5/x6 = %h/%h", rs1_data, rs2_data);
        else                       $display("FAIL x5/x6 = %h/%h, expect AAAA/5555", rs1_data, rs2_data);
        // 测试4 TODO：we=0 时尝试写，寄存器应保持原值
        write_reg(5'd7, 32'hDEAD);
        we = 0; rd = 5'd7; wr_data = 32'hBEEF; @(negedge clk); // 尝试写入
        rs1 = 5'd7; #1; 
        if (rs1_data === 32'hDEAD) $display("PASS x7 = %h", rs1_data);
        else                       $display("FAIL x7 = %h, expect DEAD", rs1_data);

        $finish;
    end

endmodule