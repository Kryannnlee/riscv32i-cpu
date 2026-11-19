# ============================================================
# BX71 核心板 (Zynq-7020, XC7Z020CLG400) 引脚约束
#
# 引脚来源：ziliao/BX71/04_引脚信息表/BX71开发板管脚信息表.xlsx
#   板载只有一个用户 LED（T10），一个按键（T19），50MHz 时钟（U18）
#   led[3:1] 和 dbg_alive 引到 GPIO0 扩展口，不接线看不到
#
# 注意：这不是小梅哥 ACZ702 开发板的引脚（那套是 U18/F20/T14）
# ============================================================

# 未用引脚不要悬空
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]

# ---- 50MHz 板载时钟 ----
set_property PACKAGE_PIN U18     [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]

# ---- 按键 KEY0，低有效 ----
set_property PACKAGE_PIN T19     [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PULLUP true         [get_ports rst_n]

# ---- LED0：板载，心跳用 ----
set_property PACKAGE_PIN T10     [get_ports {led[0]}]

# ---- led[3:1]：GPIO0 扩展口 ----
set_property PACKAGE_PIN L15     [get_ports {led[1]}]
set_property PACKAGE_PIN K14     [get_ports {led[2]}]
set_property PACKAGE_PIN J14     [get_ports {led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# ---- dbg_alive：GPIO0 扩展口 ----
set_property PACKAGE_PIN L14     [get_ports dbg_alive]
set_property IOSTANDARD LVCMOS33 [get_ports dbg_alive]

# ---- UART TX：GPIO0 扩展口，接 USB-TTL 模块的 RX ----
# 引脚来自 docs/13-vendor-reference.md（官方例程 ch05/ch06 的 uart 端口）
set_property PACKAGE_PIN K19     [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
