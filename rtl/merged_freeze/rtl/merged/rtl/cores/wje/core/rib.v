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

`include "wje_defs.v"



// WJE-prefixed private RTL module for the four-core integration.
module wje_rib(

    input wire clk,
    input wire rst,

    // master 0 interface
    input wire[`WJE_MemAddrBus] m0_addr_i,
    input wire[`WJE_MemBus] m0_data_i,
    output reg[`WJE_MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,

    // master 1 interface
    input wire[`WJE_MemAddrBus] m1_addr_i,
    input wire[`WJE_MemBus] m1_data_i,
    output reg[`WJE_MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,

    // master 2 interface
    input wire[`WJE_MemAddrBus] m2_addr_i,
    input wire[`WJE_MemBus] m2_data_i,
    output reg[`WJE_MemBus] m2_data_o,
    input wire m2_req_i,
    input wire m2_we_i,

    // master 3 interface
    input wire[`WJE_MemAddrBus] m3_addr_i,
    input wire[`WJE_MemBus] m3_data_i,
    output reg[`WJE_MemBus] m3_data_o,
    input wire m3_req_i,
    input wire m3_we_i,

    // slave 0 interface
    output reg[`WJE_MemAddrBus] s0_addr_o,
    output reg[`WJE_MemBus] s0_data_o,
    input wire[`WJE_MemBus] s0_data_i,
    output reg s0_we_o,

    output reg s0_req_o,

    // slave 1 interface
    output reg[`WJE_MemAddrBus] s1_addr_o,
    output reg[`WJE_MemBus] s1_data_o,
    input wire[`WJE_MemBus] s1_data_i,
    output reg s1_we_o,

    output reg s1_req_o,

    // slave 2 interface
    output reg[`WJE_MemAddrBus] s2_addr_o,
    output reg[`WJE_MemBus] s2_data_o,
    input wire[`WJE_MemBus] s2_data_i,
    output reg s2_we_o,

    output reg s2_req_o,

    // slave 3 interface
    output reg[`WJE_MemAddrBus] s3_addr_o,
    output reg[`WJE_MemBus] s3_data_o,
    input wire[`WJE_MemBus] s3_data_i,
    output reg s3_we_o,

    output reg s3_req_o,

    // slave 4 interface
    output reg[`WJE_MemAddrBus] s4_addr_o,
    output reg[`WJE_MemBus] s4_data_o,
    input wire[`WJE_MemBus] s4_data_i,
    output reg s4_we_o,

    output reg s4_req_o,

    // slave 5 interface
    output reg[`WJE_MemAddrBus] s5_addr_o,
    output reg[`WJE_MemBus] s5_data_o,
    input wire[`WJE_MemBus] s5_data_i,
    output reg s5_we_o,

    output reg s5_req_o,

    output reg hold_flag_o

    );




    parameter [3:0]slave_0 = 4'b0000;
    parameter [3:0]slave_1 = 4'b0001;
    parameter [3:0]slave_2 = 4'b0010;
    parameter [3:0]slave_3 = 4'b0011;
    parameter [3:0]slave_4 = 4'b0100;
    parameter [3:0]slave_5 = 4'b0101;
    parameter [3:0]slave_6 = 4'b0110;
    parameter [3:0]slave_7 = 4'b0111;

    parameter [1:0]grant0 = 2'h0;
    parameter [1:0]grant1 = 2'h1;
    parameter [1:0]grant2 = 2'h2;
    parameter [1:0]grant3 = 2'h3;

    wire[3:0] req;
    reg[1:0] grant;



    assign req = {m3_req_i, m2_req_i, m1_req_i, m0_req_i};




    always @ (*) begin
        if (req[3]) begin
            grant = grant3;
            hold_flag_o = `WJE_HoldEnable;
        end else if (req[0]) begin
            grant = grant0;
            hold_flag_o = `WJE_HoldEnable;
        end else if (req[2]) begin
            grant = grant2;
            hold_flag_o = `WJE_HoldEnable;
        end else begin
            grant = grant1;
            hold_flag_o = `WJE_HoldDisable;
        end
    end


    always @ (*) begin
        m0_data_o = `WJE_ZeroWord;
        m1_data_o = `WJE_INST_NOP;
        m2_data_o = `WJE_ZeroWord;
        m3_data_o = `WJE_ZeroWord;

        s0_addr_o = `WJE_ZeroWord;
        s1_addr_o = `WJE_ZeroWord;
        s2_addr_o = `WJE_ZeroWord;
        s3_addr_o = `WJE_ZeroWord;
        s4_addr_o = `WJE_ZeroWord;
        s5_addr_o = `WJE_ZeroWord;
        s0_data_o = `WJE_ZeroWord;
        s1_data_o = `WJE_ZeroWord;
        s2_data_o = `WJE_ZeroWord;
        s3_data_o = `WJE_ZeroWord;
        s4_data_o = `WJE_ZeroWord;
        s5_data_o = `WJE_ZeroWord;
        s0_we_o = `WJE_WriteDisable;
        s1_we_o = `WJE_WriteDisable;
        s2_we_o = `WJE_WriteDisable;
        s3_we_o = `WJE_WriteDisable;
        s4_we_o = `WJE_WriteDisable;
        s5_we_o = `WJE_WriteDisable;

        s0_req_o = `WJE_RIB_NREQ;
        s1_req_o = `WJE_RIB_NREQ;
        s2_req_o = `WJE_RIB_NREQ;
        s3_req_o = `WJE_RIB_NREQ;
        s4_req_o = `WJE_RIB_NREQ;
        s5_req_o = `WJE_RIB_NREQ;

        case (grant)
            grant0: begin
                case (m0_addr_i[31:28])

                    slave_0: begin
                        s0_we_o = m0_we_i;
                        s0_req_o = `WJE_RIB_REQ;
                        s0_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s0_data_o = m0_data_i;
                        m0_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_we_o = m0_we_i;
                        s1_req_o = `WJE_RIB_REQ;
                        s1_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s1_data_o = m0_data_i;
                        m0_data_o = s1_data_i;
                    end
//                    slave_2: begin





                    slave_7: begin
                        s2_we_o = m0_we_i;
                        s2_req_o = `WJE_RIB_REQ;
                        s2_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s2_data_o = m0_data_i;
                        m0_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m0_we_i;
                        s3_req_o = `WJE_RIB_REQ;
                        s3_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s3_data_o = m0_data_i;
                        m0_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m0_we_i;
                        s4_req_o = `WJE_RIB_REQ;
                        s4_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s4_data_o = m0_data_i;
                        m0_data_o = s4_data_i;
                    end
                    slave_6: begin
                        s5_we_o = m0_we_i;
                        s5_req_o = `WJE_RIB_REQ;
                        s5_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s5_data_o = m0_data_i;
                        m0_data_o = s5_data_i;
                    end
                    default: begin

                    end
                endcase
            end
            grant1: begin
                case (m1_addr_i[31:28])

                    slave_0: begin
                        s0_we_o = m1_we_i;
                        s0_req_o = `WJE_RIB_REQ;
                        s0_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s0_data_o = m1_data_i;
                        m1_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_we_o = m1_we_i;
                        s1_req_o = `WJE_RIB_REQ;
                        s1_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s1_data_o = m1_data_i;
                        m1_data_o = s1_data_i;
                    end
//                    slave_2: begin





                    slave_7: begin
                        s2_we_o = m1_we_i;
                        s2_req_o = `WJE_RIB_REQ;
                        s2_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s2_data_o = m1_data_i;
                        m1_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m1_we_i;
                        s3_req_o = `WJE_RIB_REQ;
                        s3_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s3_data_o = m1_data_i;
                        m1_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m1_we_i;
                        s4_req_o = `WJE_RIB_REQ;
                        s4_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s4_data_o = m1_data_i;
                        m1_data_o = s4_data_i;
                    end
                    slave_6: begin
                        s5_we_o = m1_we_i;
                        s5_req_o = `WJE_RIB_REQ;
                        s5_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s5_data_o = m1_data_i;
                        m1_data_o = s5_data_i;
                    end
                    default: begin

                    end
                endcase
            end
            grant2: begin
                case (m2_addr_i[31:28])

                    slave_0: begin
                        s0_we_o = m2_we_i;
                        s0_req_o = `WJE_RIB_REQ;
                        s0_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s0_data_o = m2_data_i;
                        m2_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_we_o = m2_we_i;
                        s1_req_o = `WJE_RIB_REQ;
                        s1_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s1_data_o = m2_data_i;
                        m2_data_o = s1_data_i;
                    end
//                    slave_2: begin





                    slave_7: begin
                        s2_we_o = m2_we_i;
                        s2_req_o = `WJE_RIB_REQ;
                        s2_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s2_data_o = m2_data_i;
                        m2_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m2_we_i;
                        s3_req_o = `WJE_RIB_REQ;
                        s3_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s3_data_o = m2_data_i;
                        m2_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m2_we_i;
                        s4_req_o = `WJE_RIB_REQ;
                        s4_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s4_data_o = m2_data_i;
                        m2_data_o = s4_data_i;
                    end
                    slave_6: begin
                        s5_we_o = m2_we_i;
                        s5_req_o = `WJE_RIB_REQ;
                        s5_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s5_data_o = m2_data_i;
                        m2_data_o = s5_data_i;
                    end
                    default: begin

                    end
                endcase
            end
            grant3: begin
                case (m3_addr_i[31:28])

                    slave_0: begin
                        s0_we_o = m3_we_i;
                        s0_req_o = `WJE_RIB_REQ;
                        s0_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s0_data_o = m3_data_i;
                        m3_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_we_o = m3_we_i;
                        s1_req_o = `WJE_RIB_REQ;
                        s1_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s1_data_o = m3_data_i;
                        m3_data_o = s1_data_i;
                    end
//                    slave_2: begin





                    slave_7: begin
                        s2_we_o = m3_we_i;
                        s2_req_o = `WJE_RIB_REQ;
                        s2_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s2_data_o = m3_data_i;
                        m3_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m3_we_i;
                        s3_req_o = `WJE_RIB_REQ;
                        s3_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s3_data_o = m3_data_i;
                        m3_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m3_we_i;
                        s4_req_o = `WJE_RIB_REQ;
                        s4_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s4_data_o = m3_data_i;
                        m3_data_o = s4_data_i;
                    end
                    slave_6: begin
                        s5_we_o = m3_we_i;
                        s5_req_o = `WJE_RIB_REQ;
                        s5_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s5_data_o = m3_data_i;
                        m3_data_o = s5_data_i;
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
