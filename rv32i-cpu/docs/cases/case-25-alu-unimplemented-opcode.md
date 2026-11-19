# Case 25 · 译码出 7/8/9，ALU 没实现，静默算成加法

> **代码来源**：原始　**严重程度**：静默（程序照跑，结果全错，不报任何错）　**阶段**：指令集 / ALU

---

## 1. 现象

没有现象。**这才是最可怕的。**

程序编译通过、链接通过、仿真通过、17 个 testbench 全绿、板子上 LED 正常闪、
串口也能打印——但只要有移位指令，算出来的就是错的。

## 2. 当时的代码

`rtl/alu_ctrl.sv`（译码端，输出 7/8/9）：

```systemverilog
(funct3 == 3'b001) ? 4'd7 :                      // sll / slli
(funct3 == 3'b101 && funct7 == 7'b0000000) ? 4'd8 :  // srl / srli
(funct3 == 3'b101 && funct7 == 7'b0100000) ? 4'd9 :  // sra / srai
```

`rtl/alu.sv`（执行端，只实现到 6）：

```systemverilog
localparam logic [3:0] ALU_ADD = 4'd0;
...
localparam logic [3:0] ALU_SLTU = 4'd6;   // ← 到此为止

case (alu_sel)
    ALU_ADD:  result = a + b;
    ...
    ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
    default:  result = 32'd0;              // ← 7、8、9 全落这里
endcase
```

## 3. 为什么错：两端的编码表不一致

译码端和执行端是**两个独立文件**，靠 `alu_sel` 这个 4 位总线通信。
**没有任何机制保证两端的编码表一致。**

| 端 | 认为 `7/8/9` 是什么 |
| --- | --- |
| `alu_ctrl` | `sll` / `srl` / `sra` |
| `alu` | 不存在，走 `default` |

而且 `default` 给的是 `result = 0`（为了防锁存器），所以移位全部返回 0。

更糟的是：**0 是个很"正常"的值**。程序不会崩，只是算错。

## 4. 怎么定位的

不是跑出来的，是**读代码读出来的**：

1. 看 `alu_ctrl` 时注意到它输出 7、8、9
2. 顺手翻 `alu.sv`，发现 `localparam` 只到 6
3. 对照 `case` 的 `default` 分支——全都归零

**验证方法**：写一组 ALU 单元测试。如果当初有这些断言，第一天就会红：

```systemverilog
a=32'h8000_0000; b=32'd4; alu_sel=4'd8; #1;   // SRL
if (result === 32'h0800_0000) ...
else                          ... FAIL
```

## 5. 修正后的代码

`rtl/alu.sv` 补齐三个：

```systemverilog
localparam logic [3:0] ALU_SLL = 4'd7;
localparam logic [3:0] ALU_SRL = 4'd8;
localparam logic [3:0] ALU_SRA = 4'd9;

...
ALU_SLL: result = a << b[4:0];              // 移位量只取低 5 位
ALU_SRL: result = a >> b[4:0];              // 逻辑右移，高位补 0
ALU_SRA: result = $signed(a) >>> b[4:0];    // 算术右移，高位补符号位
```

`tb/alu_tb.sv` 补 7 条断言（14 → 21 条），关键是这几条：

| 断言 | 抓什么 |
| --- | --- |
| `1 << 32 == 1` | 移位量只取 `b[4:0]`，取整个 b 会错 |
| `0x80000000 >> 4 = 0x08000000` | SRL 高位补 0 |
| `0x80000000 >>> 4 = 0xF8000000` | SRA 高位补符号位 |
| 上面两条**结果必须不同** | SRA 写成 `>>` 会退化成 SRL |

## 6. 怎么防止再犯

| 做法 | 说明 |
| --- | --- |
| **译码器和执行器共用同一份编码定义** | 用 `package` 或 `` `include ``，别在两个文件里各写一遍 `localparam` |
| **`default` 不要静默返回 0** | 至少在仿真里 `$error` / `$fatal`，把"未实现"暴露出来 |
| **每个 ALU 操作都要有单元测试** | 这次 17 个 testbench 全绿也没抓到，因为 ALU 只测了 0~6 |
| **新增译码分支时，同步检查执行端** | 改一端必须改另一端，这是天生的耦合点 |

### 特别说明：`default` 的两难

`default` 必须存在（否则综合出锁存器），但**返回值选什么很关键**：

| 选择 | 后果 |
| --- | --- |
| `result = 0` | 静默错误（本案） |
| `result = 32'hxxxx` | 仿真能看出来，综合后不确定 |
| `assert` / `$error` | 仿真立刻报，但综合不支持 |
| **译码端保证不输出非法值** | 治本，但依赖人工纪律 |

现实做法：`default` 返回 0 **加上**每个操作都有测试覆盖。两者缺一不可。

## 7. 一句话记忆

> **译码器能输出、执行器没实现的编号，会悄悄走 `default`。**
> 两个文件各写一份编码表，就是在埋雷。
