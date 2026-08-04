 /*
 Copyright 2026

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

// Chip-side bridge. It converts RIB ROM/RAM accesses into a fixed
// byte-wide synchronous protocol to the external FPGA bridge.
// WJE-prefixed private RTL module for the four-core integration.
module wje_bridge(

    input wire clk,
    input wire rst,

    // RIB slave0/ROM side
    input wire rom_req_i,
    input wire rom_we_i,
    input wire[`WJE_MemAddrBus] rom_addr_i,
    input wire[`WJE_MemBus] rom_data_i,
    output reg[`WJE_MemBus] rom_data_o,
    output reg rom_resp_valid_o,
    output reg[`WJE_MemAddrBus] rom_resp_addr_o,

    // RIB slave1/RAM side
    input wire ram_req_i,
    input wire ram_we_i,
    input wire[3:0] ram_byte_en_i,
    input wire[`WJE_MemAddrBus] ram_addr_i,
    input wire[`WJE_MemBus] ram_data_i,
    output reg[`WJE_MemBus] ram_data_o,

    // Chip-to-FPGA fixed 8-bit synchronous protocol

    input wire[7:0] fpga_data_i,
    output reg[7:0] fpga_data_o,

    output wire busy_o

    );

    localparam[7:0] CMD_ROM_RD  = 8'h11;
    localparam[7:0] CMD_ROM_WR  = 8'h12;
    localparam[7:0] CMD_RAM_RD  = 8'h21;
    localparam[7:0] CMD_RAM_WR  = 8'h22;
    localparam[3:0] CMD_RAM_WR_MASK = 4'h3;
    localparam[7:0] RESP_READ   = 8'h81;
    localparam[7:0] RESP_WRITE  = 8'h82;

    localparam TARGET_ROM = 1'b0;
    localparam TARGET_RAM = 1'b1;

    localparam[3:0] S_IDLE      = 4'd0;
    localparam[3:0] S_TX_CMD    = 4'd1;
    localparam[3:0] S_TX_ADDR3  = 4'd2;
    localparam[3:0] S_TX_ADDR2  = 4'd3;
    localparam[3:0] S_TX_ADDR1  = 4'd4;
    localparam[3:0] S_TX_ADDR0  = 4'd5;
    localparam[3:0] S_TX_DATA3  = 4'd6;
    localparam[3:0] S_TX_DATA2  = 4'd7;
    localparam[3:0] S_TX_DATA1  = 4'd8;
    localparam[3:0] S_TX_DATA0  = 4'd9;
    localparam[3:0] S_WAIT_RESP = 4'd10;
    localparam[3:0] S_RX_DATA3  = 4'd11;
    localparam[3:0] S_RX_DATA2  = 4'd12;
    localparam[3:0] S_RX_DATA1  = 4'd13;
    localparam[3:0] S_RX_DATA0  = 4'd14;
    localparam[3:0] S_DONE      = 4'd15;

    reg[3:0] state;
    reg target;
    reg req_we;
    reg[`WJE_MemAddrBus] addr;
    reg[`WJE_MemBus] wdata;
    reg[`WJE_MemBus] rdata;

    wire start_req = rom_req_i | ram_req_i;

    assign busy_o = ((state != S_IDLE) && (state != S_DONE)) ||
                    ((state == S_IDLE) && start_req);

    localparam[3:0] REQ_READ_CHUNKS  = 4'd7;
    localparam[3:0] REQ_WRITE_CHUNKS = 4'd12;
    localparam[3:0] RESP_HEAD_CHUNKS = 4'd2;
    localparam[3:0] RESP_READ_CHUNKS = 4'd7;

    wire[5:0] fpga_payload_i = fpga_data_i[5:0];
    wire fpga_req_toggle_i = fpga_data_i[6];
    wire fpga_ack_toggle_i = fpga_data_i[7];

    reg[71:0] tx_frame;
    reg[3:0] tx_chunks_total;
    reg[3:0] tx_chunk_index;
    reg[5:0] tx_payload;
    reg tx_req_toggle;
    reg tx_wait_ack;

    reg fpga_ack_meta;
    reg fpga_ack_sync;
    reg fpga_req_meta;
    reg fpga_req_sync;
    reg fpga_req_sync_d;
    reg rx_ack_toggle;
    reg rx_ack_pending;
    reg[3:0] rx_chunk_index;
    reg[5:0] rx_chunk0;
    reg[5:0] rx_chunk1;
    reg[5:0] rx_chunk2;
    reg[5:0] rx_chunk3;
    reg[5:0] rx_chunk4;
    reg[5:0] rx_chunk5;
    reg[5:0] rx_chunk6;

    wire rx_chunk_valid = (fpga_req_sync != fpga_req_sync_d);
    wire tx_ack_done = (tx_wait_ack == 1'b1) && (fpga_ack_sync == tx_req_toggle);
    wire[7:0] rx_resp_byte = {rx_chunk0, fpga_payload_i[5:4]};
    wire[31:0] rx_read_data = {rx_chunk1[3:0], rx_chunk2, rx_chunk3, rx_chunk4, rx_chunk5, fpga_payload_i[5:2]};

    function [5:0] get_tx_chunk;
        input[71:0] frame;
        input[3:0] chunk_index;
        begin
            case (chunk_index)
                4'd0: get_tx_chunk = frame[71:66];
                4'd1: get_tx_chunk = frame[65:60];
                4'd2: get_tx_chunk = frame[59:54];
                4'd3: get_tx_chunk = frame[53:48];
                4'd4: get_tx_chunk = frame[47:42];
                4'd5: get_tx_chunk = frame[41:36];
                4'd6: get_tx_chunk = frame[35:30];
                4'd7: get_tx_chunk = frame[29:24];
                4'd8: get_tx_chunk = frame[23:18];
                4'd9: get_tx_chunk = frame[17:12];
                4'd10: get_tx_chunk = frame[11:6];
                4'd11: get_tx_chunk = frame[5:0];
                default: get_tx_chunk = 6'h00;
            endcase
        end
    endfunction

//
//                S_IDLE: begin
//
//                S_TX_CMD: begin
//
//                S_TX_ADDR3: begin
//
//                S_TX_ADDR2: begin
//
//                S_TX_ADDR1: begin
//
//                S_TX_ADDR0: begin
//
//                S_TX_DATA3: begin
//
//                S_TX_DATA2: begin
//
//                S_TX_DATA1: begin
//
//                S_TX_DATA0: begin
//
//                S_WAIT_RESP: begin
//
//                S_RX_DATA3: begin
//                    rdata[31:24] <= fpga_data_i;
//
//                S_RX_DATA2: begin
//                    rdata[23:16] <= fpga_data_i;
//
//                S_RX_DATA1: begin
//                    rdata[15:8] <= fpga_data_i;
//
//                S_RX_DATA0: begin
//                    rdata[7:0] <= fpga_data_i;
//
//                S_DONE: begin
//

    always @ (posedge clk) begin
        if (rst == `WJE_RstEnable) begin
            state <= S_IDLE;
            target <= TARGET_ROM;
            req_we <= `WJE_WriteDisable;
            addr <= `WJE_ZeroWord;
            wdata <= `WJE_ZeroWord;
            rdata <= `WJE_ZeroWord;
            rom_data_o <= `WJE_ZeroWord;
            rom_resp_valid_o <= 1'b0;
            rom_resp_addr_o <= `WJE_ZeroWord;
            ram_data_o <= `WJE_ZeroWord;
            fpga_data_o <= 8'h00;
            tx_frame <= 72'h0;
            tx_chunks_total <= 4'h0;
            tx_chunk_index <= 4'h0;
            tx_payload <= 6'h00;
            tx_req_toggle <= 1'b0;
            tx_wait_ack <= 1'b0;
            fpga_ack_meta <= 1'b0;
            fpga_ack_sync <= 1'b0;
            fpga_req_meta <= 1'b0;
            fpga_req_sync <= 1'b0;
            fpga_req_sync_d <= 1'b0;
            rx_ack_toggle <= 1'b0;
            rx_ack_pending <= 1'b0;
            rx_chunk_index <= 4'h0;
            rx_chunk0 <= 6'h00;
            rx_chunk1 <= 6'h00;
            rx_chunk2 <= 6'h00;
            rx_chunk3 <= 6'h00;
            rx_chunk4 <= 6'h00;
            rx_chunk5 <= 6'h00;
            rx_chunk6 <= 6'h00;
        end else begin
            fpga_ack_meta <= fpga_ack_toggle_i;
            fpga_ack_sync <= fpga_ack_meta;
            fpga_req_meta <= fpga_req_toggle_i;
            fpga_req_sync <= fpga_req_meta;
            fpga_req_sync_d <= fpga_req_sync;
            fpga_data_o <= {rx_ack_toggle, tx_req_toggle, tx_payload};
            rom_resp_valid_o <= 1'b0;

            if (rx_ack_pending == 1'b1) begin
                rx_ack_toggle <= fpga_req_sync;
                rx_ack_pending <= 1'b0;
            end else if (rx_chunk_valid == 1'b1) begin
                rx_ack_pending <= 1'b1;
            end

            case (state)
                S_IDLE: begin
                    rdata <= `WJE_ZeroWord;
                    tx_wait_ack <= 1'b0;
                    tx_chunk_index <= 4'h0;
                    rx_chunk_index <= 4'h0;
                    if (ram_req_i == `WJE_RIB_REQ) begin
                        target <= TARGET_RAM;
                        req_we <= ram_we_i;
                        addr <= ram_addr_i;
                        wdata <= ram_data_i;
                        if (ram_we_i == `WJE_WriteEnable) begin
                            // 0x3m carries the four byte lanes in m. The
                            // FPGA adapter merges those lanes and performs
                            // one full-word write to the shared RAM.
                            tx_frame <= {{CMD_RAM_WR_MASK, ram_byte_en_i},
                                         ram_addr_i, ram_data_i};
                            tx_chunks_total <= REQ_WRITE_CHUNKS;
                        end else begin
                            tx_frame <= {CMD_RAM_RD, ram_addr_i, 2'b00, 30'h0};
                            tx_chunks_total <= REQ_READ_CHUNKS;
                        end
                        state <= S_TX_CMD;
                    end else if (rom_req_i == `WJE_RIB_REQ) begin
                        target <= TARGET_ROM;
                        req_we <= rom_we_i;
                        addr <= rom_addr_i;
                        wdata <= rom_data_i;
                        if (rom_we_i == `WJE_WriteEnable) begin
                            tx_frame <= {CMD_ROM_WR, rom_addr_i, rom_data_i};
                            tx_chunks_total <= REQ_WRITE_CHUNKS;
                        end else begin
                            tx_frame <= {CMD_ROM_RD, rom_addr_i, 2'b00, 30'h0};
                            tx_chunks_total <= REQ_READ_CHUNKS;
                        end
                        state <= S_TX_CMD;
                    end
                end

                S_TX_CMD: begin
                    if (tx_wait_ack == 1'b0) begin
                        tx_payload <= get_tx_chunk(tx_frame, tx_chunk_index);
                        tx_req_toggle <= ~tx_req_toggle;
                        tx_wait_ack <= 1'b1;
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin
                            rx_chunk_index <= 4'h0;
                            state <= S_WAIT_RESP;
                        end
                    end else if (tx_ack_done == 1'b1) begin
                        tx_wait_ack <= 1'b0;
                        if (tx_chunk_index == (tx_chunks_total - 1'b1)) begin
                            tx_chunk_index <= 4'h0;
                            rx_chunk_index <= 4'h0;
                            state <= S_WAIT_RESP;
                        end else begin
                            tx_chunk_index <= tx_chunk_index + 1'b1;
                        end
                    end
                end

                S_WAIT_RESP: begin
                    if ((tx_wait_ack == 1'b1) && (tx_ack_done == 1'b1)) begin
                        tx_wait_ack <= 1'b0;
                        tx_chunk_index <= 4'h0;
                    end
                    if (rx_chunk_valid == 1'b1) begin
                        if (rx_chunk_index == 4'd0) begin
                            rx_chunk0 <= fpga_payload_i;
                            rx_chunk_index <= 4'd1;
                        end else if (rx_chunk_index == 4'd1) begin
                            rx_chunk1 <= fpga_payload_i;
                            if (rx_resp_byte == RESP_READ) begin
                                rx_chunk_index <= RESP_HEAD_CHUNKS;
                                state <= S_RX_DATA3;
                            end else if (rx_resp_byte == RESP_WRITE) begin
                                rx_chunk_index <= 4'h0;
                                state <= S_DONE;
                            end else begin
                                rx_chunk_index <= 4'h0;
                            end
                        end else begin
                            rx_chunk_index <= 4'h0;
                        end
                    end
                end

                S_RX_DATA3: begin
                    if (rx_chunk_valid == 1'b1) begin
                        case (rx_chunk_index)
                            4'd2: begin
                                rx_chunk2 <= fpga_payload_i;
                                rx_chunk_index <= 4'd3;
                            end
                            4'd3: begin
                                rx_chunk3 <= fpga_payload_i;
                                rx_chunk_index <= 4'd4;
                            end
                            4'd4: begin
                                rx_chunk4 <= fpga_payload_i;
                                rx_chunk_index <= 4'd5;
                            end
                            4'd5: begin
                                rx_chunk5 <= fpga_payload_i;
                                rx_chunk_index <= 4'd6;
                            end
                            4'd6: begin
                                rx_chunk6 <= fpga_payload_i;
                                rdata <= rx_read_data;
                                if (target == TARGET_RAM) begin
                                    ram_data_o <= rx_read_data;
                                end else begin
                                    rom_data_o <= rx_read_data;
                                    rom_resp_valid_o <= 1'b1;
                                    rom_resp_addr_o <= addr;
                                end
                                rx_chunk_index <= 4'h0;
                                state <= S_DONE;
                            end
                            default: begin
                                rx_chunk_index <= RESP_HEAD_CHUNKS;
                            end
                        endcase
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
