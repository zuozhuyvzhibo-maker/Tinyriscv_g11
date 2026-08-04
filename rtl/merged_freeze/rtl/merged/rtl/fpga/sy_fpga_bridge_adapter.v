`include "sy_defs.v"

/* SY fixed-frame protocol adapter without private ROM/RAM instances. */
module sy_fpga_bridge_adapter(
    input wire clk,
    input wire rst,
    input wire[7:0] chip_data_i,
    output reg[7:0] chip_data_o,

    output wire rom_we_o,
    output wire[31:0] rom_addr_o,
    output wire[31:0] rom_wdata_o,
    output wire[3:0] rom_wstrb_o,
    input wire[31:0] rom_rdata_i,

    output wire ram_we_o,
    output wire[31:0] ram_addr_o,
    output wire[31:0] ram_wdata_o,
    output wire[3:0] ram_wstrb_o,
    input wire[31:0] ram_rdata_i
    );

    localparam TARGET_ROM = 1'b0;
    localparam TARGET_RAM = 1'b1;
    localparam FRAME_IDLE = 8'h00;
    localparam FRAME_START = 8'ha5;
    localparam FRAME_ACK = 8'h5a;

    localparam S_IDLE = 4'h0;
    localparam S_RECV_CTL = 4'h1;
    localparam S_RECV_ADR = 4'h2;
    localparam S_RECV_D0 = 4'h3;
    localparam S_RECV_D1 = 4'h4;
    localparam S_RECV_D2 = 4'h5;
    localparam S_RECV_D3 = 4'h6;
    localparam S_EXEC = 4'h7;
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
    reg[3:0] wstrb;

    wire[31:0] mem_rdata = (target == TARGET_RAM) ?
                            ram_rdata_i : rom_rdata_i;
    wire[31:0] merged_wdata = {
        wstrb[3] ? wdata[31:24] : mem_rdata[31:24],
        wstrb[2] ? wdata[23:16] : mem_rdata[23:16],
        wstrb[1] ? wdata[15:8]  : mem_rdata[15:8],
        wstrb[0] ? wdata[7:0]   : mem_rdata[7:0]
    };

    assign rom_we_o = rom_we;
    assign ram_we_o = ram_we;
    assign rom_addr_o = {22'h0, addr, 2'b00};
    assign ram_addr_o = {26'h0, addr[3:0], 2'b00};
    assign rom_wdata_o = merged_wdata;
    assign ram_wdata_o = merged_wdata;
    assign rom_wstrb_o = 4'b1111;
    assign ram_wstrb_o = 4'b1111;

    always @ (posedge clk) begin
        if (rst == `SY_RstEnable) begin
            chip_data_o <= FRAME_IDLE;
            state <= S_IDLE;
            target <= TARGET_ROM;
            we <= `SY_WriteDisable;
            addr <= 8'h00;
            wdata <= 32'h0000_0000;
            rdata <= 32'h0000_0000;
            rom_we <= `SY_WriteDisable;
            ram_we <= `SY_WriteDisable;
            wstrb <= 4'b1111;
        end else begin
            rom_we <= `SY_WriteDisable;
            ram_we <= `SY_WriteDisable;
            case (state)
                S_IDLE: begin
                    chip_data_o <= FRAME_IDLE;
                    if (chip_data_i == FRAME_START) state <= S_RECV_CTL;
                end
                S_RECV_CTL: begin
                    target <= chip_data_i[1];
                    we <= chip_data_i[0];
                    wstrb <= chip_data_i[5:2];
                    state <= S_RECV_ADR;
                end
                S_RECV_ADR: begin addr <= chip_data_i; state <= S_RECV_D0; end
                S_RECV_D0: begin wdata[7:0] <= chip_data_i; state <= S_RECV_D1; end
                S_RECV_D1: begin wdata[15:8] <= chip_data_i; state <= S_RECV_D2; end
                S_RECV_D2: begin wdata[23:16] <= chip_data_i; state <= S_RECV_D3; end
                S_RECV_D3: begin wdata[31:24] <= chip_data_i; state <= S_EXEC; end
                S_EXEC: begin
                    chip_data_o <= FRAME_ACK;
                    rdata <= mem_rdata;
                    if (we == `SY_WriteEnable) begin
                        if (target == TARGET_RAM) ram_we <= `SY_WriteEnable;
                        else rom_we <= `SY_WriteEnable;
                        state <= S_IDLE;
                    end else begin
                        state <= S_SEND_D0;
                    end
                end
                S_SEND_D0: begin chip_data_o <= rdata[7:0]; state <= S_SEND_D1; end
                S_SEND_D1: begin chip_data_o <= rdata[15:8]; state <= S_SEND_D2; end
                S_SEND_D2: begin chip_data_o <= rdata[23:16]; state <= S_SEND_D3; end
                S_SEND_D3: begin chip_data_o <= rdata[31:24]; state <= S_IDLE; end
                default: begin chip_data_o <= FRAME_IDLE; state <= S_IDLE; end
            endcase
        end
    end

endmodule
