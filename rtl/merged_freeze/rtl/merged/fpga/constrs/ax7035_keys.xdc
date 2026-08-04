# AX7035 constraints for the physical-key four-core wrapper.
# Device: xc7a35tfgg484-2. Keys and user LEDs are active low.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -add -name sys_clk_pin -period 20.000 -waveform {0.000 10.000} [get_ports clk]

# Dedicated reset button.
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports rst]

# KEY1 keeps the established UART downloader function.
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_debug_pin]

# KEY2 selects the next core, KEY3 selects the previous core, and KEY4
# temporarily changes the LED display to the four PWM channels.
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33 PULLUP true} [get_ports key_next_n]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports key_prev_n]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports key_pwm_view_n]

set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports uart_tx_pin]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports uart_rx_pin]

set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports io_scl]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports io_sda]

set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {led_o[0]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {led_o[1]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {led_o[2]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {led_o[3]}]

# Board keys are asynchronous to the 50 MHz clock and are synchronized in RTL.
set_false_path -from [get_ports {rst key_next_n key_prev_n key_pwm_view_n}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
