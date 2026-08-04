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

// sy_tinyriscv soc顶层模块
module sy_tinyriscv_soc_top(

    input wire clk,
    input wire rst,

    output reg over,         // 测试是否结束信号
    output reg succ,         // 测试是否成功信号

    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发送引脚
    input wire uart_rx_pin,  // UART接收引脚
    input wire[7:0] bridge_data_i,
    output wire[7:0] bridge_data_o,
    output wire[3:0] sy_pwm,
    output wire i2c_scl,
    inout wire i2c_sda

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
    wire s0_req_o;
    wire[`Hold_Flag_Bus] s0_hold_i;

    // slave 1 interface
    wire[`MemAddrBus] s1_addr_o;
    wire[`MemBus] s1_data_o;
    wire[`MemBus] s1_data_i;
    wire s1_we_o;
    wire s1_req_o;
    wire[`Hold_Flag_Bus] s1_hold_i;

    // slave 3 interface
    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemBus] s3_data_i;
    wire s3_we_o;

    // slave 6 interface
    wire[`MemAddrBus] s6_addr_o;
    wire[`MemBus] s6_data_o;
    wire[`MemBus] s6_data_i;
    wire s6_we_o;

    // slave 7 interface
    wire[`MemAddrBus] s7_addr_o;
    wire[`MemBus] s7_data_o;
    wire[`MemBus] s7_data_i;
    wire s7_we_o;
    wire s7_req_o;
    wire[`Hold_Flag_Bus] s7_hold_i;

    // sy_rib
    wire[`Hold_Flag_Bus] rib_hold_flag_o;


    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~u_tinyriscv.u_regs.sy_regs[26];  // when = 1, run over
            succ <= ~u_tinyriscv.u_regs.sy_regs[27];  // when = 1, run succ, otherwise fail
        end
    end

    // sy_tinyriscv处理器核模块例化
    sy_tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),

        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),

        .rib_hold_flag_i(rib_hold_flag_o)
    );

    // sy_bridge模块例化
    sy_bridge u_bridge(
        .clk(clk),
        .rst(rst),
        .rom_req_i(s0_req_o),
        .rom_we_i(s0_we_o),
        .rom_addr_i(s0_addr_o),
        .rom_data_i(s0_data_o),
        .rom_data_o(s0_data_i),
        .rom_hold_o(s0_hold_i),
        .ram_req_i(s1_req_o),
        .ram_we_i(s1_we_o),
        .ram_addr_i(s1_addr_o),
        .ram_data_i(s1_data_o),
        .ram_data_o(s1_data_i),
        .ram_hold_o(s1_hold_i),
        .bridge_data_i(bridge_data_i),
        .bridge_data_o(bridge_data_o)
    );

    // sy_uart模块例化
    sy_uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .sid_req_i(1'b0),
        .ifire_req_i(1'b0),
        .ifire_data_i(8'h0),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    // sy_pwm模块例化
    sy_pwm pwm_0(
        .clk(clk),
        .rst(rst),
        .we_i(s6_we_o),
        .addr_i(s6_addr_o),
        .data_i(s6_data_o),
        .data_o(s6_data_i),
        .pwm_o(sy_pwm)
    );

    // i2c模块例化
    sy_iic u_iic(
        .clk(clk),
        .rst(rst),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .io_scl(i2c_scl),
        .io_sda(i2c_sda)
    );

    // sy_rib模块例化
    sy_rib u_rib(
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

        // master 2 interface (JTAG removed, grounded)
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
        .s0_hold_i(s0_hold_i),

        // slave 1 interface
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_data_i(s1_data_i),
        .s1_we_o(s1_we_o),
        .s1_req_o(s1_req_o),
        .s1_hold_i(s1_hold_i),

        // slave 3 interface
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),

        // slave 6 interface
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),

        // slave 7 interface
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),
        .s7_req_o(s7_req_o),
        .s7_hold_i(3'b000),

        .hold_flag_o(rib_hold_flag_o)
    );

    // 串口下载模块例化
    sy_uart_debug u_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(uart_debug_pin),
        .req_o(m3_req_i),
        .mem_we_o(m3_we_i),
        .mem_addr_o(m3_addr_i),
        .mem_wdata_o(m3_data_i),
        .mem_rdata_i(m3_data_o)
    );

endmodule
