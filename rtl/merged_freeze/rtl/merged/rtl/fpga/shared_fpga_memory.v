/*
 * One physical FPGA memory bank shared by all four bridge protocols.
 *
 * The ROM is 256 x 32 bits.  The RAM is exactly 16 x 32 bits and uses
 * address bits [5:2], so the course software's legacy 16 KiB logical RAM
 * window aliases onto the required 16 physical words.
 */
module shared_fpga_memory(
    input wire clk,
    input wire rst,
    input wire clear_i,
    output wire ready_o,

    input wire rom_we_i,
    input wire[31:0] rom_addr_i,
    input wire[31:0] rom_wdata_i,
    input wire[3:0] rom_wstrb_i,
    output wire[31:0] rom_rdata_o,

    input wire ram_we_i,
    input wire[31:0] ram_addr_i,
    input wire[31:0] ram_wdata_i,
    input wire[3:0] ram_wstrb_i,
    output wire[31:0] ram_rdata_o
    );

    reg[31:0] rom_mem[0:255];
    reg[31:0] ram_mem[0:15];

    reg clear_active;
    reg[3:0] clear_index;

    wire[7:0] rom_index = rom_addr_i[9:2];
    wire[3:0] ram_index = ram_addr_i[5:2];

    assign ready_o = rst && !clear_i && !clear_active;
    assign rom_rdata_o = rom_mem[rom_index];
    assign ram_rdata_o = ram_mem[ram_index];

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            clear_active <= 1'b1;
            clear_index <= 4'd0;
        end else if (clear_i == 1'b1) begin
            clear_active <= 1'b1;
            clear_index <= 4'd0;
        end else if (clear_active == 1'b1) begin
            ram_mem[clear_index] <= 32'h0000_0000;
            if (clear_index == 4'd15) begin
                clear_active <= 1'b0;
                clear_index <= 4'd0;
            end else begin
                clear_index <= clear_index + 1'b1;
            end
        end else if (ram_we_i == 1'b1) begin
            if (ram_wstrb_i[0]) ram_mem[ram_index][7:0] <= ram_wdata_i[7:0];
            if (ram_wstrb_i[1]) ram_mem[ram_index][15:8] <= ram_wdata_i[15:8];
            if (ram_wstrb_i[2]) ram_mem[ram_index][23:16] <= ram_wdata_i[23:16];
            if (ram_wstrb_i[3]) ram_mem[ram_index][31:24] <= ram_wdata_i[31:24];
        end
    end

    always @ (posedge clk) begin
        if ((rst == 1'b1) && (clear_i == 1'b0) &&
            (clear_active == 1'b0) && (rom_we_i == 1'b1)) begin
            if (rom_wstrb_i[0]) rom_mem[rom_index][7:0] <= rom_wdata_i[7:0];
            if (rom_wstrb_i[1]) rom_mem[rom_index][15:8] <= rom_wdata_i[15:8];
            if (rom_wstrb_i[2]) rom_mem[rom_index][23:16] <= rom_wdata_i[23:16];
            if (rom_wstrb_i[3]) rom_mem[rom_index][31:24] <= rom_wdata_i[31:24];
        end
    end

endmodule
