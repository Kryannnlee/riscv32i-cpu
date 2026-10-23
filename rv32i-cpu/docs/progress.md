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
