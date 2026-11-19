# 进度日志（像 git log，从旧到新）

每完成一个里程碑，在下面追加一条。

---

## [001] 重置后重建结构
- 推倒旧版本（归档到 `..\_archive\`），重建 `rv32i-cpu/` 干净结构
- 文档体系：`00-index`(入口) / `resources` / `01-architecture` / `02-instruction-set` / `03-notes` / `04-plan` / `05-weak-points` / `06-verilog-ref` / `07-c-practice` / `08-thesis-notes` / `09-pitfalls` / `commands` / `mentor-mode`

## [002] Verilog 靶向练习（HDLBits）
- 过完：位运算/逻辑运算、拼接、部分选择、归约、位宽补零/截断、隐式网络、多驱动、`always_comb`/`case`/`default`/latch
- 沉淀进 `06-verilog-ref.md`、`09-pitfalls.md`、`03-notes.md`

## [003] 环境搭建
- Windows：iverilog 14.0 + GTKWave 3.3.128（已有）
- VMware Ubuntu：装好 verilator 4.038 / iverilog 11.0 / gtkwave 3.3.104

## [004] 阶段0：ALU 完成 ✅
- `rtl/alu.sv`：ADD/SUB/AND/OR/XOR/SLT（`localparam` 编码 + `always_comb`/`case`/`default` + `$signed`）
- `tb/alu_tb.sv`：9 条断言全部 PASS
- `sim/alu.vcd` 生成
- 学习曲线：从"看不懂 always"到独立写出并调通

---

## [005] 阶段1：Register File 完成 ✅
- `rtl/regfile.sv`：32×32 寄存器；两读组合、一写时序（同步复位）；x0 恒 0（读 0、写忽略）
- `tb/regfile_tb.sv`：4 条断言全 PASS（写读回、x0 保护、双口读、we=0 不写）
- `sim/regfile.vcd` 生成
- 学到：`always_ff @(posedge clk)` + 同步复位、数组、testbench 的 task/时钟

---

## [006] imm_gen 完成 ✅
- `rtl/imm_gen.sv`：按 opcode 解出 I/S/B/U/J 五种立即数并符号扩展（含 JALR）
- `tb/imm_gen_tb.sv`：9 条断言全 PASS（含负数符号扩展）
- 学到：位拼接 `{n{...}}` 符号扩展、部分选择、opcode 译码
- 注：iverilog 对 `always_comb` + 部分选择 `case(instr[6:0])` 有 `sorry` 警告（无害）；可先取 `opcode=instr[6:0]` 再 `case(opcode)` 消除

---

## [007] alu_ctrl 完成 ✅
- `rtl/alu_ctrl.sv`：alu_op(大类) + funct3/funct7 → alu_sel（含 R 型 ADD/SUB 靠 funct7 区分）
- `tb/alu_ctrl_tb.sv`：13 条断言全 PASS
- 学到：funct3/funct7 → ALU 操作的映射；`case` + 三目链；`default_nettype` 必须在模块外

---

## [008] decoder 完成 ✅
- `rtl/decoder.sv`：opcode → 8 个控制信号（先置默认值 + case 覆盖）
- `tb/decoder_tb.sv`：6 条断言全 PASS
- 阶段2（Decode）完成：imm_gen + alu_ctrl + decoder
- 学到：控制信号真值表；testbench 的 task 与 initial 是并列块、不能嵌套

---

## [009] mux2 / adder / program_counter 完成 ✅
- `rtl/mux2.sv`（参数化二选一）、`rtl/adder.sv`（加法器）、`rtl/program_counter.sv`（PC 寄存器，同步复位）
- 三个 testbench 全 PASS（mux2 4/4、adder 4/4、PC 4/4）
- 学到：`#(parameter WIDTH)` 参数化、时序 PC 的 testbench 时序（negedge 驱动）
- 进度：8/11 模块

---

## [010] imem / dmem 完成 ✅
- `rtl/imem.sv`（指令内存，只读组合，字索引 addr[31:2]）
- `rtl/dmem.sv`（数据内存，读组合 + 写时序）
- 两个 testbench 全 PASS（imem 4/4、dmem 2/2）
- 学到：字节地址 → 字索引（÷4）；为什么 imem/dmem 分开；`initial` 初始化内存（仅仿真）
- 进度：**9/11 模块**，只剩 cpu_top

---

## [011] 单周期 CPU 跑通 ✅✅✅（大里程碑）
- `rtl/cpu_top.sv`：把 9 个模块连起来（PC/imem/decoder/imm_gen/alu_ctrl/regfile/alu/dmem/mux）
- `tb/cpu_tb.sv`：跑测试程序 `addi,addi,add,sub` → x1=5, x2=3, x3=8, x4=2 **全对**
- **11/11 模块完成**；阶段0~4（单周期）全部打通
- 学到：数据通路整合、例化端口名必须与定义一字不差、分支判断、PC-next MUX

---

## [012] 五级流水线结构跑通 ✅✅（大里程碑）
- `rtl/if_id.sv`、`id_ex.sv`、`ex_mem.sv`、`mem_wb.sv`：4 个流水线寄存器
- `rtl/cpu_pipe.sv`：把 9 个模块按 5 级切开、穿过 4 个寄存器整合
- `tb/cpu_pipe_tb.sv`：跑 4 条**独立** `addi` → x1=5 x2=3 x3=8 x4=2 **全对**
- 学到：流水线整合；**regfile 读口来自 ID、写口来自 WB**；控制信号"随行"
- 踩坑：忘实例化 imm_gen → imm=X → 结果全 X（调试发现）
- 进度：阶段5 结构完成；**下一步阶段6 冒险处理**

---

## [013] 新建论文目录（留痕）
- 新建 `thesis/`（`draft.md` + `figs/`），结构里原先没有这一层
- 原因：论文正文不适合塞进 `docs/08-thesis-notes.md`（那是素材库）；按 00-index 的规则"目录要调整先在这里改"，已同步 `00-index.md` 的目录树
- 骨架参照师兄论文《H K 2 4 C 0 2 存储器芯片的故障分析及测试研究》
- 同时把 00-index 的阶段6 状态更新为"6a 已看见冒险，6b 转发 下一个"

---

<!-- 新里程碑从下面追加 -->

## [014] 阶段6b：数据转发完成 ✅✅（大里程碑）
- 新增 `rtl/forward_unit.sv`：纯组合，只输出 `forward_a` / `forward_b`（00=原值 01=EX/MEM 10=MEM/WB）
- `id_ex` 补上 `rs1` / `rs2` 编号（原先只存了数据，转发无从比较）
- `cpu_pipe` 在 EX 段加两个转发 MUX；B 口 MUX 放在 ALUSrc **之前**
- 转发条件三条与：`reg_write && (rd != 0) && (rd == rs)`；优先级 EX/MEM > MEM/WB（用 `if/else if` 表达）
- `sw` 的存数据也接转发后的 rs2——三处入口一起覆盖
- 测试程序换成 8 条，覆盖：相邻相关、隔一条相关、EX/MEM+MEM/WB 同时命中、sw 存数据转发、lw 读回
- **顺带修掉两个陈旧 testbench**：`imem_tb`（断言旧程序）和 `cpu_tb`（单周期，断言旧程序）——现在三者用同一份程序
- 全部 12 个 testbench 跑通：alu 9 / regfile 4 / imm_gen 9 / alu_ctrl 13 / decoder 6 / mux2 4 / adder 4 / pc 4 / imem 8 / dmem 2 / cpu 7 / cpu_pipe 7
- 学到：单周期与流水线跑同一程序比同一份结果，是一个免费的等价性检查
- 笔记：`03-notes.md` 第 9 轮；`09-pitfalls.md` 11~16
- 进度：**下一步 6c load-use 暂停**

## [015] RTL 全量补注释
- 17 个 RTL 文件统一加：文件头（作用 / 在 CPU 里的位置 / 输入输出 / 已知局限）+ 关键行内注释
- 重点讲清了三件事：
  1. `regfile` 读组合、写时序 → 这是所有数据冒险的根源
  2. 流水线寄存器"行李随行"：越往下越窄，`id_ex` 最多 8 个控制信号，`mem_wb` 只剩 2 个
  3. 转发 MUX 必须在 ALUSrc **之前**；`ex_mem` 的 rs2 要接转发后的值
- 顺手在注释里标出各文件的**已知局限**（decoder 缺 4 条 opcode、`next_pc` 恒 PC+4、WB MUX 只判 `result_src[0]`）
- 纯注释改动，功能零变化；12 个 testbench 全绿

## [016] 新建冒险处理专题文档（留痕）
- 新建 `docs/11-hazards.md`：阶段6 完整推演（冒险分类 / 时空图 / 6a 复现 / 6b 转发 / 6c 停顿 / 6d 冲刷 / 验证方法 / 论文对应章节）
- **改了文档规则**：`00-index.md` 原先写「不新建散文件，新知识只写 `03-notes.md`」。
  现在改为：零散知识仍进 `03-notes.md`；**成体系的大主题**可另开主题文档并登记在文档清单表里
- 原因：冒险处理横跨 6a~6d 四个阶段，散在问答里追不动；且它同时是论文第2章和第6章的素材
- `03-notes.md` 第 9 轮改成一行指针，正文不重复（避免两份内容不同步）

## [017] 阶段6c：load-use 停顿完成 ✅
- 新增 `rtl/hazard_unit.sv`：检测 lw 后紧跟使用其结果的指令，输出 `stall`
- `decoder` 新增 `uses_rs1` / `uses_rs2`：只有**真正读**的源才参与比较，
  修掉 `addi` 的立即数低位被误当成 rs2 的**误停**
- `program_counter` 加 `stall`（停住不更新）、`if_id` 加 `stall`（保持）、`id_ex` 加 `flush`（灌气泡）
- 测试程序扩到 10 条，新增：真 load-use（x7=36）、假相关反例（`addi x9,x0,10` 紧跟 `lw x10`）
- testbench 统计 `stall` 次数，断言**恰好 1 次**
- 反向验证：临时去掉 `uses_*` 条件重跑，`stall` 变成 2 次、测试失败 → 证明这个断言抓得住误停
- **踩坑**：`cpu_top` 里 `program_counter` 的 `stall` 没接 → 悬空 Z → `!Z`=X → PC 卡死。
  单周期全错（只有 x1 对）。已在 `cpu_top` 显式接 `1'b0`
- 全套 12 个 testbench 全绿（pc 6 / decoder 6 / cpu 10 / cpu_pipe 11 …）
- 笔记：`11-hazards.md` 第 5 节；`09-pitfalls.md` 17~18
- 进度：**下一步 6d 控制冒险冲刷 + next_pc MUX**

## [018] 阶段6d：控制冒险 / 分支冲刷完成 ✅（阶段6 全部完成）
- `cpu_pipe` 新增分支判断：`branch_target = id_ex_pc + id_ex_imm`（★ 必须用分支自己的 PC）
  `branch_taken` 按 funct3 区分 beq/bne；`pc_redirect = branch_taken`
- `next_pc` 从恒等于 `pc+4` 改成 MUX：`pc_redirect ? branch_target : pc_plus4`
- `if_id` 新增 `flush` 输入（优先级高于 `stall`）；`id_ex` 复用已有 `flush`，接 `stall | pc_redirect`
- 冲刷两级 → 每次跳转罚 **2 拍**（改在 ID 判断可降到 1 拍，但要多比较器和转发）
- 测试程序扩到 18 条：前面保留转发和 load-use，后面加三条分支，
  两条带「毒药指令」做对照（`addi x11, x0, 111/222`），一条不该跳
- testbench 新增 `redirect_count`，断言 **恰好 2 次**；x11=3、x12=2
- 反向验证：断掉 flush 重跑 → `x11 = 222`、`redirect_count = 3`、测试失败 → 证明断言有效
- 全套 12 个 testbench 全绿（imem 19 / cpu 12 / cpu_pipe 14 …）
- 笔记：`11-hazards.md` 第 6 节；`09-pitfalls.md` 19~20
- 进度：**阶段6 完成**。下一步：补齐 JAL/JALR/LUI/AUIPC → 然后进 P4 跑 C 程序

## [019] 新建踩坑档案 `docs/cases/`（留痕）
- 新建 `docs/cases/`：一个坑一份事故报告，固定结构
  **现象 / 当时的代码 / 为什么错 / 怎么定位 / 修正后代码 / 怎么防止 / 一句话记忆**
- 首批 12 条，覆盖阶段2~6d 真正踩过和差点踩的坑
- 每条标注：**代码来源**（原始/重建）、**严重程度**、**实际是否造成故障**
- 和 `09-pitfalls.md` 分工：那里是一句话结论 + 未踩到的防范条目；这里是完整现场
- `00-index.md` 文档规则同步更新：真正踩过的坑要建事故档案，`09-pitfalls.md` 留一句话指过去
- 用途：论文复盘章节素材、面试讲项目素材、以后复发时快速对照

## [020] 指令集补齐：LUI / AUIPC / JAL / JALR ✅
- `decoder` 新增 4 条 opcode，并新增输出 `alu_a_src`（00=rs1 01=pc 10=常数 0）
- `id_ex` 传递 `alu_a_src`；`mem_wb` 新增 `pc4` 通路（JAL/JALR 的返回地址）
- `cpu_pipe`：
  - ALU A 口加来源 MUX（转发之后、ALU 之前）
  - 跳转目标统一由 ALU 算出（JAL：A=pc；JALR：A=rs1），bit0 清零
  - `pc_redirect = branch_taken | jump`，目标二选一
  - WB MUX 改成按 `result_src` 两位完整译码（0=ALU 1=mem 2=PC+4）
- `cpu_top`（单周期）同步支持这四条，继续充当"标准答案"用于等价性对照
- 测试程序扩到 28 条：新增 JAL 前跳（带毒药）、AUIPC 算 PC、ADDI 构地址、JALR 间接跳转、LUI
- 断言语义升级：`redirect_count` 恰好 4（2 分支 + 1 JAL + 1 JALR）
- **踩坑**：`id_ex` 的新输出 `alu_a_src_out` 忘了接 → Z → 走 default → JAL 用 rs1(x0) 当基址 → 跳到 12
  详见 `cases/case-13-missing-output-port.md`
- 全套 12 个 testbench 全绿（decoder 10 / imem 29 / cpu 16 / cpu_pipe 18）
- 进度：RV32I 常用子集完整。**下一步 P4：跑 C 程序（工具链 + MMIO）或先上板**

## [021] 暂停推进功能，从零重建理解
- 原因：2026-10-30 用户说"最近的工作是你做的，我没有做"。6b 之后的代码由 AI 直接完成，
  用户只旁观，无法在答辩/面试中讲清楚
- 做法：从第0层（一条指令是什么）开始重新走，每层必须能用自己的话讲出来才往下
- 新建 `docs/12-rebuild-log.md`：记录每层的问题、回答、判断、卡点
- 阶梯：第0层 指令是什么 → 第1层 部件 → 第2层 单周期 → 第3层 流水线 → 第4层 冒险 → 第5层 修复
- 功能开发暂停，直到第3层讲通

## [022] 重建完成第0~5层，转发单元由用户重写并验证
- 走完 `12-rebuild-log.md` 的第 0~5 层，每层都要求用户自己讲清楚才往下
- 第 5 层：用户不看原代码重写 `rtl/forward_unit_mine.sv`
  - 首次提交两处文件错误：`timescale 1ps/1ns`（单位比精度小，编译报错）、放在 `rtl/rtl/` 导致通配符匹配不到
  - 修正后逻辑与原版一致
- 新增 `tb/forward_unit_cmp_tb.sv`：同一组输入喂给两份实现逐组比对
  - 寄存器号取 {0,1,2,3,4,5,31}，4 个输入 × 2 个写使能，穷举 9604 组
  - 结果：**不一致 0 组，等价**
- 全套 12 个 testbench 仍全绿
- 下一步：用同样方式重做 6c（load-use 停顿）和 6d（分支冲刷）

## [023] 6c hazard_unit 由用户重写并通过验收
- 用户写出 `rtl/hazard_unit_mine.sv`，替换 `cpu_pipe` 中的实例化
- 完整流水线测试全过：15 项寄存器检查 + stall 恰好 1 次 + 改道 4 次
- 反向验证：去掉 `uses_rs1/rs2` 守卫后 stall 变成 2 次 → 证明守卫确实防止了误停
- 至此 **forward_unit 与 hazard_unit 两份核心代码都已由用户自己写并验证**
- 全套 12 个 testbench 全绿
- 下一步：6d 分支冲刷，同样让用户自己写

## [024] 重建日志补全至 11-03
- `12-rebuild-log.md` 记录了第0~5层、第二轮 6c、以及 flush / 多 PC 的讨论
- 用户已自己写出并验证 `forward_unit_mine` 与 `hazard_unit_mine`
- 6d 定为"预测 + 验证"方式验收，尚未开始

## [025] 6d 预测验证完成，重建第一轮收尾
- 让用户先预测"把 `branch_target` 里的 `id_ex_pc` 改成 `pc` 会怎样"，再实跑对照
- 用户预测对 1 条（偏移 +8），错 2 条（x11 终值、改道次数）
- **成果**：用户预测帮我发现 `case-10` 里"多跳 12 字节"写错了，实际是 **8 字节**，
  已全局修正 5 处文档
- **发现测试盲区**：寄存器终值全对，只有改道计数抓到错误 → 记入 `09-pitfalls` 第 21 条
- 至此 6b/6c/6d 用户都已自己讲清并验证，重建第一轮结束

## [026] 首次 Vivado 综合：抓到三个综合期问题
- 器件：XC7Z020（封装待用户确认，当前用 clg400-2）
- 新增 `fpga_top.sv`（上板顶层）、`fpga/prepare_sources.py`、`fpga/synth.tcl`
- 结果：1381 LUT / 1514 FF / 128 LUTRAM / 0 BRAM；WNS +10.43ns @20ns → 约 104MHz
- 三个问题（均入 `cases/` 14~16）：
  1. Vivado 不接受 `default_nettype none` + `logic` 端口 → 综合失败
  2. 只连一个调试口 → 31 个寄存器被当死代码删掉，资源数字失真
  3. 组合读被推断成 BRAM → 上板会差一拍（最危险，不报错）
- 修法：预处理去指令 / 全寄存器异或引出 / `ram_style=distributed`

## [027] 首次上板：心跳不闪，定位到 imem 未初始化
- 板子：BX71 核心板，引脚确认 U18/T19/T10（厂商 xdc 一致）
- 现象：D4(DONE) 常亮、D9(心跳) 常亮不闪
- 根因：`imem` 只初始化了 0~27，其余为 X；综合器当 don't care，
  把 ROM 从 256x32 压成 **32x29**（见综合日志 `ROM: Preliminary Mapping Report`）；
  程序跑完后 PC 吃到未定义内容 -> X 传播 -> PC 变成 X -> LED 恒定
- 修法：`initial` 开头先 `for (i=0;i<256;i++) mem[i] = NOP;` 再覆盖测试程序
- 记入 `cases/case-17-imem-uninitialized-x.md`
- 新增 `fpga/build_all.tcl`（批量重跑 synth+impl+bitstream）

## [028] ★ 首次上板成功：CPU 在真实硬件上算出正确结果
- 板子：BX71 核心板（XC7Z020CLG400-2I）
- 判据：`led[0] = (dbg_x1 == 76) ? 慢闪 : 常亮`
  - 程序最后 `jal x1, +12` 在 PC=72 执行，返回地址应为 76
  - **D9 慢闪 → x1 == 76 → CPU 在板上算对了**
- 上板挡路的四个问题（全部入 cases/）：
  - case-14 Vivado 不接受 default_nettype none + logic
  - case-15 无观测逻辑被当死代码删
  - case-16 组合读被推断成 BRAM
  - case-17 imem 未初始化位置是 X
  - case-18 Vivado 复制了约束文件，改原文件不生效
- 定版引脚：clk=U18 / rst=T19 / led[0]=T10（高电平点亮）
- 资料齐全：`ziliao/BX71/`（原理图、引脚表、官方例程 ch01~ch28）
- **下一阶段：字节访存 → UART → C 程序**

## [029] 解压并对比 BX71 官方 68 个例程
- 解压 `BX71_020`（7020 版）全部 68 个例程到同目录 `_extracted_020/`
- 对比结论写入 `docs/13-vendor-reference.md`
- 关键发现：
  - 引脚与我们完全一致（U18/T10/T19）
  - 官方是 Verilog-2001 + 异步复位，我们是 SystemVerilog + 同步复位（我们更规范）
  - 官方 xdc **没有 create_clock**，我们有（论文要报 Fmax 必须有）
  - 可直接借用：UART 收发（ch05/06/09）、按键消抖（ch10）、存储器 IP（ch13/14）
  - UART 分频值现成：115200 对应 433（50MHz）

## [030] 从官方例程汇总引脚映射
- 解析 76 个官方 xdc，汇总 410 个信号→引脚
- UART：**TX=K19，RX=J19**（GPIO0 扩展口，需外接 USB-TTL）
- 板载固定：clk=U18 / key=T19 / LED=T10（与我们一致）
- 可选外部 LED：B20 / D19 / D20（ch09 用过）
- 完整映射写入 `docs/13-vendor-reference.md` 第 6~7 节

## [031] 阶段7a：字节/半字访存完成
- `dmem`：加字节写使能 `be[3:0]`，按通道写；`initial` 清零全部
- 新增 `rtl/load_extend.sv`：lb/lh 符号扩展、lbu/lhu 零扩展、lw 原样
- `ex_mem`：新增 `funct3` 通路（访存大小/有无符号要传到 MEM 级）
- `cpu_pipe`：字节使能 + **写数据对齐**（sb/sh 取 rs2 低位，摊到对应通道）
- `cpu_top`（单周期）：同步支持，继续当等价性基准
- 测试程序扩到 41 条：sb×2→lw、lb/lbu、sh→lh/lhu，覆盖符号扩展
- 新增 `tb/load_extend_tb.sv`（14 个断言）；dmem_tb 扩到 5 组（含字节/半字写）
- 全套 13 个 testbench 全绿
- 踩坑：`cases/case-19-store-data-alignment.md`（sb 数据源取错）、case-17 补记（dmem 未初始化）

## [032] load_extend 由用户重写并接入主设计
- 用户写 `rtl/load_extend_mine.sv`，14 条断言一次通过
- 过程中被编译器抓到一个错：声明 `b` 但用了 `byte_sel`（`default_nettype none` 生效，隐式线直接报错）
- 已替换 `cpu_pipe` / `cpu_top` 中的实例化，全套 13 个 testbench 结果不变
- 至此 **forward_unit / hazard_unit / load_extend 三个核心模块都是用户自己写的**

## [033] 性能评估：实测 CPI
- `cpu_pipe_tb` 增加性能计数：周期数、停顿次数、改道次数、最后一条写回时刻
- **实测结果**（41 条测试程序）：
  - 49 拍跑完，**CPI = 1.195**
  - 无冒险理想 45 拍（CPI 1.098），冒险开销 4 拍
  - 事件：load-use 停顿 1 拍，改道 4 次
- **重要发现：简单加法模型不成立**
  - 按 "N + 4 + 停顿 + 改道×2" 算出来是 54 拍，实测 49 拍，差 5 拍
  - 说明"每次改道罚 2 拍"这个说法，与**吞吐**口径不一致：EX 里确实插了 2 个气泡，
    但其中一个占的是"本来就要丢弃的顺取指令"的槽位，不额外损失吞吐
  - **结论：性能数据必须实测，不能靠公式推**

> ⚠️ **本条结论已作废，见 [036]。** 模型没错，错的是分母（用了静态条数 41 而不是执行条数 36）。
- 踩坑：iverilog 不支持块内 `automatic` 声明；且编译失败时错误被 `sorry:` 过滤掉了，
  白跑了一次旧 vvp

## [034] 指令集补齐：blt/bge/bltu/bgeu + 两个设计漏洞
- `alu` 新增 SLTU（无符号比较）；`alu_ctrl` 分支按 funct3 选 SUB/SLT/SLTU
- `cpu_pipe` / `cpu_top` 的 branch_taken 补四条，用 `alu_result[0]` 判断
- 测试程序扩到 57 条，用「1 和 -1」这组有符号/无符号结果相反的值验证
- **发现漏洞 1：距离 3 的 RAW**（生产者 WB、消费者 ID 同拍）转发覆盖不到
  → `regfile` 加写优先旁路，详见 `cases/case-20`
- **发现漏洞 2：旁路在单周期形成组合环**，仿真死循环
  → 加 `BYPASS` 参数，单周期关闭
- 全套 13 个 testbench 全绿（alu 14 / alu_ctrl 18 / imem 58 / cpu 26 / cpu_pipe 28）

## [035] UART 发送端完成（用户写 + 跑通）
- `rtl/uart_tx.sv`：状态机（IDLE/START/DATA/STOP）+ 波特率分频，参数化（CLK_FREQ/BAUD_RATE）
- `tb/uart_tx_tb.sv`：把串行流**解码回字节**验证，5 个字节（55/A3/00/FF/01）全过
- **踩坑 1（设计）**：tx 做成寄存器输出 → 起始位 11 拍、其余 10 拍
  → 改成 `always_comb` 组合输出，每位严格 10 拍。详见 `cases/case-21`
- **踩坑 2（testbench）**：组合信号采样要加 `#1`；等电平用 while 不用 `@(negedge)`
- 下一步：MMIO —— CPU 写某个地址 → 触发 UART 发送

## [036] 修 CPI 统计：分母错了，模型其实一直是对的
- `cpu_pipe_tb` 之前把 `PROG_LEN = 57`（imem 写了多少条）当 CPI 分母，
  但 7 处跳转跳过 8 条，**实际执行 49 条**
- 完成标记还盯在 `x30`，扩程序后它变成中途的 `mem[40]`，测的不是程序结束
  → 改盯 `mem[56]` 写的 `x18`
- 修完两边对上：`49(执行) + 4(填充) + 1(停顿) + 7×2(改道) = 68 拍`，实测 68 拍
- **回头验算老版本**：41 条程序跳过 5 条 = 执行 36 条，
  `36 + 4 + 1 + 4×2 = 49`，正是当时实测的 49 拍
  → 证明 [033] 的"加法模型不成立"是分母错误造成的假象，模型一直准
- 正确 CPI：**68/49 = 1.388**（旧值 0.860 是拿 57 当分母算的）
- 性能公式升级为**断言**：实测 ≠ 预测就报错，不再只是打印
- 全套 15 个 testbench 全绿
- 档案：`cases/case-22-static-instr-count-cpi.md`；`09-pitfalls.md` 第 22 条

## [037] ★ C 程序在 FPGA 上跑通（工具链 + MMIO + UART）
- **目标提前达成**：原计划 11-30，实际 11-19 完成
- 工具链：VMware Ubuntu（Brandys-wonderland）里的 `riscv64-unknown-elf-gcc 10.2.0`
  - Windows 侧没有工具链，WSL 也没装发行版；共享文件夹 `~/myshare/riscvpga` ↔ `D:\riscvpga`
- 内存：imem / dmem 从 256 字扩到 **1024 字（4KB）**，索引改 `addr[11:2]`
- `imem` 加参数 `USE_FILE`：0 = 手写测试程序（所有老 testbench 用），1 = `$readmemh` 加载 C 程序
- **MMIO**：`0x3000` 写 = 串口发一个字节，读 = busy 状态
  - `cpu_pipe` 里按 `addr[31:12] == 0x3` 译码
  - 写 MMIO 时必须**挡住 dmem 写**（0x3000 的 `addr[11:2]` 恰好是 0，不挡会踩 `dmem[0]`）
- 软件：`sw/start.S`（crt0 设 sp）、`sw/link.ld`、`sw/main.c`、`sw/bin2hex.py`、`sw/build.sh`
- 链接脚本内存布局：`.text` @ 0x0，`.data/.bss` @ 0x1000，栈顶 0x2000
- 验证链：`cpu_uart_tb` 把串口波形**解码回字节**，8 个字节全对
- **上板结果**：LED 心跳正常，串口 COM7 收到 `SUM=55`（8 字节：53 55 4D 3D 35 35 0D 0A）
- 综合/实现：**2112 LUT（3.97%）/ 0 BRAM / WNS +4.284ns → Fmax ≈ 63.6MHz**
  - imem 被映射成 LUT-ROM，dmem 成分布式 RAM，**两者都保持组合读**（case-16 没复发）
- **踩坑**（已建档案）：
  1. C 里不能用字符串字面量——`.rodata` 在 IMEM，而 `lw` 只走 dmem（哈佛结构）
     → `cases/case-23-rodata-in-imem.md`
  2. `$readmemh` 相对路径在 Vivado 里不一定解析得到 → `prepare_sources.py` 注成绝对路径
     → `cases/case-24-readmemh-relative-path.md`（同篇附 `open_run` 的坑）
  3. `launch_runs` 在后台进程执行，直接 `report_*` 报 "No open design"，要先 `open_run`
  4. CP2102 缺驱动；**CH9102(COM6) 是核心板 Type-C 的 PS UART**，外接 USB-TTL 是 COM7
  5. 程序只打印一次，**串口必须先打开再复位/烧写**，否则数据发完就丢了
- 顺带发现：`j .` 在五级流水线里**每 3 拍执行一次**（2 拍冲刷惩罚），不是"PC 停住"
- 全套 **17 个 testbench 全绿**（新增 cpu_c_tb 冒烟测试 + cpu_uart_tb 端到端）

## [038] 修 ALU 移位缺失 + 重新上板
- **发现**：`alu_ctrl` 会输出 `alu_sel = 7/8/9`（`sll`/`srl`/`sra`/`slli`/`srli`/`srai`），
  但 `alu.sv` 只实现到 6，三个移位全落到 `default` 返回 **0**
  → 又一处静默错误：程序照跑，结果全错，不报任何错
- **为什么没被发现**：imem 里 57 条测试程序一条移位都没有，17 个 testbench 全绿也抓不到
- **修**：`alu.sv` 补 `ALU_SLL/SRL/SRA`
  - 移位量一律取 `b[4:0]`（RISC-V 规定只取低 5 位，`1<<32` 等价于 `1<<0`）
  - `SRA` 必须写 `$signed(a) >>> b[4:0]`，否则退化成逻辑右移
- `tb/alu_tb.sv` 补 **7 条断言**（14 → 21 条）：
  - `1<<32 == 1`（移位量只取低 5 位）
  - `0x80000000 >> 4 = 0x08000000` vs `>>> 4 = 0xF8000000`（SRL/SRA 必须不同）
  - `0xFFFFFFFF >> 4 = 0x0FFFFFFF` vs `>>> 4 = 0xFFFFFFFF`
- 重新综合：**2112 LUT / 0 BRAM / WNS +4.284ns**，与修前一致
  （移位器只占几条 LUT，不在关键路径上）
- 重新上板验证：COM7 收到 `SUM=55`
- **遗留**：移位只有 ALU 单元测试，没有"整条 CPU 跑移位指令"的端到端测试
  （往 57 条程序里加会牵动 PROG_WORDS/PROG_RETIRED 和三个 testbench）
