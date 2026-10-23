# decoder 真值表（练习纸）

> 先填表，再照表写 `decoder.sv`。答案在本文件最后，填完再对照。

## 控制信号（回顾）

| 信号 | 位 | 含义 |
| --- | --- | --- |
| reg_write | 1 | 写寄存器堆（rd） |
| mem_read | 1 | 读内存（LW） |
| mem_write | 1 | 写内存（SW） |
| alu_src | 1 | ALU 的 B 口来源：0=rs2，1=imm |
| alu_op | 2 | 大类：00 加法 / 01 减法 / 10 R型 / 11 I型 |
| branch | 1 | 是分支 |
| jump | 1 | 是跳转（核心版全 0） |
| result_src | 2 | 写回来源：0=ALU / 1=mem / 2=PC+4 |

**提示（怎么推）**：
- 这条指令**要不要写寄存器**？→ reg_write。
- ALU 的第二个操作数是**寄存器还是立即数**？→ alu_src。
- 它属于哪一大类？→ alu_op（R=10 / I算术=11 / 访存=00 / 分支=01）。
- 要不要读/写内存？→ mem_read / mem_write。
- 写回的是 ALU 结果还是内存数据？→ result_src。

## 空白表（把空格填上；前 2 行是例子）

| 指令 | reg_write | mem_read | mem_write | alu_src | alu_op | branch | result_src |
| --- | --- | --- | --- | --- | --- | --- | --- |
| add | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| sub | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| and | | | | | | | |
| or  | | | | | | | |
| xor | | | | | | | |
| slt | | | | | | | |
| addi | | | | | | | |
| andi | | | | | | | |
| ori  | | | | | | | |
| xori | | | | | | | |
| slti | | | | | | | |
| lw   | | | | | | | |
| sw   | | | | | | | |
| beq  | | | | | | | |
| bne  | | | | | | | |

---

## 答案（填完再看）

| 指令 | reg_write | mem_read | mem_write | alu_src | alu_op | branch | result_src |
| --- | --- | --- | --- | --- | --- | --- | --- |
| add | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| sub | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| and | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| or  | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| xor | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| slt | 1 | 0 | 0 | 0 | 10 | 0 | 0 |
| addi | 1 | 0 | 0 | 1 | 11 | 0 | 0 |
| andi | 1 | 0 | 0 | 1 | 11 | 0 | 0 |
| ori  | 1 | 0 | 0 | 1 | 11 | 0 | 0 |
| xori | 1 | 0 | 0 | 1 | 11 | 0 | 0 |
| slti | 1 | 0 | 0 | 1 | 11 | 0 | 0 |
| lw   | 1 | 1 | 0 | 1 | 00 | 0 | 1 |
| sw   | 0 | 0 | 1 | 1 | 00 | 0 | x |
| beq  | 0 | 0 | 0 | 0 | 01 | 1 | x |
| bne  | 0 | 0 | 0 | 0 | 01 | 1 | x |

**规律总结（帮忙记忆）**：
- **R 型**：reg_write=1、alu_src=0、alu_op=10、其余 0。
- **I 算术**：reg_write=1、alu_src=1、alu_op=11、其余 0。（和 R 型只差 alu_src 和 alu_op）
- **LW**：reg_write=1、mem_read=1、alu_src=1、alu_op=00、result_src=1。
- **SW**：reg_write=0、mem_write=1、alu_src=1、alu_op=00。
- **BEQ/BNE**：全部 0/0，只有 alu_op=01、branch=1。
- 核心版 **jump 恒 0**。
