# Case 16 · 组合读被推断成 Block RAM，上板会差一拍

> **代码来源**：原始　**严重程度**：致命且静默（仿真全对，上板错）　**阶段**：首次综合

---

## 1. 现象

综合报告里出现：

```
| u_cpu/dmem_i/mem_reg | 256 x 32 (READ_FIRST) | W | R | Port A | 1 |
| Block RAM Tile | 0.5 |
| LUT as Memory  | 0   |
```

日志：

```
INFO: [Synth 8-7052] The timing for the instance u_cpu/dmem_i/mem_reg
      (implemented as a Block RAM) might be sub-optimal ...
```

**没有 ERROR，没有 CRITICAL WARNING。** 纯靠读报告才发现。

## 2. 当时的代码

```systemverilog
module dmem (...);
    logic [31:0] mem [0:255];

    // 组合读：地址一变，数据当拍就出来
    assign rd_data = mem[addr[31:2]];

    // 同步写
    always_ff @(posedge clk)
        if (we) mem[addr[31:2]] <= wr_data;
endmodule
```

## 3. 为什么错

**Block RAM 的读是跟时钟走的，做不到组合读。**

Xilinx 的 BRAM 内部有输出寄存器，读数据在时钟沿之后才出来。
而我们的 `dmem` 靠的是"地址一给，数据立刻出来"，`mem_wb` 在同一拍末采样。

如果真按 BRAM 实现，`lw` 拿到的数据会**晚一拍**：

```
        本拍                下一拍
地址 ──► BRAM（先锁存）──► 数据出来
        可我们期望这里就有数据
```

后果：所有 `lw` 的值都错，而**仿真、综合都不报错**。
这是"仿真全绿、上板皆错"的典型。

## 4. 怎么定位的

不是靠报错，是靠**读综合报告**：

1. 看资源表，发现 `Block RAM = 0.5`、`LUT as Memory = 0`
2. 但我们有两个 256×32 的存储器，且都是组合读——**组合读怎么可能变成 BRAM？**
3. 回看 RTL：`assign rd_data = mem[addr[31:2]]` 确实是异步读
4. 结论：Vivado 的推断和 RTL 语义不符

## 5. 修法：用属性强制

```systemverilog
// dmem
(* ram_style = "distributed" *) logic [31:0] mem [0:255];

// imem（只读，用 rom_style）
(* rom_style = "distributed" *) logic [31:0] mem [0:255];
```

`distributed` = LUTRAM，由查找表拼成，**支持组合读**，语义和代码一致。

修完报告：

```
| LUT as Memory | 128 |
| Block RAM Tile | 0 |
```

## 6. 怎么防止再犯

- **上板前必读综合报告**，特别是存储器的推断方式（`report_utilization` / `report_ram_utilization`）。
- 组合读的存储器，明确写 `ram_style = "distributed"`。
- 同步读的存储器才应该用 BRAM（面积小、频率高）。
- 记住这条对应关系：

| RTL 写法 | 正确实现 |
| --- | --- |
| 组合读 + 同步写 | LUTRAM（distributed） |
| 同步读 + 同步写 | BRAM |
| 只有初值、只读 | ROM（distributed 或 BRAM + INIT） |

## 7. 一句话记忆

> **综合器会"猜"你的意图，猜错了也不报错。**
> 存储器尤其要看报告，别信默认。
