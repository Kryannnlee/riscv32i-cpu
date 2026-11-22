# 实测证据（evidence）

> 这里放**可直接引用**的原始证据——报告原文、串口原始输出。
> 论文附录、答辩材料从这里取，不要用别处的转述。

---

## 最终版本（硬件除法，推荐引用这一套）

| 文件 | 内容 |
| --- | --- |
| `dhrystone-hwdiv-timing.rpt` | Vivado 实现后时序报告（WNS、关键路径） |
| `dhrystone-hwdiv-utilization.rpt` | Vivado 实现后资源报告（LUT/FF/DSP/BRAM） |
| `dhrystone-hwdiv-board-output.txt` | 板上串口原始字节 + 解码 + 换算 |

### 关键数值

**时序**（`dhrystone-hwdiv-timing.rpt`）

```
sys_clk   周期 20.000 ns  →  50.000 MHz
WNS       0.903 ns
失败端点  0
```

**资源**（`dhrystone-hwdiv-utilization.rpt`）

```
Slice LUTs        5094 / 53200   (9.58%)
Slice Registers   1694 / 106400  (1.59%)
DSPs                12 / 220     (5.45%)
Block RAM Tile       0 / 140     (0.00%)
```

**性能**（`dhrystone-hwdiv-board-output.txt`）

```
Dhrystones per Second: 89269
→ 50.8 DMIPS = 1.02 DMIPS/MHz @ 50MHz
```

---

## 历史版本（软件除法，用于对比）

| 文件 | 说明 |
| --- | --- |
| `dhrystone-timing.rpt` / `dhrystone-utilization.rpt` | 除法走软件库时的报告（WNS +1.170，4878 LUT） |
| `dhrystone-board-output.txt` | 43,029 Dhrystones/s |

**软件除法 vs 硬件除法**（同一份 RTL，只换了除法实现）：

| | 每轮耗时 | Dhrystones/s | DMIPS/MHz |
| --- | --- | --- | --- |
| 软件除法 `-mno-div` + `sw/div.c` | 23 µs | 43,029 | 0.49 |
| **硬件除法 `rv32im` + `rtl/div_unit.sv`** | **11 µs** | **89,269** | **1.02** |

**性能翻倍。** 这张表适合放进论文的性能评估章节。

---

## 怎么复现

```bash
# 1. VMware Ubuntu 里构建 Dhrystone
cd ~/myshare/riscvpga/rv32i-cpu/sw && bash build_bench.sh

# 2. Windows 上带标签构建，报告归档到 fpga/reports/<标签>/
cd D:/riscvpga/rv32i-cpu
python fpga/prepare_sources.py
BUILD_TAG=dhrystone-hwdiv vivado -mode batch -source fpga/build_bitstream.tcl

# 3. 烧板子，串口 115200 看输出
```

`BUILD_TAG` 的作用：`report_*.rpt` 固定名文件每次构建都会被覆盖，
带标签的副本存到 `fpga/reports/<标签>/`，不会被下一次构建冲掉。

---

## 注意：数值随程序内容变化

同一个 RTL，**烧进去的程序不同，LUT 和 WNS 都不一样**——指令存储器的内容是常量，
常量改变会影响 LUT 实现和布局布线。

| 程序 | LUT | WNS |
| --- | --- | --- |
| Dhrystone（硬件除法） | 5094（9.58%） | +0.903 ns |
| 演示（循环回显，硬件除法） | 4733（8.90%） | +1.635 ns |
| 演示（加对齐检查前） | 4438（8.34%） | +2.445 ns |

**论文里引用资源/时序数据时必须注明是哪一版程序**，否则前后数字对不上。
