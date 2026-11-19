# 烧板脚本：在 Vivado 的 Tcl Console 里执行
#   source D:/riscvpga/rv32i-cpu/fpga/program.tcl
#
# 前提：hw_server 已经在 3250 端口跑起来（默认的 3121 被 Windows 保留了）
#   D:\Xilinx\Vivado\2023.2\bin\hw_server.bat -s tcp::3250 -p0

# 0a) 初始化 labtools（没这步后面所有 hw_* 命令都会报 44-235）
open_hw_manager

# 0b) 如果已经连着别的 server（比如 3121），先断开
if {[llength [get_hw_servers -quiet]] > 0} {
    disconnect_hw_server [get_hw_servers]
}

# 1) 连到指定端口的 hw_server（不用 Auto Connect）
connect_hw_server -url localhost:3250

# 2) 打开目标（板子）
open_hw_target

# 3) 选中 PL 器件
#    注意：JTAG 链上还有 arm_dap_0（Zynq 的 ARM 调试口），
#    用 lindex ... 0 会取到它，它不是可编程器件。必须按名字挑。
current_hw_device [get_hw_devices xc7z020_1]
refresh_hw_device -update_hw_probes false [current_hw_device]

# 4) 指定比特流并烧写
set_property PROGRAM.FILE {D:/riscvpga/rv32i-cpu/fpga/vivado_build/rv32i.runs/impl_1/fpga_top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]

puts "=== program done ==="
