`include "ldk_defs.v"

/*
 * LDK core tile for the four-core integration.
 * The native acknowledged RIB and LDK bridge protocol are preserved.
 */
module ldk_core_tile(
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

    wire m0_req;
    wire m0_we;
    wire m0_ack;
    wire[31:0] m0_addr;
    wire[31:0] m0_wdata;
    wire[31:0] m0_rdata;

    wire m1_req;
    wire m1_ack;
    wire[31:0] m1_addr;
    wire[31:0] m1_rdata;

    wire debug_ack_unused;
    wire rib_hold_unused;

    wire s0_req;
    wire s0_we;
    wire s0_ack;
    wire[31:0] s0_addr;
    wire[31:0] s0_wdata;
    wire[31:0] s0_rdata;

    wire[31:0] uart_addr;
    wire[31:0] uart_wdata;
    wire[31:0] uart_rdata;
    wire uart_we;

    wire[31:0] pwm_addr;
    wire[31:0] pwm_wdata;
    wire pwm_we;

    wire i2c_req;
    wire[31:0] i2c_addr;
    wire[31:0] i2c_wdata;
    wire[31:0] i2c_rdata;
    wire i2c_we;
    wire i2c_ack;
    wire i2c_scl;
    wire i2c_sda_value;
    wire i2c_sda_oe;
    wire bridge_busy;
    wire[31:0] debug_rdata_internal;

    assign debug_rdata_o = debug_rdata_internal;
    assign debug_busy_o = bridge_busy;
    assign pwm_addr_o = pwm_addr;
    assign pwm_wdata_o = pwm_wdata;
    assign pwm_we_o = pwm_we;
    assign i2c_scl_drive_low_o = ~i2c_scl;
    assign i2c_sda_drive_low_o = i2c_sda_oe && (i2c_sda_value == 1'b0);

    ldk_tinyriscv u_core(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr),
        .rib_ex_data_i(m0_rdata),
        .rib_ex_data_o(m0_wdata),
        .rib_ex_req_o(m0_req),
        .rib_ex_we_o(m0_we),
        .rib_ex_ack_i(m0_ack),
        .rib_pc_req_o(m1_req),
        .rib_pc_ack_i(m1_ack),
        .rib_pc_addr_o(m1_addr),
        .rib_pc_data_i(m1_rdata),
        .rf_raddr1_o(rf_raddr1_o),
        .rf_raddr2_o(rf_raddr2_o),
        .rf_rdata1_i(rf_rdata1_i),
        .rf_rdata2_i(rf_rdata2_i),
        .rf_we_o(rf_we_o),
        .rf_waddr_o(rf_waddr_o),
        .rf_wdata_o(rf_wdata_o)
    );

    ldk_uart u_uart(
        .clk(clk),
        .rst(rst),
        .we_i(uart_we),
        .addr_i(uart_addr),
        .data_i(uart_wdata),
        .data_o(uart_rdata),
        .tx_pin(uart_tx_o),
        .rx_pin(uart_rx_i)
    );

    ldk_bridge_master u_bridge(
        .clk(clk),
        .rst(rst),
        .rib_req_i(s0_req),
        .rib_we_i(s0_we),
        .rib_addr_i(s0_addr),
        .rib_data_i(s0_wdata),
        .rib_data_o(s0_rdata),
        .bmaster_RX_data(bridge_data_i),
        .bmaster_TX_data(bridge_data_o),
        .rib_ack_o(s0_ack),
        .hold_flag_o(bridge_busy)
    );

    ldk_iic_dk u_i2c(
        .clk(clk),
        .rst(rst),
        .req_i({i2c_req, 1'b1}),
        .we_i(i2c_we),
        .addr_i(i2c_addr),
        .data_i(i2c_wdata),
        .data_o(i2c_rdata),
        .ack_o(i2c_ack),
        .SCL_o(i2c_scl),
        .SDA_o(i2c_sda_value),
        .SDA_oe_o(i2c_sda_oe),
        .SDA_i(i2c_sda_i)
    );

    ldk_rib u_rib(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(m0_addr),
        .m0_data_i(m0_wdata),
        .m0_data_o(m0_rdata),
        .m0_req_i(m0_req),
        .m0_we_i(m0_we),
        .m0_ack_o(m0_ack),
        .m1_addr_i(m1_addr),
        .m1_data_i(32'h0000_0000),
        .m1_data_o(m1_rdata),
        .m1_req_i(m1_req),
        .m1_we_i(1'b0),
        .m1_ack_o(m1_ack),
        .m2_addr_i(32'h0000_0000),
        .m2_data_i(32'h0000_0000),
        .m2_data_o(),
        .m2_req_i(1'b0),
        .m2_we_i(1'b0),
        .m3_addr_i(debug_addr_i),
        .m3_data_i(debug_wdata_i),
        .m3_data_o(debug_rdata_internal),
        .m3_req_i(debug_req_i),
        .m3_we_i(debug_we_i),
        .m3_ack_o(debug_ack_unused),
        .s0_addr_o(s0_addr),
        .s0_data_o(s0_wdata),
        .s0_data_i(s0_rdata),
        .s0_we_o(s0_we),
        .s0_req_o(s0_req),
        .s0_ack_i(s0_ack),
        .s1_addr_o(),
        .s1_data_o(),
        .s1_data_i(32'h0000_0000),
        .s1_we_o(),
        .s1_ack_i(1'b0),
        .s2_addr_o(),
        .s2_data_o(),
        .s2_data_i(32'h0000_0000),
        .s2_we_o(),
        .s3_addr_o(uart_addr),
        .s3_data_o(uart_wdata),
        .s3_data_i(uart_rdata),
        .s3_we_o(uart_we),
        .s4_addr_o(),
        .s4_data_o(),
        .s4_data_i(32'h0000_0000),
        .s4_we_o(),
        .s5_addr_o(),
        .s5_data_o(),
        .s5_data_i(32'h0000_0000),
        .s5_we_o(),
        .s6_addr_o(pwm_addr),
        .s6_data_o(pwm_wdata),
        .s6_data_i(pwm_rdata_i),
        .s6_we_o(pwm_we),
        .s7_req_o(i2c_req),
        .s7_addr_o(i2c_addr),
        .s7_data_o(i2c_wdata),
        .s7_data_i(i2c_rdata),
        .s7_we_o(i2c_we),
        .s7_ack_i(i2c_ack),
        .hold_flag_o(rib_hold_unused)
    );

endmodule
