`include "../rtl/core/defines.v"

module bridge_fpga(
    input wire clk,
    input wire rst,

    input wire[7:0] chip_data_i,
    output reg[7:0] chip_data_o,

    input wire dbg_we_i,
    input wire[`MemAddrBus] dbg_addr_i,
    input wire[`MemBus] dbg_wdata_i
    );

    localparam REQ_SOF = 8'ha5;
    localparam RESP_SOF = 8'h5a;
    localparam CMD_READ = 8'h01;
    localparam CMD_WRITE = 8'h02;
    localparam STATUS_OK = 8'h00;
    localparam STATUS_BAD_CHECKSUM = 8'he1;
    localparam STATUS_BAD_ADDRESS = 8'he2;
    localparam STATUS_BAD_COMMAND = 8'he3;

    localparam S_IDLE = 5'd0;
    localparam S_RECV_CMD = 5'd1;
    localparam S_RECV_ADDR3 = 5'd2;
    localparam S_RECV_ADDR2 = 5'd3;
    localparam S_RECV_ADDR1 = 5'd4;
    localparam S_RECV_ADDR0 = 5'd5;
    localparam S_RECV_DATA3 = 5'd6;
    localparam S_RECV_DATA2 = 5'd7;
    localparam S_RECV_DATA1 = 5'd8;
    localparam S_RECV_DATA0 = 5'd9;
    localparam S_RECV_BYTEEN = 5'd10;
    localparam S_RECV_CSUM = 5'd11;
    localparam S_EXEC = 5'd12;
    localparam S_RESP_SOF = 5'd13;
    localparam S_RESP_STATUS = 5'd14;
    localparam S_RESP_DATA3 = 5'd15;
    localparam S_RESP_DATA2 = 5'd16;
    localparam S_RESP_DATA1 = 5'd17;
    localparam S_RESP_DATA0 = 5'd18;
    localparam S_RESP_CSUM = 5'd19;

    reg[4:0] state;
    reg[7:0] cmd;
    reg[`MemAddrBus] addr;
    reg[`MemBus] wdata;
    reg[7:0] byteen;
    reg[7:0] req_checksum;
    reg[7:0] status;
    reg[`MemBus] rdata;
    reg[`MemBus] rom_rdata;
    reg[`MemBus] ram_rdata;
    reg[`MemBus] write_word;

    (* ram_style = "distributed" *)
    reg[`MemBus] rom_mem[0:`RomNum - 1];
    (* ram_style = "distributed" *)
    reg[`MemBus] ram_mem[0:`MemNum - 1];

    wire[7:0] calc_req_checksum = cmd ^ addr[31:24] ^ addr[23:16] ^
                                   addr[15:8] ^ addr[7:0] ^
                                   wdata[31:24] ^ wdata[23:16] ^
                                   wdata[15:8] ^ wdata[7:0] ^
                                   byteen;
    wire[7:0] resp_checksum = status ^ rdata[31:24] ^ rdata[23:16] ^
                               rdata[15:8] ^ rdata[7:0];

    wire addr_is_rom = (addr[31:28] == 4'h0);
    wire addr_is_ram = (addr[31:28] == 4'h1);
    wire dbg_addr_is_rom = (dbg_addr_i[31:28] == 4'h0);
    wire dbg_addr_is_ram = (dbg_addr_i[31:28] == 4'h1);
    wire packet_ok = (req_checksum == calc_req_checksum);
    wire cmd_is_write = (cmd == CMD_WRITE);
    wire normal_write = (state == S_EXEC) && packet_ok && cmd_is_write &&
                        (addr_is_rom || addr_is_ram);
    wire rom_we = ((dbg_we_i == `WriteEnable) && dbg_addr_is_rom) ||
                  ((dbg_we_i != `WriteEnable) && normal_write && addr_is_rom);
    wire ram_we = ((dbg_we_i == `WriteEnable) && dbg_addr_is_ram) ||
                  ((dbg_we_i != `WriteEnable) && normal_write && addr_is_ram);
    wire[7:0] rom_waddr = (dbg_we_i == `WriteEnable) ? dbg_addr_i[9:2] : addr[9:2];
    wire[3:0] ram_waddr = (dbg_we_i == `WriteEnable) ? dbg_addr_i[5:2] : addr[5:2];
    wire[`MemBus] rom_wdata = (dbg_we_i == `WriteEnable) ? dbg_wdata_i : write_word;
    wire[`MemBus] ram_wdata = (dbg_we_i == `WriteEnable) ? dbg_wdata_i : write_word;
    wire[`MemBus] read_word = addr_is_rom ? rom_rdata :
                               (addr_is_ram ? ram_rdata : `ZeroWord);

    always @ (*) begin
        write_word = read_word;
        if (byteen[0] == 1'b1) begin
            write_word[7:0] = wdata[7:0];
        end
        if (byteen[1] == 1'b1) begin
            write_word[15:8] = wdata[15:8];
        end
        if (byteen[2] == 1'b1) begin
            write_word[23:16] = wdata[23:16];
        end
        if (byteen[3] == 1'b1) begin
            write_word[31:24] = wdata[31:24];
        end
    end

    always @ (posedge clk) begin
        if (rom_we == `WriteEnable) begin
            rom_mem[rom_waddr] <= rom_wdata;
        end
        rom_rdata <= rom_mem[addr[9:2]];
    end

    always @ (posedge clk) begin
        if (ram_we == `WriteEnable) begin
            ram_mem[ram_waddr] <= ram_wdata;
        end
        ram_rdata <= ram_mem[addr[5:2]];
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state <= S_IDLE;
            cmd <= 8'h0;
            addr <= `ZeroWord;
            wdata <= `ZeroWord;
            byteen <= 8'h0;
            req_checksum <= 8'h0;
            status <= STATUS_OK;
            rdata <= `ZeroWord;
            chip_data_o <= 8'h00;
        end else begin
            chip_data_o <= 8'h00;

            case (state)
                S_IDLE: begin
                    status <= STATUS_OK;
                    rdata <= `ZeroWord;
                    if (chip_data_i == REQ_SOF) begin
                        state <= S_RECV_CMD;
                    end
                end
                S_RECV_CMD: begin
                    cmd <= chip_data_i;
                    state <= S_RECV_ADDR3;
                end
                S_RECV_ADDR3: begin
                    addr[31:24] <= chip_data_i;
                    state <= S_RECV_ADDR2;
                end
                S_RECV_ADDR2: begin
                    addr[23:16] <= chip_data_i;
                    state <= S_RECV_ADDR1;
                end
                S_RECV_ADDR1: begin
                    addr[15:8] <= chip_data_i;
                    state <= S_RECV_ADDR0;
                end
                S_RECV_ADDR0: begin
                    addr[7:0] <= chip_data_i;
                    state <= S_RECV_DATA3;
                end
                S_RECV_DATA3: begin
                    wdata[31:24] <= chip_data_i;
                    state <= S_RECV_DATA2;
                end
                S_RECV_DATA2: begin
                    wdata[23:16] <= chip_data_i;
                    state <= S_RECV_DATA1;
                end
                S_RECV_DATA1: begin
                    wdata[15:8] <= chip_data_i;
                    state <= S_RECV_DATA0;
                end
                S_RECV_DATA0: begin
                    wdata[7:0] <= chip_data_i;
                    state <= S_RECV_BYTEEN;
                end
                S_RECV_BYTEEN: begin
                    byteen <= chip_data_i;
                    state <= S_RECV_CSUM;
                end
                S_RECV_CSUM: begin
                    req_checksum <= chip_data_i;
                    state <= S_EXEC;
                end
                S_EXEC: begin
                    if (req_checksum != calc_req_checksum) begin
                        status <= STATUS_BAD_CHECKSUM;
                        rdata <= `ZeroWord;
                    end else if ((addr[31:28] != 4'h0) && (addr[31:28] != 4'h1)) begin
                        status <= STATUS_BAD_ADDRESS;
                        rdata <= `ZeroWord;
                    end else if (cmd == CMD_READ) begin
                        status <= STATUS_OK;
                        rdata <= read_word;
                    end else if (cmd == CMD_WRITE) begin
                        status <= STATUS_OK;
                        rdata <= `ZeroWord;
                        if (addr[31:28] == 4'h0) begin
                            rom_mem[addr[9:2]] <= write_word;
                        end else begin
                            ram_mem[addr[5:2]] <= write_word;
                        end
                    end else begin
                        status <= STATUS_BAD_COMMAND;
                        rdata <= `ZeroWord;
                    end
                    state <= S_RESP_SOF;
                end
                S_RESP_SOF: begin
                    chip_data_o <= RESP_SOF;
                    state <= S_RESP_STATUS;
                end
                S_RESP_STATUS: begin
                    chip_data_o <= status;
                    state <= S_RESP_DATA3;
                end
                S_RESP_DATA3: begin
                    chip_data_o <= rdata[31:24];
                    state <= S_RESP_DATA2;
                end
                S_RESP_DATA2: begin
                    chip_data_o <= rdata[23:16];
                    state <= S_RESP_DATA1;
                end
                S_RESP_DATA1: begin
                    chip_data_o <= rdata[15:8];
                    state <= S_RESP_DATA0;
                end
                S_RESP_DATA0: begin
                    chip_data_o <= rdata[7:0];
                    state <= S_RESP_CSUM;
                end
                S_RESP_CSUM: begin
                    chip_data_o <= resp_checksum;
                    state <= S_IDLE;
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
