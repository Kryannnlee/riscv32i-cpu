`timescale 1ns/1ps
`default_nettype none

// ============================================================
// div_unit -- 32 位除法器（多周期，restoring 算法）
//
// 为什么必须多周期：
//   组合展开要 32 级"移位-比较-减"，实测最长路径 82.6ns，
//   50MHz（20ns）差 4 倍。拆成 32 拍，每拍只做一级，路径很短。
//
// 算法（restoring division）：
//   rem = 0, quo = 0
//   重复 32 次：
//       r_next = (rem << 1) | 被除数的下一位     ← 要 33 位，防左移溢出
//       quo = quo << 1
//       if (r_next >= 除数) { rem = r_next - 除数; quo[0] = 1; }
//       else                 { rem = r_next; }
//   结束后 quo 是商，rem 是余数
//
// RISC-V 规定的三种特殊情况：
//   1. 除零   -> 商 = 全 1（0xFFFFFFFF），余数 = 被除数（不产生异常）
//   2. 溢出   -> INT_MIN / -1 的商 = INT_MIN，余数 = 0
//   3. 符号   -> 商的符号 = 两操作数符号异或；余数的符号跟被除数
// ============================================================
module div_unit (
    input  logic        clk,
    input  logic        rst,

    input  logic        start,       // 单拍脉冲：开始一次除法
    input  logic        is_signed,   // 1 = div/rem（有符号），0 = divu/remu
    input  logic        want_rem,    // 1 = 要余数，0 = 要商
    input  logic [31:0] dividend,    // 被除数（rs1）
    input  logic [31:0] divisor,     // 除数（rs2）

    output logic [31:0] result,      // 商或余数
    output logic        busy,        // 1 = 正在算
    output logic        done         // 算完的单拍脉冲
);
    typedef enum logic [1:0] {IDLE, RUN, FINISH} state_t;
    state_t state;

    logic [32:0] rem;        // 33 位余数：左移时要吞掉一位
    logic [31:0] quo;        // 商，逐步左移填位
    logic [31:0] a_sh;       // 被除数，每拍左移，最高位喂给 rem
    logic [31:0] b_reg;      // 除数（已取绝对值）
    logic [5:0]  cnt;        // 已完成的轮数 0..31

    // 开始那拍算好的中间量
    logic        sign_a, sign_b, q_neg;
    logic [31:0] ua, ub;
    logic        div_by_zero;
    logic        overflow;

    always_comb begin
        sign_a = dividend[31];
        sign_b = divisor[31];
        q_neg  = is_signed & (sign_a ^ sign_b);

        ua = (is_signed & dividend[31]) ? (~dividend + 32'd1) : dividend;
        ub = (is_signed & divisor[31])  ? (~divisor  + 32'd1) : divisor;

        div_by_zero = (divisor == 32'd0);
        overflow    = is_signed & (dividend == 32'h8000_0000) & (divisor == 32'hFFFF_FFFF);
    end

    // 本轮左移后的余数（33 位）
    wire [32:0] r_next = {rem[31:0], a_sh[31]};

    always_ff @(posedge clk) begin
        if (rst) begin
            state  <= IDLE;
            rem    <= 33'd0;
            quo    <= 32'd0;
            a_sh   <= 32'd0;
            b_reg  <= 32'd0;
            cnt    <= 6'd0;
            result <= 32'd0;
            busy   <= 1'b0;
            done   <= 1'b0;
        end else begin
            done <= 1'b0;       // 默认不给脉冲

            case (state)

            IDLE: begin
                busy <= 1'b0;
                if (start) begin
                    if (div_by_zero) begin
                        result <= want_rem ? dividend : 32'hFFFF_FFFF;
                        done   <= 1'b1;
                    end else if (overflow) begin
                        result <= want_rem ? 32'd0 : 32'h8000_0000;
                        done   <= 1'b1;
                    end else begin
                        busy  <= 1'b1;
                        rem   <= 33'd0;
                        quo   <= 32'd0;
                        a_sh  <= ua;
                        b_reg <= ub;
                        cnt   <= 6'd0;
                        state <= RUN;
                    end
                end
            end

            RUN: begin
                busy <= 1'b1;

                // 一轮：余数左移吞一位，再判断够不够减
                if (r_next >= {1'b0, b_reg}) begin
                    rem <= r_next - {1'b0, b_reg};
                    quo <= {quo[30:0], 1'b1};
                end else begin
                    rem <= r_next;
                    quo <= {quo[30:0], 1'b0};
                end
                a_sh <= {a_sh[30:0], 1'b0};

                cnt <= cnt + 6'd1;
                if (cnt == 6'd31)
                    state <= FINISH;
            end

            FINISH: begin
                busy  <= 1'b0;
                done  <= 1'b1;
                state <= IDLE;

                if (want_rem)
                    // 余数符号跟**被除数**
                    result <= (is_signed & sign_a) ? (~rem[31:0] + 32'd1) : rem[31:0];
                else
                    // 商符号 = 两操作数符号异或
                    result <= q_neg ? (~quo + 32'd1) : quo;
            end

            default: state <= IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
