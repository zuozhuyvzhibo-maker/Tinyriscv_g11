`include "../core/defines.v"

// tinyriscv FPGA顶层模块
module tinyriscv_soc_top_FPGA(

    input wire clk,
    input wire rst,

    output wire succ,         // 测试是否成功信号


    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚
    output wire[2:0] PWM_o,
    output wire io_scl,
    inout wire io_sda

    );
wire over;
wire[3:0] PWM_o_inter;
wire[7:0] fpga_bridge_data;
wire[7:0] chip_bridge_data;

assign PWM_o=PWM_o_inter[2:0];

    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst(rst),
        .over(over),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .pwm(PWM_o_inter),
        .i2c_scl(io_scl),
        .i2c_sda(io_sda),
        .bridge_data_i(fpga_bridge_data),
        .bridge_data_o(chip_bridge_data)
    );

    bridge_fpga bridge_fpga_0(
        .clk(clk),
        .rst(rst),
        .bridge_data_i(chip_bridge_data),
        .bridge_data_o(fpga_bridge_data)
    );





endmodule
