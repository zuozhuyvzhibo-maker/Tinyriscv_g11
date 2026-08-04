/*
 Copyright 2026 Liudk

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0
*/

`include "ldk_defs.v"

/*
 * Request-driven I2C controller used by the LDK rT instruction.
 *
 * An LM75 read is issued as one combined transaction:
 *   START, 0x90, ACK, pointer 0x00, ACK, repeated START, 0x91, ACK,
 *   high byte, master ACK, low byte, master NACK, STOP.
 *
 * req_i may remain asserted until ack_o.  req_wait_release prevents that
 * level from starting a second transaction.  The externally visible
 * register interface is retained for compatibility with the original core.
 */
// LDK-prefixed private RTL module for the four-core integration.
module ldk_iic_dk (
    input  wire               clk,
    input  wire               rst,
    input  wire [1:0]         req_i,
    input  wire               we_i,
    input  wire [`LDK_MemAddrBus] addr_i,
    input  wire [`LDK_MemBus]     data_i,
    output wire [`LDK_MemBus]     data_o,
    output reg                ack_o,
    output wire               SCL_o,
    output wire               SDA_o,
    output wire               SDA_oe_o,
    input  wire               SDA_i
);

`ifdef IVERILOG_FAST_SIM
    localparam integer QUARTER_DIV = 2;
`else
    // CLK_DIVIDER is SYS_CLK_HZ/(4*I2C_CLK_HZ).
    localparam integer QUARTER_DIV = `LDK_CLK_DIVIDER;
`endif

    localparam [4:0] IDLE             = 5'd0;
    localparam [4:0] START            = 5'd1;
    localparam [4:0] ADDR_BYTE        = 5'd2;
    localparam [4:0] ADDR_BYTE_ACK    = 5'd3;
    localparam [4:0] POINTER_BYTE     = 5'd4;
    localparam [4:0] POINTER_BYTE_ACK = 5'd5;
    localparam [4:0] RE_START         = 5'd6;
    localparam [4:0] READ_ADDR        = 5'd7;
    localparam [4:0] READ_ADDR_ACK    = 5'd8;
    localparam [4:0] BUS_FREE         = 5'd9;
    localparam [4:0] RD_HI_BYTE       = 5'd10;
    localparam [4:0] RD_HI_BYTE_ACK   = 5'd11;
    localparam [4:0] RD_LO_BYTE       = 5'd12;
    localparam [4:0] RD_LO_BYTE_ACK   = 5'd13;
    localparam [4:0] STOP             = 5'd14;

    localparam [1:0] MAX_ATTEMPTS     = 2'd3;
    localparam [1:0] BUS_FREE_QUARTERS = 2'd2;

    reg [`LDK_MemAddrBus] addr_reg;
    reg [`LDK_MemBus] data_in_reg;
    reg [`LDK_MemBus] data_out_reg;
    reg [`LDK_MemAddrBus] transaction_addr;

    // These names are intentionally retained for waveform/debug compatibility.
    reg [4:0] iic_cs;
    reg [3:0] sda_counter;
    reg [1:0] phase;
    reg [31:0] divider_count;
    reg [7:0] tx_byte;
    reg rx_ack;
    reg iic_busy;
    reg iic_start;
    reg req_wait_release;
    reg scl_reg;
    reg sda_drive_low;
    reg transaction_nack;
    reg [1:0] attempt_count;
    reg [1:0] bus_free_count;

    wire request_valid = (req_i == `LDK_IICRead) || (req_i == `LDK_IICWrite);
    wire quarter_tick = (divider_count == (QUARTER_DIV - 1));

    assign data_o = data_out_reg;
    assign SCL_o = scl_reg;
    // The integration wrapper converts this pair to an open-drain pin.
    assign SDA_o = 1'b0;
    assign SDA_oe_o = sda_drive_low;

    always @(posedge clk) begin
        if (rst == `LDK_RstEnable) begin
            addr_reg <= 32'h0000_0091;
            data_in_reg <= `LDK_ZeroWord;
        end else if (we_i == `LDK_WriteEnable) begin
            case (addr_i[17:16])
                2'b01: addr_reg <= data_i;
                2'b11: data_in_reg <= data_i;
                default: begin
                    addr_reg <= addr_reg;
                    data_in_reg <= data_in_reg;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst == `LDK_RstEnable) begin
            iic_cs <= IDLE;
            phase <= 2'd0;
            divider_count <= 32'd0;
            sda_counter <= 4'd0;
            tx_byte <= 8'h00;
            rx_ack <= 1'b1;
            iic_busy <= 1'b0;
            iic_start <= 1'b0;
            req_wait_release <= 1'b0;
            scl_reg <= 1'b1;
            sda_drive_low <= 1'b0;
            data_out_reg <= `LDK_ZeroWord;
            transaction_addr <= 32'h0000_0091;
            transaction_nack <= 1'b0;
            attempt_count <= 2'd0;
            bus_free_count <= 2'd0;
            ack_o <= `LDK_AckDisable;
        end else begin
            ack_o <= `LDK_AckDisable;
            iic_start <= 1'b0;

            if (!request_valid)
                req_wait_release <= 1'b0;

            if (iic_cs == IDLE) begin
                divider_count <= 32'd0;
                phase <= 2'd0;
                scl_reg <= 1'b1;
                sda_drive_low <= 1'b0;
                iic_busy <= 1'b0;
                if (request_valid && !req_wait_release) begin
                    iic_start <= 1'b1;
                    req_wait_release <= 1'b1;
                    iic_busy <= 1'b1;
                    transaction_addr <=
                        (we_i && (addr_i[17:16] == 2'b01)) ? data_i : addr_reg;
                    data_out_reg <= `LDK_ZeroWord;
                    transaction_nack <= 1'b0;
                    attempt_count <= 2'd1;
                    bus_free_count <= 2'd0;
                    iic_cs <= BUS_FREE;
                end
            end else begin
                iic_busy <= 1'b1;
                if (quarter_tick)
                    divider_count <= 32'd0;
                else
                    divider_count <= divider_count + 1'b1;

                if (quarter_tick) begin
                    case (iic_cs)
                        BUS_FREE: begin
                            scl_reg <= 1'b1;
                            sda_drive_low <= 1'b0;
                            phase <= 2'd0;
                            sda_counter <= 4'd0;
                            if (SDA_i === 1'b1) begin
                                if (bus_free_count ==
                                    (BUS_FREE_QUARTERS - 1'b1)) begin
                                    bus_free_count <= 2'd0;
                                    iic_cs <= START;
                                end else begin
                                    bus_free_count <= bus_free_count + 1'b1;
                                end
                            end else begin
                                bus_free_count <= 2'd0;
                            end
                        end

                        START: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b1;
                                    sda_drive_low <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    // SDA falling while SCL is high: START.
                                    sda_drive_low <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_reg <= 1'b0;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    tx_byte <= {transaction_addr[7:1], 1'b0};
                                    sda_counter <= 4'd0;
                                    phase <= 2'd0;
                                    iic_cs <= ADDR_BYTE;
                                end
                            endcase
                        end

                        ADDR_BYTE, POINTER_BYTE, READ_ADDR: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= ~tx_byte[7 - sda_counter];
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: phase <= 2'd3;
                                default: begin
                                    scl_reg <= 1'b0;
                                    phase <= 2'd0;
                                    if (sda_counter == 4'd7) begin
                                        sda_counter <= 4'd0;
                                        if (iic_cs == ADDR_BYTE)
                                            iic_cs <= ADDR_BYTE_ACK;
                                        else if (iic_cs == POINTER_BYTE)
                                            iic_cs <= POINTER_BYTE_ACK;
                                        else
                                            iic_cs <= READ_ADDR_ACK;
                                    end else begin
                                        sda_counter <= sda_counter + 1'b1;
                                    end
                                end
                            endcase
                        end

                        ADDR_BYTE_ACK, POINTER_BYTE_ACK, READ_ADDR_ACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    rx_ack <= SDA_i;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_reg <= 1'b0;
                                    phase <= 2'd0;
                                    if (rx_ack != 1'b0) begin
                                        transaction_nack <= 1'b1;
                                        iic_cs <= STOP;
                                    end else if (iic_cs == ADDR_BYTE_ACK) begin
                                        tx_byte <= 8'h00;
                                        iic_cs <= POINTER_BYTE;
                                    end else if (iic_cs == POINTER_BYTE_ACK) begin
                                        iic_cs <= RE_START;
                                    end else begin
                                        sda_counter <= 4'd0;
                                        iic_cs <= RD_HI_BYTE;
                                    end
                                end
                            endcase
                        end

                        RE_START: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    // SDA falling while SCL is high: repeated START.
                                    sda_drive_low <= 1'b1;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_reg <= 1'b0;
                                    tx_byte <= {transaction_addr[7:1], 1'b1};
                                    sda_counter <= 4'd0;
                                    phase <= 2'd0;
                                    iic_cs <= READ_ADDR;
                                end
                            endcase
                        end

                        RD_HI_BYTE, RD_LO_BYTE: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    if (iic_cs == RD_HI_BYTE)
                                        data_out_reg[15 - sda_counter] <= SDA_i;
                                    else
                                        data_out_reg[7 - sda_counter] <= SDA_i;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_reg <= 1'b0;
                                    phase <= 2'd0;
                                    if (sda_counter == 4'd7) begin
                                        sda_counter <= 4'd0;
                                        if (iic_cs == RD_HI_BYTE)
                                            iic_cs <= RD_HI_BYTE_ACK;
                                        else
                                            iic_cs <= RD_LO_BYTE_ACK;
                                    end else begin
                                        sda_counter <= sda_counter + 1'b1;
                                    end
                                end
                            endcase
                        end

                        RD_HI_BYTE_ACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= 1'b1;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: phase <= 2'd3;
                                default: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= 1'b0;
                                    sda_counter <= 4'd0;
                                    phase <= 2'd0;
                                    iic_cs <= RD_LO_BYTE;
                                end
                            endcase
                        end

                        RD_LO_BYTE_ACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    // Release SDA for the final NACK.
                                    sda_drive_low <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: phase <= 2'd3;
                                default: begin
                                    scl_reg <= 1'b0;
                                    phase <= 2'd0;
                                    iic_cs <= STOP;
                                end
                            endcase
                        end

                        STOP: begin
                            case (phase)
                                2'd0: begin
                                    scl_reg <= 1'b0;
                                    sda_drive_low <= 1'b1;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_reg <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    // SDA rising while SCL is high: STOP.
                                    sda_drive_low <= 1'b0;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    phase <= 2'd0;
                                    if (transaction_nack &&
                                        (attempt_count < MAX_ATTEMPTS)) begin
                                        attempt_count <= attempt_count + 1'b1;
                                        transaction_nack <= 1'b0;
                                        bus_free_count <= 2'd0;
                                        sda_counter <= 4'd0;
                                        rx_ack <= 1'b1;
                                        data_out_reg <= `LDK_ZeroWord;
                                        iic_cs <= BUS_FREE;
                                    end else begin
                                        ack_o <= `LDK_AckEnable;
                                        iic_busy <= 1'b0;
                                        attempt_count <= 2'd0;
                                        bus_free_count <= 2'd0;
                                        if (transaction_nack)
                                            data_out_reg <= `LDK_ZeroWord;
                                        transaction_nack <= 1'b0;
                                        iic_cs <= IDLE;
                                    end
                                end
                            endcase
                        end

                        default: begin
                            iic_cs <= IDLE;
                            phase <= 2'd0;
                            scl_reg <= 1'b1;
                            sda_drive_low <= 1'b0;
                            transaction_nack <= 1'b0;
                            attempt_count <= 2'd0;
                            bus_free_count <= 2'd0;
                        end
                    endcase
                end
            end
        end
    end

endmodule
