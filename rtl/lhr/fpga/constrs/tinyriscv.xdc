# AX7035 course constraints
# Vivado device: xc7a35tfgg484-2

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports {clk}]

set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PACKAGE_PIN F20 [get_ports rst]

set_property IOSTANDARD LVCMOS33 [get_ports succ]
set_property PACKAGE_PIN F19 [get_ports succ]

set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
set_property PACKAGE_PIN G16 [get_ports uart_tx_pin]

set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN G15 [get_ports uart_rx_pin]

set_property IOSTANDARD LVCMOS33 [get_ports uart_debug_pin]
set_property PACKAGE_PIN M13 [get_ports uart_debug_pin]

set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[0]}]
set_property PACKAGE_PIN E21 [get_ports {pwm_o[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[1]}]
set_property PACKAGE_PIN D20 [get_ports {pwm_o[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {pwm_o[2]}]
set_property PACKAGE_PIN C20 [get_ports {pwm_o[2]}]

# The ASIC-side RTL implements the fourth channel as pwm_o[3]. The AX7035
# wrapper exposes only pwm_o[2:0] because the course constraint file assigns
# three physical board pins.

set_property IOSTANDARD LVCMOS33 [get_ports io_scl]
set_property PACKAGE_PIN M22 [get_ports io_scl]

set_property IOSTANDARD LVCMOS33 [get_ports io_sda]
set_property PACKAGE_PIN N22 [get_ports io_sda]
