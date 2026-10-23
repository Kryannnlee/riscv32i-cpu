# 01 · 架构总图（从逻辑门到最终 CPU）

> 这张文档回答两个问题：**最终要做出什么** + **我现在在哪**。
> 约定：数据 32 位；寄存器编号 5 位；命名小写下划线。

---

## 0. 分层理解（我们在哪一层）

```
第 4 层  五级流水线 CPU + 冒险处理        ← 最终目标
          IF ─reg─ ID ─reg─ EX ─reg─ MEM ─reg─ WB
   ▲
第 3 层  单周期数据通路（把模块连起来）    ← 先打通
   ▲
第 2 层  功能模块                          ← 正在写这层
          pc · imem · decoder · imm_gen · alu_ctrl · regfile · alu · dmem · adder · mux2
   ▲
第 1 层  基本元件
          门(AND/OR/XOR/NOT) · 多路器 MUX · 加法器 · 触发器(寄存器) · 存储器
```

**你写 RTL，就是在第 2 层搭模块；综合器把第 2 层变成第 1 层的门/触发器/LUT。**

---

## 1. 最终目标：五级流水线 CPU 总图

```
                 ┌──────────────────────────────────────────────────────────────┐
                 │                          CPU TOP                              │
                 └──────────────────────────────────────────────────────────────┘

   IF 取指            ID 译码               EX 执行            MEM 访存           WB 写回
 ┌───────────┐    ┌──────────────┐    ┌───────────────┐   ┌──────────┐    ┌──────────┐
 │    PC     │    │   Decoder    │    │      ALU      │   │   DMEM   │    │  WB Mux  │
 │           │    │  RegFile(读) │    │   转发 MUX     │   │  (LW/SW) │    │          │
 │   IMEM    │    │   ImmGen     │    │   分支比较     │   │          │    │          │
 └─────┬─────┘    └──────┬───────┘    └───────┬───────┘   └────┬─────┘    └────┬─────┘
       │                 │                    │                │               │
   ┌───▼───┐         ┌───▼───┐            ┌───▼────┐       ┌───▼───┐       ┌───▼───┐
   │ IF/ID │────────►│ ID/EX │───────────►│ EX/MEM │──────►│ MEM/WB│──────►│ 写回   │
   └───────┘         └───────┘            └────────┘       └───────┘       └───────┘
    流水线寄存器        流水线寄存器          流水线寄存器      流水线寄存器

   NextPC MUX：PC+4  /  分支目标  /  跳转目标
   冒险处理(Hazard)：转发(Forward) + 暂停(Stall) + 冲刷(Flush)
```

**关键概念**：
- 每个 `─reg─`（IF/ID 等）是**流水线寄存器**，把一条指令的中间结果"存一拍"传给下一级。
- 5 级同时工作 → 吞吐率提高（但单条指令耗时不变）。
- "冒险处理"是三件套：**转发**(把结果抄近路)、**暂停**(等 load)、**冲刷**(丢弃取错的指令)。

---

## 2. 单周期数据通路（先做这个）

```
        ┌──────┐  pc   ┌──────┐
        │  PC  │──────►│ IMEM │──► instr
        └──▲───┘       └──────┘        │
           │                           ▼
        pc_next                 ┌────────────┐
           │                    │  Decoder   │──► 控制信号
           │                    └─────┬──────┘
           │              ┌───────────┼────────────┐
           │              ▼           ▼            │
           │        ┌─────────┐ ┌──────────┐       │
           │        │ RegFile │ │ ImmGen   │       │
           │        └─┬─────┬─┘ └────┬─────┘       │
           │       rs1   rs2        imm           │
           │        │     └──┐       │            │
           │        │    [ALUSrc MUX]◄┘            │
           │        └──────┬──┘                    │
           │               ▼                       │
           │           ┌───────┐                   │
           │           │  ALU  │──► alu_result      │
           │           └───┬───┘                   │
           │               │                       │
           │          ┌────▼────┐                  │
           │          │  DMEM   │──► mem_rdata      │
           │          └─────────┘                  │
           │               │                       │
           │        [ResultSrc MUX] ──► wr_data ───┘（写回 RegFile）
           │
       [PCNext MUX] = PC+4 / 分支目标 / 跳转目标
```

---

## 2b. 进度地图（随时看这里）

```
第1层 基本元件
  [x] 组合逻辑 = ALU 用的门/MUX
  [x] 时序逻辑 = 寄存器(触发器)

第2层 功能模块
  [x] alu.sv               ✅ 测试通过
  [x] regfile.sv           ✅ 测试通过
  [x] imm_gen.sv           ✅ 测试通过
  [x] alu_ctrl.sv          ✅ 测试通过
  [x] decoder.sv           ✅ 测试通过
  [x] mux2.sv / adder.sv   ✅ 测试通过
  [x] program_counter.sv   ✅ 测试通过
  [x] imem.sv              ✅ 测试通过
  [x] dmem.sv              ✅ 测试通过

第3层 单周期
  [x] cpu_top.sv （整合 + 跑测试程序）✅ 单周期 CPU 跑通！

第4层 五级流水线
  [x] if_id / id_ex / ex_mem / mem_wb 流水线寄存器 ✅
  [x] cpu_pipe.sv 五级整合 ✅ 无相关程序跑通
  [ ] hazard_unit（转发/停顿/冲刷）← 下一个

外设 / 上板
  [ ] uart（打印）
  [ ] Vivado 工程 + 约束
```

---

## 3. 模块清单

| 模块 | 作用 | 输入 | 输出 |
| --- | --- | --- | --- |
| `pc` | 存"当前指令地址" | clk, rst, pc_next[31:0] | pc[31:0] |
| `imem` | 指令内存：地址→指令 | addr[31:0] | instr[31:0] |
| `decoder` | 主控制：指令→控制信号 | instr[31:0] | 见控制信号表 |
| `imm_gen` | 立即数生成 | instr[31:0] | imm[31:0] |
| `alu_ctrl` | 产生 ALU 的具体操作 | alu_op[1:0], funct3, funct7 | alu_sel[3:0] |
| `regfile` | 32 个通用寄存器 | clk, we, rs1, rs2, rd, wr_data | rs1_data, rs2_data |
| `alu` | 算术/逻辑 | a, b, alu_sel[3:0] | result, zero |
| `dmem` | 数据内存 | clk, we, addr, wr_data | rd_data |
| `adder` | 加法（PC+4 / 目标地址） | a, b | sum |
| `mux2` | 二选一（参数化位宽） | sel, d0, d1 | y |
| `cpu_top` | 把上面全部连起来 | clk, rst | （以后接 UART 等） |

## 4. 控制信号（decoder 输出）

| 信号 | 位宽 | 含义 |
| --- | --- | --- |
| `reg_write` | 1 | 写寄存器堆 |
| `mem_read` | 1 | 读数据内存（LW） |
| `mem_write` | 1 | 写数据内存（SW） |
| `alu_src` | 1 | 0=rs2 1=imm |
| `alu_op` | 2 | 大类，给 alu_ctrl |
| `branch` | 1 | 是分支指令 |
| `jump` | 1 | 是跳转（JAL/JALR） |
| `result_src` | 2 | 写回来源：0=ALU 1=mem 2=PC+4 |

## 5. ALU 操作编码（alu 与 alu_ctrl 必须一致）

| alu_sel[3:0] | 操作 | 说明 |
| --- | --- | --- |
| 0 | ADD | 加法 / 算地址 / PC+imm |
| 1 | SUB | 减法 / 分支比较 |
| 2 | AND | 按位与 |
| 3 | OR | 按位或 |
| 4 | XOR | 按位异或 |
| 5 | SLT | 有符号小于则置 1 |

---

## 6. 设计决策（已定）

1. **先做核心、后补跳转**：第一版只做 R/I 运算 + LW/SW + BEQ/BNE，跑通再加 JAL/JALR/LUI/AUIPC。
2. **分支比较**：用 ALU 的 `zero`（做减法）即可（BEQ/BNE 够）。
3. **复位**：统一**同步复位**（`always_ff @(posedge clk)` + `if(rst)`）。
4. **ALU 大类**：`alu_op` 分 R 型 / I 型算术 / 访存 / 分支。

---

## 7. 五个阶段的含义（IF / ID / EX / MEM / WB）

> 一条指令的一生就这五步。单周期里它们在一个周期内先后发生;流水线里它们被寄存器隔开、并行。

### IF — 取指（Instruction Fetch）
- **干什么**：用 **PC** 的地址去**指令内存**取出一条 32 位指令。
- **同时算下一条**：`PC_next`(通常 PC+4,跳转时是目标)。等时钟沿把 `PC_next` 写回 PC。
- **涉及模块**：`pc`、`imem`、`adder`(算 PC+4)。
- **产出**：`instr[31:0]` 和 `pc`。

### ID — 译码（Instruction Decode）
- **干什么**：把 `instr` 翻译成**控制信号**;从**寄存器堆**读出 `rs1`、`rs2`;生成**立即数**。
- **涉及模块**：`decoder`(主控制)、`regfile`(读)、`imm_gen`。
- **产出**：控制信号、`rs1_data`、`rs2_data`、`imm`。

### EX — 执行（Execute）
- **干什么**：**ALU** 用 `a`、`b` 按 `alu_sel` 运算。
  - 算术/逻辑：算结果。
  - 访存：算地址 `rs1 + imm`。
  - 分支：相减判断是否相等(`zero`)。
- **涉及模块**：`alu`、`alu_ctrl`、ALUSrc MUX。
- **产出**：`alu_result`、`zero`。

### MEM — 访存（Memory）
- **干什么**：只有 `LW`/`SW` 真正动内存:
  - `LW`：读 `DMEM[地址]`。
  - `SW`：写 `DMEM[地址] = rs2_data`。
  - 其它指令**空过**。
- **涉及模块**：`dmem`。
- **产出**：`mem_rdata`(读出的数据)。

### WB — 写回（Write Back）
- **干什么**：把结果写回**寄存器堆**的 `rd`。来源由 `result_src` 选:
  - 算术/逻辑 → ALU 结果
  - `LW` → 内存读出的数据
  - `JAL/JALR` → PC+4(返回地址)
- **涉及模块**：`regfile`(写)、WB MUX。
- **产出**：寄存器被更新。

### 三个阶段怎么"串"成一条指令（以三条为例）
| 指令 | IF | ID | EX | MEM | WB |
| --- | --- | --- | --- | --- | --- |
| `addi x5,x6,10` | 取指 | 译码 | x6+10 | — | 写 x5 |
| `lw x5,8(x6)` | 取指 | 译码 | 算地址 x6+8 | 读内存 | 写 x5 |
| `beq x5,x6,L` | 取指 | 译码 | x5−x6 | — | — (不写) |

**记忆**：取指(去拿)→ 译码(看懂)→ 执行(算)→ 访存(存取内存)→ 写回(存回寄存器)。

---

## 8. 五级流水线切分图（阶段5）

> 在 5 级之间插 4 个流水线寄存器，让 5 条指令并行。
> 规则：**每个寄存器存"这一级的产出 + 后面各级要用、还没用到的控制信号"**（"行李随行"）。

```
   IF ──[if_id]──► ID ──[id_ex]──► EX ──[ex_mem]──► MEM ──[mem_wb]──► WB
```

**各级归属的模块**
```
IF : pc, imem
ID : decoder, regfile(读), imm_gen
EX : alu_ctrl, ALUSrc mux, alu
MEM: dmem
WB : WB mux, regfile(写)
```

**各流水线寄存器存什么**

| 寄存器 | 位置 | 存的内容 |
| --- | --- | --- |
| `if_id` | IF→ID | `pc`、`instr`、`pc_plus4` |
| `id_ex` | ID→EX | `rs1_data`、`rs2_data`、`imm`、`rd`、`pc`、`pc_plus4`、`funct3`、`funct7` + **全部 8 个控制信号** |
| `ex_mem` | EX→MEM | `alu_result`、`rs2_data`(给 SW)、`zero`、`rd`、`pc_plus4` + 控制(`reg_write`、`mem_read`、`mem_write`、`branch`、`jump`、`result_src`) |
| `mem_wb` | MEM→WB | `alu_result`、`mem_rdata`、`rd` + 控制(`reg_write`、`result_src`) |

**控制信号"随行"(每级用掉自用的、其余转发)**
```
ID 产生 8 个
   EX  用 alu_src / alu_op
   MEM 用 mem_read / mem_write
   WB  用 reg_write / result_src
   (branch / jump 用于 PC 决策)
```

**第一版(阶段5)先不处理冒险** → 有数据相关时结果会错，阶段6 再加转发/暂停/冲刷。
