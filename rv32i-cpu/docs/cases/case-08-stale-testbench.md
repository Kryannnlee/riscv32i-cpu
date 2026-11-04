# Case 08 · imem 换了程序，两个老 testbench 还在断言旧值

> **代码来源**：原始　**严重程度**：浪费（假警报，白查半天）　**阶段**：6a / 6b 各中过一次

---

## 1. 现象

每次换 `rtl/imem.sv` 里的测试程序，都会出现这种结果：

```
imem: 0 PASS, 4 FAIL
cpu : 1 PASS, 9 FAIL
cpu_pipe: 全 PASS

```

RTL 本身没问题（`cpu_pipe` 全绿），但另外两个 testbench 红了一片。

第一次遇到时，以为是自己改坏了什么，查了很久才发现是**测试 expectations 过期**。

## 2. 当时的代码

`imem` 的程序换成了"转发测试"版本，但 `tb/imem_tb.sv` 还写着更早那套程序的值：

```systemverilog
// 旧程序残留
addr = 32'd0;  #1; if (instr===32'h00A30293) $display("PASS addr=0"); else $display("FAIL ...");
addr = 32'd4;  #1; if (instr===32'h007302B3) $display("PASS addr=4"); else $display("FAIL ...");
```

`tb/cpu_tb.sv` 同理，还期望老的 4 条指令结果：

```systemverilog
$display("x1=%0d (期望 5)", dut.register_file.regs[1]);
$display("x2=%0d (期望 3)", dut.register_file.regs[2]);   // 新程序里 x2 = 10
$display("x3=%0d (期望 8)", dut.register_file.regs[3]);
$display("x4=%0d (期望 2)", dut.register_file.regs[4]);   // 新程序里 x4 = 18
```

## 3. 为什么错

**根因是 `imem` 把测试程序硬编码在 RTL 里。**

于是 `imem` 同时承担了两个职责：
1. 指令存储器（模块）
2. 测试程序（数据）

任何用到 `imem` 的 testbench 都被绑定到"这一刻的程序"上。
程序一换，所有相关 testbench 全过期。

## 4. 怎么定位的

判断依据很简单：**同一个 RTL，`cpu_pipe` 全绿、`imem` 全红**。

如果 RTL 真坏了，不可能只有两个 testbench 挂而流水线全对。
所以问题一定在测试侧，不在设计侧。

再看 FAIL 的内容——"期望值"和"实际值"都指向**旧程序**。立刻明白了。

## 5. 当时的修正

把两个 testbench 的期望值改成当前程序的值，并在 `imem_tb` 里加了一句提醒：

```systemverilog
    // 期望内容必须和 rtl/imem.sv 里的程序保持一致。
    // 注意：这说明 imem_tb 和"仿真程序"耦合了——改程序就得改这里。
```

## 6. 正确的长期解法（还没做）

把程序从 RTL 里搬出去：

```systemverilog
    initial $readmemh("sw/program.hex", mem);
```

好处：
- 换程序只改 `.hex`，RTL 不动
- 上板时本来就要走这条路（`initial` 硬编码的初值综合不出来）

**代价**：`imem_tb` 仍然要跟着 `.hex` 改。彻底解耦需要给 `imem` 加一个"装载使能"端口，
让 testbench 能自己写内存——这个等真要写大量测试时再做。

## 7. 怎么防止再犯

- 改 `imem` 里的程序后，**立刻**跑全套回归，不要等到下一个功能点。
- 看到"部分 testbench 红、主链路绿"，先怀疑测试过期，不要怀疑设计。
- `commands.md` 里记着当前基线数字，对不上就是回归。

## 8. 一句话记忆

> RTL 里塞测试数据，等于让所有 testbench 都和那份数据绑死。换程序 = 全量返工。
