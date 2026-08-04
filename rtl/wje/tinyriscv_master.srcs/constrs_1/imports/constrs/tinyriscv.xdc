# 时钟约束50MHz
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} -add [get_ports clk]

# Configuration bank 0 voltage. AX7035 schematic ties CFGBVS_0 to VCCO_0/+3.3V.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# 时钟引脚

# 复位引脚
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PACKAGE_PIN F20 [get_ports rst]

# 程序执�?�成功指示引�?
set_property IOSTANDARD LVCMOS33 [get_ports succ]
set_property PACKAGE_PIN F19 [get_ports succ]

# 串口发送引�?
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
set_property PACKAGE_PIN G16 [get_ports uart_tx_pin]

# 串口接收引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN G15 [get_ports uart_rx_pin]
set_property PULLUP true [get_ports uart_rx_pin]

# PWM 引脚
set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[0]}]
set_property PACKAGE_PIN E21 [get_ports {pwm_o[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[1]}]
set_property PACKAGE_PIN D20 [get_ports {pwm_o[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[2]}]
set_property PACKAGE_PIN C20 [get_ports {pwm_o[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[3]}]
set_property PACKAGE_PIN P16 [get_ports {pwm_o[3]}]

# I2C 引脚
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]
set_property PACKAGE_PIN M22 [get_ports i2c_scl]
set_property PULLUP true [get_ports i2c_scl]

set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]
set_property PACKAGE_PIN N22 [get_ports i2c_sda]
set_property PULLUP true [get_ports i2c_sda]
# Debug 引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_debug_pin]
set_property PACKAGE_PIN M13 [get_ports uart_debug_pin]

# Status pins
set_property IOSTANDARD LVCMOS33 [get_ports over]
set_property PACKAGE_PIN F18 [get_ports over]




