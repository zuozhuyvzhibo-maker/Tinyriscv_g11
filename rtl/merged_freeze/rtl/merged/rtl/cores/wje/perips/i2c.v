/*
 Copyright 2026

 Licensed under the Apache License, Version 2.0.
 */

`include "wje_defs.v"

// I2C master peripheral.
// RIB/MMIO side:
//   0x0001_0000: slave address register, bits[6:0]
//   0x0002_0000: write data register. Writing starts one I2C write transfer.
//   0x0003_0000: read data/status register. Writing starts one I2C read transfer.
//                 Single-byte transfers keep legacy {20'h0, last_op_read, ack_error, done, busy, rx_data[7:0]}.
//                 LM75 temperature reads return {12'h0, last_op_read, ack_error, done, busy, rx_data[15:0]}.
// rT side:
//   temp_start_i starts a fixed LM75 temperature read:
//   START, LM75_ADDR+W, pointer 0x00, repeated START, LM75_ADDR+R, MSB ACK, LSB NACK, STOP.
// I2C side uses open-drain behavior: drive low or release, never drive high.
// WJE-prefixed private RTL module for the four-core integration.
module wje_i2c #(
    parameter integer CLK_DIV = 250,
    parameter [6:0] LM75_ADDR = 7'h48
)(
    input wire clk,
    input wire rst,

    input wire[`WJE_MemBus] data_i,
    input wire[`WJE_MemAddrBus] addr_i,
    input wire we_i,
    input wire req_i,

    output reg[`WJE_MemBus] data_o,

    input wire temp_start_i,
    input wire temp_accept_i,
    output wire temp_busy_o,
    output reg temp_done_o,
    output reg temp_ack_error_o,
    output reg[15:0] temp_raw_o,

    output wire i2c_scl_drive_low_o,
    input wire i2c_scl_i,
    output wire i2c_sda_drive_low_o,
    input wire i2c_sda_i
    );

    localparam REG_ADDR   = 24'h01_0000;
    localparam REG_TXDATA = 24'h02_0000;
    localparam REG_RXDATA = 24'h03_0000;

    localparam S_IDLE       = 4'd0;
    localparam S_START      = 4'd1;
    localparam S_START_HOLD = 4'd2;
    localparam S_BIT_LOW    = 4'd3;
    localparam S_BIT_HIGH   = 4'd4;
    localparam S_ACK_LOW    = 4'd5;
    localparam S_ACK_HIGH   = 4'd6;
    localparam S_STOP_LOW   = 4'd7;
    localparam S_STOP_SETUP = 4'd8;
    localparam S_STOP_REL   = 4'd9;
    localparam S_RESTART_LOW   = 4'd10;
    localparam S_RESTART_SETUP = 4'd11;
    localparam S_RESTART_START = 4'd12;

    localparam PHASE_ADDR_W   = 3'd0;
    localparam PHASE_WRITE    = 3'd1;
    localparam PHASE_ADDR_R   = 3'd2;
    localparam PHASE_READ1    = 3'd3;
    localparam PHASE_READ_MSB = 3'd4;
    localparam PHASE_READ_LSB = 3'd5;

    localparam OP_MMIO_WRITE = 2'd0;
    localparam OP_MMIO_READ1 = 2'd1;
    localparam OP_TEMP_READ  = 2'd2;

    localparam integer DIV_LIMIT = (CLK_DIV <= 1) ? 1 : CLK_DIV;

    reg scl_drive_low;
    reg sda_drive_low;

    reg[3:0] state;
    reg[2:0] byte_phase;
    reg[1:0] op_type;
    reg[15:0] div_cnt;
    reg[2:0] bit_index;
    reg[7:0] tx_shift;
    reg[7:0] rx_shift;

    reg[6:0] slave_addr;
    reg[7:0] tx_data;
    reg[15:0] rx_data;
    reg busy;
    reg done;
    reg ack_error;
    reg last_op_read;
    reg temp_wait_release;

    wire scl_in;
    wire sda_in;

    assign i2c_scl_drive_low_o = scl_drive_low;
    assign i2c_sda_drive_low_o = sda_drive_low;
    assign scl_in = i2c_scl_i;
    assign sda_in = i2c_sda_i;
    assign temp_busy_o = busy;

    wire reg_write_en = (req_i == `WJE_RIB_REQ) && (we_i == `WJE_WriteEnable);
    wire start_write_transfer = reg_write_en && (addr_i[23:0] == REG_TXDATA) && (busy == 1'b0);
    wire start_read_transfer = reg_write_en && (addr_i[23:0] == REG_RXDATA) && (busy == 1'b0);
    wire start_temp_transfer = (temp_start_i == 1'b1) &&
                               (temp_done_o == 1'b0) &&
                               (temp_wait_release == 1'b0) &&
                               (busy == 1'b0);

    wire read_phase = (byte_phase == PHASE_READ1) ||
                      (byte_phase == PHASE_READ_MSB) ||
                      (byte_phase == PHASE_READ_LSB);

    always @ (posedge clk) begin
        if (rst == `WJE_RstEnable) begin
            scl_drive_low <= 1'b0;
            sda_drive_low <= 1'b0;
            state <= S_IDLE;
            byte_phase <= PHASE_ADDR_W;
            op_type <= OP_MMIO_WRITE;
            div_cnt <= 16'h0;
            bit_index <= 3'd7;
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            slave_addr <= 7'h00;
            tx_data <= 8'h00;
            rx_data <= 16'h0000;
            busy <= 1'b0;
            done <= 1'b0;
            ack_error <= 1'b0;
            last_op_read <= 1'b0;
            temp_done_o <= 1'b0;
            temp_ack_error_o <= 1'b0;
            temp_raw_o <= 16'h0000;
            temp_wait_release <= 1'b0;
        end else begin
            if (temp_accept_i == 1'b1) begin
                temp_done_o <= 1'b0;
                temp_wait_release <= 1'b1;
            end else if ((temp_wait_release == 1'b1) &&
                         (temp_start_i == 1'b0)) begin
                // Rearm only after the completed rT instruction leaves EX.
                temp_wait_release <= 1'b0;
            end

            if (reg_write_en && (addr_i[23:0] == REG_ADDR) && (busy == 1'b0)) begin
                slave_addr <= data_i[6:0];
            end

            if (state == S_IDLE) begin
                scl_drive_low <= 1'b0;
                sda_drive_low <= 1'b0;
                div_cnt <= 16'h0;

                if (start_temp_transfer) begin
                    op_type <= OP_TEMP_READ;
                    tx_data <= 8'h00;
                    tx_shift <= {LM75_ADDR, 1'b0};
                    byte_phase <= PHASE_ADDR_W;
                    bit_index <= 3'd7;
                    busy <= 1'b1;
                    done <= 1'b0;
                    ack_error <= 1'b0;
                    last_op_read <= 1'b1;
                    temp_ack_error_o <= 1'b0;
                    state <= S_START;
                end else if (start_write_transfer) begin
                    op_type <= OP_MMIO_WRITE;
                    tx_data <= data_i[7:0];
                    tx_shift <= {slave_addr, 1'b0};
                    byte_phase <= PHASE_ADDR_W;
                    bit_index <= 3'd7;
                    busy <= 1'b1;
                    done <= 1'b0;
                    ack_error <= 1'b0;
                    last_op_read <= 1'b0;
                    state <= S_START;
                end else if (start_read_transfer) begin
                    op_type <= OP_MMIO_READ1;
                    tx_shift <= {slave_addr, 1'b1};
                    byte_phase <= PHASE_ADDR_R;
                    bit_index <= 3'd7;
                    busy <= 1'b1;
                    done <= 1'b0;
                    ack_error <= 1'b0;
                    last_op_read <= 1'b1;
                    state <= S_START;
                end
            end else begin
                if (div_cnt < (DIV_LIMIT - 1)) begin
                    div_cnt <= div_cnt + 16'd1;
                end else begin
                    div_cnt <= 16'h0;

                    case (state)
                        S_START: begin
                            scl_drive_low <= 1'b0;
                            sda_drive_low <= 1'b1;
                            state <= S_START_HOLD;
                        end

                        S_START_HOLD: begin
                            scl_drive_low <= 1'b1;
                            sda_drive_low <= 1'b1;
                            state <= S_BIT_LOW;
                        end

                        S_BIT_LOW: begin
                            scl_drive_low <= 1'b1;
                            if (read_phase == 1'b1) begin
                                sda_drive_low <= 1'b0;
                            end else begin
                                sda_drive_low <= (tx_shift[bit_index] == 1'b0);
                            end
                            state <= S_BIT_HIGH;
                        end

                        S_BIT_HIGH: begin
                            scl_drive_low <= 1'b0;
                            if (read_phase == 1'b1) begin
                                rx_shift[bit_index] <= sda_in;
                            end

                            if (bit_index == 3'd0) begin
                                state <= S_ACK_LOW;
                            end else begin
                                bit_index <= bit_index - 3'd1;
                                state <= S_BIT_LOW;
                            end
                        end

                        S_ACK_LOW: begin
                            scl_drive_low <= 1'b1;
                            if (byte_phase == PHASE_READ_MSB) begin
                                sda_drive_low <= 1'b1;
                            end else begin
                                sda_drive_low <= 1'b0;
                            end
                            state <= S_ACK_HIGH;
                        end

                        S_ACK_HIGH: begin
                            scl_drive_low <= 1'b0;

                            if ((byte_phase == PHASE_ADDR_W) || (byte_phase == PHASE_ADDR_R) ||
                                (byte_phase == PHASE_WRITE)) begin
                                if (sda_in == 1'b1) begin
                                    ack_error <= 1'b1;
                                    state <= S_STOP_LOW;
                                end else begin
                                    case (byte_phase)
                                        PHASE_ADDR_W: begin
                                            byte_phase <= PHASE_WRITE;
                                            tx_shift <= tx_data;
                                            bit_index <= 3'd7;
                                            state <= S_BIT_LOW;
                                        end
                                        PHASE_ADDR_R: begin
                                            if (op_type == OP_TEMP_READ) begin
                                                byte_phase <= PHASE_READ_MSB;
                                            end else begin
                                                byte_phase <= PHASE_READ1;
                                            end
                                            rx_shift <= 8'h00;
                                            bit_index <= 3'd7;
                                            state <= S_BIT_LOW;
                                        end
                                        default: begin
                                            if (op_type == OP_TEMP_READ) begin
                                                state <= S_RESTART_LOW;
                                            end else begin
                                                state <= S_STOP_LOW;
                                            end
                                        end
                                    endcase
                                end
                            end else begin
                                if (byte_phase == PHASE_READ_MSB) begin
                                    rx_data[15:8] <= rx_shift;
                                    byte_phase <= PHASE_READ_LSB;
                                    rx_shift <= 8'h00;
                                    bit_index <= 3'd7;
                                    state <= S_BIT_LOW;
                                end else if (byte_phase == PHASE_READ_LSB) begin
                                    rx_data[7:0] <= rx_shift;
                                    state <= S_STOP_LOW;
                                end else begin
                                    rx_data <= {8'h00, rx_shift};
                                    state <= S_STOP_LOW;
                                end
                            end
                        end

                        S_RESTART_LOW: begin
                            scl_drive_low <= 1'b1;
                            sda_drive_low <= 1'b0;
                            state <= S_RESTART_SETUP;
                        end

                        S_RESTART_SETUP: begin
                            scl_drive_low <= 1'b0;
                            sda_drive_low <= 1'b0;
                            state <= S_RESTART_START;
                        end

                        S_RESTART_START: begin
                            scl_drive_low <= 1'b0;
                            sda_drive_low <= 1'b1;
                            tx_shift <= {LM75_ADDR, 1'b1};
                            byte_phase <= PHASE_ADDR_R;
                            bit_index <= 3'd7;
                            state <= S_START_HOLD;
                        end

                        S_STOP_LOW: begin
                            scl_drive_low <= 1'b1;
                            sda_drive_low <= 1'b1;
                            state <= S_STOP_SETUP;
                        end

                        S_STOP_SETUP: begin
                            scl_drive_low <= 1'b0;
                            sda_drive_low <= 1'b1;
                            state <= S_STOP_REL;
                        end

                        S_STOP_REL: begin
                            scl_drive_low <= 1'b0;
                            sda_drive_low <= 1'b0;
                            busy <= 1'b0;
                            done <= 1'b1;
                            if (op_type == OP_TEMP_READ) begin
                                temp_done_o <= 1'b1;
                                temp_ack_error_o <= ack_error;
                                temp_raw_o <= rx_data;
                            end
                            state <= S_IDLE;
                        end

                        default: begin
                            scl_drive_low <= 1'b0;
                            sda_drive_low <= 1'b0;
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end
                    endcase
                end
            end
        end
    end

    always @ (*) begin
        if (rst == `WJE_RstEnable) begin
            data_o = `WJE_ZeroWord;
        end else begin
            case (addr_i[23:0])
                REG_ADDR: begin
                    data_o = {25'h0, slave_addr};
                end
                REG_TXDATA: begin
                    data_o = {24'h0, tx_data};
                end
                REG_RXDATA: begin
                    if (op_type == OP_TEMP_READ) begin
                        data_o = {12'h0, last_op_read, ack_error, done, busy, rx_data};
                    end else begin
                        data_o = {20'h0, last_op_read, ack_error, done, busy, rx_data[7:0]};
                    end
                end
                default: begin
                    data_o = `WJE_ZeroWord;
                end
            endcase
        end
    end

endmodule
