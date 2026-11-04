# Case 14 · Vivado 综合器拒绝 `default_nettype none` + `logic` 端口

> **代码来源**：原始　**严重程度**：阻塞（综合直接失败）　**阶段**：首次综合

---

## 1. 现象

第一次跑综合，报：

```
ERROR: [Synth 8-6735] net type must be explicitly specified for 'a'
                      when default_nettype is none [rtl/adder.sv:19]
ERROR: [Synth 8-439] module 'fpga_top' not found
```

同一个文件，**iverilog 编译完全正常，仿真也全绿**。

## 2. 出问题的代码

```systemverilog
`default_nettype none
module adder (
    input  logic [31:0] a,      // ← 第 19 行，Vivado 卡在这
    input  logic [31:0] b,
    output logic [31:0] sum
);
```

## 3. 为什么错

| 工具 | `default_nettype none` + `input logic` |
| --- | --- |
| iverilog | ✅ 接受 |
| Vivado 综合器 | ❌ 拒绝，要求显式写 `wire` |

Vivado 在 `default_nettype none` 生效时，要求端口有**显式的线网类型**，
而 `logic` 在它眼里是数据类型，不是线网类型。

## 4. 怎么定位的（走了弯路）

**第一次判断错了。** 看到错误指向端口声明行，先怀疑是注释里的中文/装饰符号，
做了三组对照实验（纯 ASCII / 只留汉字 / 汉字+全角标点），结果都"通过"。

**但那些实验只跑了 `read_verilog`，没跑 `synth_design`。**
补做带综合的对照才定死：

| 变体 | read_verilog | synth_design |
| --- | --- | --- |
| 带 `default_nettype none` | ✅ | ❌ |
| 去掉这一行 | ✅ | ✅ |

**教训：验证工具行为时，要跑到真正出错的那一步，不能只做一半。**

## 5. 修法

不删源码里的指令（它能在仿真时抓漏声明，有价值），改成综合前生成副本：

`fpga/prepare_sources.py`：

```python
text = text.replace("`default_nettype none\n", "")
text = text.replace("`default_nettype wire", "")
```

输出到 `fpga/build/`，`synth.tcl` 从那里读。

## 6. 怎么防止再犯

- **仿真通过 ≠ 综合通过。** 每加一批 RTL，尽早跑一次综合。
- 判断工具问题时，对照组必须和真实流程一致（该跑综合就跑综合）。
- `default_nettype none` 这类"仿真友好、综合不友好"的写法，做成预处理，两边都保留。

## 7. 一句话记忆

> iverilog 接受、Vivado 不接受，是常态。**别用仿真器验证综合器。**
