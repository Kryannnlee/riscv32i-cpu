`timescale 1ns/1ps
`default_nettype none

module imem_tb;
    logic [31:0] addr, instr;
    imem dut (.addr(addr), .instr(instr));

    initial begin
        $dumpfile("sim/imem.vcd");
        $dumpvars(0, imem_tb);

        addr = 32'd0;  #1; if (instr===32'h00A30293) $display("PASS addr=0"); else $display("FAIL addr=0 -> %h", instr);
        addr = 32'd4;  #1; if (instr===32'h007302B3) $display("PASS addr=4"); else $display("FAIL addr=4 -> %h", instr);
        addr = 32'd8;  #1; if (instr===32'h00B30333) $display("PASS addr=8"); else $display("FAIL addr=8 -> %h", instr);
        addr = 32'd12; #1; if (instr===32'h00C303B3) $display("PASS addr=12"); else $display("FAIL addr=12 -> %h", instr);

        $finish;
    end
endmodule

`default_nettype wire
