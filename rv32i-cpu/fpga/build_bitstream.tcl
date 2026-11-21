# 一键：新建工程 -> 综合 -> 实现 -> 生成比特流
#
# 用法（在 rv32i-cpu 目录下）：
#   python fpga/prepare_sources.py
#   vivado -mode batch -source fpga/build_bitstream.tcl
#
# 为什么不复用旧工程：
#   Vivado 会把源文件和约束**复制**进工程目录（sources_1/imports/...），
#   之后改 fpga/build/ 或 fpga/rv32i.xdc 都不会生效——这就是 case-18。
#   每次新建工程最省心，代价只是多花一点时间。

set root "D:/riscvpga/rv32i-cpu"
set part "xc7z020clg400-1"
set proj "$root/fpga/vivado_build"

file delete -force $proj
create_project -force rv32i $proj -part $part

add_files -norecurse [glob $root/fpga/build/*.sv]
add_files -fileset constrs_1 -norecurse $root/fpga/rv32i.xdc
set_property top fpga_top [current_fileset]
update_compile_order -fileset sources_1

# 时序收敛策略（都是实测出来的，别凭直觉改）
#
#   配置                                   WNS
#   ------------------------------------   ---------
#   place Explore   + route Explore         +0.521   加 UART 接收后明显变差
#   place ExtraTimingOpt + route AggressiveExplore  +1.204  ← 当前，最稳
#
# 关键教训：加一点逻辑（UART 接收只多 33 个 LUT）就会改变布局，
# 原来那条乘法器路径的**布线**可能被挤差 1.3ns。逻辑没变慢，是布线变差了。
# 所以换布局策略是有效的补救手段，不能只看"逻辑没加在关键路径上"。
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE      Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE    ExtraTimingOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE    AggressiveExplore [get_runs impl_1]

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "=== STATUS: [get_property STATUS [get_runs impl_1]] ==="

# launch_runs 是在后台进程里跑的，当前会话的内存里没有打开的设计。
# 直接调 report_* 会报 "No open design"，必须先 open_run 把它加载回来。
open_run impl_1
report_utilization    -file $root/fpga/util_impl.rpt
report_timing_summary -file $root/fpga/timing_impl.rpt -max_paths 5

puts "=== BITSTREAM: $proj/rv32i.runs/impl_1/fpga_top.bit ==="
exit
