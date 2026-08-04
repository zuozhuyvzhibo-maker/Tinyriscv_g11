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
module sy_bridge(

    input wire clk,
    input wire rst,

    input wire rom_req_i,
    input wire rom_we_i,
    input wire[`SY_MemAddrBus] rom_addr_i,
    input wire[`SY_MemBus] rom_data_i,
    output wire[`SY_MemBus] rom_data_o,
    output wire[`SY_Hold_Flag_Bus] rom_hold_o,

    input wire ram_req_i,
    input wire ram_we_i,
    input wire[3:0] ram_byte_en_i,
    input wire[`SY_MemAddrBus] ram_addr_i,
    input wire[`SY_MemBus] ram_data_i,
    output wire[`SY_MemBus] ram_data_o,
    output wire[`SY_Hold_Flag_Bus] ram_hold_o,

    input wire[7:0] bridge_data_i,
    output reg[7:0] bridge_data_o

    );

    localparam TARGET_ROM = 1'b0;
    localparam TARGET_RAM = 1'b1;

    localparam FRAME_IDLE  = 8'h00;
    localparam FRAME_START = 8'ha5;
    localparam FRAME_ACK   = 8'h5a;

    localparam S_IDLE     = 4'h0;
    localparam S_SEND_CTL = 4'h1;
    localparam S_SEND_ADR = 4'h2;
    localparam S_SEND_D0  = 4'h3;
    localparam S_SEND_D1  = 4'h4;
    localparam S_SEND_D2  = 4'h5;
    localparam S_SEND_D3  = 4'h6;
    localparam S_WAIT_ACK = 4'h7;
    localparam S_RECV_D0  = 4'h8;
    localparam S_RECV_D1  = 4'h9;
    localparam S_RECV_D2  = 4'ha;
    localparam S_RECV_D3  = 4'hb;

    reg[3:0] state;
    reg target;
    reg we;
    reg[7:0] addr;
    reg[31:0] wdata;
    reg[3:0] byte_en;
    reg[31:0] rdata;
    reg done;
    reg done_wait;

    reg last_target;
    reg last_we;
    reg[7:0] last_addr;
    reg[31:0] last_wdata;
    reg[3:0] last_byte_en;

    wire req = rom_req_i | ram_req_i;
    wire req_target = ram_req_i? TARGET_RAM: TARGET_ROM;
    wire req_we = ram_req_i? ram_we_i: rom_we_i;
    wire[`SY_MemAddrBus] req_addr = ram_req_i? ram_addr_i: rom_addr_i;
    wire[`SY_MemBus] req_wdata = ram_req_i? ram_data_i: rom_data_i;
    wire[3:0] req_byte_en = ram_req_i ? ram_byte_en_i : 4'b1111;
    wire[7:0] req_word_addr = req_addr[9:2];

    wire same_req = done &&
                    (last_target == req_target) &&
                    (last_we == req_we) &&
                    (last_addr == req_word_addr) &&
                    ((req_we == `SY_WriteDisable) ||
                     ((last_wdata == req_wdata) &&
                      (last_byte_en == req_byte_en)));

    wire hold = req && !(same_req && (done_wait == 1'b0));

    assign rom_data_o = rdata;
    assign ram_data_o = rdata;
    assign rom_hold_o = (rom_req_i && hold)? `SY_HoldEnable: `SY_HoldDisable;
    assign ram_hold_o = (ram_req_i && hold)? `SY_HoldEnable: `SY_HoldDisable;

    always @ (posedge clk) begin
        if (rst == `SY_RstEnable) begin
            bridge_data_o <= FRAME_IDLE;
            state <= S_IDLE;
            target <= TARGET_ROM;
            we <= `SY_WriteDisable;
            addr <= 8'h0;
            wdata <= `SY_ZeroWord;
            byte_en <= 4'b1111;
            rdata <= `SY_ZeroWord;
            done <= 1'b0;
            done_wait <= 1'b0;
            last_target <= TARGET_ROM;
            last_we <= `SY_WriteDisable;
            last_addr <= 8'h0;
            last_wdata <= `SY_ZeroWord;
            last_byte_en <= 4'b1111;
        end else begin
            case (state)
                S_IDLE: begin
                    bridge_data_o <= FRAME_IDLE;
                    if (req == `SY_RIB_NREQ) begin
                        done <= 1'b0;
                        done_wait <= 1'b0;
                    end else if (same_req && done_wait) begin
                        done_wait <= 1'b0;
                    end else if (!same_req) begin
                        target <= req_target;
                        we <= req_we;
                        addr <= req_word_addr;
                        wdata <= req_wdata;
                        byte_en <= req_byte_en;
                        done <= 1'b0;
                        bridge_data_o <= FRAME_START;
                        state <= S_SEND_CTL;
                    end
                end
                S_SEND_CTL: begin
                    bridge_data_o <= {2'b00, byte_en, target, we};
                    state <= S_SEND_ADR;
                end
                S_SEND_ADR: begin
                    bridge_data_o <= addr;
                    state <= S_SEND_D0;
                end
                S_SEND_D0: begin
                    bridge_data_o <= wdata[7:0];
                    state <= S_SEND_D1;
                end
                S_SEND_D1: begin
                    bridge_data_o <= wdata[15:8];
                    state <= S_SEND_D2;
                end
                S_SEND_D2: begin
                    bridge_data_o <= wdata[23:16];
                    state <= S_SEND_D3;
                end
                S_SEND_D3: begin
                    bridge_data_o <= wdata[31:24];
                    state <= S_WAIT_ACK;
                end
                S_WAIT_ACK: begin
                    bridge_data_o <= FRAME_IDLE;
                    if (bridge_data_i == FRAME_ACK) begin
                        if (we == `SY_WriteEnable) begin
                            last_target <= target;
                            last_we <= we;
                        last_addr <= addr;
                        last_wdata <= wdata;
                        last_byte_en <= byte_en;
                        done <= 1'b1;
                        done_wait <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                            state <= S_RECV_D0;
                        end
                    end
                end
                S_RECV_D0: begin
                    rdata[7:0] <= bridge_data_i;
                    state <= S_RECV_D1;
                end
                S_RECV_D1: begin
                    rdata[15:8] <= bridge_data_i;
                    state <= S_RECV_D2;
                end
                S_RECV_D2: begin
                    rdata[23:16] <= bridge_data_i;
                    state <= S_RECV_D3;
                end
                S_RECV_D3: begin
                    rdata[31:24] <= bridge_data_i;
                    last_target <= target;
                    last_we <= we;
                    last_addr <= addr;
                    last_wdata <= wdata;
                    last_byte_en <= byte_en;
                    done <= 1'b1;
                    done_wait <= 1'b1;
                    state <= S_IDLE;
                end
                default: begin
                    bridge_data_o <= FRAME_IDLE;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

