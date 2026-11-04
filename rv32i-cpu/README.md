# rv32i-cpu

基于 FPGA 的 RV32I 五级流水线处理器（毕业设计）。

目标：**仿真跑通 → 上板跑通 C 程序（UART 输出）→ 论文**。
平台：Xilinx XC7Z020（梅哥 ACZ702 核心板），纯 PL 实现，不使用 ARM 硬核。

## 当前进度

```
阶段0~4  单周期 CPU        ✅ 11 个模块 + 整合，测试全过
阶段5    五级流水线结构    ✅ IF/ID/EX/MEM/WB + 4 个流水线寄存器
阶段6a   数据冒险复现      ✅ 有相关时结果错误，已定位
阶段6b   数据转发          ✅ EX/MEM 与 MEM/WB 两条通路，EX/MEM 优先
阶段6c   load-use 暂停     ⬜
阶段6d   控制冒险冲刷      ⬜
阶段7    跑 C 程序 / 上板  ⬜
```

## 指令支持

| 类别 | 已实现 |
| --- | --- |
| R 型 | `add` `sub` `and` `or` `xor` `slt` |
| I 型算术 | `addi` `andi` `ori` `xori` `slti` |
| 访存 | `lw` `sw` |
| 分支 | `beq` `bne`（译码完成，PC 选择逻辑待接） |
| 跳转 | `jal` `jalr`、`lui` `auipc` 待补 |

## 目录

```
rtl/     RTL 源码（SystemVerilog）
tb/      testbench
sim/     仿真脚本与产物
docs/    文档（入口：docs/00-index.md）
```

## 仿真

需要 [Icarus Verilog](http://iverilog.icarus.com/) 14.0+：

```bash
iverilog -g2012 -o sim/cpu_pipe.vvp rtl/*.sv tb/cpu_pipe_tb.sv
vvp sim/cpu_pipe.vvp
```

跑单个模块的测试，把 `cpu_pipe` 换成对应模块名即可（如 `alu`、`regfile`、`decoder`）。
波形可用 GTKWave 打开 `sim/*.vcd`。

## 设计与验证文档

从 [docs/00-index.md](docs/00-index.md) 进入。里面按「指令集 → 架构 → 各模块 → 踩坑」组织，
含每个模块的设计取舍、控制信号真值表和已踩过的坑。

## 许可

MIT，见 [LICENSE](../LICENSE)。
