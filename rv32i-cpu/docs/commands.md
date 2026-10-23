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
