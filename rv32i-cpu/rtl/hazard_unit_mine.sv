`timescale 1ns/1ps
`default_nettype none

module hazard_unit_mine (
    input  logic       id_ex_mem_read,    // EX 这条是不是 lw
    input  logic [4:0] id_ex_rd,          // 它写哪个寄存器
    input  logic [4:0] if_id_rs1,         // ID 这条要读的两个源
    input  logic [4:0] if_id_rs2,
    input  logic       if_id_uses_rs1,    // 它真的读这两个源吗
    input  logic       if_id_uses_rs2,
    output logic       stall
);

    assign stall = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                   ( (if_id_uses_rs1 && (id_ex_rd == if_id_rs1)) ||
                     (if_id_uses_rs2 && (id_ex_rd == if_id_rs2)) ); 
                     
endmodule
`default_nettype wire
