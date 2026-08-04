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

// ldk_tinyriscv soc妞よ泛鐪板Ο鈥虫健
module ldk_tinyriscv_soc_top(

    input wire clk,
    input wire rst,

    output reg succ,         // 濞村鐦弰顖氭儊閹存劕濮涙穱鈥冲娇

    input wire uart_debug_pin, // 娑撴彃褰涙稉瀣祰娴ｈ儻鍏樺鏇″壖

    output wire uart_tx_pin, // UART閸欐垿鈧礁绱╅懘?
    input wire uart_rx_pin,  // UART閹恒儲鏁瑰鏇″壖

    output wire [`BridgeBus] bmaster_TX_data, // 娓氭帛tag濡€虫健娴ｈ法鏁ら惃鍕夐幒銉ゅ瘜閹恒儱褰涢弫鐗堝祦閹崵鍤?
    input wire [`BridgeBus] bmaster_RX_data,   // 娓氭帛tag濡€虫健娴ｈ法鏁ら惃鍕夐幒銉ゅ瘜閹恒儱褰涢弫鐗堝祦閹崵鍤?

    output wire [3:0] pwm_o, // PWM澶栬鐨勮緭鍑轰俊鍙?

    output wire SCL_o ,  
    output wire SDA_o ,  
    output wire SDA_oe_o, 
    input  wire SDA_i  



    );

    wire [3:0] pwm_out_tmp ;
    assign pwm_o = pwm_out_tmp;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            //over <= 1'b1;
            succ <= 1'b1;
        end else begin
            //over <= ~u_tinyriscv.u_regs.ldk_regs[26];  // when = 1, run over
            succ <= ~u_tinyriscv.u_regs.ldk_regs[27];  // when = 1, run succ, otherwise fail
        end
    end

    // master 0 interface
    wire m0_req_i;
    wire m0_we_i;
    wire m0_ack_o;
    wire[`MemAddrBus] m0_addr_i;
    wire[`MemBus] m0_data_i;
    wire[`MemBus] m0_data_o;

    // master 1 interface
    wire m1_req_i;
    wire m1_we_i;
    wire m1_ack_o;
    wire[`MemAddrBus] m1_addr_i;
    wire[`MemBus] m1_data_i;
    wire[`MemBus] m1_data_o;

    // master 2 interface
    wire[`MemAddrBus] m2_addr_i;
    wire[`MemBus] m2_data_i;
    wire[`MemBus] m2_data_o;
    wire m2_req_i;
    wire m2_we_i;

    // master 3 interface
    wire[`MemAddrBus] m3_addr_i;
    wire[`MemBus] m3_data_i;
    wire[`MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;
    wire m3_ack_o;

    // slave 0 interface
    wire s0_req_o;
    wire s0_we_o;
    wire s0_ack_i;
    wire[`MemAddrBus] s0_addr_o;
    wire[`MemBus] s0_data_o;
    wire[`MemBus] s0_data_i;

    // slave 1 interface
    wire s1_req_o;
    wire s1_we_o;
    wire s1_ack_i;
    wire[`MemAddrBus] s1_addr_o;
    wire[`MemBus] s1_data_o;
    wire[`MemBus] s1_data_i;

    // slave 2 interface
    wire[`MemAddrBus] s2_addr_o;
    wire[`MemBus] s2_data_o;
    wire[`MemBus] s2_data_i;
    wire s2_we_o;

    // slave 3 interface
    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemBus] s3_data_i;
    wire s3_we_o;

    // slave 4 interface
    wire[`MemAddrBus] s4_addr_o;
    wire[`MemBus] s4_data_o;
    wire[`MemBus] s4_data_i;
    wire s4_we_o;

    // slave 5 interface
    wire[`MemAddrBus] s5_addr_o;
    wire[`MemBus] s5_data_o;
    wire[`MemBus] s5_data_i;
    wire s5_we_o;

    // slave 6 interface
    wire[`MemAddrBus] s6_addr_o;
    wire[`MemBus] s6_data_o;
    wire[`MemBus] s6_data_i;
    wire s6_we_o;

    // slave 7 interface
    wire s7_req_o;
    wire[`MemAddrBus] s7_addr_o;
    wire[`MemBus] s7_data_o;
    wire[`MemBus] s7_data_i;
    wire s7_we_o;
    wire s7_ack_i;

    // ldk_rib
    wire rib_hold_flag_o;




    // ldk_tinyriscv婢跺嫮鎮婇崳銊︾壋濡€虫健娓氬瀵?
    ldk_tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),

        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_ex_ack_i(m0_ack_o),

        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),
        .rib_pc_req_o(m1_req_i),
        .rib_pc_ack_i(m1_ack_o)
    );


    // ldk_uart濡€虫健娓氬瀵?
    ldk_uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );


    // ldk_rib濡€虫健娓氬瀵?
    ldk_rib u_rib(
        .clk(clk),
        .rst(rst),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),
        .m0_ack_o(m0_ack_o),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(m1_req_i),
        .m1_we_i(`WriteDisable),
        .m1_ack_o(m1_ack_o),

        // master 2 interface
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
        .m3_ack_o(m3_ack_o),

        // slave 0 interface
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_we_o(s0_we_o),
        .s0_req_o(s0_req_o),
        .s0_ack_i(s0_ack_i),

        // slave 1 interface
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_data_i(s1_data_i),
        .s1_we_o(s1_we_o),
        .s1_ack_i(s1_ack_i),

        // slave 2 interface
        .s2_addr_o(),
        .s2_data_o(),
        .s2_data_i(`ZeroWord),
        .s2_we_o(),

        // slave 3 interface
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),

        // slave 4 interface
        .s4_addr_o(),
        .s4_data_o(),
        .s4_data_i(`ZeroWord),
        .s4_we_o(),

        // slave 5 interface
        .s5_addr_o(),
        .s5_data_o(),
        .s5_data_i(`ZeroWord),
        .s5_we_o(),

        // slave 6 interface
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),

        // slave 7 interface
        .s7_req_o(s7_req_o),
        .s7_addr_o(s7_addr_o),     // 浠庤澶?璇汇€佸啓鍦板潃
        .s7_data_o(s7_data_o),         // 浠庤澶?鍐欐暟鎹?
        .s7_data_i(s7_data_i),         // 浠庤澶?璇诲彇鍒扮殑鏁版嵁
        .s7_we_o(s7_we_o),                    // 浠庤澶?鍐欐爣蹇?
        .s7_ack_i(s7_ack_i),

        .hold_flag_o(rib_hold_flag_o)
    );

    // Bridge濡€虫健娓氬瀵?
    ldk_bridge_master u_bridge_master(
        .clk(clk),
        .rst(rst),

        // ldk_rib閹恒儱褰?
        .rib_req_i(s0_req_o),
        .rib_we_i(s0_we_o),
        .rib_ack_o(s0_ack_i),
        .rib_addr_i(s0_addr_o),
        .rib_data_i(s0_data_o),
        .rib_data_o(s0_data_i),

        .bmaster_RX_data(bmaster_RX_data),
        .bmaster_TX_data(bmaster_TX_data),
        .hold_flag_o()
        );

    // 娑撴彃褰涙稉瀣祰濡€虫健娓氬瀵?
    ldk_uart_debug u_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(uart_debug_pin),
        .req_o(m3_req_i),
        .mem_we_o(m3_we_i),
        .mem_addr_o(m3_addr_i),
        .mem_wdata_o(m3_data_i),
        .mem_rdata_i(m3_data_o),
        .mem_write_ack_i(m3_ack_o)
    );

    ldk_iic_dk u_iic_dk ( 

    .clk(clk), 
    .rst(rst),
    .req_i({s7_req_o, 1'b1}), 
    .we_i(s7_we_o),
    .addr_i(s7_addr_o),
    .data_i(s7_data_o),
    .data_o(s7_data_i),   
    .ack_o(s7_ack_i),  
    .SCL_o(SCL_o) ,  
    .SDA_o(SDA_o) ,  
    .SDA_oe_o(SDA_oe_o), 
    .SDA_i(SDA_i)  

    );



    ldk_pwm u_pwm  (

        .clk     ( clk ) ,
        .rst     ( rst ) ,
        .we_i    ( s6_we_o ) ,
        .addr_i  ( s6_addr_o ),
        .data_i  ( s6_data_o ),
        .data_o  ( s6_data_i ),
        .PWM_o   ( pwm_out_tmp )
        
    ) ;



endmodule
