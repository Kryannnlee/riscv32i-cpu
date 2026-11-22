# Case 27 · `sltiu` 没实现，unsigned 比较静默算成加法

> **代码来源**：原始　**严重程度**：静默（不报错，结果错）　**阶段**：指令集补齐

---

## 1. 现象

一直没暴露。写 C 程序、跑 Dhrystone、上板演示都正常。

直到核对 "RV32I 到底实现了多少条" 才发现：

```
RV32I 基础指令共 40 条，我们只实现了 36 条
缺：SLTIU、FENCE、ECALL、EBREAK
```

## 2. 当时的代码

`rtl/alu_ctrl.sv` 的 I 型译码：

```systemverilog
2'b11 : alu_sel = (funct3 == 3'b000) ? 4'd0 : // addi
                (funct3 == 3'b001) ? 4'd7 : // slli
                (funct3 == 3'b101 && ...)  ? 4'd8 : // srli
                (funct3 == 3'b101 && ...)  ? 4'd9 : // srai
                  (funct3 == 3'b010) ? 4'd5 : // slti
                  (funct3 == 3'b100) ? 4'd4 : // xori
                  (funct3 == 3'b110) ? 4'd3 : // ori
                  (funct3 == 3'b111) ? 4'd2 : // andi
                  4'd0;                        // ← 011 落这里 = ADD
```

`funct3 = 011`（SLTIU）**没有对应的分支**，落到最后的 `4'd0`。

## 3. 为什么错

`4'd0` 是 `ALU_ADD`。所以 `sltiu` 会被当成 **`addi`** 执行：

```c
if (x < 10u) { ... }      // gcc 可能生成 sltiu
// 实际执行：x = x + 10，然后看结果……全是错的
```

和 case-25（移位落到 default 返回 0）是**同一类错误**：
**译码器输出、执行器没有对应，落到兜底值。**

## 4. 怎么定位的

不是跑出来的，是**数出来的**：

1. 对照 RV32I 的 40 条指令清单，逐条打勾
2. 打到最后发现 I 型只剩 7 个 funct3 分支，`011` 缺席
3. 再查 `decoder` 的 opcode：也只有 9 个，缺 `0001111`(FENCE) 和 `1110011`(SYSTEM)

## 5. 修正后的代码

```systemverilog
(funct3 == 3'b010) ? 4'd5 : // slti
// sltiu：立即数符号扩展后按无符号比较，正好是 ALU_SLTU 的语义
(funct3 == 3'b011) ? 4'd6 : // sltiu   ← 新增
```

`decoder` 里补 FENCE / SYSTEM（都输出默认值 = NOP）：

```systemverilog
// FENCE：单核、无 Cache、访存有序，什么都不用做
7'b0001111: begin end
// ECALL/EBREAK：本该触发异常，本设计没有异常机制，只能当 NOP
7'b1110011: begin end
```

## 6. 现在的覆盖情况

| 项 | 状态 |
| --- | --- |
| RV32I 40 条译码 | ✅ 40/40 |
| SLTIU 语义 | ✅ 复用 ALU_SLTU |
| ECALL/EBREAK | ⚠️ 当 NOP（**没有异常机制**） |
| 异常/中断 | ❌ 完全没有 |
| CSR 指令 | ❌ 没有 |

## 7. 一句话记忆

> **"实现了 RV32I 子集"这种说法没有信息量。**
> 要说得出来：40 条里实现了几条、哪几条缺、缺的那几条会怎么表现。
