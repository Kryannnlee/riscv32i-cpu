`timescale 1ns/1ps
`default_nettype none
/* l   = load（从内存读）
b   = byte（1 字节）
h   = halfword（半字，2 字节）
w   = word（字，4 字节）
u   = unsigned（无符号） 
addr= address（地址）
*/
module load_extend_mine (
    input  logic [31:0] word,      // 内存读出的整字
    input  logic [1:0]  addr_lo,   // 地址最低 2 位
                                    /*addr_lo	要拿的字节
                                    00	word[7:0]
                                    01	word[15:8]
                                    10	word[23:16]
                                    11	word[31:24]*/
    /*读取 8 位：4 个位置，所以需要 addr_lo[1:0]。
        读取 16 位：2 个位置，所以只需要 addr_lo[1]。
        读取 32 位：整个数据都要，不需要选择。*/

    input  logic [2:0]  funct3,    // 000 lb / 001 lh / 010 lw / 100 lbu / 101 lhu
    output logic [31:0] data       // 结果
);
// 问题：dmem 一次读出一个 32 位整字，但 lb/lh 只要其中一个字节/半字，
//      而且 lb/lh 要**符号扩展**，lbu/lhu 要**零扩展**。
//      这一步在 MEM 级完成，结果再锁进 MEM/WB。
    logic [15:0] half;// 先按 addr[1] 选出半字 LH/LHU
 
    logic [7:0] byte_sel;// 再按 addr[0] 从半字里选出字节 LB/LBU

    // 先按 addr[1] 选出半字
    assign half = addr_lo[1] ? word[31:16] : word[15:0];

    // 再按 addr[0] 从半字里选出字节
    assign byte_sel = addr_lo[0] ? half[15:8] : half[7:0];
    // TODO: 在这里写
     always_comb begin
        case (funct3)
            3'b000:  data = {{24{byte_sel[7]}}, byte_sel};   // lb  符号扩展
            3'b100:  data = {24'd0, byte_sel};               // lbu 零扩展
            3'b001:  data = {{16{half[15]}}, half};          // lh  符号扩展
            3'b101:  data = {16'd0, half};                   // lhu 零扩展
            default: data = word;                            // lw（010）及其它
        endcase
    end

endmodule
`default_nettype wire