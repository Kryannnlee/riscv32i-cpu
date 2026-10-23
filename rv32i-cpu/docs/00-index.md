# 00 · 项目总入口

> **这是唯一入口。** 只看这一个文件，就能知道：项目结构、工作规则、当前进度、文档在哪。

---

## 1. 一句话

基于 FPGA 的 RV32I 五级流水线处理器设计与实现。目标：仿真跑通 → 上板跑通 C 程序 → 论文。

---

## 2. 目录结构（定死，不再改）

```
rv32i-cpu/
├── rtl/      RTL 源码 (SystemVerilog)
├── tb/       testbench
├── sim/      仿真脚本与产物 (vvp / vcd)
├── docs/     唯一的知识/进度入口
├── sw/       (以后) 汇编 / C 测试程序
├── fpga/     (以后) Vivado 工程
├── thesis/   论文草稿（draft.md）+ 图（figs/）
└── README.md
```

**资料库（不进工作区，平时不看）**：
- `..\_reference\` — 下载的参考核
- `..\_archive\` — 之前推倒的旧版本（后路，确认不需要后可删）
- `..\*.pdf` — RISC-V 官方手册

---

## 3. 工作规则（5 条铁律）

1. **唯一入口**：所有文档信息汇总到本文件，不再散落。
2. **脊柱 + 补丁**：项目本身是主线；缺什么基础，卡住时按需补，不整套刷课。
3. **只补当前需要的**：不是"它很重要"就去学，是"这一步需要"才学。
4. **每块必须有 testbench 且跑通**，才算完成。
5. **助教模式**：先自己给现象/尝试/判断，AI 帮查漏洞，不直接给答案。

### 关于“定死”的含义
- 结构和规则默认**稳定不变**，但**不是锁死**：所有文件都是纯文本，随时可改。
- 改动原则：**轻易不改；要改就留痕**——在 `progress.md` 追加一条“改了什么、为什么”。
- 目录/文档职责若要调整，先在这里改，再同步 `README.md`。

---

## 4. 当前进度

```
阶段0 ALU        ✅ 已完成（测试全过）
阶段1 RegFile    ✅ 已完成（测试全过）
阶段2 Decode     ✅ imm_gen · alu_ctrl · decoder 完成
阶段3 PC+IMEM    ✅ mux2·adder·PC·imem·dmem 完成
阶段4 单周期CPU  ✅ cpu_top 整合完成，跑通测试程序！
阶段5 五级流水线 ✅ 结构跑通（无相关程序）
阶段6 冒险处理   ▶ 6a 已看见冒险（x2=0），6b 转发 下一个
阶段7 跑C/上板/论文 ⬜ 未开始
```

---

## 5. 文档清单（本目录）

| 文件 | 作用 | 状态 |
| --- | --- | --- |
| `00-index.md` | 唯一入口（本文件） | ✅ |
| `resources.md` | 资源编目（本地资料/一生一芯/工具） | ✅ |
| `01-architecture.md` | 架构总图（分层 + 数据通路 + 五级含义 + 进度地图） | ✅ |
| `02-instruction-set.md` | RV32I 子集编码 + opcode/funct 表 + 对答案例子 | ✅ |
| `03-notes.md` | 题库总集：所有问答 + 标准答案 | ✅ |
| `04-plan.md` | 计划、完成标准、决策、时间线 | ✅ |
| `05-weak-points.md` | 错题本：没答对/答不出的 | ✅ |
| `06-verilog-ref.md` | Verilog/SystemVerilog 语法速查 | ✅ |
| `commands.md` | 命令行速查（iverilog/vvp/gtkwave） | ✅ |
| `mentor-mode.md` | 助教模式学习约定 | ✅ |
| `07-c-practice.md` | C + Verilog 补齐清单（靶向） | ✅ |
| `08-thesis-notes.md` | 论文素材库 | ✅ |
| `09-pitfalls.md` | 避坑清单（bug 可能性） | ✅ |
| `10-instructions-plain.md` | 指令大白话（一条一句） | ✅ |
| `worksheet-format.md` | 练习纸：指令格式 | ✅ |
| `worksheet-decoder.md` | 练习纸：decoder 真值表 | ✅ |
| `cheatsheet.html` | 打印版速查卡（A4 两栏，浏览器打印） | ✅ |
| `architecture.html` | 架构总图（分层 + 流水线图 + 进度地图，可打印） | ✅ |
| `progress.md` | 里程碑日志（追加式） | ✅ |

> 规则：新知识只写进 `03-notes.md`；架构只更新 `01-architecture.md`；进度只追加 `progress.md`。不新建散文件。
