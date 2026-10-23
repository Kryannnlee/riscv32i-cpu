# 06 · Verilog / SystemVerilog 速查（贴本项目）

只记本项目用得到的。写 `rtl/` 时随时翻。

---

## 1. 模块 module
```systemverilog
module alu (
    input  logic [31:0] a,
    output logic [31:0] result
);
    // 内部逻辑
endmodule
```
- `input`/`output` 是方向；一文件一模块；`endmodule` 收尾。

## 2. 位宽与常数
```systemverilog
logic [31:0] a;        // 32 位
32'd5                  // 32 位十进制
32'b1010               // 32 位二进制
32'hDEAD_BEEF          // 32 位十六进制
```
- `[31:0]` = 32 根线，bit31 最高、bit0 最低；`_` 只是给人看。

**常数格式**：`<宽度>'<进制><值>`
```
32 'h DEAD
│    │  └─ 值
│    └──── h=十六进制 (d=十进制, b=二进制, o=八进制)
└───────── 位宽
```
- `32'hDEAD` = `0x0000DEAD`（16 位值，高位补 0 到 32 位）
- `32'd10` / `32'b1010` / `32'hBEEF`
- **魔数**：`DEAD`、`BEEF`、`DEADBEEF` 是程序里常用的"好记的填充值"，**无特殊含义**，只图一眼能认出。

## 3. 组合逻辑：`assign`
```systemverilog
assign zero = (result == 32'd0);
```
- 输入一变输出立刻变，**无时钟**。

## 4. 组合逻辑：`always_comb` + `case`
```systemverilog
always_comb begin
    case (alu_sel)
        4'd0: result = a + b;
        default: result = 32'd0;
    endcase
end
```
- **`case` 必须写 `default`**，否则可能综合出**锁存器(latch)**（bug）。

## 5. 时序逻辑：`always_ff @(posedge clk)`
```systemverilog
always_ff @(posedge clk) begin
    if (rst) q <= 32'd0;
    else     q <= d;
end
```
- 只在时钟上升沿更新；写 PC、寄存器堆、流水线寄存器都靠它。

## 6. `=` 与 `<=`（最容易错）
| | `=` 阻塞 | `<=` 非阻塞 |
| --- | --- | --- |
| 用在哪 | `always_comb` | `always_ff` |
| 行为 | 立即生效 | 读旧值，本时刻末一起更新 |

**口诀**：组合用 `=`，时序用 `<=`。
**记忆法**：> 先记住我要给谁赋什么，最后大家一起变。

## 7. `logic` / `reg` / `wire`
- 统一用 `logic`。`reg` 是旧写法，**不一定是硬件寄存器**。
- **不要从类型名判断硬件，看“谁驱动它”**：

| 看到 | 硬件是 |
| --- | --- |
| `always_comb` | 组合逻辑 |
| `always_ff @(posedge clk)` | 寄存器 |
| `assign` | 连续连接 |

坑（以后讲）：一个信号有多个驱动源时，`logic` 不能随便替代 `wire`。

## 8. `localparam`
```systemverilog
localparam logic [3:0] ALU_ADD = 4'd0;   // 常量，定义后不能改
logic      [3:0] ALU_ADD = 4'd0;         // 变量，可再赋值
```
- 类比 C 的 `const int`；被保护的是**名字**，不是右边的字面量。

## 9. 运算符
```systemverilog
a + b   a - b   a & b   a | b   a ^ b   ~a
a << 2  a >> 2
a == b  a < b
a ? b : c        // 三目
```

**位运算 vs 逻辑运算**（重点）

| 按位（逐位，输出等宽） | 逻辑（整体当布尔，输出 1 位） |
| --- | --- |
| `a & b` 按位与 | `a && b` 逻辑与 |
| `a \| b` 按位或 | `a \|\| b` 逻辑或 |
| `~a` 按位取反 | `!a` 逻辑非 |

- **按位**：对每一对 bit 分别套用同一个门规则。`b=111` → `a|b` 恒 `=111=7`；`b=0` → `a|0=a`。
- **逻辑**：把整个向量看成一个值（非零 = 真），只出 1 位。

## 9b. 部分选择 `[ ]` 与拼接 `{ }`

**部分选择**：方向必须和声明一致。声明 `[31:0]` 就只能 `[31:24]`、`[7:0]`
（`in[0:31]` 是**非法**的）。
```systemverilog
in[31:24]   // 最高字节
in[7:0]     // 最低字节
```

**拼接 `{ }`**：把几段 bit 拼成一个向量，**写在前面的在最高位**。
```systemverilog
assign out = { a, b, c };          // {a,b,c}
assign x = {4'b1010, in[3:0]};     // 8 位
```

**归约运算（unary，把整个向量归约成 1 位）**：
```systemverilog
&in    // 全 1 才为 1       （AND 归约）
|in    // 有 1 就为 1       （OR 归约）
^in    // 各位异或（奇偶校验）
~&in   // 与非归约
```
注意是**一元**、写在信号前：`&in` 不是 `a & in`。

**复制**：`{n{y}}` = 把 y 重复 n 次。
```systemverilog
{4{1'b1}}       // 4'b1111
{20{instr[31]}} // 符号扩展用
```

**字节反转示例**：
```systemverilog
assign out = { in[7:0], in[15:8], in[23:16], in[31:24] };
```

> 注意：**bit 反转**（每位都倒）和**字节反转**（只换 8 位组）是两回事。

**赋值时位宽不匹配（不报错！）**：
- **窄 → 宽**：无符号**高位补 0**（如 16 位赋给 24 位，高 8 位 = 0）。
- **宽 → 窄**：**截断**。
- **部分选择漏驱动的位**：在仿真里是**高阻 `Z`**（综合会警告）；**不是** latch。

**部分选择可放等号左边**（分段驱动）：
```systemverilog
assign {out[7:0], out[15:8]} = in;   // 左侧拼接 = 右侧 16 位
assign out[15:0] = {...};            // 等价
```

## 10. 有符号：`$signed`
```systemverilog
result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
```
- 默认无符号；比较负数必须 `$signed`。`4'b1111`：无符号 15，有符号 -1。

## 11. 实例化（testbench 里接被测模块）
```systemverilog
alu dut (
    .a(a), .b(b), .alu_sel(alu_sel),
    .result(result), .zero(zero)
);
```
- 左边 `.端口名` 必须和模块端口**完全一致**；右边是本地的信号。

## 12. testbench 三件套
```systemverilog
`timescale 1ns/1ps
initial begin
    $dumpfile("sim/xxx.vcd");
    $dumpvars(0, xxx_tb);
    ...
    $display("...");
    $finish;
end
```

---

## 13. 隐式网络（Implicit nets）—— 常见坑

没显式声明的信号，Verilog 会**偷偷当成 1-bit wire**，不报错，导致高位被截断：
```systemverilog
wire [2:0] a, c;
assign a = 3'b101;
assign b = a;   // b 没声明 → 被当 1-bit，b = 1'b1
assign c = b;   // c = 3'b001  ← 和预期不符的 bug
```

**防范**
1. 所有信号都显式用 `logic` 声明（我们一直这么做）。
2. 文件顶部加 `` `default_nettype none ``，未声明就**编译报错**。

⚠️ **关键**：`` `default_nettype `` 是**全局、跨文件**的（会影响之后编译的所有文件）。
所以**开头设 `none`，结尾必须恢复 `wire`**。

**本项目 RTL 文件模板**：
```systemverilog
`timescale 1ns/1ps
`default_nettype none

module xxx (
    ...
);

    // ...

endmodule

`default_nettype wire
```

危险场景：**变量名拼错**（`result` 写成 `reslt`）——编译通过但逻辑全错。

---

## 14. 参数 `parameter` 与 `#( )`

```systemverilog
module mux2 #(parameter WIDTH = 32) (   // #(...) = 参数列表
    input  logic [WIDTH-1:0] d0,        // (...) = 端口列表
    output logic [WIDTH-1:0] y
);
```

- **`#( )`** = **参数**列表（常量、规格，如位宽）。
- **`( )`** = **端口**列表（信号、连线）。
- `#` 就是用来区分这两个列表的标记。

**例化时传参**：
```systemverilog
mux2 #(.WIDTH(32)) m1 ( .sel(s), .d0(a), .d1(b), .y(y) );
      └ 参数：WIDTH=32 ┘   └──── 端口连接 ────┘
```

**`parameter` vs `localparam`**：
| | 作用域 | 能否从外部改 |
| --- | --- | --- |
| `parameter` | 可被例化时**覆盖** | 能（`#(.WIDTH(8))`） |
| `localparam` | 模块内部常量 | 不能 |

**类比**：`#()` = "设置"（规格），`()` = "接线"（信号）。

## 速查表
| 想干的事 | 写法 |
| --- | --- |
| 输出=输入函数 | `assign y = a & b;` |
| 多分支组合 | `always_comb` + `case`(+`default`) |
| 存值 | `always_ff @(posedge clk)` + `<=` |
| 命名常量 | `localparam ... = ...;` |
| 32 位常数 | `32'd5` / `32'b1010` / `32'hFF` |
| 负数比较 | `$signed(a) < $signed(b)` |
| 接被测模块 | `模块名 实例名 (.端口(信号));` |
