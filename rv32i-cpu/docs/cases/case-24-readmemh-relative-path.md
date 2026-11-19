# Case 24 · `$readmemh` 用了相对路径，仿真能读、综合读不到

> **代码来源**：原始　**严重程度**：静默（综合不报错，但 ROM 里是空的或者全 0）　**阶段**：C 程序 / 上板

---

## 1. 现象

同一个 `rtl/imem.sv`：

- 用 `iverilog` 仿真 → 程序正常跑
- 用 `Vivado` 综合上板 → 板上什么都不动

综合日志里没有任何 ERROR，最多一条不起眼的 warning。比特流照样生成，照样能烧。

## 2. 当时的代码

```systemverilog
if (USE_FILE) begin
    $readmemh("sw/prog.hex", mem);   // ← 相对路径
end
```

## 3. 为什么错

**相对路径是相对"进程的当前工作目录"，不是相对源文件。**

| 工具 | 运行时的 cwd | `"sw/prog.hex"` 指向 |
| --- | --- | --- |
| `iverilog` + `vvp` | 工程根目录（`sim/run.ps1` 会切过去） | ✅ 正确 |
| Vivado batch | 启动 Vivado 的那个 shell 的目录 | ❓ 不一定是工程根 |

一旦 Vivado 的 cwd 不在工程根，`$readmemh` 找不到文件——
**它不会报错终止**，只是什么都不加载，`mem` 保持 `initial` 里的值（全 NOP）。

于是板上 CPU 一直在执行 NOP，PC 空转，LED 可能还闪（心跳是独立计数器），
但串口永远没有输出。

## 4. 怎么定位的

**这次是预防性地避开了**：写 `prepare_sources.py` 时就考虑到两个工具的 cwd 可能不同。

定位这类问题的通用办法：

1. 看综合日志里有没有 `$readmemh` 相关的 warning
2. 综合后在 Vivado 里打开综合后的网表，看 ROM 的初值是不是全 0 / 全 NOP
3. 最直接：仿真跑得通、上板不动，**第一个怀疑对象就是"文件没读到"**

## 5. 修正后的代码

`fpga/prepare_sources.py` 在生成综合副本时，把路径换成绝对路径：

```python
HEX_ABS = os.path.abspath("sw/prog.hex").replace("\\", "/")

for f in files:
    text = open(f, encoding="utf-8").read()
    text = text.replace("`default_nettype none\n", "")
    text = text.replace("`default_nettype wire", "")
    text = text.replace('"sw/prog.hex"', '"%s"' % HEX_ABS)   # ← 这一行
    ...
```

生成出来的 `fpga/build/imem.sv` 里是：

```systemverilog
$readmemh("D:/riscvpga/rv32i-cpu/sw/prog.hex", mem);
```

**仿真源码保持相对路径**（可移植），**综合副本用绝对路径**（保证能读到）。
两边各取所需，源头只有一份。

## 6. 怎么防止再犯

| 做法 | 说明 |
| --- | --- |
| **凡是给工具读的文件，先问"它的 cwd 是什么"** | 编译、综合、仿真的 cwd 往往都不一样 |
| **预处理阶段统一处理路径** | 像 `prepare_sources.py` 这样，一处转换、两边受益 |
| **综合完检查 ROM/RAM 的初值** | Vivado 的 `Report Utilization` 后面有 ROM 映射报告，能看到深度和实现方式 |
| **仿真通过但上板不动 → 先怀疑文件没加载** | 这类问题不报错，最容易被当成"时序问题"查半天 |

## 7. 一句话记忆

> **相对路径只对自己那套工具有效。跨工具传文件，一律转成绝对路径。**

---

## 附：同时踩到的另一个 Vivado 用法坑

`fpga/build_bitstream.tcl` 里这样写：

```tcl
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
report_utilization -file $root/fpga/util_impl.rpt     ;# ← 这里报错
```

报 `ERROR: [Common 17-53] User Exception: No open design.`

原因：`launch_runs` 是在**另一个进程**里跑的，主会话的内存里并没有打开任何设计。
`wait_on_run` 只是等它结束，不会把设计加载回来。

修法：报告之前先 `open_run impl_1`。

```tcl
wait_on_run impl_1
open_run impl_1                                        ;# ← 补这一行
report_utilization    -file $root/fpga/util_impl.rpt
report_timing_summary -file $root/fpga/timing_impl.rpt
```

**注意**：这条报错**不影响比特流生成**，比特流早就写好了，只是报告没出来。
看到 ERROR 别慌，先看 `=== STATUS: ... ===` 那行是不是 `Complete`。
