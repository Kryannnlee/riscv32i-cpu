`timescale 1ns/1ps

module mux2_tb;
    logic        sel;
    logic [31:0] d0, d1, y;

    mux2 dut (.sel(sel), .d0(d0), .d1(d1), .y(y));   // WIDTH 用默认 32

    initial begin
        $dumpfile("sim/mux2.vcd");
        $dumpvars(0, mux2_tb);

        // sel=0 → y = d0
        sel = 1'b0; d0 = 32'hAAAA_AAAA; d1 = 32'h5555_5555; #1;
        if (y === 32'hAAAA_AAAA) $display("PASS: sel=0 -> y=%h", y);
        else                     $display("FAIL: sel=0 -> y=%h", y);

        // sel=1 → y = d1
        sel = 1'b1; #1;
        if (y === 32'h5555_5555) $display("PASS: sel=1 -> y=%h", y);
        else                     $display("FAIL: sel=1 -> y=%h", y);

                // 换一组 d0/d1 再测
        sel = 1'b0; d0 = 32'h1111_1111; d1 = 32'h2222_2222; #1;
        if (y === 32'h1111_1111) $display("PASS: sel=0 -> y=%h", y);
        else                     $display("FAIL: sel=0 -> y=%h", y);
    
        sel = 1'b1; #1;   // d0/d1 不变，只翻 sel
        if (y === 32'h2222_2222) $display("PASS: sel=1 -> y=%h", y);
        else                     $display("FAIL: sel=1 -> y=%h", y);
        $finish;
    end

endmodule