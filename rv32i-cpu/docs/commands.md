# 命令速查

工作目录一律为项目根：`D:\riscvpga\rv32i-cpu`

## 环境检查（装好后只跑一次）
```powershell
iverilog -V
vvp -V
gtkwave --version
```

## 通用模板（复制改名字）

```powershell
cd D:\riscvpga\rv32i-cpu
# 1) 编译：RTL + testbench → vvp
iverilog -g2012 -o sim\<名字>.vvp rtl\<rtl>.sv tb\<tb>.sv
# 2) 运行 → 生成 .vcd
vvp sim\<名字>.vvp
# 3) 看波形
gtkwave sim\<名字>.vcd
```

例子：
```powershell
iverilog -g2012 -o sim\mux2.vvp rtl\mux2.sv tb\mux2_tb.sv
vvp sim\mux2.vvp
gtkwave sim\mux2.vcd
```

## 跑仿真（编译 + 运行）
```powershell
powershell -File sim\run.ps1 -Top tb\alu_tb.sv -Sources rtl\alu.sv -Out sim\alu.vvp
```
- 多个源文件用逗号：`-Sources rtl\a.sv,rtl\b.sv`

## 看波形
```powershell
gtkwave sim\alu.vcd
```

## 只做语法检查（不仿真）
```powershell
iverilog -g2012 -Wall -o NUL rtl\alu.sv
```

## 清理生成物
```powershell
Remove-Item sim\*.vvp, sim\*.vcd -ErrorAction SilentlyContinue
```

## 看 Markdown（VS Code 预览）
VS Code 默认把 `.md` 当**纯文本**显示（看到 `|` 原文）。要看渲染后的表格：
- `Ctrl+Shift+V` → 当前文件预览
- `Ctrl+K` 然后 `V` → 右侧预览

（Antigravity 等富文本环境默认就渲染，所以那里表格是好的。）

## 关键参数
| 参数                  | 含义                                            |
| --------------------- | ----------------------------------------------- |
| `-g2012`              | 启用 SystemVerilog（`logic` / `always_comb` 需要） |
| `-Wall`               | 打开全部警告，早发现 latch / 位宽问题           |
| `-o`                  | 指定输出的 vvp                                  |
| `$dumpfile / $dumpvars` | testbench 里声明 VCD，`vvp` 阶段真正写盘       |

## 跑全套回归

**一条命令，自动返回退出码**：

```powershell
cd D:\riscvpga\rv32i-cpu
powershell -File sim/regress.ps1
```

输出：

```
TESTBENCH                PASS   FAIL  RESULT
---------------------- ------ ------  --------
alu_ctrl_tb                18      0  ok
alu_tb                     21      0  ok
...
==> ALL PASS
```

- 任何一项失败 → 脚本 **exit 1**，可以直接接 CI / pre-commit
- 判断依据是 **`vvp` 的退出码**，不是 grep 文本
  （`$fatal` 打印的是 `FATAL:`，不含 `FAIL` 这个子串，纯文本匹配会漏）
- `forward_unit_cmp_tb` 的报告词是 `EQUIVALENT`，脚本单独识别

**当前基线**：17 个 testbench 全绿，共 228 条断言。

### testbench 的失败处理规定

```systemverilog
if (实际 === 期望) $display("PASS ...");
else begin $display("FAIL ..."); errors++; end

// 结尾必须有这两行
if (errors > 0) $fatal(1, "%0d 处断言失败", errors);
$finish;
```

`$fatal` 会让 `vvp` 返回非 0，这是自动化唯一可靠的信号。
只写 `$display("FAIL")` 是不够的——2026-11 之前所有 testbench 都这样，
跑完看起来永远成功。

> 注意：`imem_tb` 和 `cpu_tb` 断言的是 `rtl/imem.sv` 里的**具体程序内容**。
> 改测试程序时这两个 testbench 必须同步改，否则会假报警。
