`include "../core/defines.v"

module ext_mem_bridge(
    input wire clk,
    input wire rst,

    input wire req_i,
    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] wdata_i,
    output reg[`MemBus] rdata_o,
    output reg ready_o,
    output reg busy_o,
    output reg error_o,

    output reg[7:0] ext_data_o,
    input wire[7:0] ext_data_i
    );

    localparam REQ_SOF = 8'ha5;
    localparam RESP_SOF = 8'h5a;
    localparam CMD_READ = 8'h01;
    localparam CMD_WRITE = 8'h02;
    localparam BYTEEN_WORD = 8'h0f;
    localparam STATUS_OK = 8'h00;

    localparam S_IDLE = 5'd0;
    localparam S_SEND_SOF = 5'd1;
    localparam S_SEND_CMD = 5'd2;
    localparam S_SEND_ADDR3 = 5'd3;
    localparam S_SEND_ADDR2 = 5'd4;
    localparam S_SEND_ADDR1 = 5'd5;
    localparam S_SEND_ADDR0 = 5'd6;
    localparam S_SEND_DATA3 = 5'd7;
    localparam S_SEND_DATA2 = 5'd8;
    localparam S_SEND_DATA1 = 5'd9;
    localparam S_SEND_DATA0 = 5'd10;
    localparam S_SEND_BYTEEN = 5'd11;
    localparam S_SEND_CSUM = 5'd12;
    localparam S_WAIT_RESP = 5'd13;
    localparam S_RECV_STATUS = 5'd14;
    localparam S_RECV_DATA3 = 5'd15;
    localparam S_RECV_DATA2 = 5'd16;
    localparam S_RECV_DATA1 = 5'd17;
    localparam S_RECV_DATA0 = 5'd18;
    localparam S_RECV_CSUM = 5'd19;
    localparam S_DONE = 5'd20;

    reg[4:0] state;
    reg cmd;
    reg[`MemAddrBus] req_addr;
    reg[`MemBus] req_wdata;
    reg[7:0] req_checksum;
    reg[7:0] resp_status;
    reg[`MemBus] resp_rdata;
    reg[7:0] resp_checksum;

    wire[7:0] cmd_byte = (cmd == `WriteEnable) ? CMD_WRITE : CMD_READ;
    wire[7:0] calc_req_checksum = cmd_byte ^ req_addr[31:24] ^ req_addr[23:16] ^
                                   req_addr[15:8] ^ req_addr[7:0] ^
                                   req_wdata[31:24] ^ req_wdata[23:16] ^
                                   req_wdata[15:8] ^ req_wdata[7:0] ^
                                   BYTEEN_WORD;
    wire[7:0] calc_resp_checksum = resp_status ^ resp_rdata[31:24] ^
                                    resp_rdata[23:16] ^ resp_rdata[15:8] ^
                                    resp_rdata[7:0];

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state <= S_IDLE;
            cmd <= `WriteDisable;
            req_addr <= `ZeroWord;
            req_wdata <= `ZeroWord;
            req_checksum <= 8'h0;
            resp_status <= STATUS_OK;
            resp_rdata <= `ZeroWord;
            resp_checksum <= 8'h0;
            rdata_o <= `ZeroWord;
            ready_o <= `False;
            busy_o <= `False;
            error_o <= `False;
            ext_data_o <= 8'h00;
        end else begin
            ready_o <= `False;
            ext_data_o <= 8'h00;

            case (state)
                S_IDLE: begin
                    busy_o <= `False;
                    error_o <= `False;
                    if (req_i == `RIB_REQ) begin
                        cmd <= we_i;
                        req_addr <= addr_i;
                        req_wdata <= wdata_i;
                        busy_o <= `True;
                        state <= S_SEND_SOF;
                    end
                end
                S_SEND_SOF: begin
                    ext_data_o <= REQ_SOF;
                    req_checksum <= calc_req_checksum;
                    state <= S_SEND_CMD;
                end
                S_SEND_CMD: begin
                    ext_data_o <= cmd_byte;
                    state <= S_SEND_ADDR3;
                end
                S_SEND_ADDR3: begin
                    ext_data_o <= req_addr[31:24];
                    state <= S_SEND_ADDR2;
                end
                S_SEND_ADDR2: begin
                    ext_data_o <= req_addr[23:16];
                    state <= S_SEND_ADDR1;
                end
                S_SEND_ADDR1: begin
                    ext_data_o <= req_addr[15:8];
                    state <= S_SEND_ADDR0;
                end
                S_SEND_ADDR0: begin
                    ext_data_o <= req_addr[7:0];
                    state <= S_SEND_DATA3;
                end
                S_SEND_DATA3: begin
                    ext_data_o <= req_wdata[31:24];
                    state <= S_SEND_DATA2;
                end
                S_SEND_DATA2: begin
                    ext_data_o <= req_wdata[23:16];
                    state <= S_SEND_DATA1;
                end
                S_SEND_DATA1: begin
                    ext_data_o <= req_wdata[15:8];
                    state <= S_SEND_DATA0;
                end
                S_SEND_DATA0: begin
                    ext_data_o <= req_wdata[7:0];
                    state <= S_SEND_BYTEEN;
                end
                S_SEND_BYTEEN: begin
                    ext_data_o <= BYTEEN_WORD;
                    state <= S_SEND_CSUM;
                end
                S_SEND_CSUM: begin
                    ext_data_o <= req_checksum;
                    state <= S_WAIT_RESP;
                end
                S_WAIT_RESP: begin
                    if (ext_data_i == RESP_SOF) begin
                        state <= S_RECV_STATUS;
                    end
                end
                S_RECV_STATUS: begin
                    resp_status <= ext_data_i;
                    state <= S_RECV_DATA3;
                end
                S_RECV_DATA3: begin
                    resp_rdata[31:24] <= ext_data_i;
                    state <= S_RECV_DATA2;
                end
                S_RECV_DATA2: begin
                    resp_rdata[23:16] <= ext_data_i;
                    state <= S_RECV_DATA1;
                end
                S_RECV_DATA1: begin
                    resp_rdata[15:8] <= ext_data_i;
                    state <= S_RECV_DATA0;
                end
                S_RECV_DATA0: begin
                    resp_rdata[7:0] <= ext_data_i;
                    state <= S_RECV_CSUM;
                end
                S_RECV_CSUM: begin
                    resp_checksum <= ext_data_i;
                    rdata_o <= resp_rdata;
                    error_o <= (resp_status != STATUS_OK) || (ext_data_i != calc_resp_checksum);
                    state <= S_DONE;
                end
                S_DONE: begin
                    ready_o <= `True;
                    busy_o <= `False;
                    state <= S_IDLE;
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
