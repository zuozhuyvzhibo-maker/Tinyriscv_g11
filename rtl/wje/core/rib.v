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

`include "defines.v"


// RIB总线模块
module rib(

    input wire clk,                         // RIB 时钟输入，当前模块仲裁逻辑主要为组合逻辑
    input wire rst,                         // RIB 复位输入，保留给总线模块使用

    // master 0 interface
    input wire[`MemAddrBus] m0_addr_i,     // 主设备0读、写地址
    input wire[`MemBus] m0_data_i,         // 主设备0写数据
    output reg[`MemBus] m0_data_o,         // 主设备0读取到的数据
    input wire m0_req_i,                   // 主设备0访问请求标志
    input wire m0_we_i,                    // 主设备0写标志

    // master 1 interface
    input wire[`MemAddrBus] m1_addr_i,     // 主设备1读、写地址
    input wire[`MemBus] m1_data_i,         // 主设备1写数据
    output reg[`MemBus] m1_data_o,         // 主设备1读取到的数据
    input wire m1_req_i,                   // 主设备1访问请求标志
    input wire m1_we_i,                    // 主设备1写标志

    // master 2 interface
    input wire[`MemAddrBus] m2_addr_i,     // 主设备2读、写地址
    input wire[`MemBus] m2_data_i,         // 主设备2写数据
    output reg[`MemBus] m2_data_o,         // 主设备2读取到的数据
    input wire m2_req_i,                   // 主设备2访问请求标志
    input wire m2_we_i,                    // 主设备2写标志

    // master 3 interface
    input wire[`MemAddrBus] m3_addr_i,     // 主设备3读、写地址
    input wire[`MemBus] m3_data_i,         // 主设备3写数据
    output reg[`MemBus] m3_data_o,         // 主设备3读取到的数据
    input wire m3_req_i,                   // 主设备3访问请求标志
    input wire m3_we_i,                    // 主设备3写标志

    // slave 0 interface
    output reg[`MemAddrBus] s0_addr_o,     // 从设备0读、写地址
    output reg[`MemBus] s0_data_o,         // 从设备0写数据
    input wire[`MemBus] s0_data_i,         // 从设备0读取到的数据
    output reg s0_we_o,                    // 从设备0写标志
    // 原接口没有 s0_req_o，新增该信号用于通知 bridge 当前 slave0 访问有效
    output reg s0_req_o,                   //新增：RIB slave0/ROM 访问有效信号

    // slave 1 interface
    output reg[`MemAddrBus] s1_addr_o,     // 从设备1读、写地址
    output reg[`MemBus] s1_data_o,         // 从设备1写数据
    input wire[`MemBus] s1_data_i,         // 从设备1读取到的数据
    output reg s1_we_o,                    // 从设备1写标志
    // 原接口没有 s1_req_o，新增该信号用于通知 bridge 当前 slave1 访问有效
    output reg s1_req_o,                   //新增：RIB slave1/RAM 访问有效信号

    // slave 2 interface
    output reg[`MemAddrBus] s2_addr_o,     // 从设备2读、写地址
    output reg[`MemBus] s2_data_o,         // 从设备2写数据
    input wire[`MemBus] s2_data_i,         // 从设备2读取到的数据
    output reg s2_we_o,                    // 从设备2写标志
    // 原接口没有 s2_req_o，新增该信号用于保持其他 slave 接口形式一致
    output reg s2_req_o,                   //新增：RIB slave2 访问有效信号

    // slave 3 interface
    output reg[`MemAddrBus] s3_addr_o,     // 从设备3读、写地址
    output reg[`MemBus] s3_data_o,         // 从设备3写数据
    input wire[`MemBus] s3_data_i,         // 从设备3读取到的数据
    output reg s3_we_o,                    // 从设备3写标志
    // 原接口没有 s3_req_o，新增该信号用于保持其他 slave 接口形式一致
    output reg s3_req_o,                   //新增：RIB slave3 访问有效信号

    // slave 4 interface
    output reg[`MemAddrBus] s4_addr_o,     // 从设备4读、写地址
    output reg[`MemBus] s4_data_o,         // 从设备4写数据
    input wire[`MemBus] s4_data_i,         // 从设备4读取到的数据
    output reg s4_we_o,                    // 从设备4写标志
    // 原接口没有 s4_req_o，新增该信号用于保持其他 slave 接口形式一致
    output reg s4_req_o,                   //新增：RIB slave4 访问有效信号

    // slave 5 interface
    output reg[`MemAddrBus] s5_addr_o,     // 从设备5读、写地址
    output reg[`MemBus] s5_data_o,         // 从设备5写数据
    input wire[`MemBus] s5_data_i,         // 从设备5读取到的数据
    output reg s5_we_o,                    // 从设备5写标志
    // 原接口没有 s5_req_o，新增该信号用于保持其他 slave 接口形式一致
    output reg s5_req_o,                   //新增：RIB slave5 访问有效信号

    output reg hold_flag_o                 // 暂停流水线标志

    );


    // 访问地址的最高4位决定要访问的是哪一个从设备
    // 因此最多支持16个从设备
    parameter [3:0]slave_0 = 4'b0000;       // 地址高 4 位为 0 时访问 slave0，当前对应 ROM/bridge ROM 侧
    parameter [3:0]slave_1 = 4'b0001;       // 地址高 4 位为 1 时访问 slave1，当前对应 RAM/bridge RAM 侧
    parameter [3:0]slave_2 = 4'b0010;       // 地址高 4 位为 2 时访问 slave2，原工程预留给 timer
    parameter [3:0]slave_3 = 4'b0011;       // 地址高 4 位为 3 时访问 slave3，当前对应 UART
    parameter [3:0]slave_4 = 4'b0100;       // 地址高 4 位为 4 时访问 slave4，原工程预留给 GPIO
    parameter [3:0]slave_5 = 4'b0101;       // 地址高 4 位为 5 时访问 slave5，原工程预留给 SPI
    parameter [3:0]slave_6 = 4'b0110;       // 地址高 4 位为 6 时访问 PWM，复用物理 s5 接口
    parameter [3:0]slave_7 = 4'b0111;       // 地址高 4 位为 7 时访问 I2C，复用物理 slave2接口，即原来的timer
    
    parameter [1:0]grant0 = 2'h0;           // 仲裁结果：当前授权 master0
    parameter [1:0]grant1 = 2'h1;           // 仲裁结果：当前授权 master1
    parameter [1:0]grant2 = 2'h2;           // 仲裁结果：当前授权 master2
    parameter [1:0]grant3 = 2'h3;           // 仲裁结果：当前授权 master3

    wire[3:0] req;                          // 4 个 master 的请求向量
    reg[1:0] grant;                         // 当前仲裁选中的 master 编号


    // 主设备请求信号
    assign req = {m3_req_i, m2_req_i, m1_req_i, m0_req_i}; // 将各 master 请求打包，便于固定优先级仲裁

    // 仲裁逻辑
    // 固定优先级仲裁机制
    // 优先级由高到低：主设备3，主设备0，主设备2，主设备1
    always @ (*) begin // 组合仲裁逻辑，根据请求向量实时选择一个 master
        if (req[3]) begin // master3 请求有效时优先级最高，通常对应 uart_debug
            grant = grant3; // 授权 master3 使用 RIB
            hold_flag_o = `HoldEnable; // 其他流水线访问需要暂停，等待高优先级 master 完成
        end else if (req[0]) begin // master0 请求有效时优先级次高，通常对应 EX 阶段 load/store
            grant = grant0; // 授权 master0 使用 RIB
            hold_flag_o = `HoldEnable; // 数据访问期间暂停取指推进，避免总线冲突
        end else if (req[2]) begin // master2 请求有效时优先级再次，通常对应 JTAG 访存
            grant = grant2; // 授权 master2 使用 RIB
            hold_flag_o = `HoldEnable; // 调试访存期间暂停流水线
        end else begin // 没有高优先级请求时，默认授权 master1
            grant = grant1; // master1 通常是取指端口，因此默认让取指访问总线
            hold_flag_o = `HoldDisable; // 只有默认取指访问时，不额外发出 RIB 暂停
        end // 仲裁优先级判断结束
    end // 仲裁组合逻辑结束

    // 根据仲裁结果，选择(访问)对应的从设备
    always @ (*) begin // 组合选路逻辑，根据授权 master 和地址高位选择目标 slave
        m0_data_o = `ZeroWord; // 默认 master0 读数据为 0，未命中 slave 时避免锁存
        m1_data_o = `INST_NOP; // 默认 master1 取指为 NOP，未命中时避免执行未知指令
        m2_data_o = `ZeroWord; // 默认 master2 读数据为 0，未命中 slave 时避免锁存
        m3_data_o = `ZeroWord; // 默认 master3 读数据为 0，未命中 slave 时避免锁存

        s0_addr_o = `ZeroWord; // 默认 slave0 地址清零
        s1_addr_o = `ZeroWord; // 默认 slave1 地址清零
        s2_addr_o = `ZeroWord; // 默认 slave2 地址清零
        s3_addr_o = `ZeroWord; // 默认 slave3 地址清零
        s4_addr_o = `ZeroWord; // 默认 slave4 地址清零
        s5_addr_o = `ZeroWord; // 默认 slave5 地址清零
        s0_data_o = `ZeroWord; // 默认 slave0 写数据清零
        s1_data_o = `ZeroWord; // 默认 slave1 写数据清零
        s2_data_o = `ZeroWord; // 默认 slave2 写数据清零
        s3_data_o = `ZeroWord; // 默认 slave3 写数据清零
        s4_data_o = `ZeroWord; // 默认 slave4 写数据清零
        s5_data_o = `ZeroWord; // 默认 slave5 写数据清零
        s0_we_o = `WriteDisable; // 默认不写 slave0
        s1_we_o = `WriteDisable; // 默认不写 slave1
        s2_we_o = `WriteDisable; // 默认不写 slave2
        s3_we_o = `WriteDisable; // 默认不写 slave3
        s4_we_o = `WriteDisable; // 默认不写 slave4
        s5_we_o = `WriteDisable; // 默认不写 slave5
        // 原默认值只清除 we/addr/data，没有 s*_req_o；外部 bridge 需要明确的访问有效信号
        s0_req_o = `RIB_NREQ;              //新增：默认 slave0 无有效访问
        s1_req_o = `RIB_NREQ;              //新增：默认 slave1 无有效访问
        s2_req_o = `RIB_NREQ;              //新增：默认 slave2 无有效访问
        s3_req_o = `RIB_NREQ;              //新增：默认 slave3 无有效访问
        s4_req_o = `RIB_NREQ;              //新增：默认 slave4 无有效访问
        s5_req_o = `RIB_NREQ;              //新增：默认 slave5 无有效访问

        case (grant) // 根据仲裁结果选择当前哪一个 master 驱动 slave 总线
            grant0: begin // master0 获得授权
                case (m0_addr_i[31:28]) // 使用 master0 地址高 4 位选择 slave
                    // 原分支只转发 we/addr/data 并返回 data_i；现在额外拉高对应 s*_req_o
                    slave_0: begin
                        s0_we_o = m0_we_i; // 将 master0 写使能转发给 slave0
                        s0_req_o = `RIB_REQ;           //新增：slave0 被当前 master 访问时拉高请求
                        s0_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave0
                        s0_data_o = m0_data_i; // 将 master0 写数据转发给 slave0
                        m0_data_o = s0_data_i; // 将 slave0 读数据返回给 master0
                    end
                    slave_1: begin
                        s1_we_o = m0_we_i; // 将 master0 写使能转发给 slave1
                        s1_req_o = `RIB_REQ;           //新增：slave1 被当前 master 访问时拉高请求
                        s1_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave1
                        s1_data_o = m0_data_i; // 将 master0 写数据转发给 slave1
                        m0_data_o = s1_data_i; // 将 slave1 读数据返回给 master0
                    end
//                    slave_2: begin
//                        s2_we_o = m0_we_i; // 将 master0 写使能转发给 slave2
//                        s2_req_o = `RIB_REQ;           //新增：slave2 被当前 master 访问时拉高请求
//                        s2_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave2
//                        s2_data_o = m0_data_i; // 将 master0 写数据转发给 slave2
//                        m0_data_o = s2_data_i; // 将 slave2 读数据返回给 master0
//                    end
                    slave_7: begin
                        s2_we_o = m0_we_i; // 将 master0 写使能转发给 I2C 复用的 slave2
                        s2_req_o = `RIB_REQ;           //新增：I2C 被当前 master 访问时拉高请求
                        s2_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 I2C
                        s2_data_o = m0_data_i; // 将 master0 写数据转发给 I2C
                        m0_data_o = s2_data_i; // 将 I2C 读数据返回给 master0
                    end
                    slave_3: begin
                        s3_we_o = m0_we_i; // 将 master0 写使能转发给 slave3
                        s3_req_o = `RIB_REQ;           //新增：slave3 被当前 master 访问时拉高请求
                        s3_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave3
                        s3_data_o = m0_data_i; // 将 master0 写数据转发给 slave3
                        m0_data_o = s3_data_i; // 将 slave3 读数据返回给 master0
                    end
                    slave_4: begin
                        s4_we_o = m0_we_i; // 将 master0 写使能转发给 slave4
                        s4_req_o = `RIB_REQ;           //新增：slave4 被当前 master 访问时拉高请求
                        s4_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave4
                        s4_data_o = m0_data_i; // 将 master0 写数据转发给 slave4
                        m0_data_o = s4_data_i; // 将 slave4 读数据返回给 master0
                    end
                    slave_6: begin
                        s5_we_o = m0_we_i; // 将 master0 写使能转发给 slave5
                        s5_req_o = `RIB_REQ;           //新增：slave5 被当前 master 访问时拉高请求
                        s5_addr_o = {{4'h0}, {m0_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave5
                        s5_data_o = m0_data_i; // 将 master0 写数据转发给 slave5
                        m0_data_o = s5_data_i; // 将 slave5 读数据返回给 master0
                    end
                    default: begin

                    end
                endcase
            end
            grant1: begin // master1 获得授权
                case (m1_addr_i[31:28]) // 使用 master1 地址高 4 位选择 slave
                    // 原分支只转发 we/addr/data 并返回 data_i；现在额外拉高对应 s*_req_o
                    slave_0: begin
                        s0_we_o = m1_we_i; // 将 master1 写使能转发给 slave0
                        s0_req_o = `RIB_REQ;           //新增：slave0 被当前 master 访问时拉高请求
                        s0_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave0
                        s0_data_o = m1_data_i; // 将 master1 写数据转发给 slave0
                        m1_data_o = s0_data_i; // 将 slave0 读数据返回给 master1
                    end
                    slave_1: begin
                        s1_we_o = m1_we_i; // 将 master1 写使能转发给 slave1
                        s1_req_o = `RIB_REQ;           //新增：slave1 被当前 master 访问时拉高请求
                        s1_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave1
                        s1_data_o = m1_data_i; // 将 master1 写数据转发给 slave1
                        m1_data_o = s1_data_i; // 将 slave1 读数据返回给 master1
                    end
//                    slave_2: begin
//                        s2_we_o = m1_we_i; // 将 master1 写使能转发给 slave2
//                        s2_req_o = `RIB_REQ;           //新增：slave2 被当前 master 访问时拉高请求
//                        s2_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave2
//                        s2_data_o = m1_data_i; // 将 master1 写数据转发给 slave2
//                        m1_data_o = s2_data_i; // 将 slave2 读数据返回给 master1
//                    end
                    slave_7: begin
                        s2_we_o = m1_we_i; // 将 master1 写使能转发给 I2C 复用的 slave2
                        s2_req_o = `RIB_REQ;           //新增：I2C 被当前 master 访问时拉高请求
                        s2_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 I2C
                        s2_data_o = m1_data_i; // 将 master1 写数据转发给 I2C
                        m1_data_o = s2_data_i; // 将 I2C 读数据返回给 master1
                    end
                    slave_3: begin
                        s3_we_o = m1_we_i; // 将 master1 写使能转发给 slave3
                        s3_req_o = `RIB_REQ;           //新增：slave3 被当前 master 访问时拉高请求
                        s3_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave3
                        s3_data_o = m1_data_i; // 将 master1 写数据转发给 slave3
                        m1_data_o = s3_data_i; // 将 slave3 读数据返回给 master1
                    end
                    slave_4: begin
                        s4_we_o = m1_we_i; // 将 master1 写使能转发给 slave4
                        s4_req_o = `RIB_REQ;           //新增：slave4 被当前 master 访问时拉高请求
                        s4_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave4
                        s4_data_o = m1_data_i; // 将 master1 写数据转发给 slave4
                        m1_data_o = s4_data_i; // 将 slave4 读数据返回给 master1
                    end
                    slave_6: begin
                        s5_we_o = m1_we_i; // 将 master1 写使能转发给 slave5
                        s5_req_o = `RIB_REQ;           //新增：slave5 被当前 master 访问时拉高请求
                        s5_addr_o = {{4'h0}, {m1_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave5
                        s5_data_o = m1_data_i; // 将 master1 写数据转发给 slave5
                        m1_data_o = s5_data_i; // 将 slave5 读数据返回给 master1
                    end
                    default: begin

                    end
                endcase
            end
            grant2: begin // master2 获得授权
                case (m2_addr_i[31:28]) // 使用 master2 地址高 4 位选择 slave
                    // 原分支只转发 we/addr/data 并返回 data_i；现在额外拉高对应 s*_req_o
                    slave_0: begin
                        s0_we_o = m2_we_i; // 将 master2 写使能转发给 slave0
                        s0_req_o = `RIB_REQ;           //新增：slave0 被当前 master 访问时拉高请求
                        s0_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave0
                        s0_data_o = m2_data_i; // 将 master2 写数据转发给 slave0
                        m2_data_o = s0_data_i; // 将 slave0 读数据返回给 master2
                    end
                    slave_1: begin
                        s1_we_o = m2_we_i; // 将 master2 写使能转发给 slave1
                        s1_req_o = `RIB_REQ;           //新增：slave1 被当前 master 访问时拉高请求
                        s1_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave1
                        s1_data_o = m2_data_i; // 将 master2 写数据转发给 slave1
                        m2_data_o = s1_data_i; // 将 slave1 读数据返回给 master2
                    end
//                    slave_2: begin
//                        s2_we_o = m2_we_i; // 将 master2 写使能转发给 slave2
//                        s2_req_o = `RIB_REQ;           //新增：slave2 被当前 master 访问时拉高请求
//                        s2_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave2
//                        s2_data_o = m2_data_i; // 将 master2 写数据转发给 slave2
//                        m2_data_o = s2_data_i; // 将 slave2 读数据返回给 master2
//                    end
                    slave_7: begin
                        s2_we_o = m2_we_i; // 将 master2 写使能转发给 I2C 复用的 slave2
                        s2_req_o = `RIB_REQ;           //新增：I2C 被当前 master 访问时拉高请求
                        s2_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 I2C
                        s2_data_o = m2_data_i; // 将 master2 写数据转发给 I2C
                        m2_data_o = s2_data_i; // 将 I2C 读数据返回给 master2
                    end
                    slave_3: begin
                        s3_we_o = m2_we_i; // 将 master2 写使能转发给 slave3
                        s3_req_o = `RIB_REQ;           //新增：slave3 被当前 master 访问时拉高请求
                        s3_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave3
                        s3_data_o = m2_data_i; // 将 master2 写数据转发给 slave3
                        m2_data_o = s3_data_i; // 将 slave3 读数据返回给 master2
                    end
                    slave_4: begin
                        s4_we_o = m2_we_i; // 将 master2 写使能转发给 slave4
                        s4_req_o = `RIB_REQ;           //新增：slave4 被当前 master 访问时拉高请求
                        s4_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave4
                        s4_data_o = m2_data_i; // 将 master2 写数据转发给 slave4
                        m2_data_o = s4_data_i; // 将 slave4 读数据返回给 master2
                    end
                    slave_6: begin
                        s5_we_o = m2_we_i; // 将 master2 写使能转发给 slave5
                        s5_req_o = `RIB_REQ;           //新增：slave5 被当前 master 访问时拉高请求
                        s5_addr_o = {{4'h0}, {m2_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave5
                        s5_data_o = m2_data_i; // 将 master2 写数据转发给 slave5
                        m2_data_o = s5_data_i; // 将 slave5 读数据返回给 master2
                    end
                    default: begin

                    end
                endcase
            end
            grant3: begin // master3 获得授权
                case (m3_addr_i[31:28]) // 使用 master3 地址高 4 位选择 slave
                    // 原分支只转发 we/addr/data 并返回 data_i；现在额外拉高对应 s*_req_o
                    slave_0: begin
                        s0_we_o = m3_we_i; // 将 master3 写使能转发给 slave0
                        s0_req_o = `RIB_REQ;           //新增：slave0 被当前 master 访问时拉高请求
                        s0_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave0
                        s0_data_o = m3_data_i; // 将 master3 写数据转发给 slave0
                        m3_data_o = s0_data_i; // 将 slave0 读数据返回给 master3
                    end
                    slave_1: begin
                        s1_we_o = m3_we_i; // 将 master3 写使能转发给 slave1
                        s1_req_o = `RIB_REQ;           //新增：slave1 被当前 master 访问时拉高请求
                        s1_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave1
                        s1_data_o = m3_data_i; // 将 master3 写数据转发给 slave1
                        m3_data_o = s1_data_i; // 将 slave1 读数据返回给 master3
                    end
//                    slave_2: begin
//                        s2_we_o = m3_we_i; // 将 master3 写使能转发给 slave2
//                        s2_req_o = `RIB_REQ;           //新增：slave2 被当前 master 访问时拉高请求
//                        s2_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave2
//                        s2_data_o = m3_data_i; // 将 master3 写数据转发给 slave2
//                        m3_data_o = s2_data_i; // 将 slave2 读数据返回给 master3
//                    end
                    slave_7: begin
                        s2_we_o = m3_we_i; // 将 master3 写使能转发给 I2C 复用的 slave2
                        s2_req_o = `RIB_REQ;           //新增：I2C 被当前 master 访问时拉高请求
                        s2_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 I2C
                        s2_data_o = m3_data_i; // 将 master3 写数据转发给 I2C
                        m3_data_o = s2_data_i; // 将 I2C 读数据返回给 master3
                    end
                    slave_3: begin
                        s3_we_o = m3_we_i; // 将 master3 写使能转发给 slave3
                        s3_req_o = `RIB_REQ;           //新增：slave3 被当前 master 访问时拉高请求
                        s3_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave3
                        s3_data_o = m3_data_i; // 将 master3 写数据转发给 slave3
                        m3_data_o = s3_data_i; // 将 slave3 读数据返回给 master3
                    end
                    slave_4: begin
                        s4_we_o = m3_we_i; // 将 master3 写使能转发给 slave4
                        s4_req_o = `RIB_REQ;           //新增：slave4 被当前 master 访问时拉高请求
                        s4_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave4
                        s4_data_o = m3_data_i; // 将 master3 写数据转发给 slave4
                        m3_data_o = s4_data_i; // 将 slave4 读数据返回给 master3
                    end
                    slave_6: begin
                        s5_we_o = m3_we_i; // 将 master3 写使能转发给 slave5
                        s5_req_o = `RIB_REQ;           //新增：slave5 被当前 master 访问时拉高请求
                        s5_addr_o = {{4'h0}, {m3_addr_i[27:0]}}; // 去掉地址高 4 位译码字段后转发给 slave5
                        s5_data_o = m3_data_i; // 将 master3 写数据转发给 slave5
                        m3_data_o = s5_data_i; // 将 slave5 读数据返回给 master3
                    end
                    default: begin

                    end
                endcase
            end
            default: begin

            end
        endcase
    end

endmodule
