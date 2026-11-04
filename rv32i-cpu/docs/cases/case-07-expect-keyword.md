# Case 07 · 变量名 `expect` 是 SystemVerilog 关键字，编译直接报语法错误

> **代码来源**：原始　**严重程度**：浪费（编译失败，但原因不明显）　**阶段**：6b

---

## 1. 现象

写 imem 的 testbench 时，编译直接挂掉：

```
tb/imem_tb.sv:10: syntax error
tb/imem_tb.sv:10: error: Syntax error in variable list.
tb/imem_tb.sv:18: syntax error
tb/imem_tb.sv:18: Syntax in assignment statement l-value.
...
```

一共报了十几行，**全都在说"语法错误"，但没说是哪个词有问题**。
第 18 行之后每一条 `expected[i] = ...` 都报错。

## 2. 当时的代码

```systemverilog
module imem_tb;
    logic [31:0] addr, instr;
    imem dut (.addr(addr), .instr(instr));

    logic [31:0] expect [0:7];     // ← 第 10 行
    int i;
    int errors = 0;

    initial begin
        ...
        expect[0] = 32'h00500093;  // ← 第 18 行起全是错的
```

## 3. 为什么错

**`expect` 是 SystemVerilog 的关键字**（SVA 断言里的 `expect` 语句）。

拿关键字当变量名，编译器在解析声明时就直接卡住；后面的每一条赋值也跟着报错，
所以错误信息看起来"到处都是"，实际上是**同一个词**。

## 4. 怎么定位的

报错指向"变量声明"这一行（`Syntax error in variable list`），说明问题就在声明里。

逐个看那一行的每个词：`logic`（对）、`[31:0]`（对）、`expect`（可疑）、`[0:7]`（对）。

搜一下"SystemVerilog keyword list"，`expect` 在里面。

## 5. 修正后的代码

```systemverilog
    logic [31:0] expected [0:7];   // 加一个 d
```

## 6. 怎么防止再犯

- 报错集中在某一行，**先怀疑那一行里的标识符**，不要被后续几十行报错带偏。
- 常见会撞的关键字：`expect`、`property`、`sequence`、`assume`、`cover`、`checker`、`wait`。
- 起名时加前缀/后缀（`exp_val`、`expected`）比裸名安全。

## 7. 一句话记忆

> 一堆语法错误指向同一片区域时，八成是**一个词**撞了关键字，不是每行都写错。
