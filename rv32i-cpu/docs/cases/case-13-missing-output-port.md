# Case 13 · `id_ex` 的新输出没接，`alu_a_src` 变 Z，JAL 跳到地址 12

> **代码来源**：原始　**严重程度**：致命（跳转到完全错误的地址）　**阶段**：指令集补齐
> **实际影响**：真实发生，2026-10-28 现场踩到

---

## 1. 现象

补齐 JAL / JALR / LUI / AUIPC 后跑流水线测试：

```
  PASS   x1 = 76           ← jal 的返回地址写对了
  FAIL   x23 = 0   期望 1  ← 跳转目标处的指令没执行
  FAIL   x21 = 0   期望 104
  FAIL   x24 = 0   期望 1
  FAIL   x20 = 0   期望 305418240
  FAIL   改道次数 = 6，期望 4
```

**返回地址对、目标地址错**，而且程序像是跑飞了。

加每拍打印后看到关键一行：

```
c24  pc= 80 instr=22c00593 redirect=1 stall=0 id_ex_jump=1
c25  pc= 12 instr=00310233 redirect=0 stall=0
```

JAL 在 PC=72 处执行，`imm = 12`，**结果跳到了 12**（而不是 84）。

## 2. 当时的代码

`rtl/cpu_pipe.sv` 里，`id_ex` 例化只接了新的输入，**忘了接新的输出**：

```systemverilog
    id_ex id_ex_i (
        ...
        .alu_op_in(alu_op), .result_src_in(result_src), .alu_a_src_in(alu_a_src),
        ...
        .alu_op_out(id_ex_alu_op),
        .result_src_out(id_ex_result_src)
        // ← 少了 .alu_a_src_out(id_ex_alu_a_src)
    );
```

而下游在用它：

```systemverilog
    always_comb begin
        case (id_ex_alu_a_src)
            2'b01:   alu_a = id_ex_pc;
            2'b10:   alu_a = 32'd0;
            default: alu_a = ex_rs1;
        endcase
    end
```

## 3. 为什么错

输出没接 → `id_ex_alu_a_src` 这根线**没人驱动** → 高阻 **Z**。

`case (Z)` 既不等于 `2'b01` 也不等于 `2'b10`，于是走 `default`：

```
alu_a = ex_rs1
```

JAL 的 rs1 字段来自 `instr[19:15]`，也就是立即数的一部分，
译码成寄存器号后读到的是 **x0 = 0**。

所以 JAL 算出来：

```
0 + 12 = 12      ← 应该 72 + 12 = 84
```

**返回地址是对的原因**：`pc+4` 走的是 `result_src=2` 那条路，和 ALU 无关，
所以 `x1 = 76` 正确——这正是最迷惑人的地方：**一半对一半错**。

## 4. 怎么定位的

1. 先看症状：**返回地址对、目标错** → 说明跳转指令本身执行了，
   错的是"目标地址从哪来"。
2. 加每拍打印 `pc` / `redirect` / `id_ex_jump`，看到 pc 从 80 直接跳到 **12**。
3. 反推：`12 = 0 + 12`。基址是 0，说明 ALU 的 A 口取的不是 PC。
4. 检查 A 口 MUX 的输入 `id_ex_alu_a_src` → 查它由谁驱动 → **没有 `_out` 连接**。

## 5. 修正后的代码

```systemverilog
        .alu_op_out(id_ex_alu_op),
        .result_src_out(id_ex_result_src),
        .alu_a_src_out(id_ex_alu_a_src)      // ★ 补上
    );
```

修好后：

```
  PASS   x1 = 76
  PASS   x23 = 1
  PASS   x21 = 104
  PASS   x24 = 1
  PASS   x20 = 305418240
  PASS   改道次数 = 4（2 分支 + 1 JAL + 1 JALR）
```

## 6. 怎么防止再犯

**给模块加端口（输入或输出），两边都要接。**

- 加**输入**不接 → 模块收到 Z（见 case 09）
- 加**输出**不接 → 下游收到 Z（本 case）

两者的症状都是 Z，但一个害自己、一个害别人。

流程：

```bash
# 加完端口后，先看模块定义里有哪些端口
grep -n "alu_a_src" rtl/id_ex.sv
# 再看例化处是不是每个都出现了
grep -n "alu_a_src" rtl/cpu_pipe.sv
```

**数量对不上，就是漏了。**

## 7. 一句话记忆

> 加端口是"两边的事"。输入漏接害自己，输出漏接害别人，都会变成 Z，
> 也都会**悄悄走 default 分支**。
