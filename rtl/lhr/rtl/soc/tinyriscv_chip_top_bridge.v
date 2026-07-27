`include "../core/defines.v"

// ASIC-side single-design top. The two 8-bit bridge ports are the project
// innovation interface that replaces on-chip ROM and RAM.
module tinyriscv_chip_top_bridge(
    input wire clk,
    input wire rst,
    output wire succ,
    output wire uart_tx_pin,
    input wire uart_rx_pin,
    output wire[3:0] pwm_o,
    output wire io_scl,
    inout wire io_sda,
    output wire[7:0] bridge_data_o,
    input wire[7:0] bridge_data_i
    );

    wire[`MemAddrBus] m0_addr_i;
    wire[`MemBus] m0_data_i;
    wire[`MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;
    wire[`MemAddrBus] m1_addr_i;
    wire[`MemBus] m1_data_o;

    wire ext_req_o;
    wire[`MemAddrBus] ext_addr_o;
    wire[`MemBus] ext_data_o;
    wire[`MemBus] ext_data_i;
    wire ext_ready_i;
    wire ext_we_o;
    wire ext_busy_i;
    wire ext_error_i;

    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemBus] s3_data_i;
    wire s3_we_o;
    wire[`MemAddrBus] s6_addr_o;
    wire[`MemBus] s6_data_o;
    wire[`MemBus] s6_data_i;
    wire s6_we_o;
    wire[`MemAddrBus] s7_addr_o;
    wire[`MemBus] s7_data_o;
    wire[`MemBus] s7_data_i;
    wire s7_we_o;
    wire[`Hold_Flag_Bus] rib_hold_flag_o;

    tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),
        .rib_hold_flag_i(rib_hold_flag_o),
        .succ_o(succ)
    );

    ext_mem_bridge u_ext_mem_bridge(
        .clk(clk),
        .rst(rst),
        .req_i(ext_req_o),
        .we_i(ext_we_o),
        .addr_i(ext_addr_o),
        .wdata_i(ext_data_o),
        .rdata_o(ext_data_i),
        .ready_o(ext_ready_i),
        .busy_o(ext_busy_i),
        .error_o(ext_error_i),
        .ext_data_o(bridge_data_o),
        .ext_data_i(bridge_data_i)
    );

    uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    pwm pwm_0(
        .clk(clk),
        .rst(rst),
        .we_i(s6_we_o),
        .addr_i(s6_addr_o),
        .data_i(s6_data_o),
        .data_o(s6_data_i),
        .pwm_o(pwm_o)
    );

    i2c i2c_0(
        .clk(clk),
        .rst(rst),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .io_scl(io_scl),
        .io_sda(io_sda)
    );

    rib_ext_bridge u_rib(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`RIB_REQ),
        .m1_we_i(`WriteDisable),
        .ext_req_o(ext_req_o),
        .ext_addr_o(ext_addr_o),
        .ext_data_o(ext_data_o),
        .ext_data_i(ext_data_i),
        .ext_ready_i(ext_ready_i),
        .ext_we_o(ext_we_o),
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),
        .hold_flag_o(rib_hold_flag_o)
    );

endmodule
