/*
 * Single-FPGA validation top for the merged four-core design.
 * The chip and all four FPGA bridge endpoints are placed in one bitstream.
 */
module tinyriscv_merged_fpga_top(
    input wire clk,
    input wire rst,
    input wire[1:0] chip_sel,
    output wire succ,
    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,
    inout wire io_sda,
    output wire io_scl,
    output wire[3:0] pwm_o
    );

    wire[7:0] chip_to_fpga;
    wire[7:0] fpga_to_chip;
    wire memory_ready;

    tinyriscv_merged_chip_top u_chip(
        .clk(clk),
        .rst(rst && memory_ready),
        .chip_sel(chip_sel),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .io_sda(io_sda),
        .io_scl(io_scl),
        .pwm_o(pwm_o),
        .bridge_data_o(chip_to_fpga),
        .bridge_data_i(fpga_to_chip)
    );

    merged_fpga_bridge_bank u_bridge_bank(
        .clk(clk),
        .rst(rst),
        .chip_sel(chip_sel),
        .chip_data_i(chip_to_fpga),
        .chip_data_o(fpga_to_chip),
        .memory_ready_o(memory_ready)
    );

endmodule
