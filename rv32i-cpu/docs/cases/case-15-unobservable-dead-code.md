# Case 15 · 只连一个调试口，31 个寄存器被当死代码删掉

> **代码来源**：原始　**严重程度**：静默（数字失真，不报错）　**阶段**：首次综合

---

## 1. 现象

综合成功，资源报告：

```
Slice LUTs  1085   2.04%
Slice Registers 1488  1.40%
```

但同时有一堆警告：

```
24 WARNING: Port xxx in module dmem  is either unconnected or has no load
25 WARNING: Port xxx in module decoder is either unconnected or has no load
```

## 2. 当时的代码

`fpga_top` 只把 x1 接到 LED：

```systemverilog
assign led = dbg_x1[3:0];       // 只有 x1 可观测
```

其余 31 个寄存器、大部分控制信号，算出来的值**没有任何下游**。

## 3. 为什么错

综合器不是"照抄 RTL"，它会做**死代码消除**。

一段逻辑如果对任何输出都没有影响，就没有必要存在——删掉能省资源、省功耗。
在综合器眼里，这不是偷懒，是优化。

于是：

```
x2..x31 只被写、没人读  → 删
只为这些寄存器服务的控制信号 → 删
dmem 的读数据没有下游      → 部分剪掉
```

**结果：资源和时序数字都不是真实占用，写进论文会被评委问住。**

## 4. 怎么定位的

看警告的关键词：`is either unconnected or has no load`。

再对照"我们只接了一个 4 位输出"这个事实，就能推出：
**可观测的输出太少，导致大部分电路被判定为无用。**

## 5. 修法：人为制造观测点

`regfile.sv` 增加一个把所有寄存器异或起来的输出：

```systemverilog
always_comb begin
    dbg_xor = 32'd0;
    for (int i = 1; i < 32; i++)
        dbg_xor = dbg_xor ^ regs[i];
end
```

`fpga_top` 把它压成一比特引到管脚：

```systemverilog
assign dbg_alive = ^dbg_xor_all;
```

这一比特没有任何实际功能，**纯粹是"拴住"所有寄存器**，让综合器一个都删不掉。

修完：

| | 修前 | 修后 |
| --- | --- | --- |
| Slice LUTs | 1085 | **1381** |
| Slice Registers | 1488 | **1514** |
| LUTRAM | 0 | **128** |

寄存器数从 1488 → 1514 变化不大（128 个通用寄存器本来就在），
但 LUT 和 LUTRAM 明显上升，说明之前确实被剪掉了一批组合逻辑。

## 6. 怎么防止再犯

- **做资源统计前，先确认设计"全部可观测"。**
- 常见做法：把所有寄存器的异或/或约简引到管脚；或者对关键模块加 `DONT_TOUCH`。
- 看到 `has no load` 警告时，问自己：这条逻辑在本该存在的场景里，真的没用吗？
  如果答案是"有用，只是没人看"，那就是被优化了。

## 7. 一句话记忆

> 综合器的目标是"最少资源实现同样功能"，不是"照抄你的 RTL"。
> **没人看的东西，就不存在。**
