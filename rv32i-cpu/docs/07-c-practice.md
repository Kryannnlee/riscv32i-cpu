# 07 · 补齐清单（C + Verilog 靶向）

> 原则：只补项目用得到的。做完一项把 `[ ]` 改 `[x]`，并记卡点。

## 优先级（重要）

| 项 | 现在需要吗 | 说明 |
| --- | --- | --- |
| **Verilog** | ✅ 现在就补 | 阻塞项目（要写 RTL） |
| **C** | ⏳ 背景/并行 | P4（跑 C 程序）才用，**别让它阻塞 CPU 开发** |

---

## A. Verilog —— HDLBits（靶向，不整套刷）

网址：`https://hdlbits.01xz.net/wiki/Problem_sets`

### ⭐ 写 ALU 前，只剩这 3 题（已完成 ✅，ALU 已写出）
- [x] `alwaysblock1`（组合 always）→ ALU 主体
- [x] `always_case` → ALU 选操作
- [x] `always_nolatches`（避免 latch → 写 default）

### 可选（不做也不影响）
- [ ] `always_if2`
- [ ] `conditional`

### 已覆盖（Basics / Vectors 阶段，做过就划掉）
- [x] Getting Started / Output Zero / wires / gates
- [x] Vectors / 部分选择 / 位运算 / 拼接 / 归约
- [x] `vector2`（字节反转）、`vectorgates`（位/逻辑）、`vector3`（拼接赋值）、`module_shift`（三实例串联）

### 以后各模块前再做
- [ ] `alwaysblock2`（时序 always）→ regfile / PC
- [ ] `mux2to1v` → MUX
- [ ] `dff8r` / `dff8ar` → PC / regfile
- [ ] `count15` → PC 每拍 +4
- [ ] `tb/clock` / `tb/and` → testbench

---

## B. C —— 《Linux C 编程一站式学习》(akaedu)

网址：`https://akaedu.github.io/book/`
在线跑程序/看汇编：**Compiler Explorer** `https://godbolt.org`
每章读完，做**章末习题**，程序保存到本地 `sw/c/`。

### 一生一芯官方要求（E1）
第 **1~9、11~16、21、23~25** 章 + **26.1（链表）**，完成所有习题。

### 我们的优先级调整
**① 核心（先做）**
- [ ] Ch1~9（基础：程序概念/常量变量/函数/分支/循环/结构体/数组）
- [ ] Ch14 计算机中数的表示 ★（补码，呼应 CPU）
- [ ] Ch15 数据类型详解（类型转换）
- [ ] Ch16 运算符详解 → 1. 位运算 ★（掩码、移位）
- [ ] Ch21 预处理
- [ ] Ch23 指针 ★（最重要）
- [ ] Ch24 函数接口
- [ ] Ch25 C 标准库

**② 数据结构/算法（ysyx 要，项目非必需 → 缓做）**
- [ ] Ch11 排序与查找
- [ ] Ch12 栈与队列
- [ ] Ch13 本阶段总结
- [ ] Ch26.1 链表

**③ 项目额外建议（对 CPU 特别有用）**
- [ ] Ch10 gdb（单步、断点、段错误）
- [ ] Ch17 计算机体系结构基础 ★（内存/地址、CPU、设备、存储层次）
- [ ] Ch19 汇编与 C 之间的关系 ★（启动例程、变量存储布局、`volatile`）

**④ 跳过 / 略读**
- 跳过：**整个 Part III（Linux 系统编程）**：文件 I/O、文件系统、进程、线程、socket、信号、正则、Shell
- 略读即可：Ch18 x86 汇编、Ch20 链接详解（P4 需要时再看）

### 更硬核（可选，想系统练 C 再上）
- HackerRank – C ／ Exercism – C ／ 牛客 – C 专项

---

## 与本项目的对应（为什么要读）

| C 主题 | 项目里哪里用到 |
| --- | --- |
| 指针 / 数组 / 结构体 | 写测试程序、驱动寄存器 |
| 位运算 | 指令编码、掩码、MMIO |
| 补码 / 类型转换 | 和 ALU、`$signed` 完全对应 |
| 体系结构基础 | 验证你对 CPU 的理解 |
| 启动例程 / 链接 | 把 C 编译进我们的 CPU 运行 |
| `volatile` | MMIO 写 UART 必须用 |
| gdb | 调试程序 |
