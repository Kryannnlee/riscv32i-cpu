# Case 09 · 新加的 `stall` 端口没接，悬空成 Z，PC 直接卡死

> **代码来源**：原始　**严重程度**：致命（整个单周期 CPU 停摆）　**阶段**：6c
> **实际影响**：真实发生，本次会话中现场踩到

---

## 1. 现象

给 `program_counter` 加了 `stall` 输入后，跑全套回归：

```
cpu              1 PASS  9 FAIL
cpu_pipe        11 PASS  0 FAIL
```

流水线全绿，**单周期 CPU 全红**。

打开 `cpu_tb` 的输出：

```
  PASS   x1 = 5
  FAIL   x2 = 0   期望 10
  FAIL   x3 = 0   期望 8
  FAIL   x4 = 0   期望 18
  FAIL   x5 = 0   期望 18
  ...
```

**只有第一条指令生效**，其余寄存器全是 0。没有任何编译错误、没有 X、没有报错。

## 2. 当时的代码

`rtl/cpu_top.sv` 里，`program_counter` 的例化还是老样子：

```systemverilog
    program_counter pc_reg (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );                       // ← 新加的 .stall 没有接
```

而 `rtl/program_counter.sv` 已经改成了：

```systemverilog
    input  logic        stall,     // 1 = 停住不动
    ...
    always_ff @(posedge clk) begin
        if (rst)
            pc <= 32'd0;
        else if (!stall)       // ← 这里
            pc <= pc_next;
    end
```

## 3. 为什么错

因果链是这样的：

```
.stall 没接
   ↓
该输入悬空 = 高阻 Z
   ↓
!stall  →  !Z  →  X（不确定）
   ↓
if (rst) ... else if (X) ...
   X 既不算真也不算假
   ↓
两个分支都不执行
   ↓
pc 一次都不被赋值 → 永远保持复位后的 0
   ↓
PC 一直指向第 0 条指令
   ↓
addi x1, x0, 5 被无限次执行 → x1 = 5，其余寄存器没人碰 → 全是 0
```

关键点：**不是报错，是"静默地不做事"**。Verilog 对悬空输入不报错，只是给你 Z。

## 4. 怎么定位的

三步：

1. **看模式**：只有第一条指令生效 → 说明 PC 没动过，一直在执行同一条。
2. **查 PC**：打开波形，看 `pc` 是不是复位后一直是 0。是。
3. **查为什么不动**：`pc` 只在 `else if (!stall)` 里更新 → 看 `stall` 的波形 → 是 **Z**。

`stall` 为什么是 Z？回去看例化点 → 没写 `.stall(...)`。

## 5. 修正后的代码

```systemverilog
    // 程序计数器：存当前指令地址
    // 单周期没有流水线，不存在 load-use 停顿，stall 固定接 0。
    // （不接的话是 Z，`!stall` 变成 X，PC 会卡住不动）
    program_counter pc_reg (
        .clk     (clk),
        .rst     (rst),
        .stall   (1'b0),        // ★
        .pc_next (pc_next),
        .pc      (pc)
    );
```

## 6. 怎么防止再犯

**给模块加输入端口后，按这个顺序过一遍：**

1. 全工程搜模块名，列出所有例化点
   ```bash
   grep -rn "program_counter" rtl/ tb/
   ```
2. 每个例化点补端口
3. 每个对应的 `*_tb.sv` 也补端口（testbench 也是例化点！）
4. 跑全套回归，确认没有从 PASS 变 FAIL

用不上的输入，**显式接常量**（`1'b0`），不要留空。

## 7. 一句话记忆

> 输入端口不接 = Z，不是 0。`if` 遇到 Z 会变成 X，然后**悄悄什么都不做**。
> 加端口之后，先搜全工程再编译。
