# 只出报告，不重新综合：打开已有工程和实现结果
# 用法： vivado -mode batch -source fpga/report_only.tcl

set root "D:/riscvpga/rv32i-cpu"
open_project $root/fpga/vivado_build/rv32i.xpr
open_run impl_1
report_utilization    -file $root/fpga/util_impl.rpt
report_timing_summary -file $root/fpga/timing_impl.rpt -max_paths 5
puts "=== reports written ==="
exit
