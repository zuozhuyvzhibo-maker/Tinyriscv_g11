// FPGA verification top. The chip-to-memory bridge is contained inside this
// wrapper, so the board interface contains only the agreed course signals.
module tinyriscv_soc_top_bridge_fpga(
    input wire clk,
    input wire rst,
    output wire succ,
    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,
    output wire[2:0] pwm_o,
    output wire io_scl,
    inout wire io_sda
    );

    wire[3:0] pwm_all;
    wire[7:0] chip_to_fpga;
    wire[7:0] fpga_to_chip;
    wire chip_uart_tx;
    wire chip_uart_rx;
    wire debug_uart_tx;
    wire debug_en = uart_debug_pin;
    wire chip_rst = rst & ~debug_en;
    wire dbg_rom_we;
    wire[31:0] dbg_rom_addr;
    wire[31:0] dbg_rom_wdata;

    // The course AX7035 file defines three physical PWM pins. The ASIC-side
    // design still retains all four required PWM channels.
    assign pwm_o = pwm_all[2:0];
    assign uart_tx_pin = debug_en ? debug_uart_tx : chip_uart_tx;
    assign chip_uart_rx = debug_en ? 1'b1 : uart_rx_pin;

    tinyriscv_chip_top_bridge u_chip(
        .clk(clk),
        .rst(chip_rst),
        .succ(succ),
        .uart_tx_pin(chip_uart_tx),
        .uart_rx_pin(chip_uart_rx),
        .pwm_o(pwm_all),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .bridge_data_o(chip_to_fpga),
        .bridge_data_i(fpga_to_chip)
    );

    fpga_uart_debug u_fpga_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(debug_en),
        .uart_tx_pin(debug_uart_tx),
        .uart_rx_pin(uart_rx_pin),
        .rom_we_o(dbg_rom_we),
        .rom_addr_o(dbg_rom_addr),
        .rom_wdata_o(dbg_rom_wdata)
    );

    bridge_fpga u_bridge_fpga(
        .clk(clk),
        .rst(rst),
        .chip_data_i(chip_to_fpga),
        .chip_data_o(fpga_to_chip),
        .dbg_we_i(dbg_rom_we),
        .dbg_addr_i(dbg_rom_addr),
        .dbg_wdata_i(dbg_rom_wdata)
    );

endmodule
