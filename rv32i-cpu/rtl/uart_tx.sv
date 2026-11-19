`timescale 1ns/1ps
`default_nettype none

module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200
)(
    input  logic       clk,         // 50MHz
    input  logic       rst,         // 高有效，和项目其他模块一致
    input  logic [7:0] data,        // 要发的字节
    input  logic       send,        // 拉高一次发一帧
    output logic       tx,          // 串行输出
    output logic       busy         // 1 = 正在发送
);

    // 计算每个 bit 需要的时钟周期数
    localparam int CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state, next_state;

    // 内部寄存器
    logic [7:0]  data_reg;
    logic [15:0] clk_cnt;       // 波特率计数器
    logic [2:0]  bit_cnt;       // 发送数据位计数器 (0~7)
    
    // 边沿检测：捕捉 send 的上升沿（防止电平持续高导致误触发）
    logic send_d;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            send_d <= 1'b0;
        end else begin
            send_d <= send;
        end
    end
    
    logic send_pulse;
    assign send_pulse = send & ~send_d;

    // 状态寄存器
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 数据锁存寄存器
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_reg <= 8'h00;
        end else if (state == IDLE && send_pulse) begin
            data_reg <= data;
        end
    end

    // 波特率时钟计数器
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= '0;
        end else if (state == IDLE) begin
            clk_cnt <= '0;
        end else begin
            if (clk_cnt == CYCLES_PER_BIT - 1) begin
                clk_cnt <= '0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
    end

    // 数据位计数器 (0 到 7)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_cnt <= '0;
        end else if (state == DATA) begin
            if (clk_cnt == CYCLES_PER_BIT - 1) begin
                bit_cnt <= bit_cnt + 1'b1;
            end
        end else begin
            bit_cnt <= '0;
        end
    end

    // 下一个状态逻辑
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (send_pulse) begin
                    next_state = START;
                end
            end
            START: begin
                if (clk_cnt == CYCLES_PER_BIT - 1) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                if (clk_cnt == CYCLES_PER_BIT - 1) begin
                    if (bit_cnt == 3'd7) begin
                        next_state = STOP;
                    end
                end
            end
            STOP: begin
                if (clk_cnt == CYCLES_PER_BIT - 1) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // busy：仍然是寄存器（表示"正在发送"）
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            busy <= 1'b0;
        else
            busy <= (state != IDLE) || send_pulse;
    end

    // tx：组合输出，和 state 同拍变化。
    // 做成寄存器输出的话，tx 会比 state 晚一拍：起始位变成 CPB+1 拍，
    // 后面每一位的边界都跟着错，接收端采样会漂移。
    always_comb begin
        case (state)
            IDLE:    tx = 1'b1;
            START:   tx = 1'b0;                 // 起始位
            DATA:    tx = data_reg[bit_cnt];    // 低位先发（LSB first）
            STOP:    tx = 1'b1;                 // 停止位
            default: tx = 1'b1;
        endcase
    end







endmodule
`default_nettype wire
