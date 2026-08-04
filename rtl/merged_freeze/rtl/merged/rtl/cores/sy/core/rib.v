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

`include "sy_defs.v"

// SY-prefixed private RTL module for the four-core integration.
module sy_rib(

    input wire clk,
    input wire rst,

    // master 0 interface: cpu data
    input wire[`SY_MemAddrBus] m0_addr_i,
    input wire[`SY_MemBus] m0_data_i,
    output reg[`SY_MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,

    // master 1 interface: cpu instruction
    input wire[`SY_MemAddrBus] m1_addr_i,
    input wire[`SY_MemBus] m1_data_i,
    output reg[`SY_MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,

    // master 2 interface: jtag
    input wire[`SY_MemAddrBus] m2_addr_i,
    input wire[`SY_MemBus] m2_data_i,
    output reg[`SY_MemBus] m2_data_o,
    input wire m2_req_i,
    input wire m2_we_i,

    // master 3 interface: uart debug
    input wire[`SY_MemAddrBus] m3_addr_i,
    input wire[`SY_MemBus] m3_data_i,
    output reg[`SY_MemBus] m3_data_o,
    input wire m3_req_i,
    input wire m3_we_i,

    // slave 0 interface: external rom bridge
    output reg[`SY_MemAddrBus] s0_addr_o,
    output reg[`SY_MemBus] s0_data_o,
    input wire[`SY_MemBus] s0_data_i,
    output reg s0_we_o,
    output reg s0_req_o,
    input wire[`SY_Hold_Flag_Bus] s0_hold_i,

    // slave 1 interface: external ram bridge
    output reg[`SY_MemAddrBus] s1_addr_o,
    output reg[`SY_MemBus] s1_data_o,
    input wire[`SY_MemBus] s1_data_i,
    output reg s1_we_o,
    output reg s1_req_o,
    input wire[`SY_Hold_Flag_Bus] s1_hold_i,

    // slave 3 interface: uart
    output reg[`SY_MemAddrBus] s3_addr_o,
    output reg[`SY_MemBus] s3_data_o,
    input wire[`SY_MemBus] s3_data_i,
    output reg s3_we_o,

    // slave 6 interface: pwm
    output reg[`SY_MemAddrBus] s6_addr_o,
    output reg[`SY_MemBus] s6_data_o,
    input wire[`SY_MemBus] s6_data_i,
    output reg s6_we_o,

    // slave 7 interface: i2c
    output reg[`SY_MemAddrBus] s7_addr_o,
    output reg[`SY_MemBus] s7_data_o,
    input wire[`SY_MemBus] s7_data_i,
    output reg s7_we_o,
    output reg s7_req_o,
    input wire[`SY_Hold_Flag_Bus] s7_hold_i,

    output reg[`SY_Hold_Flag_Bus] hold_flag_o

    );

    parameter [3:0] slave_0 = 4'b0000;
    parameter [3:0] slave_1 = 4'b0001;
    parameter [3:0] slave_3 = 4'b0011;
    parameter [3:0] slave_6 = 4'b0110;
    parameter [3:0] slave_7 = 4'b0111;

    parameter [1:0] grant0 = 2'h0;
    parameter [1:0] grant1 = 2'h1;
    parameter [1:0] grant2 = 2'h2;
    parameter [1:0] grant3 = 2'h3;

    wire[3:0] req;
    reg[1:0] grant;

    assign req = {m3_req_i, m2_req_i, m1_req_i, m0_req_i};

    always @ (*) begin
        if (req[3]) begin
            grant = grant3;
        end else if (req[0]) begin
            grant = grant0;
        end else if (req[2]) begin
            grant = grant2;
        end else begin
            grant = grant1;
        end
    end

    always @ (*) begin
        m0_data_o = `SY_ZeroWord;
        m1_data_o = `SY_INST_NOP;
        m2_data_o = `SY_ZeroWord;
        m3_data_o = `SY_ZeroWord;

        s0_addr_o = `SY_ZeroWord;
        s1_addr_o = `SY_ZeroWord;
        s3_addr_o = `SY_ZeroWord;
        s6_addr_o = `SY_ZeroWord;
        s7_addr_o = `SY_ZeroWord;
        s0_data_o = `SY_ZeroWord;
        s1_data_o = `SY_ZeroWord;
        s3_data_o = `SY_ZeroWord;
        s6_data_o = `SY_ZeroWord;
        s7_data_o = `SY_ZeroWord;
        s0_we_o = `SY_WriteDisable;
        s1_we_o = `SY_WriteDisable;
        s3_we_o = `SY_WriteDisable;
        s6_we_o = `SY_WriteDisable;
        s7_we_o = `SY_WriteDisable;
        s0_req_o = `SY_RIB_NREQ;
        s1_req_o = `SY_RIB_NREQ;
        s7_req_o = `SY_RIB_NREQ;
        hold_flag_o = `SY_Hold_None;

        case (grant)
            grant0: begin
                case (m0_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m0_we_i;
                        s0_req_o = `SY_RIB_REQ;
                        s0_addr_o = {4'h0, m0_addr_i[27:0]};
                        s0_data_o = m0_data_i;
                        m0_data_o = s0_data_i;
                        hold_flag_o = (s0_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    slave_1: begin
                        s1_we_o = m0_we_i;
                        s1_req_o = `SY_RIB_REQ;
                        s1_addr_o = {4'h0, m0_addr_i[27:0]};
                        s1_data_o = m0_data_i;
                        m0_data_o = s1_data_i;
                        hold_flag_o = (s1_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    slave_3: begin
                        s3_we_o = m0_we_i;
                        s3_addr_o = {4'h0, m0_addr_i[27:0]};
                        s3_data_o = m0_data_i;
                        m0_data_o = s3_data_i;
                        hold_flag_o = `SY_Hold_Pc;
                    end
                    slave_6: begin
                        s6_we_o = m0_we_i;
                        s6_addr_o = {4'h0, m0_addr_i[27:0]};
                        s6_data_o = m0_data_i;
                        m0_data_o = s6_data_i;
                        hold_flag_o = `SY_Hold_Pc;
                    end
                    slave_7: begin
                        s7_we_o = m0_we_i;
                        s7_req_o = `SY_RIB_REQ;
                        s7_addr_o = {4'h0, m0_addr_i[27:0]};
                        s7_data_o = m0_data_i;
                        m0_data_o = s7_data_i;
                        hold_flag_o = (s7_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    default: begin

                    end
                endcase
            end
            grant1: begin
                case (m1_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m1_we_i;
                        s0_req_o = `SY_RIB_REQ;
                        s0_addr_o = {4'h0, m1_addr_i[27:0]};
                        s0_data_o = m1_data_i;
                        m1_data_o = s0_data_i;
                        hold_flag_o = (s0_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_None;
                    end
                    slave_1: begin
                        s1_we_o = m1_we_i;
                        s1_req_o = `SY_RIB_REQ;
                        s1_addr_o = {4'h0, m1_addr_i[27:0]};
                        s1_data_o = m1_data_i;
                        m1_data_o = s1_data_i;
                        hold_flag_o = (s1_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_None;
                    end
                    slave_3: begin
                        s3_we_o = m1_we_i;
                        s3_addr_o = {4'h0, m1_addr_i[27:0]};
                        s3_data_o = m1_data_i;
                        m1_data_o = s3_data_i;
                    end
                    slave_6: begin
                        s6_we_o = m1_we_i;
                        s6_addr_o = {4'h0, m1_addr_i[27:0]};
                        s6_data_o = m1_data_i;
                        m1_data_o = s6_data_i;
                    end
                    slave_7: begin
                        s7_we_o = m1_we_i;
                        s7_req_o = `SY_RIB_REQ;
                        s7_addr_o = {4'h0, m1_addr_i[27:0]};
                        s7_data_o = m1_data_i;
                        m1_data_o = s7_data_i;
                        hold_flag_o = (s7_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_None;
                    end
                    default: begin

                    end
                endcase
            end
            grant2: begin
                case (m2_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m2_we_i;
                        s0_req_o = `SY_RIB_REQ;
                        s0_addr_o = {4'h0, m2_addr_i[27:0]};
                        s0_data_o = m2_data_i;
                        m2_data_o = s0_data_i;
                        hold_flag_o = (s0_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    slave_1: begin
                        s1_we_o = m2_we_i;
                        s1_req_o = `SY_RIB_REQ;
                        s1_addr_o = {4'h0, m2_addr_i[27:0]};
                        s1_data_o = m2_data_i;
                        m2_data_o = s1_data_i;
                        hold_flag_o = (s1_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    slave_3: begin
                        s3_we_o = m2_we_i;
                        s3_addr_o = {4'h0, m2_addr_i[27:0]};
                        s3_data_o = m2_data_i;
                        m2_data_o = s3_data_i;
                        hold_flag_o = `SY_Hold_Pc;
                    end
                    slave_6: begin
                        s6_we_o = m2_we_i;
                        s6_addr_o = {4'h0, m2_addr_i[27:0]};
                        s6_data_o = m2_data_i;
                        m2_data_o = s6_data_i;
                        hold_flag_o = `SY_Hold_Pc;
                    end
                    slave_7: begin
                        s7_we_o = m2_we_i;
                        s7_req_o = `SY_RIB_REQ;
                        s7_addr_o = {4'h0, m2_addr_i[27:0]};
                        s7_data_o = m2_data_i;
                        m2_data_o = s7_data_i;
                        hold_flag_o = (s7_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    default: begin

                    end
                endcase
            end
            grant3: begin
                case (m3_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m3_we_i;
                        s0_req_o = `SY_RIB_REQ;
                        s0_addr_o = {4'h0, m3_addr_i[27:0]};
                        s0_data_o = m3_data_i;
                        m3_data_o = s0_data_i;
                        hold_flag_o = (s0_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    slave_1: begin
                        s1_we_o = m3_we_i;
                        s1_req_o = `SY_RIB_REQ;
                        s1_addr_o = {4'h0, m3_addr_i[27:0]};
                        s1_data_o = m3_data_i;
                        m3_data_o = s1_data_i;
                        hold_flag_o = (s1_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
                    end
                    slave_3: begin
                        s3_we_o = m3_we_i;
                        s3_addr_o = {4'h0, m3_addr_i[27:0]};
                        s3_data_o = m3_data_i;
                        m3_data_o = s3_data_i;
                        hold_flag_o = `SY_Hold_Pc;
                    end
                    slave_6: begin
                        s6_we_o = m3_we_i;
                        s6_addr_o = {4'h0, m3_addr_i[27:0]};
                        s6_data_o = m3_data_i;
                        m3_data_o = s6_data_i;
                        hold_flag_o = `SY_Hold_Pc;
                    end
                    slave_7: begin
                        s7_we_o = m3_we_i;
                        s7_req_o = `SY_RIB_REQ;
                        s7_addr_o = {4'h0, m3_addr_i[27:0]};
                        s7_data_o = m3_data_i;
                        m3_data_o = s7_data_i;
                        hold_flag_o = (s7_hold_i != `SY_Hold_None)? `SY_Hold_Rib: `SY_Hold_Pc;
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

