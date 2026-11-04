# Case 01 · iverilog 对 `always_comb` 里的常量位选报 42 条 sorry

> **代码来源**：原始　**严重程度**：浪费　**阶段**：2（imm_gen）起，至今仍存在

---

## 1. 现象

每次编译都会刷出一大段：

```
rtl/imm_gen.sv:41: sorry: constant selects in always_* processes are not fully
supported (the process will be sensitive to all bits in 'instr[31:0]').
rtl/imm_gen.sv:44: sorry: ...
```

`rtl/*.sv` 全量编译时一共 **42 条**。编译不失败，仿真结果也对。

## 2. 当时的代码

```systemverilog
always_comb begin
    case (instr[6:0])
        7'b0010011: imm = {{20{instr[31]}}, instr[31:20]};
        ...
```

## 3. 为什么错

不是代码错，是 **iverilog 的能力限制**。

`always_comb` 要求工具自己推导敏感列表。遇到 `instr[31]`、`instr[6:0]` 这种**常量位选**时，
iverilog 做不到精确推导，就退化成"对整个 `instr[31:0]` 敏感"，然后打一条 `sorry` 说明它偷懒了。

敏感列表变宽只会让**仿真**多算几次，**综合出来的硬件完全一样**。所以是无害警告。

## 4. 怎么定位的

一开始以为是自己写错了。做了对照实验：把 `always_comb` 换成 `always @(*)` 后警告消失，
说明问题出在工具对 `always_comb` 的处理，不是逻辑本身。

## 5. 处理方式（没有改代码）

**保留 `always_comb`**，编译时过滤掉这类警告：

```bash
iverilog -g2012 -o sim/x.vvp rtl/*.sv tb/x_tb.sv 2>&1 | grep -v "sorry:"
```

理由：`always_comb` 比 `always @(*)` 多一层检查（多驱动、推断 latch 等），
为了消一条工具限制的警告而换掉它，是拿代码质量换安静。

## 6. 怎么防止再犯

- 看到 `sorry:` 先判断是**工具限制**还是**自己写错**。这里的关键词是 `sorry`（不是 `error` / `warning`）。
- 真正的错误是 `error:` 和 `syntax error`，那些必须修。
- 编译时统一过滤，免得 42 条噪音盖住真错误。

## 7. 一句话记忆

> `sorry` 是 iverilog 说"我做不到"，不是"你写错了"。可以过滤，别改代码迁就它。
