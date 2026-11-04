`timescale 1ns/1ps

// 等价性验证：把同一组输入同时喂给
//   forward_unit       （原有版本）
//   forward_unit_mine  （用户重写的版本）
// 逐组比对输出。全部一致 = 两者行为等价。

module forward_unit_cmp_tb;
    logic [4:0] id_ex_rs1, id_ex_rs2, ex_mem_rd, mem_wb_rd;
    logic       ex_mem_reg_write, mem_wb_reg_write;
    logic [1:0] forward_a, forward_b;        // 原版输出
    logic [1:0] forward_a_m, forward_b_m;    // 用户版输出

    forward_unit ref_dut (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    forward_unit_mine mine_dut (
        .id_ex_rs1       (id_ex_rs1),
        .id_ex_rs2       (id_ex_rs2),
        .ex_mem_rd       (ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd       (mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a       (forward_a_m),
        .forward_b       (forward_b_m)
    );

    // 取几个有代表性的寄存器号：0（特殊）、1~5（常见）、31（边界）
    int vals [0:6];

    int errors  = 0;
    int checked = 0;

    initial begin
        $dumpfile("sim/forward_unit_cmp.vcd");
        $dumpvars(0, forward_unit_cmp_tb);

        vals[0] = 0; vals[1] = 1; vals[2] = 2; vals[3] = 3;
        vals[4] = 4; vals[5] = 5; vals[6] = 31;

        // 穷举这几个值的所有组合 × 两个写使能的 4 种情况
        for (int i = 0; i < 7; i++)
        for (int j = 0; j < 7; j++)
        for (int k = 0; k < 7; k++)
        for (int l = 0; l < 7; l++)
        for (int w1 = 0; w1 < 2; w1++)
        for (int w2 = 0; w2 < 2; w2++) begin
            id_ex_rs1        = vals[i];
            id_ex_rs2        = vals[j];
            ex_mem_rd        = vals[k];
            mem_wb_rd        = vals[l];
            ex_mem_reg_write = w1;
            mem_wb_reg_write = w2;
            #1;

            checked++;
            if (forward_a !== forward_a_m || forward_b !== forward_b_m) begin
                errors++;
                if (errors <= 5)
                    $display("MISMATCH  rs1=%0d rs2=%0d | ex_rd=%0d we=%b | wb_rd=%0d we=%b",
                             id_ex_rs1, id_ex_rs2,
                             ex_mem_rd, ex_mem_reg_write,
                             mem_wb_rd, mem_wb_reg_write);
            end
        end

        $display("---- 等价性检查 ----");
        $display("  比对了 %0d 组输入，不一致 %0d 组", checked, errors);

        if (errors == 0)
            $display("==== EQUIVALENT（两份实现行为完全一致）====");
        else
            $display("==== NOT EQUIVALENT ====");

        $finish;
    end

endmodule
