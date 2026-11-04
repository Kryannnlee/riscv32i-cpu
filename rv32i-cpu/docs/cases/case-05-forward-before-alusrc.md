# Case 05 · 转发 MUX 放在 ALUSrc 之后，立即数被"转发"掉

> **代码来源**：原始（讨论中列出的错误写法）　**严重程度**：静默
> **实际影响**：**写码前就识别并避开**，没有造成故障　**阶段**：6b

---

## 1. 现象（假如踩了会怎样）

`addi` / `lw` 这类用立即数的指令，结果偶尔算错；而纯 `add` / `sub` 一直正常。
错得没有规律，取决于前一条指令写的是哪个寄存器。

## 2. 错误写法

```systemverilog
    // 先做 ALUSrc 选择
    assign alu_b = id_ex_alu_src ? id_ex_imm : id_ex_rs2_data;

    // 再在 alu_b 上面套一层转发（← 错）
    always_comb begin
        case (forward_b)
            2'b01:   alu_b = ex_mem_alu_result;
            2'b10:   alu_b = wb_data;
            default: alu_b = alu_b_pre;      // 还得先存一份原值，越来越绕
        endcase
    end
```

## 3. 为什么错

两个 MUX 的**顺序**搞反了。

正确的数据流：

```
寄存器堆 rs2 ──► [转发 MUX] ──► [ALUSrc MUX] ──► ALU 的 B 口
                                             ▲
                                          立即数
```

转发只应该替换"**寄存器读出来的那个值**"，不该替换"**已经选好的立即数**"。

把转发放在 ALUSrc 之后，等于：`addi` 明明选的是立即数，
却可能被上一条指令的 ALU 结果覆盖掉。

## 4. 怎么想到的

把两个 MUX 画出来（就上面那个图），然后问：
**"转发到底是替换哪一个候选值？"**

答案：替换 `rs2_data`。那它就必须在 `rs2_data` 被选中**之前**动手。

## 5. 正确写法

```systemverilog
    // 1) 先转发 rs2
    always_comb begin
        case (forward_b)
            2'b01:   ex_rs2 = ex_mem_alu_result;
            2'b10:   ex_rs2 = wb_data;
            default: ex_rs2 = id_ex_rs2_data;
        endcase
    end

    // 2) 再做 ALUSrc 选择
    assign alu_b = id_ex_alu_src ? id_ex_imm : ex_rs2;
```

## 6. 怎么防止再犯

- 画数据通路图，把 MUX 按顺序摆出来，再写代码。
- 顺序写错的典型症状是"**只有一部分指令出错**"，而不是全错——因为只有走某一条分支的指令受影响。

## 7. 一句话记忆

> 转发替换的是"寄存器读出来的值"，所以必须排在"选择寄存器还是立即数"**之前**。
