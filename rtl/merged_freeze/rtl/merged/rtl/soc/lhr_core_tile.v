`include "lhr_defs.v"

/*
 * LHR core tile for the four-core integration.
 * The tile keeps the LHR CPU, UART, I2C, and bridge protocol private.
 * Register-file, PWM, and UART-download resources are connected externally.
 */
module lhr_core_tile(
    input wire clk,
    input wire rst,

    input wire debug_req_i,
    input wire debug_we_i,
    input wire[31:0] debug_addr_i,
    input wire[31:0] debug_wdata_i,
    output wire[31:0] debug_rdata_o,
    output wire debug_busy_o,

    output wire[4:0] rf_raddr1_o,
    output wire[4:0] rf_raddr2_o,
    input wire[31:0] rf_rdata1_i,
    input wire[31:0] rf_rdata2_i,
    output wire rf_we_o,
    output wire[4:0] rf_waddr_o,
    output wire[31:0] rf_wdata_o,

    output wire pwm_we_o,
    output wire[31:0] pwm_addr_o,
    output wire[31:0] pwm_wdata_o,
    input wire[31:0] pwm_rdata_i,

    output wire uart_tx_o,
    input wire uart_rx_i,
    output wire i2c_scl_drive_low_o,
    output wire i2c_sda_drive_low_o,
    input wire i2c_sda_i,

    output wire[7:0] bridge_data_o,
    input wire[7:0] bridge_data_i
    );

    wire[31:0] core_m0_addr;
    wire[31:0] core_m0_wdata;
    wire[31:0] rib_m0_rdata;
    wire core_m0_req;
    wire core_m0_we;
    wire[3:0] core_m0_byte_en;
    wire[31:0] core_m1_addr;
    wire[31:0] core_m1_rdata;
    wire[2:0] rib_hold;
    wire[2:0] core_hold;

    wire[31:0] rib_m0_addr;
    wire[31:0] rib_m0_wdata;
    wire rib_m0_req;
    wire rib_m0_we;
    wire[3:0] rib_m0_byte_en;

    wire ext_req;
    wire[31:0] ext_addr;
    wire[31:0] ext_wdata;
    wire[31:0] ext_rdata;
    wire ext_ready;
    wire ext_we;
    wire[3:0] ext_byte_en;
    wire ext_busy;
    wire ext_error_unused;

    wire[31:0] uart_addr;
    wire[31:0] uart_wdata;
    wire[31:0] uart_rdata;
    wire uart_we;
    wire[31:0] i2c_addr;
    wire[31:0] i2c_wdata;
    wire[31:0] i2c_rdata;
    wire i2c_we;
    wire i2c_scl;
    wire i2c_data_valid;
    wire[31:0] pwm_addr_internal;
    wire[31:0] pwm_wdata_internal;
    wire pwm_we_internal;

    // LHR has no native debug master port, so debug temporarily owns m0.
    assign rib_m0_addr = debug_req_i ? debug_addr_i : core_m0_addr;
    assign rib_m0_wdata = debug_req_i ? debug_wdata_i : core_m0_wdata;
    assign rib_m0_req = debug_req_i ? 1'b1 : core_m0_req;
    assign rib_m0_we = debug_req_i ? debug_we_i : core_m0_we;
    assign rib_m0_byte_en = debug_req_i ? 4'hf : core_m0_byte_en;
    assign debug_rdata_o = rib_m0_rdata;
    assign debug_busy_o = debug_req_i && ext_busy &&
                          ((debug_addr_i[31:28] == 4'h0) ||
                           (debug_addr_i[31:28] == 4'h1));
    wire i2c_read_req = core_m0_req && !core_m0_we &&
                        (core_m0_addr == `LHR_I2C_INPUT_REG);
    assign core_hold = debug_req_i ? `LHR_Hold_Id :
                       (i2c_read_req ?
                        (i2c_data_valid ? `LHR_Hold_Id :
                                          `LHR_Hold_Id_Keep) : rib_hold);

    assign pwm_addr_o = pwm_addr_internal;
    assign pwm_wdata_o = pwm_wdata_internal;
    assign pwm_we_o = pwm_we_internal;
    assign i2c_scl_drive_low_o = ~i2c_scl;

    lhr_tinyriscv u_core(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(core_m0_addr),
        .rib_ex_data_i(rib_m0_rdata),
        .rib_ex_data_o(core_m0_wdata),
        .rib_ex_req_o(core_m0_req),
        .rib_ex_we_o(core_m0_we),
        .rib_ex_byte_en_o(core_m0_byte_en),
        .rib_pc_addr_o(core_m1_addr),
        .rib_pc_data_i(core_m1_rdata),
        .rib_hold_flag_i(core_hold),
        .rf_raddr1_o(rf_raddr1_o),
        .rf_raddr2_o(rf_raddr2_o),
        .rf_rdata1_i(rf_rdata1_i),
        .rf_rdata2_i(rf_rdata2_i),
        .rf_we_o(rf_we_o),
        .rf_waddr_o(rf_waddr_o),
        .rf_wdata_o(rf_wdata_o)
    );

    lhr_ext_mem_bridge u_bridge(
        .clk(clk),
        .rst(rst),
        .req_i(ext_req),
        .we_i(ext_we),
        .addr_i(ext_addr),
        .wdata_i(ext_wdata),
        .byteen_i(ext_byte_en),
        .rdata_o(ext_rdata),
        .ready_o(ext_ready),
        .busy_o(ext_busy),
        .error_o(ext_error_unused),
        .ext_data_o(bridge_data_o),
        .ext_data_i(bridge_data_i)
    );

    lhr_uart u_uart(
        .clk(clk),
        .rst(rst),
        .we_i(uart_we),
        .addr_i(uart_addr),
        .data_i(uart_wdata),
        .data_o(uart_rdata),
        .tx_pin(uart_tx_o),
        .rx_pin(uart_rx_i)
    );

    lhr_i2c u_i2c(
        .clk(clk),
        .rst(rst),
        .we_i(i2c_we),
        .addr_i(i2c_addr),
        .data_i(i2c_wdata),
        .data_o(i2c_rdata),
        .data_valid_o(i2c_data_valid),
        .i2c_scl_o(i2c_scl),
        .i2c_sda_drive_low_o(i2c_sda_drive_low_o),
        .i2c_sda_i(i2c_sda_i)
    );

    lhr_rib_ext_bridge u_rib(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(rib_m0_addr),
        .m0_data_i(rib_m0_wdata),
        .m0_data_o(rib_m0_rdata),
        .m0_req_i(rib_m0_req),
        .m0_we_i(rib_m0_we),
        .m0_byte_en_i(rib_m0_byte_en),
        .m1_addr_i(core_m1_addr),
        .m1_data_i(32'h0000_0000),
        .m1_data_o(core_m1_rdata),
        .m1_req_i(1'b1),
        .m1_we_i(1'b0),
        .ext_req_o(ext_req),
        .ext_addr_o(ext_addr),
        .ext_data_o(ext_wdata),
        .ext_data_i(ext_rdata),
        .ext_ready_i(ext_ready),
        .ext_we_o(ext_we),
        .ext_byte_en_o(ext_byte_en),
        .s3_addr_o(uart_addr),
        .s3_data_o(uart_wdata),
        .s3_data_i(uart_rdata),
        .s3_we_o(uart_we),
        .s6_addr_o(pwm_addr_internal),
        .s6_data_o(pwm_wdata_internal),
        .s6_data_i(pwm_rdata_i),
        .s6_we_o(pwm_we_internal),
        .s7_addr_o(i2c_addr),
        .s7_data_o(i2c_wdata),
        .s7_data_i(i2c_rdata),
        .s7_we_o(i2c_we),
        .hold_flag_o(rib_hold)
    );

endmodule
