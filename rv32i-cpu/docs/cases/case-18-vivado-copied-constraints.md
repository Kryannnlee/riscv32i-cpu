# Case 18 · Vivado 把约束文件复制进工程，改原文件不生效

> **代码来源**：原始　**严重程度**：致命（改了半天约束，等于没改）　**阶段**：首次上板

---

## 1. 现象

按官方引脚表把 `fpga/rv32i.xdc` 改成 BX71 的引脚（clk=U18、rst=T19、led=T10），
重新综合、实现、生成比特流、烧写——**灯还是不亮**。

反复改、反复重建，耗时很久，每次现象完全一样。

## 2. 问题在哪

Vivado 工程实际用的不是我们改的那个文件：

```
D:/riscvpga/rv32i-cpu/fpga/rv32i.xdc                              ← 我们改的（没被用）
.../prototype_rv32i.srcs/constrs_1/imports/fpga/rv32i.xdc         ← 工程实际用的（旧的）
```

工程里那份还是**开发板的旧引脚**：

```tcl
set_property PACKAGE_PIN F20 [get_ports rst_n]
set_property PACKAGE_PIN T14 [get_ports {led[0]}]     # ← 核心板上没接 LED
```

所以 `led[0]` 一直被绑到 T14——一个在 BX71 上什么都没连的球。

## 3. 为什么错

**Vivado 的 Add Sources 默认勾选 "Copy sources into project"。**

勾上之后，Vivado 把文件**复制**到工程自己的 `.srcs/` 目录，之后一切构建都用副本。
你在原目录改文件，它完全看不见——**而且不会提示**。

## 4. 怎么定位的

1. 先用独立计数器驱动 LED（和 CPU 无关），确认"时钟 + LED 引脚"这条链路
2. 还是不闪 → 问题在引脚层面，不在逻辑
3. 找工程里所有的 `.xdc`：

```bash
find prototype_rv32i -name "*.xdc"
```

4. 发现有两份，且**工程用的是 `.srcs/` 里的副本**
5. 打开副本一看，引脚还是旧的

## 5. 修法

把正确的文件复制过去：

```bash
cp fpga/rv32i.xdc fpga/prototype_rv32i/prototype_rv32i.srcs/constrs_1/imports/fpga/rv32i.xdc
```

再重建，灯就闪了。

## 6. 怎么防止再犯

| 做法 | 说明 |
| --- | --- |
| 加文件时**取消勾选** Copy sources into project | 工程引用原文件，改了立刻生效（推荐） |
| 已经复制了 | 每次改完手动 `cp` 覆盖副本 |
| 定期检查 | `find <project> -name "*.xdc"` 看有没有两份 |

**同样的坑也会出现在 `.sv` 源文件上**——如果加源码时勾了复制，
改 `rtl/` 里的文件同样不生效。

## 7. 一句话记忆

> "我改了，它也重建了，但就是没变" —— 先确认**它构建的到底是不是我改的那个文件**。
