# Case 03 · 寄存器堆的写口接到了 ID 级，不是 WB 级

> **代码来源**：重建（据阶段5 学习记录复原）
> **严重程度**：致命　**阶段**：5（cpu_pipe 整合）

---

## 1. 现象

流水线跑起来，寄存器值全乱：不是全 0、也不是全 X，而是"像是写对了，但值不对"，
而且换一段程序，错法也跟着变。

## 2. 当时的代码

把单周期的写法直接搬到流水线里：

```systemverilog
    regfile regfile_i (
        .clk     (clk),
        .rst     (rst),
        .rs1     (if_id_instr[19:15]),
        .rs2     (if_id_instr[24:20]),
        .rd      (if_id_instr[11:7]),     // ← 错：这是 ID 级指令的 rd
        .wr_data (wb_data),               // ← 却是 WB 级的数据
        .we      (reg_write)              // ← 也是 ID 级译出来的
    );
```

## 3. 为什么错

**单周期里读和写是同一拍、同一条指令，所以三个口都能用 `instr`。流水线里不是。**

流水线的同一拍，三个口各自属于**不同的指令**：

| 口 | 属于哪一级 | 应该用哪个信号 |
| --- | --- | --- |
| 读口 rs1/rs2 | **ID**（正在译码的指令） | `if_id_instr[19:15]` / `[24:20]` |
| 写口 rd | **WB**（正在写回的指令） | `mem_wb_rd` |
| 写数据 wr_data | **WB** | `wb_data` |
| 写使能 we | **WB** | `mem_wb_reg_write` |

接错之后，写进去的数据是 A 指令的，写的目标寄存器却是 B 指令的 —— 数据通路整体串了。

## 4. 怎么定位的

问自己一句：**"这条指令拿到写口信息时，它自己处在哪一级？"**

`wb_data` 来自 `mem_wb_*`，那是 WB 级；`if_id_instr` 是 ID 级。两个不同级的东西接到同一个模块上，
一定有一个是错的。

再对照 `01-architecture.md` 第 8 节"各级归属的模块"：

```
IF : pc, imem
ID : decoder, regfile(读), imm_gen
EX : alu_ctrl, ALUSrc mux, alu
MEM: dmem
WB : WB mux, regfile(写)
```

regfile 的**读**在 ID，**写**在 WB —— 同一个模块，两个口分属两级。

## 5. 修正后的代码

```systemverilog
    regfile regfile_i (
        .clk      (clk),
        .rst      (rst),
        .rs1      (if_id_instr[19:15]),   // 读：ID 级
        .rs2      (if_id_instr[24:20]),
        .rd       (mem_wb_rd),            // 写：WB 级 ★
        .wr_data  (wb_data),              // WB 级 ★
        .we       (mem_wb_reg_write)      // WB 级 ★
    );
```

## 6. 怎么防止再犯

接任何一个模块的端口前，先回答：**这个信号属于哪一级？这条指令此刻在哪一级？**

两边的答案必须一致。不一致就说明接错了。

## 7. 一句话记忆

> 流水线里同一个模块的不同口，可能属于**不同指令**。regfile 读在 ID、写在 WB。
