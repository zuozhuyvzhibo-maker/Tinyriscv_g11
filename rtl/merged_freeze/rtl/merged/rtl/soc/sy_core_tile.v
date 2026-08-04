`include "sy_defs.v"

/*
 * SY core tile for the four-core integration.
 * The SY bridge, UART, and I2C implementations remain private to this tile.
 */
module sy_core_tile(
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

    wire[31:0] m0_addr;
    wire[31:0] m0_wdata;
    wire[31:0] m0_rdata;
    wire m0_req;
    wire m0_we;
    wire[3:0] m0_byte_en;
    wire[31:0] m1_addr;
    wire[31:0] m1_rdata;
    wire[2:0] rib_hold;

    wire[31:0] s0_addr;
    wire[31:0] s0_wdata;
    wire[31:0] s0_rdata;
    wire s0_req;
    wire s0_we;
    wire[2:0] s0_hold;

    wire[31:0] s1_addr;
    wire[31:0] s1_wdata;
    wire[31:0] s1_rdata;
    wire s1_req;
    wire s1_we;
    wire[2:0] s1_hold;

    wire[31:0] uart_addr;
    wire[31:0] uart_wdata;
    wire[31:0] uart_rdata;
    wire uart_we;

    wire[31:0] pwm_addr;
    wire[31:0] pwm_wdata;
    wire pwm_we;

    wire[31:0] i2c_addr;
    wire[31:0] i2c_wdata;
    wire[31:0] i2c_rdata;
    wire i2c_we;
    wire i2c_req_unused;
    wire i2c_scl;
    wire temp_req;
    wire temp_accept;
    wire temp_busy;
    wire temp_done;
    wire temp_ack_error;
    wire[15:0] temp_raw;

    assign debug_busy_o = (|s0_hold) || (|s1_hold);
    assign pwm_addr_o = pwm_addr;
    assign pwm_wdata_o = pwm_wdata;
    assign pwm_we_o = pwm_we;
    assign i2c_scl_drive_low_o = ~i2c_scl;

    sy_tinyriscv u_core(
        .clk(clk),
        .rst(rst),
        .temp_req_o(temp_req),
        .temp_accept_o(temp_accept),
        .temp_busy_i(temp_busy),
        .temp_done_i(temp_done),
        .temp_ack_error_i(temp_ack_error),
        .temp_raw_i(temp_raw),
        .rib_ex_addr_o(m0_addr),
        .rib_ex_data_i(m0_rdata),
        .rib_ex_data_o(m0_wdata),
        .rib_ex_req_o(m0_req),
        .rib_ex_we_o(m0_we),
        .rib_ex_byte_en_o(m0_byte_en),
        .rib_pc_addr_o(m1_addr),
        .rib_pc_data_i(m1_rdata),
        .rib_hold_flag_i(rib_hold),
        .rf_raddr1_o(rf_raddr1_o),
        .rf_raddr2_o(rf_raddr2_o),
        .rf_rdata1_i(rf_rdata1_i),
        .rf_rdata2_i(rf_rdata2_i),
        .rf_we_o(rf_we_o),
        .rf_waddr_o(rf_waddr_o),
        .rf_wdata_o(rf_wdata_o)
    );

    sy_bridge u_bridge(
        .clk(clk),
        .rst(rst),
        .rom_req_i(s0_req),
        .rom_we_i(s0_we),
        .rom_addr_i(s0_addr),
        .rom_data_i(s0_wdata),
        .rom_data_o(s0_rdata),
        .rom_hold_o(s0_hold),
        .ram_req_i(s1_req),
        .ram_we_i(s1_we),
        .ram_byte_en_i(m0_byte_en),
        .ram_addr_i(s1_addr),
        .ram_data_i(s1_wdata),
        .ram_data_o(s1_rdata),
        .ram_hold_o(s1_hold),
        .bridge_data_i(bridge_data_i),
        .bridge_data_o(bridge_data_o)
    );

    sy_uart u_uart(
        .clk(clk),
        .rst(rst),
        .we_i(uart_we),
        .addr_i(uart_addr),
        .data_i(uart_wdata),
        .sid_req_i(1'b0),
        .ifire_req_i(1'b0),
        .ifire_data_i(8'h00),
        .data_o(uart_rdata),
        .tx_pin(uart_tx_o),
        .rx_pin(uart_rx_i)
    );

    sy_iic u_i2c(
        .clk(clk),
        .rst(rst),
        .we_i(i2c_we),
        .addr_i(i2c_addr),
        .data_i(i2c_wdata),
        .temp_req_i(temp_req),
        .temp_accept_i(temp_accept),
        .temp_busy_o(temp_busy),
        .temp_done_o(temp_done),
        .temp_ack_error_o(temp_ack_error),
        .temp_raw_o(temp_raw),
        .data_o(i2c_rdata),
        .i2c_scl_o(i2c_scl),
        .i2c_sda_drive_low_o(i2c_sda_drive_low_o),
        .i2c_sda_i(i2c_sda_i)
    );

    sy_rib u_rib(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(m0_addr),
        .m0_data_i(m0_wdata),
        .m0_data_o(m0_rdata),
        .m0_req_i(m0_req),
        .m0_we_i(m0_we),
        .m1_addr_i(m1_addr),
        .m1_data_i(32'h0000_0000),
        .m1_data_o(m1_rdata),
        .m1_req_i(1'b1),
        .m1_we_i(1'b0),
        .m2_addr_i(32'h0000_0000),
        .m2_data_i(32'h0000_0000),
        .m2_data_o(),
        .m2_req_i(1'b0),
        .m2_we_i(1'b0),
        .m3_addr_i(debug_addr_i),
        .m3_data_i(debug_wdata_i),
        .m3_data_o(debug_rdata_o),
        .m3_req_i(debug_req_i),
        .m3_we_i(debug_we_i),
        .s0_addr_o(s0_addr),
        .s0_data_o(s0_wdata),
        .s0_data_i(s0_rdata),
        .s0_we_o(s0_we),
        .s0_req_o(s0_req),
        .s0_hold_i(s0_hold),
        .s1_addr_o(s1_addr),
        .s1_data_o(s1_wdata),
        .s1_data_i(s1_rdata),
        .s1_we_o(s1_we),
        .s1_req_o(s1_req),
        .s1_hold_i(s1_hold),
        .s3_addr_o(uart_addr),
        .s3_data_o(uart_wdata),
        .s3_data_i(uart_rdata),
        .s3_we_o(uart_we),
        .s6_addr_o(pwm_addr),
        .s6_data_o(pwm_wdata),
        .s6_data_i(pwm_rdata_i),
        .s6_we_o(pwm_we),
        .s7_addr_o(i2c_addr),
        .s7_data_o(i2c_wdata),
        .s7_data_i(i2c_rdata),
        .s7_we_o(i2c_we),
        .s7_req_o(i2c_req_unused),
        .s7_hold_i(3'b000),
        .hold_flag_o(rib_hold)
    );

endmodule
