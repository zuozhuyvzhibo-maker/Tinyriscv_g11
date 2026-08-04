/*
 Copyright 2026

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

// Board-level top for single-FPGA bring-up.
// The chip-side SoC and FPGA-side ROM/RAM wje_bridge are placed in the same bitstream.
module wje_tinyriscv_board_top(

    input wire clk,
    input wire rst,

    output wire over,
    output wire succ,

    input wire uart_debug_pin,

    output wire uart_tx_pin,
    input wire uart_rx_pin,

    output wire[3:0] pwm_o,
    inout wire i2c_scl,
    inout wire i2c_sda

    );

    wire[7:0] chip_to_fpga_data;
    wire[7:0] fpga_to_chip_data;

    wje_tinyriscv_soc_top u_soc(
        .clk(clk),
        .rst(rst),
        .over(over),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .fpga_data_i(fpga_to_chip_data),
        .fpga_data_o(chip_to_fpga_data),
        .pwm_o(pwm_o),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    wje_bridge_fpga u_bridge_fpga(
        .clk(clk),
        .rst(rst),
        .chip_data_i(chip_to_fpga_data),
        .chip_data_o(fpga_to_chip_data)
    );

endmodule
