`timescale 1ns/1ps
`default_nettype none

// ============================================================
// uart_rx -- UART 接收端（8N1，115200）
//
// 和 uart_tx 的差别很大，因为接收是"猜别人的时钟"：
//   TX 只要按自己的节奏一位位发出去就行；
//   RX 必须从线上的电平变化里**重建出对方的位边界**。
//
// 三个关键点（参考官方例程 ch06/ch09 的做法）：
//
//   1. 两级同步器
//      rx 是异步输入（对方时钟和我们无关），直接用会有亚稳态。
//      先用两个触发器把它同步到 clk 域，再做任何判断。
//
//   2. 位中间采样
//      起始位下降沿是唯一定时基准。从那一刻起数 CPB 拍就是一位。
//      在每位的**正中间**（MID 拍）采样，这时信号最稳。
//
//   3. 五点多数表决
//      在中间连采 5 拍（MID-2 .. MID+2），3 票以上才算 1。
//      相当于一个数字滤波器，能滤掉毛刺和轻微波特率偏差。
//
//   另外还有假起始位退出：采完起始位如果多数是 1，说明那是噪声不是起始位，
//   立刻回 IDLE，不等收完 10 位。
// ============================================================
module uart_rx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst,        // 高有效，和项目其他模块一致
    input  logic       rx,         // 串行输入（接 USB-TTL 的 TXD）
    output logic [7:0] data,       // 收到的字节
    output logic       valid,      // 收完一帧的单拍脉冲
    output logic       busy        // 1 = 正在接收
);
    // 一位占多少拍。50MHz/115200 = 434
    localparam int CPB = CLK_FREQ / BAUD_RATE;
    // 采样中心：位中间
    localparam int MID = CPB / 2;

    // ---------------- 两级同步器 ----------------
    logic rx_s1, rx_s2, rx_s3;

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_s1 <= 1'b1;      // 空闲时线上是高电平
            rx_s2 <= 1'b1;
            rx_s3 <= 1'b1;
        end else begin
            rx_s1 <= rx;
            rx_s2 <= rx_s1;
            rx_s3 <= rx_s2;     // 第三级只用来做下降沿检测
        end
    end

    // 下降沿 = 起始位开始（注意：检测的是"上一拍还是高、这一拍变低"）
    wire start_edge = rx_s3 & ~rx_s2;

    // ---------------- 状态机 ----------------
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,      // 等过起始位
        DATA  = 2'b10,      // 收 8 个数据位
        STOP  = 2'b11       // 等过停止位
    } state_t;

    state_t      state;
    logic [15:0] cyc;        // 位内计数器 0 .. CPB-1
    logic [2:0]  bitn;       // 第几个数据位 0..7
    logic [7:0]  shreg;      // 移位寄存器（低位先进）
    logic [2:0]  vote;       // 五点表决累加器 0..5

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cyc   <= 16'd0;
            bitn  <= 3'd0;
            shreg <= 8'd0;
            vote  <= 3'd0;
            data  <= 8'd0;
            valid <= 1'b0;
            busy  <= 1'b0;
        end else begin
            valid <= 1'b0;      // 默认不给脉冲

            case (state)

            IDLE: begin
                busy <= 1'b0;
                cyc  <= 16'd0;
                bitn <= 3'd0;
                vote <= 3'd0;
                if (start_edge) begin
                    busy  <= 1'b1;
                    state <= START;
                end
            end

            // 起始位：数完一整位，同时做假起始位检测
            START: begin
                cyc <= cyc + 16'd1;

                if (cyc >= MID - 2 && cyc <= MID + 2)
                    vote <= vote + {2'b00, rx_s2};

                // 采完 5 点后的下一拍 vote 已经齐了
                if (cyc == MID + 3) begin
                    if (vote >= 3'd3) begin
                        // 起始位多数是 1 -> 是噪声，不是真的起始位
                        state <= IDLE;
                        busy  <= 1'b0;
                    end
                    vote <= 3'd0;
                end

                if (cyc == CPB - 1) begin
                    cyc   <= 16'd0;
                    bitn  <= 3'd0;
                    state <= DATA;
                end
            end

            // 8 个数据位，低位先到
            DATA: begin
                cyc <= cyc + 16'd1;

                if (cyc >= MID - 2 && cyc <= MID + 2)
                    vote <= vote + {2'b00, rx_s2};

                if (cyc == MID + 3) begin
                    // 5 个采样点已全部累加进 vote，3 票以上算 1
                    shreg <= {(vote >= 3'd3), shreg[7:1]};
                    vote  <= 3'd0;
                end

                if (cyc == CPB - 1) begin
                    cyc <= 16'd0;
                    if (bitn == 3'd7)
                        state <= STOP;
                    else
                        bitn <= bitn + 3'd1;
                end
            end

            // 停止位：数完一整位就交付数据
            STOP: begin
                cyc <= cyc + 16'd1;
                if (cyc == CPB - 1) begin
                    cyc   <= 16'd0;
                    state <= IDLE;
                    data  <= shreg;
                    valid <= 1'b1;      // 单拍脉冲
                    busy  <= 1'b0;
                end
            end

            default: state <= IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
