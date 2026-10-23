# 资源编目（统一入口，不用再到处找）

> 规则：需要哪个资源，直接说“看 XX”，由 agent 抓取/提炼并记入 `03-notes.md`。
> 平时不需要自己开网页。

---

## 0. 目标

基于 FPGA 的 RV32I 五级流水线处理器设计与实现。路径：
`单周期 → 五级流水线 → 冒险 → 跑 C 程序 → FPGA 上板 → 论文`

---

## 1. 本地资料（已在磁盘）

| 资源 | 位置 | 用途 |
| --- | --- | --- |
| RISC-V 非特权指令集手册（英文） | `D:\riscvpga\riscv-unprivileged.pdf` | 查指令编码（权威） |
| RISC-V Reader（中文） | `D:\riscvpga\RISC-V-Reader-Chinese-v1.pdf` | 入门讲解 |
| 参考核（别人写的 5 级流水线） | `D:\riscvpga\_reference\rv32i-5stage-core-main\` | **卡住时**才看，平时不碰 |
| 旧版本（已推倒） | `D:\riscvpga\_archive\` | 后路，确认不需要可删 |

---

## 2. 一生一芯讲义（按需取用，不整套刷）

基准网址：`https://ysyx.oscc.cc`

| 主题 | 链接 | 什么时候用 |
| --- | --- | --- |
| F1 如何科学地提问 | `/docs/2407/f/1.html` | 随时（提升沟通效率） |
| F3 数字逻辑电路基础 | `/docs/2407/f/3.html` | 补数字电路 |
| F4 计算机系统的状态机模型 | `/docs/2407/f/4.html` | 理解状态机 |
| F5 支持数列求和的简单处理器 | `/docs/2407/f/5.html` | 理解“简单处理器”怎么搭 |
| F6 功能完备的迷你 RISC-V | `/docs/2407/f/6.html` | 迷你 CPU 全貌 |
| E2 硬件描述语言 | `/docs/2407/e/2.html` | 补 Verilog/SV |
| E1 C 语言程序设计 | `/docs/2407/e/1.html` | 补 C（跑程序前） |
| E4 从 C 代码到二进制程序 | `/docs/2407/e/4.html` | 理解编译/链接 |
| D2 程序的机器级表示 | `/docs/2407/d/2.html` | 汇编 / 指令编码 |
| D3 运行时环境（AM） | `/docs/2407/d/3.html` | 跑 C 程序时 |
| D4 用 RTL 实现迷你 RISC-V | `/docs/2407/d/4.html` | 单周期参考 |
| C2 支持 RV32E 的单周期 NPC | `/docs/2407/c/2.html` | 单周期参考 |
| D5 设备和输入输出 | `/docs/2407/d/5.html` | 上板 + UART |
| C3 调试技巧 | `/docs/2407/c/3.html` | 全程调试 |
| B3 时序分析和优化 | `/docs/2407/b/3.html` | 上板/性能 |
| B5 流水线处理器 | `/docs/2407/b/5.html` | **流水线重点** |

> 不用看的（流片/系统方向，与毕设无关）：
> E5 物理设计、B1 总线、B2 SoC、B4 缓存、C5 异常/RT-Thread、A 阶段。

---

## 3. 工具

| 工具 | 用途 | 状态 |
| --- | --- | --- |
| Icarus Verilog 14.0 | 编译/仿真 | 已装 |
| GTKWave 3.3.128 | 看波形 | 已装 |
| VS Code + Verilog 扩展 | 写代码 | 已装/待装扩展 |
| Compiler Explorer | 在线跑 C / 看汇编 | `https://godbolt.org` |
| RISC-V 工具链 | 编译 C/汇编 | **待确认** |
| Linux 环境 | 装 RISC-V 工具链 / Verilator | **VMware Ubuntu 虚拟机（已有）** |
| Verilator | Lint（位宽/多驱动检查） | 待装（见 `04-plan.md` 待办） |
| Vivado | FPGA 综合/下载 | 待用 |
| 开发板 | 小梅哥 ACZ702 核心板 | XC7Z020-1CLGA400；512MB DDR3；eMMC/QSPI；RTL8211F 网口；HDMI(SII9022)；WM8960 音频；RTC；USB2.0 OTG |
| 板载 USB-UART | **CH343P** | ⚠️ 接在 **PS(ARM) 端** UART，不是 PL；PL 用串口需确认走线/外接 USB-TTL |

---

## 3a-2. Linux（VMware Ubuntu）要装什么

```bash
sudo apt update
# 基础 + Verilator + 仿真
sudo apt install -y build-essential git curl python3
sudo apt install -y verilator iverilog gtkwave
# 以后(P4 前)再装 RISC-V 工具链
# sudo apt install -y gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```
装完给虚拟机**打快照**。验证：`verilator --version`。

## 3b. GitHub 同类项目调研（参考库，不是粘贴源）

调研时间：第 1 次。搜索 "rv32i 5-stage pipeline verilog" 命中 271 个仓库。

| 项目 | ★ | 语言 | 特点 | 用途 |
| --- | --- | --- | --- | --- |
| [RISC-KC/basic_rv32s](https://github.com/RISC-KC/basic_rv32s) | 109 | Verilog | **教学框架**：单周期→5 级流水线 + FPGA 验证 + 学习指南 | **最佳陪练**；印证路线正确 |
| [cepdnaclk/e16-co502-...group1](https://github.com/cepdnaclk/e16-co502-RV32IM-pipeline-implementation-group1) | 29 | Verilog | RV32IM 5 级，**Icarus+GTKWave**，默认分支 `forwarding`，有 Pages 文档 | 工具链最像；**转发 golden model** |
| [eminfedar/fedar-e1-rv32i](https://github.com/eminfedar/fedar-e1-rv32i) | 24 | Verilog-2005 | 5 级 RV32I，**FPGA 可综合**，32 GPIO，代码短小 | 上板参考；易读 |
| [Peymanc1/RV32IM-from-scratch](https://github.com/Peymanc1/RV32IM-from-scratch) | 11 | SystemVerilog | 单周期→5 级 + cache，**Zybo Z7-20（XC7Z020）** 跑 DOOM，Spike 验证 | **FPGA 上板最佳参考（同款芯片）** |
| [bodsvei/BITSillicon_RISC-V](https://github.com/bodsvei/BITSillicon_RISC-V) | 12 | Verilog | 5 级 RV32I，**转发 + 冒险处理 + 静态分支预测** | 冒险处理参考 |
| [Entropify/Entropic_R32-P5_RISC-V](https://github.com/Entropify/Entropic_R32-P5_RISC-V) | 22 | Python/SV | 5 级 + 分支预测 + **cocotb** 验证 + 流片 | 高级验证方法学参考 |
| [GSTL-ITU/HORNET-RV32IMF](https://github.com/GSTL-ITU/HORNET-RV32IMF) | — | Verilog | 5 级 RV32IMF SoC，FPGA 优化，UART/外设 | SoC/外设参考 |

**重点推荐（中文，和本项目几乎同路线）**：
- [Azalea8/riscv_cpu](https://github.com/Azalea8/riscv_cpu)（138★，Verilog）
  - 含 `single_cycle_cpu/` + `five_pipeline_cpu/` 两套；README 是**中文小教程**，讲透指令编码、单周期、流水线、**前递/停顿/控制冒险**。
  - 用途：**P2/P3（流水线+冒险）的最佳中文参考**；模块划分与控制信号表可参考。
  - 注意：设计选择与我们不同（分支判断塞进 ALU、ALU 5 位控制、含移位/SLTU）；**只作参考不抄**；无 license。

**三大作用**
1. **验证 golden model**：转发正确波形、冒险期望值有出处。
2. **FPGA 上板**：有**同款 XC7Z020** 的现成参考。
3. **methodology**：证明“单周期→流水线→FPGA”是被验证过的教学路径。

**纪律（必须遵守）**
- **只当参考，不当粘贴源**：看懂思路自己写；直接抄，一改适配就崩。
- **别被带跑**：这些项目带 cache/AXI/DOOM，比我们大得多；**不因此加需求**（否则 2~3 个月拖成 1 年）。
- 复用代码前**先看 license**（有的 MIT，有的无 license）。

## 3c. HDLBits（Verilog 针对性练习，不整套刷）

网址：`https://hdlbits.01xz.net/wiki/Problem_sets`

只做与本项目直接对应的题：

| 题目 | 对应 |
| --- | --- |
| `alwaysblock1`（组合 always） | ALU / decoder |
| `alwaysblock2`（时序 always） | regfile / PC |
| `always_case` | decoder |
| `always_if2` / `always_nolatches` | “为什么要写 default” |
| `conditional`（三目） | regfile 的 x0 保护 |
| `mux2to1v` | MUX |
| `dff8r` / `dff8ar`（带复位 DFF） | PC / regfile 写入 |
| `count15`（计数器） | PC 每拍 +4 |
| `tb/clock` / `tb/and` | 写 testbench |

> 定位：补 Verilog 语法的**靶向练习**，几分钟一题；**不是**课程，不整套刷。

## 4. 工作方式（交互规则）

1. **我当聚合层**：抓取资料、提炼要点、整理文档、答疑；你负责思考与决策。
2. **少开网页**：要哪个资源你说一声，我去取。
3. **知识只落三处**：概念→`03-notes.md`；架构→`01-architecture.md`；进度→`progress.md`。
4. **每模块必须有 testbench 且跑通**。
5. **助教模式**：先给现象/尝试/判断，再一起查漏洞。
