`include "wje_defs.v"

/*
 * WJE core tile for the four-core integration.
 * The custom bridge, extension handshakes, UART, and I2C remain private.
 */
module wje_core_tile(
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
    input wire i2c_scl_i,
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
    wire rib_hold;

    wire[31:0] s0_addr;
    wire[31:0] s0_wdata;
    wire[31:0] s0_rdata;
    wire s0_req;
    wire s0_we;
    wire[31:0] s1_addr;
    wire[31:0] s1_wdata;
    wire[31:0] s1_rdata;
    wire s1_req;
    wire s1_we;

    wire[31:0] i2c_addr;
    wire[31:0] i2c_wdata;
    wire[31:0] i2c_rdata;
    wire i2c_req;
    wire i2c_we;

    wire[31:0] uart_addr;
    wire[31:0] uart_wdata;
    wire[31:0] uart_rdata;
    wire uart_we;

    wire[31:0] pwm_addr;
    wire[31:0] pwm_wdata;
    wire pwm_we;

    wire bridge_busy;
    wire rom_resp_valid;
    wire[31:0] rom_resp_addr;
    wire ifetch_resp_stale;
    wire core_mem_busy;

    wire sid_start;
    wire sid_busy;
    wire if_uart_start;
    wire if_uart_accept;
    wire[7:0] if_uart_data;
    wire if_uart_busy;
    wire if_uart_done;
    wire temp_start;
    wire temp_hold_unused;
    wire temp_accept;
    wire temp_busy;
    wire temp_done;
    wire temp_ack_error;
    wire[15:0] temp_raw;

    assign ifetch_resp_stale = rom_resp_valid && (rom_resp_addr != m1_addr);
    assign core_mem_busy = bridge_busy || ifetch_resp_stale;
    assign debug_busy_o = bridge_busy;
    assign pwm_addr_o = pwm_addr;
    assign pwm_wdata_o = pwm_wdata;
    assign pwm_we_o = pwm_we;

    wje_tinyriscv u_core(
        .clk(clk),
        .rst(rst),
        .sid_start_o(sid_start),
        .sid_busy_i(sid_busy),
        .if_uart_start_o(if_uart_start),
        .if_uart_accept_o(if_uart_accept),
        .if_uart_data_o(if_uart_data),
        .if_uart_busy_i(if_uart_busy),
        .if_uart_done_i(if_uart_done),
        .temp_start_o(temp_start),
        .temp_hold_o(temp_hold_unused),
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
        .rib_mem_busy_i(core_mem_busy),
        .rf_raddr1_o(rf_raddr1_o),
        .rf_raddr2_o(rf_raddr2_o),
        .rf_rdata1_i(rf_rdata1_i),
        .rf_rdata2_i(rf_rdata2_i),
        .rf_we_o(rf_we_o),
        .rf_waddr_o(rf_waddr_o),
        .rf_wdata_o(rf_wdata_o)
    );

    wje_bridge u_bridge(
        .clk(clk),
        .rst(rst),
        .rom_req_i(s0_req),
        .rom_we_i(s0_we),
        .rom_addr_i(s0_addr),
        .rom_data_i(s0_wdata),
        .rom_data_o(s0_rdata),
        .rom_resp_valid_o(rom_resp_valid),
        .rom_resp_addr_o(rom_resp_addr),
        .ram_req_i(s1_req),
        .ram_we_i(s1_we),
        .ram_byte_en_i(m0_byte_en),
        .ram_addr_i(s1_addr),
        .ram_data_i(s1_wdata),
        .ram_data_o(s1_rdata),
        .fpga_data_i(bridge_data_i),
        .fpga_data_o(bridge_data_o),
        .busy_o(bridge_busy)
    );

    wje_i2c u_i2c(
        .clk(clk),
        .rst(rst),
        .data_i(i2c_wdata),
        .addr_i(i2c_addr),
        .we_i(i2c_we),
        .req_i(i2c_req),
        .data_o(i2c_rdata),
        .temp_start_i(temp_start),
        .temp_accept_i(temp_accept),
        .temp_busy_o(temp_busy),
        .temp_done_o(temp_done),
        .temp_ack_error_o(temp_ack_error),
        .temp_raw_o(temp_raw),
        .i2c_scl_drive_low_o(i2c_scl_drive_low_o),
        .i2c_scl_i(i2c_scl_i),
        .i2c_sda_drive_low_o(i2c_sda_drive_low_o),
        .i2c_sda_i(i2c_sda_i)
    );

    wje_uart u_uart(
        .clk(clk),
        .rst(rst),
        .we_i(uart_we),
        .addr_i(uart_addr),
        .data_i(uart_wdata),
        .sid_start_i(sid_start),
        .if_uart_start_i(if_uart_start),
        .if_uart_accept_i(if_uart_accept),
        .if_uart_data_i(if_uart_data),
        .data_o(uart_rdata),
        .sid_busy_o(sid_busy),
        .if_uart_busy_o(if_uart_busy),
        .if_uart_done_o(if_uart_done),
        .tx_pin(uart_tx_o),
        .rx_pin(uart_rx_i)
    );

    wje_rib u_rib(
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
        .s1_addr_o(s1_addr),
        .s1_data_o(s1_wdata),
        .s1_data_i(s1_rdata),
        .s1_we_o(s1_we),
        .s1_req_o(s1_req),
        .s2_addr_o(i2c_addr),
        .s2_data_o(i2c_wdata),
        .s2_data_i(i2c_rdata),
        .s2_we_o(i2c_we),
        .s2_req_o(i2c_req),
        .s3_addr_o(uart_addr),
        .s3_data_o(uart_wdata),
        .s3_data_i(uart_rdata),
        .s3_we_o(uart_we),
        .s3_req_o(),
        .s4_addr_o(),
        .s4_data_o(),
        .s4_data_i(32'h0000_0000),
        .s4_we_o(),
        .s4_req_o(),
        .s5_addr_o(pwm_addr),
        .s5_data_o(pwm_wdata),
        .s5_data_i(pwm_rdata_i),
        .s5_we_o(pwm_we),
        .s5_req_o(),
        .hold_flag_o(rib_hold)
    );

endmodule
