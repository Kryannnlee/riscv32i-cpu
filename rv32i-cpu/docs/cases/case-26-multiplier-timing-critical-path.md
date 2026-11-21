# Case 26 · 加了乘法器，CPU 时序直接崩了

> **代码来源**：原始　**严重程度**：致命（功能全对，但 50MHz 下不工作）　**阶段**：M 扩展

---

## 1. 现象

给 ALU 加完 M 扩展的乘法（`mul/mulh/mulhu/mulhsu`），功能全对：
17 个 testbench 全绿，C 程序输出 `A=42 / B=8 / C=2` 一字不差。

然后跑综合：

```
WNS(ns) = -0.767      219 个端点违规      Timing constraints are not met.
```

**加之前是 +4.284ns。** 一个乘法器让时序掉了 5ns，50MHz 直接不满足。

## 2. 当时的代码

```systemverilog
// 跳转目标取自 ALU
assign jump_target = {alu_result[31:1], 1'b0};

// 分支条件也取自 ALU
3'b100:  branch_taken = id_ex_branch &  alu_result[0];   // blt
3'b101:  branch_taken = id_ex_branch & ~alu_result[0];   // bge
```

而 ALU 里新加了乘法器：

```systemverilog
ALU_MUL:    result = mul_uu[31:0];      // mul    低 32 位
ALU_MULH:   result = mul_ss[63:32];     // mulh   有符号高半
ALU_MULHU:  result = mul_uu[63:32];     // mulhu  无符号高半
```

## 3. 为什么错：共享 ALU 的代价

ALU 是**组合逻辑**，所有运算并列在同一个 `case` 里，输出经一个 MUX 汇成 `alu_result`。

综合器看到的路径是：

```
mem_wb 寄存器
   → 转发 MUX
      → ALU（包含乘法器，2 个 DSP48 级联）
         → alu_result[0]
            → branch_taken
               → pc_redirect
                  → next_pc
                     → PC 寄存器
```

**综合器无法证明"分支指令一定不会走乘法"**——`alu_sel` 是运行时信号。
所以在它看来，这条路径随时可能穿过乘法器，必须按最坏情况算。

| 加入前 | 加入后 |
| --- | --- |
| 加法器/比较器 ≈ 2ns | 乘法器 ≈ 5~7ns |

## 4. 怎么定位的：读时序报告的三个字段

```
Source:        u_cpu/mem_wb_i/reg_write_out_reg/C
Destination:   u_cpu/pc_reg/pc_reg[30]/D
Data Path Delay: 20.667ns  (logic 11.343ns, route 9.324ns)
Logic Levels:  33  (CARRY4=20  DSP48E1=2  LUT2=1  LUT4=3  LUT6=7)
                          ↑↑↑↑↑↑↑↑↑↑↑
```

| 看什么 | 说明 |
| --- | --- |
| **Source / Destination** | 从哪到哪：MEM/WB 寄存器 → PC 寄存器 |
| **Logic Levels** | 33 级——正常路径一般 10~15 级 |
| **里面的 DSP48E1=2** | **乘法器在这条路径上**，这是决定性证据 |

## 5. 第一次修错了

以为是 `jump_target` 借用了 ALU，于是给它单独配加法器：

```systemverilog
assign jalr_target = (ex_rs1 + id_ex_imm) & ~32'd1;
assign jump_target = (id_ex_alu_a_src == 2'b01) ? branch_target : jalr_target;
```

重新综合：**WNS 还是 -0.772**。

原因：`branch_taken` 仍然依赖 `alu_result[0]`，路径没断。

**教训**：改之前要确认"关键路径到底经过哪个信号"，而不是猜。

## 6. 正确的修法：把分支判断也拆出来

```systemverilog
// 专用比较器：只算"相等 / 大小"，不经过 ALU
logic br_eq, br_ltu, br_lts;
assign br_eq  = (ex_rs1 == ex_rs2);
assign br_ltu = (ex_rs1 <  ex_rs2);                  // 无符号
assign br_lts = ($signed(ex_rs1) < $signed(ex_rs2)); // 有符号

case (id_ex_funct3)
    3'b000:  branch_taken = id_ex_branch &  br_eq;    // beq
    3'b001:  branch_taken = id_ex_branch & ~br_eq;    // bne
    3'b100:  branch_taken = id_ex_branch &  br_lts;   // blt
    3'b101:  branch_taken = id_ex_branch & ~br_lts;   // bge
    3'b110:  branch_taken = id_ex_branch &  br_ltu;   // bltu
    3'b111:  branch_taken = id_ex_branch & ~br_ltu;   // bgeu
endcase
```

结果：

| 指标 | 修前 | 修后 |
| --- | --- | --- |
| WNS | −0.767 ns | **+4.215 ns** |
| Fmax | ≈ 48.6 MHz | **≈ 63.4 MHz** |
| LUT | 2696 | 2710（**只多 14 个**） |

**多一个比较器，反而只多 14 个 LUT**——因为 ALU 里那条长路被剪掉了，综合器优化出更多余量。

## 7. 怎么防止再犯

| 做法 | 说明 |
| --- | --- |
| **每次综合都看 WNS，不只看"0 errors"** | 时序违规不会让综合失败，只会静默生成跑不动的比特流 |
| **往共享 ALU 里塞大运算单元前，先评估关键路径** | 乘法器、除法器、桶形移位器都是"面积不大、路径很长"的典型 |
| **看时序报告先看 Logic Levels 和单元类型** | 出现 `DSP48`/`CARRY4` 密集 = 大运算在路径上 |
| **控制信号尽量从"窄逻辑"产生** | 分支判断只需要比较，不该借道完整 ALU |

## 8. 一句话记忆

> **共享 ALU 是个放大器：你塞进去的任何大运算，都会出现在每一条曾用过 ALU 的路径上。**
> 分支判断、跳转目标这类"窄逻辑"，别和乘法器挤一辆车。

---

## 附：为什么除法最后没做进硬件

同一轮里还测了组合除法器：

| 运算 | 最长路径 | 等效 Fmax |
| --- | --- | --- |
| 乘法 | 5.8 ns | ~171 MHz |
| **除法** | **82.6 ns** | **~12 MHz** |

32 位除法是 32 级"移位-比较-减"的串行过程，展开成组合逻辑后路径极长。
50MHz 需要 20ns，差 4 倍，**做不了**。

最终方案：
- 乘法 → 硬件（`-march=rv32im`）
- 除法 → 软件（`-mno-div` + 自写 `__divsi3` 等，见 `sw/div.c`）

这是一次**用测量数据做的设计取舍**，比拍脑袋可靠。
