# 一键重跑：综合 -> 实现 -> 生成比特流（在项目目录下执行）
#   vivado -mode batch -source fpga/build_all.tcl
#
# 前提：先跑过 python fpga/prepare_sources.py

open_project D:/riscvpga/rv32i-cpu/fpga/prototype_rv32i/prototype_rv32i.xpr

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "=== STATUS: [get_property STATUS [get_runs impl_1]] ==="
exit
