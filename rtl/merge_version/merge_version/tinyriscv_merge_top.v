module tinyriscv_merge_top(
    input wire clk,
    input wire rst,
    input wire[2:0] chip_sel,

    output wire over,
    output wire succ,

    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,

    output wire[3:0] pwm_o,
    inout wire io_scl,
    inout wire io_sda
);

    wire sel_lhr = (chip_sel == 3'd0);
    wire sel_ldk = (chip_sel == 3'd1);
    wire sel_wje = (chip_sel == 3'd2);
    wire sel_sy  = (chip_sel == 3'd3);

    wire lhr_succ;
    wire lhr_uart_tx;
    wire[3:0] lhr_pwm;
    wire lhr_scl;
    tri1 lhr_sda;

    wire ldk_succ;
    wire ldk_uart_tx;
    wire[3:0] ldk_pwm;
    wire ldk_scl;
    tri1 ldk_sda;

    wire wje_over;
    wire wje_succ;
    wire wje_uart_tx;
    wire[3:0] wje_pwm;
    tri1 wje_scl;
    tri1 wje_sda;

    wire sy_over;
    wire sy_succ;
    wire sy_uart_tx;
    wire[3:0] sy_pwm;
    wire sy_scl;
    tri1 sy_sda;

    lhr_tinyriscv_soc_top_bridge_fpga u_lhr_top(
        .clk(clk),
        .rst(rst | ~sel_lhr),
        .succ(lhr_succ),
        .uart_debug_pin(uart_debug_pin & sel_lhr),
        .uart_tx_pin(lhr_uart_tx),
        .uart_rx_pin(uart_rx_pin),
        .pwm_o(lhr_pwm),
        .io_scl(lhr_scl),
        .io_sda(lhr_sda)
    );

    ldk_tinyriscv_soc_top_with_bridge u_ldk_top(
        .clk(clk),
        .rst(rst | ~sel_ldk),
        .succ(ldk_succ),
        .uart_debug_pin(uart_debug_pin & sel_ldk),
        .uart_tx_pin(ldk_uart_tx),
        .uart_rx_pin(uart_rx_pin),
        .io_sda(ldk_sda),
        .io_scl(ldk_scl),
        .pwm_o(ldk_pwm)
    );

    wje_tinyriscv_board_top u_wje_top(
        .clk(clk),
        .rst(rst | ~sel_wje),
        .over(wje_over),
        .succ(wje_succ),
        .uart_debug_pin(uart_debug_pin & sel_wje),
        .uart_tx_pin(wje_uart_tx),
        .uart_rx_pin(uart_rx_pin),
        .pwm_o(wje_pwm),
        .i2c_scl(wje_scl),
        .i2c_sda(wje_sda)
    );






    sy_tinyriscv_soc_top_FPGA u_sy_top(
        .clk(clk),
        .rst(rst | ~sel_sy),
        .succ(sy_succ),
        .uart_debug_pin(uart_debug_pin & sel_sy),
        .uart_tx_pin(sy_uart_tx),
        .uart_rx_pin(uart_rx_pin),
        .PWM_o(sy_pwm),
        .io_scl(sy_scl),
        .io_sda(sy_sda)
    );

    assign sy_over = u_sy_top.over;

    assign io_scl = sel_lhr ? lhr_scl :
                    sel_ldk ? ldk_scl :
                    sel_sy  ? sy_scl  :
                    1'bz;

    tranif1 u_lhr_sda_sw(io_sda, lhr_sda, sel_lhr);
    tranif1 u_ldk_sda_sw(io_sda, ldk_sda, sel_ldk);
    tranif1 u_wje_sda_sw(io_sda, wje_sda, sel_wje);
    tranif1 u_wje_scl_sw(io_scl, wje_scl, sel_wje);
    tranif1 u_sy_sda_sw(io_sda, sy_sda, sel_sy);

    assign uart_tx_pin = sel_lhr ? lhr_uart_tx :
                         sel_ldk ? ldk_uart_tx :
                         sel_wje ? wje_uart_tx :
                         sel_sy  ? sy_uart_tx  :
                         1'b1;

    assign pwm_o = sel_lhr ? lhr_pwm :
                   sel_ldk ? ldk_pwm :
                   sel_wje ? wje_pwm :
                   sel_sy  ? sy_pwm  :
                   4'b0000;

    assign succ = sel_lhr ? lhr_succ :
                  sel_ldk ? ldk_succ :
                  sel_wje ? wje_succ :
                  sel_sy  ? sy_succ  :
                  1'b1;

    assign over = sel_wje ? wje_over :
                  sel_sy  ? sy_over  :
                  1'b1;

endmodule

module tinyriscv_soc_top_with_bridge #(
    parameter[2:0] CHIP_SEL = 3'd1
)(
    input wire clk,
    input wire rst,
    output wire succ,
    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,
    inout wire io_sda,
    output wire io_scl,
    output wire[2:0] pwm_o
);

    wire[3:0] pwm_all;
    wire over_unused;

    tinyriscv_merge_top u_merge_top(
        .clk(clk),
        .rst(rst),
        .chip_sel(CHIP_SEL),
        .over(over_unused),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .pwm_o(pwm_all),
        .io_scl(io_scl),
        .io_sda(io_sda)
    );

    assign pwm_o = pwm_all[2:0];

endmodule
