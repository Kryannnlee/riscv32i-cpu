# 第一次综合：只看资源占用和时序，不生成比特流
#
# 用法（在 rv32i-cpu 目录下，两步）：
#   python fpga/prepare_sources.py
#   vivado -mode batch -source fpga/synth.tcl
#
# 为什么要先跑 prepare_sources.py：
#   Vivado 综合器不接受 default_nettype none + input logic 的写法，
#   预处理器会生成一份去掉该指令的副本到 fpga/build/。

set part "xc7z020clg400-1"

read_verilog -sv [glob fpga/build/*.sv]
read_xdc fpga/rv32i.xdc
synth_design -top fpga_top -part $part

report_utilization    -file fpga/util.rpt
report_timing_summary -file fpga/timing.rpt -max_paths 5

exit
