`include "ldk_defs.v"

/* LDK byte protocol adapter without a private memory array. */
module ldk_fpga_bridge_adapter(
    input wire clk,
    input wire rst,
    input wire[7:0] chip_data_i,
    output wire[7:0] chip_data_o,

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

    assign rom_wstrb_o = 4'b1111;
    assign ram_wstrb_o = 4'b1111;

    ldk_bridge_slave u_bridge_slave(
        .clk(clk),
        .rst(rst),
        .bslave_RX_data(chip_data_i),
        .bslave_TX_data(chip_data_o),
        .ram_we_o(ram_we_o),
        .ram_addr_o(ram_addr_o),
        .ram_data_o(ram_wdata_o),
        .ram_data_i(ram_rdata_i),
        .rom_we_o(rom_we_o),
        .rom_addr_o(rom_addr_o),
        .rom_data_o(rom_wdata_o),
        .rom_data_i(rom_rdata_i)
    );

endmodule
