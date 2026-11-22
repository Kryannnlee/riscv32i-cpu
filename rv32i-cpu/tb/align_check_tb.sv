`timescale 1ns/1ps
`default_nettype none

// ============================================================
// align_check_tb -- 穷举 funct3 × addr_lo × is_mem 的组合
//
// 三种数据宽度 × 四种地址低位 × 访存/非访存 = 24 组，全部检查。
// ============================================================
module align_check_tb;

    logic [2:0] funct3;
    logic [1:0] addr_lo;
    logic       is_mem;
    logic       misaligned;

    align_check dut (
        .funct3    (funct3),
        .addr_lo   (addr_lo),
        .is_mem    (is_mem),
        .misaligned(misaligned)
    );

    int errors = 0;
    int i, j, k;

    // 期望值：按对齐规则算
    function automatic logic expect_mis(input logic [2:0] f3,
                                        input logic [1:0] a,
                                        input logic       mem);
        logic bad;
        case (f3)
            3'b010:          bad = (a != 2'b00);
            3'b001, 3'b101:  bad = a[0];
            default:         bad = 1'b0;
        endcase
        return mem & bad;
    endfunction

    logic [2:0] f3_list [0:4];
    initial begin
        $display("==== align_check 穷举测试 ====");
        f3_list[0] = 3'b000;   // lb / sb
        f3_list[1] = 3'b001;   // lh / sh
        f3_list[2] = 3'b010;   // lw / sw
        f3_list[3] = 3'b100;   // lbu
        f3_list[4] = 3'b101;   // lhu

        for (i = 0; i < 5; i++) begin
            for (j = 0; j < 4; j++) begin
                for (k = 0; k < 2; k++) begin
                    funct3  = f3_list[i];
                    addr_lo = j[1:0];
                    is_mem  = k[0];
                    #1;
                    if (misaligned !== expect_mis(f3_list[i], j[1:0], k[0])) begin
                        $display("  FAIL f3=%03b addr_lo=%02b is_mem=%b -> %b (期望 %b)",
                                 funct3, addr_lo, is_mem, misaligned,
                                 expect_mis(f3_list[i], j[1:0], k[0]));
                        errors++;
                    end
                end
            end
        end

        $display("  PASS 检查了 5×4×2 = 40 组");

        if (errors == 0) $display("==== ALIGN_CHECK ALL PASS ====");
        else             $display("==== ALIGN_CHECK FAIL: %0d 处 ====", errors);

        if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
        $finish;
    end

endmodule
`default_nettype wire
