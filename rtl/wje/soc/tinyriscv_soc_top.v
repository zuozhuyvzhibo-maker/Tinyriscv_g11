 /*
 Copyright 2020 Blue Liang, liangkangnan@163.com

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

`include "../core/defines.v"

// tinyriscv soc顶层模块
module tinyriscv_soc_top(

    input wire clk,
    input wire rst,

    output reg over,         // 测试是否完成信号
    output reg succ,         // 测试是否成功信号

    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚
    //inout wire[1:0] gpio,    // GPIO引脚

    // input wire spi_miso,     // SPI MISO引脚
    // output wire spi_mosi,    // SPI MOSI引脚
    // output wire spi_ss,      // SPI SS引脚
    // output wire spi_clk      // SPI CLK引脚

    // 新增：8位外部接口（连到FPGA）
    input wire[7:0] fpga_data_i,
    output wire[7:0] fpga_data_o,

    output wire[3:0] pwm_o,   // PWM输出端口
    inout wire i2c_scl,       // I2C SCL引脚
    inout wire i2c_sda        // I2C SDA引脚

    );


    // master 0 interface
    wire[`MemAddrBus] m0_addr_i;
    wire[`MemBus] m0_data_i;
    wire[`MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;

    // master 1 interface
    wire[`MemAddrBus] m1_addr_i;
    wire[`MemBus] m1_data_i;
    wire[`MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;

    // master 3 interface
    wire[`MemAddrBus] m3_addr_i;
    wire[`MemBus] m3_data_i;
    wire[`MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;

    // slave 0 interface
    wire[`MemAddrBus] s0_addr_o;
    wire[`MemBus] s0_data_o;
    wire[`MemBus] s0_data_i;
    wire s0_we_o;
    wire s0_req_o;  //新增

    // slave 1 interface
    wire[`MemAddrBus] s1_addr_o;
    wire[`MemBus] s1_data_o;
    wire[`MemBus] s1_data_i;
    wire s1_we_o;
    wire s1_req_o;  //新增

    // slave 2 interface
    wire[`MemAddrBus] s2_addr_o;
    wire[`MemBus] s2_data_o;
    wire[`MemBus] s2_data_i;
    wire s2_we_o;
    wire s2_req_o;  //新增

    // slave 3 interface
    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemBus] s3_data_i;
    wire s3_we_o;
    wire s3_req_o;  //新增

    // slave 4 interface
    wire[`MemAddrBus] s4_addr_o;
    wire[`MemBus] s4_data_o;
    wire[`MemBus] s4_data_i;
    wire s4_we_o;
    wire s4_req_o;  //新增

    // slave 5 interface
    wire[`MemAddrBus] s5_addr_o;
    wire[`MemBus] s5_data_o;
    wire[`MemBus] s5_data_i;
    wire s5_we_o;
    wire s5_req_o;  //新增


    // rib
    wire rib_hold_flag_o;
    wire bridge_busy;
    wire rom_resp_valid;
    wire[`MemAddrBus] rom_resp_addr;
    wire ifetch_resp_stale;
    wire cpu_mem_busy;

    // tinyriscv
    wire sid_start;
    wire sid_busy;
    wire if_uart_start;
    wire[7:0] if_uart_data;
    wire if_uart_busy;
    wire temp_start;
    wire temp_hold;
    wire temp_busy;
    wire temp_done;
    wire temp_ack_error;
    wire[15:0] temp_raw;

    // timer0
    //wire timer0_int;

    // gpio
//    wire[1:0] io_in;
//    wire[31:0] gpio_ctrl;
//    wire[31:0] gpio_data;

//    assign s2_data_i = `ZeroWord;
    assign s4_data_i = `ZeroWord;
    assign ifetch_resp_stale = rom_resp_valid && (rom_resp_addr != m1_addr_i);
    assign cpu_mem_busy = bridge_busy | ifetch_resp_stale;


    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~u_tinyriscv.u_regs.regs[26];  // when = 1, run over
            succ <= ~u_tinyriscv.u_regs.regs[27];  // when = 1, run succ, otherwise fail
        end
    end

    // tinyriscv处理器核模块例化
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
        .rib_mem_busy_i(cpu_mem_busy),

        .sid_start_o(sid_start),
        .sid_busy_i(sid_busy),
        .if_uart_start_o(if_uart_start),
        .if_uart_data_o(if_uart_data),
        .if_uart_busy_i(if_uart_busy),
        .temp_start_o(temp_start),
        .temp_hold_o(temp_hold),
        .temp_busy_i(temp_busy),
        .temp_done_i(temp_done),
        .temp_ack_error_i(temp_ack_error),
        .temp_raw_i(temp_raw)
    );

//    // rom模块例化
//    rom u_rom(
//        .clk(clk),
//        .rst(rst),
//        .we_i(s0_we_o),
//        .addr_i(s0_addr_o),
//        .data_i(s0_data_o),
//        .data_o(s0_data_i)
//    );
//
//    // ram模块例化
//    ram u_ram(
//        .clk(clk),
//        .rst(rst),
//        .we_i(s1_we_o),
//        .addr_i(s1_addr_o),
//        .data_i(s1_data_o),
//        .data_o(s1_data_i)
//    );

    // bridge模块例化
    bridge u_bridge(
        .clk(clk),
        .rst(rst),

        .rom_req_i(s0_req_o),
        .rom_we_i(s0_we_o),
        .rom_addr_i(s0_addr_o),
        .rom_data_i(s0_data_o),
        .rom_data_o(s0_data_i),
        .rom_resp_valid_o(rom_resp_valid),
        .rom_resp_addr_o(rom_resp_addr),

        .ram_req_i(s1_req_o),
        .ram_we_i(s1_we_o),
        .ram_addr_i(s1_addr_o),
        .ram_data_i(s1_data_o),
        .ram_data_o(s1_data_i),

        .fpga_data_i(fpga_data_i),
        .fpga_data_o(fpga_data_o),

        .busy_o(bridge_busy)
    );

//    // timer模块例化
//    timer timer_0(
//        .clk(clk),
//        .rst(rst),
//        .data_i(s2_data_o),
//        .addr_i(s2_addr_o),
//        .we_i(s2_we_o),
//        .data_o(s2_data_i),
//        .int_sig_o(timer0_int)
//    );

    // i2c模块例化
    i2c i2c_0(
        .clk(clk),
        .rst(rst),
        .data_i(s2_data_o),
        .addr_i(s2_addr_o),
        .we_i(s2_we_o),
        .req_i(s2_req_o),
        .data_o(s2_data_i),
        .temp_start_i(temp_start),
        .temp_busy_o(temp_busy),
        .temp_done_o(temp_done),
        .temp_ack_error_o(temp_ack_error),
        .temp_raw_o(temp_raw),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // uart模块例化
    uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .sid_start_i(sid_start),
        .if_uart_start_i(if_uart_start),
        .if_uart_data_i(if_uart_data),
        .data_o(s3_data_i),
        .sid_busy_o(sid_busy),
        .if_uart_busy_o(if_uart_busy),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

//    // io0
//    assign gpio[0] = (gpio_ctrl[1:0] == 2'b01)? gpio_data[0]: 1'bz;
//    assign io_in[0] = gpio[0];
//    // io1
//    assign gpio[1] = (gpio_ctrl[3:2] == 2'b01)? gpio_data[1]: 1'bz;
//    assign io_in[1] = gpio[1];
//
//    // gpio模块例化
//    gpio gpio_0(
//        .clk(clk),
//        .rst(rst),
//        .we_i(s4_we_o),
//        .addr_i(s4_addr_o),
//        .data_i(s4_data_o),
//        .data_o(s4_data_i),
//        .io_pin_i(io_in),
//        .reg_ctrl(gpio_ctrl),
//        .reg_data(gpio_data)
//    );

    // PWM模块例化：RIB slave6 复用物理 s5 接口
    pwm pwm_0(
        .clk(clk),
        .rst(rst),
        .data_i(s5_data_o),
        .addr_i(s5_addr_o),
        .we_i(s5_we_o),
        .data_o(s5_data_i),
        .pwm_o(pwm_o)
    );

//    // spi模块例化
//    spi spi_0(
//        .clk(clk),
//        .rst(rst),
//        .data_i(s5_data_o),
//        .addr_i(s5_addr_o),
//        .we_i(s5_we_o),
//        .data_o(s5_data_i),
//        .spi_mosi(spi_mosi),
//        .spi_miso(spi_miso),
//        .spi_ss(spi_ss),
//        .spi_clk(spi_clk)
//    );

    // rib模块例化
    rib u_rib(
        .clk(clk),
        .rst(rst),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`RIB_REQ),
        .m1_we_i(`WriteDisable),

        // master 2 interface (JTAG已删,接零)
        .m2_addr_i(`ZeroWord),
        .m2_data_i(`ZeroWord),
        .m2_data_o(),
        .m2_req_i(`RIB_NREQ),
        .m2_we_i(`WriteDisable),

        // master 3 interface
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_data_o(m3_data_o),
        .m3_req_i(m3_req_i),
        .m3_we_i(m3_we_i),

        // slave 0 interface
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_we_o(s0_we_o),
        .s0_req_o(s0_req_o),

        // slave 1 interface
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_data_i(s1_data_i),
        .s1_we_o(s1_we_o),
        .s1_req_o(s1_req_o),

        // slave 2 interface
        .s2_addr_o(s2_addr_o),
        .s2_data_o(s2_data_o),
        .s2_data_i(s2_data_i),
        .s2_we_o(s2_we_o),
        .s2_req_o(s2_req_o),

        // slave 3 interface
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),
        .s3_req_o(s3_req_o),

        // slave 4 interface
        .s4_addr_o(s4_addr_o),
        .s4_data_o(s4_data_o),
        .s4_data_i(s4_data_i),
        .s4_we_o(s4_we_o),
        .s4_req_o(s4_req_o),

        // slave 5 interface
        .s5_addr_o(s5_addr_o),
        .s5_data_o(s5_data_o),
        .s5_data_i(s5_data_i),
        .s5_we_o(s5_we_o),
        .s5_req_o(s5_req_o),

        .hold_flag_o(rib_hold_flag_o)
    );

    // 串口下载模块例化
    uart_debug u_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(uart_debug_pin),
        .req_o(m3_req_i),
        .mem_we_o(m3_we_i),
        .mem_addr_o(m3_addr_i),
        .mem_wdata_o(m3_data_i),
        .mem_rdata_i(m3_data_o),
        .mem_busy_i(bridge_busy)
    );

endmodule
