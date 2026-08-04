/*
 * AX7035 physical-key wrapper for one four-core bitstream.
 *
 * RESET: active-low board reset, synchronized to clk before use
 * KEY1:  uart_debug_pin, active low
 * KEY2:  select next core
 * KEY3:  select previous core
 * KEY4:  hold to display the four PWM outputs
 * LEDs:  selected core in one-hot form; all on when succ is active
 */
module tinyriscv_merged_fpga_key_top #(
    parameter integer DEBOUNCE_CYCLES = 500000,
    parameter integer COUNTER_WIDTH = 19
    )(
    input wire clk,
    input wire rst,
    input wire uart_debug_pin,
    input wire key_next_n,
    input wire key_prev_n,
    input wire key_pwm_view_n,
    output wire uart_tx_pin,
    input wire uart_rx_pin,
    inout wire io_sda,
    output wire io_scl,
    output wire[3:0] led_o
    );

    wire system_rst;
    wire[1:0] chip_sel;
    wire pwm_view;
    wire succ;
    wire[3:0] pwm;

    merged_reset_sync u_reset_sync(
        .clk(clk),
        .rst_n_async(rst),
        .rst_n_sync(system_rst)
    );

    merged_board_control #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_board_control(
        .clk(clk),
        .rst(system_rst),
        .key_next_n(key_next_n),
        .key_prev_n(key_prev_n),
        .key_pwm_view_n(key_pwm_view_n),
        .chip_sel(chip_sel),
        .pwm_view(pwm_view)
    );

    tinyriscv_merged_fpga_top u_merged(
        .clk(clk),
        .rst(system_rst),
        .chip_sel(chip_sel),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .io_sda(io_sda),
        .io_scl(io_scl),
        .pwm_o(pwm)
    );

    merged_status_leds u_status_leds(
        .chip_sel(chip_sel),
        .succ(succ),
        .pwm_view(pwm_view),
        .pwm(pwm),
        .led_n(led_o)
    );

endmodule
