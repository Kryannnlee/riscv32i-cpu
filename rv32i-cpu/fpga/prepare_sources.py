"""
为 Vivado 综合准备源码副本。

为什么要这一步：
    Vivado 的综合器**不接受** ``default_nettype none`` 配合 SystemVerilog 的
    ``input logic`` 端口声明，会报：
        [Synth 8-6735] net type must be explicitly specified for 'a'
                       when default_nettype is none
    iverilog 接受同样的写法，所以仿真一直是好的，问题只在综合时才暴露。

做法：
    把 rtl/*.sv 复制到 fpga/build/，去掉 ``default_nettype none / wire`` 两行。
    源码保持原样（仿真仍然享受这条指令的"漏声明就报错"保护）。

用法（在 rv32i-cpu 目录下）：
    python fpga/prepare_sources.py
"""

import glob
import os

SRC = "rtl"
DST = "fpga/build"

os.makedirs(DST, exist_ok=True)

files = sorted(glob.glob(os.path.join(SRC, "*.sv")))
for f in files:
    text = open(f, encoding="utf-8").read()
    text = text.replace("`default_nettype none\n", "")
    text = text.replace("`default_nettype wire", "")
    out = os.path.join(DST, os.path.basename(f))
    open(out, "w", encoding="utf-8", newline="\n").write(text)

print(f"prepared {len(files)} files -> {DST}/")
