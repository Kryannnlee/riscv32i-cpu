# Case 06 · 转发优先级用两个独立 `if`，写反了

> **代码来源**：原始（讨论中列出的错误写法）　**严重程度**：静默
> **实际影响**：**写码前就识别并避开**，没有造成故障　**阶段**：6b

---

## 1. 现象（假如踩了会怎样）

两条指令先后写同一个寄存器，第三条指令去读它时，拿到的是**先写的那条**的结果。

例：

```
I1  add x1, x2, x3      → x1 = 10
I2  add x1, x4, x5      → x1 = 99   （覆盖）
I3  add x6, x1, x7      → 应该用 99，实际用了 10
```

程序里出现"值落后一代"的错误，而且只在**连续两条写同一寄存器**时出现。

## 2. 错误写法

```systemverilog
    always_comb begin
        forward_a = 2'b00;

        // 条件 A：EX/MEM 命中
        if (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs1)
            forward_a = 2'b01;

        // 条件 B：MEM/WB 命中
        if (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs1)
            forward_a = 2'b10;      // ← 后执行的覆盖前面
    end
```

## 3. 为什么错

两个独立的 `if` 是**顺序执行**的：第二个 `if` 如果成立，会覆盖第一个 `if` 赋的值。

结果就是 **MEM/WB 优先于 EX/MEM**——恰好反了。

而正确语义是：两条指令都写同一个寄存器时，**后来的那条才是对的**。
I2 比 I1 新，I2 的结果在 **EX/MEM** 里。所以 EX/MEM 必须优先。

## 4. 怎么想到的

画一张表，把 I3 在 EX 那一拍的三级状态列出来：

| 指令 | 此刻在 | 结果在哪个寄存器 |
| --- | --- | --- |
| I1 | WB | MEM/WB |
| I2 | MEM | EX/MEM |
| I3 | EX | —— 它要读 |

I2 更年轻 → 取 EX/MEM。**优先级 = 新旧顺序**。

## 5. 正确写法

```systemverilog
    always_comb begin
        // if / else if 的顺序天然表达优先级
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b01;          // 上一条 → EX/MEM，优先
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b10;          // 上上条 → MEM/WB
        else
            forward_a = 2'b00;
    end
```

## 6. 怎么防止再犯

- 有优先级的组合逻辑，用 `if / else if` 或带优先级的 `case`，**不要用两个独立 `if`**。
- 两个独立 `if` 隐含的优先级是"后写者胜"，很容易和直觉相反。

## 7. 一句话记忆

> 两个 `if` 不是"任一成立"，是"后者覆盖前者"。优先级要用 `if / else if` 明说。
