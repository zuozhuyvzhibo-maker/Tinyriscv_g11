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

module sy_bridge_fpga(

    input wire clk,
    input wire rst,

    input wire[7:0] bridge_data_i,
    output reg[7:0] bridge_data_o

    );

    localparam TARGET_ROM = 1'b0;
    localparam TARGET_RAM = 1'b1;

    localparam FRAME_IDLE  = 8'h00;
    localparam FRAME_START = 8'ha5;
    localparam FRAME_ACK   = 8'h5a;

    localparam S_IDLE    = 4'h0;
    localparam S_RECV_CTL = 4'h1;
    localparam S_RECV_ADR = 4'h2;
    localparam S_RECV_D0 = 4'h3;
    localparam S_RECV_D1 = 4'h4;
    localparam S_RECV_D2 = 4'h5;
    localparam S_RECV_D3 = 4'h6;
    localparam S_EXEC    = 4'h7;
    localparam S_SEND_D0 = 4'h8;
    localparam S_SEND_D1 = 4'h9;
    localparam S_SEND_D2 = 4'ha;
    localparam S_SEND_D3 = 4'hb;

    reg[3:0] state;
    reg target;
    reg we;
    reg[7:0] addr;
    reg[31:0] wdata;
    reg[31:0] rdata;
    reg rom_we;
    reg ram_we;

    wire[`MemBus] rom_data;
    wire[`MemBus] ram_data;
    wire[`MemBus] mem_rdata = (target == TARGET_RAM)? ram_data: rom_data;

    sy_rom_ext u_rom_ext(
        .clk(clk),
        .rst(rst),
        .we_i(rom_we),
        .addr_i(addr),
        .data_i(wdata),
        .data_o(rom_data)
    );

    sy_ram_ext u_ram_ext(
        .clk(clk),
        .rst(rst),
        .we_i(ram_we),
        .addr_i(addr[3:0]),
        .data_i(wdata),
        .data_o(ram_data)
    );

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            bridge_data_o <= FRAME_IDLE;
            state <= S_IDLE;
            target <= TARGET_ROM;
            we <= `WriteDisable;
            addr <= 8'h0;
            wdata <= `ZeroWord;
            rdata <= `ZeroWord;
            rom_we <= `WriteDisable;
            ram_we <= `WriteDisable;
        end else begin
            rom_we <= `WriteDisable;
            ram_we <= `WriteDisable;
            case (state)
                S_IDLE: begin
                    bridge_data_o <= FRAME_IDLE;
                    if (bridge_data_i == FRAME_START) begin
                        state <= S_RECV_CTL;
                    end
                end
                S_RECV_CTL: begin
                    target <= bridge_data_i[1];
                    we <= bridge_data_i[0];
                    state <= S_RECV_ADR;
                end
                S_RECV_ADR: begin
                    addr <= bridge_data_i;
                    state <= S_RECV_D0;
                end
                S_RECV_D0: begin
                    wdata[7:0] <= bridge_data_i;
                    state <= S_RECV_D1;
                end
                S_RECV_D1: begin
                    wdata[15:8] <= bridge_data_i;
                    state <= S_RECV_D2;
                end
                S_RECV_D2: begin
                    wdata[23:16] <= bridge_data_i;
                    state <= S_RECV_D3;
                end
                S_RECV_D3: begin
                    wdata[31:24] <= bridge_data_i;
                    state <= S_EXEC;
                end
                S_EXEC: begin
                    bridge_data_o <= FRAME_ACK;
                    rdata <= mem_rdata;
                    if (we == `WriteEnable) begin
                        if (target == TARGET_RAM) begin
                            ram_we <= `WriteEnable;
                        end else begin
                            rom_we <= `WriteEnable;
                        end
                        state <= S_IDLE;
                    end else begin
                        state <= S_SEND_D0;
                    end
                end
                S_SEND_D0: begin
                    bridge_data_o <= rdata[7:0];
                    state <= S_SEND_D1;
                end
                S_SEND_D1: begin
                    bridge_data_o <= rdata[15:8];
                    state <= S_SEND_D2;
                end
                S_SEND_D2: begin
                    bridge_data_o <= rdata[23:16];
                    state <= S_SEND_D3;
                end
                S_SEND_D3: begin
                    bridge_data_o <= rdata[31:24];
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
