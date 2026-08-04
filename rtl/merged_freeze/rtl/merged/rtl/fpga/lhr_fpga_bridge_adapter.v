`include "lhr_defs.v"

/* LHR framed/checksummed protocol adapter without private ROM/RAM arrays. */
module lhr_fpga_bridge_adapter(
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
    reg[31:0] addr;
    reg[31:0] wdata;
    reg[7:0] byteen;
    reg[7:0] req_checksum;
    reg[7:0] status;
    reg[31:0] rdata;

    wire[7:0] calc_req_checksum = cmd ^ addr[31:24] ^ addr[23:16] ^
                                   addr[15:8] ^ addr[7:0] ^
                                   wdata[31:24] ^ wdata[23:16] ^
                                   wdata[15:8] ^ wdata[7:0] ^ byteen;
    wire[7:0] resp_checksum = status ^ rdata[31:24] ^ rdata[23:16] ^
                               rdata[15:8] ^ rdata[7:0];

    /* ROM is strict 1 KiB.  RAM keeps the legacy 16 KiB logical window,
       while the shared physical array aliases it through address [5:2]. */
    wire addr_is_rom = (addr < 32'h0000_0400);
    wire addr_is_ram = (addr >= 32'h1000_0000) &&
                       (addr < 32'h1000_4000);
    wire packet_ok = (req_checksum == calc_req_checksum);
    wire normal_write = (state == S_EXEC) && packet_ok &&
                        (cmd == CMD_WRITE) && (addr_is_rom || addr_is_ram);
    wire[31:0] read_word = addr_is_rom ? rom_rdata_i :
                            (addr_is_ram ? ram_rdata_i : 32'h0000_0000);

    assign rom_we_o = normal_write && addr_is_rom;
    assign ram_we_o = normal_write && addr_is_ram;
    assign rom_addr_o = addr;
    assign ram_addr_o = addr;
    assign rom_wdata_o = wdata;
    assign ram_wdata_o = wdata;
    assign rom_wstrb_o = byteen[3:0];
    assign ram_wstrb_o = byteen[3:0];

    always @ (posedge clk) begin
        if (rst == `LHR_RstEnable) begin
            state <= S_IDLE;
            cmd <= 8'h00;
            addr <= 32'h0000_0000;
            wdata <= 32'h0000_0000;
            byteen <= 8'h00;
            req_checksum <= 8'h00;
            status <= STATUS_OK;
            rdata <= 32'h0000_0000;
            chip_data_o <= 8'h00;
        end else begin
            chip_data_o <= 8'h00;
            case (state)
                S_IDLE: begin
                    status <= STATUS_OK;
                    rdata <= 32'h0000_0000;
                    if (chip_data_i == REQ_SOF) state <= S_RECV_CMD;
                end
                S_RECV_CMD: begin cmd <= chip_data_i; state <= S_RECV_ADDR3; end
                S_RECV_ADDR3: begin addr[31:24] <= chip_data_i; state <= S_RECV_ADDR2; end
                S_RECV_ADDR2: begin addr[23:16] <= chip_data_i; state <= S_RECV_ADDR1; end
                S_RECV_ADDR1: begin addr[15:8] <= chip_data_i; state <= S_RECV_ADDR0; end
                S_RECV_ADDR0: begin addr[7:0] <= chip_data_i; state <= S_RECV_DATA3; end
                S_RECV_DATA3: begin wdata[31:24] <= chip_data_i; state <= S_RECV_DATA2; end
                S_RECV_DATA2: begin wdata[23:16] <= chip_data_i; state <= S_RECV_DATA1; end
                S_RECV_DATA1: begin wdata[15:8] <= chip_data_i; state <= S_RECV_DATA0; end
                S_RECV_DATA0: begin wdata[7:0] <= chip_data_i; state <= S_RECV_BYTEEN; end
                S_RECV_BYTEEN: begin byteen <= chip_data_i; state <= S_RECV_CSUM; end
                S_RECV_CSUM: begin req_checksum <= chip_data_i; state <= S_EXEC; end
                S_EXEC: begin
                    if (!packet_ok) begin
                        status <= STATUS_BAD_CHECKSUM;
                        rdata <= 32'h0000_0000;
                    end else if (!(addr_is_rom || addr_is_ram)) begin
                        status <= STATUS_BAD_ADDRESS;
                        rdata <= 32'h0000_0000;
                    end else if (cmd == CMD_READ) begin
                        status <= STATUS_OK;
                        rdata <= read_word;
                    end else if (cmd == CMD_WRITE) begin
                        status <= STATUS_OK;
                        rdata <= 32'h0000_0000;
                    end else begin
                        status <= STATUS_BAD_COMMAND;
                        rdata <= 32'h0000_0000;
                    end
                    state <= S_RESP_SOF;
                end
                S_RESP_SOF: begin chip_data_o <= RESP_SOF; state <= S_RESP_STATUS; end
                S_RESP_STATUS: begin chip_data_o <= status; state <= S_RESP_DATA3; end
                S_RESP_DATA3: begin chip_data_o <= rdata[31:24]; state <= S_RESP_DATA2; end
                S_RESP_DATA2: begin chip_data_o <= rdata[23:16]; state <= S_RESP_DATA1; end
                S_RESP_DATA1: begin chip_data_o <= rdata[15:8]; state <= S_RESP_DATA0; end
                S_RESP_DATA0: begin chip_data_o <= rdata[7:0]; state <= S_RESP_CSUM; end
                S_RESP_CSUM: begin chip_data_o <= resp_checksum; state <= S_IDLE; end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
