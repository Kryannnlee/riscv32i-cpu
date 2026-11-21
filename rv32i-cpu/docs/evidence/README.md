# 实测证据（evidence）

> 这里放**可直接引用**的原始证据文件——报告原文、串口原始输出。
> 论文附录、答辩材料从这里取，不要用别处的转述。

---

## 文件清单

| 文件 | 内容 | 来源 |
| --- | --- | --- |
| `dhrystone-timing.rpt` | Vivado 实现后时序报告（WNS 表、关键路径） | `report_timing_summary` |
| `dhrystone-utilization.rpt` | Vivado 实现后资源报告（LUT / FF / DSP / BRAM） | `report_utilization` |
| `dhrystone-board-output.txt` | 板上跑 Dhrystone 的串口原始字节 + 解码 | 串口助手 COM7 |

两份 `.rpt` 是 Vivado 原样输出，**未经任何修改**。
生成时间见文件头部 `| Date :` 那一行。

---

## 关键数值（从上面文件里读出来的）

### 时序（`dhrystone-timing.rpt`）

```
sys_clk   周期 20.000 ns  →  50.000 MHz
WNS       1.170 ns
失败端点  0
```

`WNS = 1.170ns` 意味着最长路径 18.830ns，**50MHz 约束满足**。

### 资源（`dhrystone-utilization.rpt`）

```
Slice LUTs                 4878 / 53200   (9.17%)
  LUT as Logic             2830 / 53200   (5.32%)
  LUT as Memory            2048 / 17400  (11.77%)   ← 全是分布式 RAM
Slice Registers            1694 / 106400  (1.59%)
Block RAM Tile                0 / 140      (0.00%)
DSPs                         12 / 220      (5.45%)
```

**Block RAM = 0** 是设计选择：imem/dmem 全用 LUTRAM，保持组合读，
避免 BRAM 同步读带来的流水线适配问题（见 `cases/case-16`）。

### 性能（`dhrystone-board-output.txt`）

```
Dhrystones per Second: 43029
→ 24.5 DMIPS = 0.49 DMIPS/MHz @ 50MHz
```

---

## 怎么复现

```bash
# 1. 在 VMware Ubuntu 里构建 Dhrystone 程序
cd ~/myshare/riscvpga/rv32i-cpu/sw && bash build_bench.sh

# 2. 回到 Windows，带标签构建，报告会归档到 fpga/reports/dhrystone/
cd D:/riscvpga/rv32i-cpu
python fpga/prepare_sources.py
BUILD_TAG=dhrystone vivado -mode batch -source fpga/build_bitstream.tcl

# 3. 烧板子，串口 115200 看输出
```

`BUILD_TAG` 的作用：`report_*.rpt` 固定名文件每次构建都会被覆盖，
带标签的副本存到 `fpga/reports/<标签>/`，不会被下一次构建冲掉。

---

## 注意：数值随程序内容变化

同一个 RTL，**烧进去的程序不同，LUT 和 WNS 都不一样**——因为指令存储器
的内容是常量，常量改变会影响 LUT 实现和布局布线。

| 程序 | LUT | WNS |
| --- | --- | --- |
| Dhrystone | 4878（9.17%） | +1.170 ns |
| 循环回显演示 | 4417（8.30%） | +0.771 ns |

**论文里引用资源/时序数据时，必须注明是哪一版程序**，否则前后数字对不上。
