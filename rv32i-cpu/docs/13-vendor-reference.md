# 13 · 官方例程对比（BX71 / 芯路恒）

> 资料位置：`ziliao/BX71型ZYNQ核心板用户资料/02_例程源码/【Verilog】逻辑设计与验证例程/_extracted_020/`
> （68 个例程已全部解压，对应 7020 板；7010 的是 `BX71_010`，未解压）

---

## 1. 风格对比

| 维度 | 官方例程 | 我们的设计 | 评价 |
| --- | --- | --- | --- |
| HDL | Verilog-2001：`reg` / `always @(posedge clk)` | SystemVerilog：`logic` / `always_ff` / `always_comb` | 我们更现代，综合结果一样 |
| 复位 | **异步、低有效**：`always @(posedge clk or negedge rst_n)` | **同步、高有效**：`always_ff @(posedge clk) if (rst)` | 两种都能用；FPGA 推荐同步复位（避免毛刺） |
| 端口 | 位置连接 `uart_byte_tx(clk, reset_n, ...)` | 命名连接 `.clk(clk)` | **命名更好**，改端口顺序不会错 |
| 约束 | 只有 `PACKAGE_PIN` + `IOSTANDARD` | 多了 `create_clock -period 20` | **我们有更完整的约束**，时序报告才有意义 |
| 存储器 | Block Memory IP + `.coe` 初始化文件 | RTL 数组 + `initial` | IP 更省资源；RTL 数组更好仿真、更好读 |

**结论：我们的写法整体更规范，不需要改成官方风格。** 值得借鉴的是具体模块，不是编码风格。

---

## 2. 引脚：完全一致

`ch01/led_flash.xdc`：

```tcl
set_property PACKAGE_PIN U18 [get_ports clk]     # 50MHz
set_property PACKAGE_PIN T10 [get_ports led]     # D9
set_property PACKAGE_PIN T19 [get_ports rst_n]   # S4
```

和我们现在的 `fpga/rv32i.xdc` 一字不差。

---

## 3. 可以直接拿来用的模块

### ① UART 发送：`ch05/uart_byte_tx.v`

接口：

```verilog
module uart_byte_tx(
    input        clk,          // 50MHz
    input        reset_n,      // 低有效
    input  [7:0] data_byte,    // 要发的字节
    input        send_en,      // 发送使能
    input  [2:0] baud_set,     // 波特率选择
    output reg   uart_tx,      // 串行输出
    output reg   tx_done,      // 发完一字节
    output reg   uart_state    // 忙标志
);
```

波特率分频值（50MHz，直接可用）：

| baud_set | 波特率 | 分频值 |
| --- | --- | --- |
| 0 | 9600 | 5207 |
| 1 | 19200 | 2603 |
| 2 | 38400 | 1301 |
| 3 | 57600 | 867 |
| 4 | **115200** | **433** |

实现思路：分频计数 → 产生位时钟 `bps_clk` → 用一个 0~10 的计数器依次输出
起始位、8 位数据（LSB 先）、停止位。

**改造点**：它是异步复位 + Verilog-2001 写法，接进我们的设计时，
要么保持原样（异步复位在 FPGA 里也可用），要么改成同步复位 + `always_ff` 统一风格。

### ② UART 接收：`ch06/uart_byte_rx.v`
### ③ 回环：`ch09/`（把收发的拼起来）
### ④ 按键消抖：`ch10/ch11`

如果我们用 S4 按键做复位/触发，**需要消抖**，可以直接参考。

### ⑤ 存储器 IP：`ch13/ch14/ch15`

用 Vivado 的 Block Memory Generator + `.coe` 初始化文件。

这提示了一条后续路线：

```
现在：imem/dmem = RTL 数组 + initial（简单、好仿真）
以后：换成 BRAM IP + .coe（省 LUT、更贴近工程实践）
```

跑 C 程序时如果要更大内存，IP 是更合适的选择。

---

## 4. 例程清单里对我们有用的

| 例程 | 用途 |
| --- | --- |
| `ch01_led_flash` | 最小工程模板、xdc 写法 |
| `ch05_uart_tx` / `ch06_uart_rx` / `ch09_uart_loopback` | **UART 全套** |
| `ch10_key_filter` / `ch11_key_led` | 按键消抖 |
| `ch13_rom_ip` / `ch14_ram_ip` | 存储器 IP 用法 |
| `ch18_pll_led` | PLL 用法（以后想超频 50MHz 以上时用） |

其余（DDS、ADC、DAC、摄像头、以太网、TFT）和本项目无关。

---

## 5. 一个观察：官方例程没有 `create_clock`

68 个例程的 xdc 里基本都没有时钟约束。这意味着：

- 综合/实现能过，但**时序报告是"无约束"状态**，看不出真实余量
- 我们的 `create_clock -period 20` 是更专业的做法

论文第 7 章要写"最高工作频率"，就必须有 `create_clock`，否则 Vivado 报不出数。
这一点我们做对了。

---

## 6. 引脚映射（从 76 个官方 xdc 里汇总）

### 板载固定资源

| 信号 | 引脚 | 说明 | 我们用了 |
| --- | --- | --- | --- |
| 时钟 | **U18** | 50MHz 晶振 | ✅ `clk` |
| 按键 | **T19** | S4，低有效 | ✅ `rst_n` |
| 板载 LED | **T10** | D9，高电平点亮 | ✅ `led[0]` |

### 串口（GPIO0 扩展口）

| 信号 | 引脚 | 出处 |
| --- | --- | --- |
| **UART_TX** | **K19** | ch05 `uart_tx.xdc`、ch09 `IO.xdc` |
| **UART_RX** | **J19** | ch06 `uart_rx_test_pin.xdc`、ch09 `IO.xdc` |

**注意**：这两个脚在板边的 **GPIO0 排针**上，不是板载 USB 口。
板载 CH9102F 接的是 PS_UART（B12/C12），PL 够不到。

→ **必须外接 USB-TTL 模块，用杜邦线把 TX/RX 接到 K19/J19。**

### GPIO 扩展口（可选，接外部 LED）

ch09 回环例程用它们显示状态：

| 信号 | 引脚 |
| --- | --- |
| led[0] | B20 |
| led[1] | D19 |
| led[2] | D20 |

如果要看多位结果，可以外接 3~8 个 LED 到这些脚。

---

## 7. 本项目建议的最终映射

```tcl
# 板载
clk         -> U18     # 50MHz
rst_n       -> T19     # S4 按键，低有效
led[0]      -> T10     # D9 板载绿灯，心跳/结果指示

# 串口（外接 USB-TTL）
uart_tx     -> K19     # 接 USB-TTL 的 RX
uart_rx     -> J19     # 接 USB-TTL 的 TX（可选）

# 可选：外接 LED 看多位结果
led[3:1]    -> B20 / D19 / D20
```

这套映射**全部有官方例程背书**，不是猜的。
