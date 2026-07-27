`include "defines.v"

module rib_ext_bridge(
    input wire clk,
    input wire rst,

    input wire[`MemAddrBus] m0_addr_i,
    input wire[`MemBus] m0_data_i,
    output reg[`MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,

    input wire[`MemAddrBus] m1_addr_i,
    input wire[`MemBus] m1_data_i,
    output reg[`MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,

    output reg ext_req_o,
    output reg[`MemAddrBus] ext_addr_o,
    output reg[`MemBus] ext_data_o,
    input wire[`MemBus] ext_data_i,
    input wire ext_ready_i,
    output reg ext_we_o,

    output reg[`MemAddrBus] s3_addr_o,
    output reg[`MemBus] s3_data_o,
    input wire[`MemBus] s3_data_i,
    output reg s3_we_o,

    output reg[`MemAddrBus] s6_addr_o,
    output reg[`MemBus] s6_data_o,
    input wire[`MemBus] s6_data_i,
    output reg s6_we_o,

    output reg[`MemAddrBus] s7_addr_o,
    output reg[`MemBus] s7_data_o,
    input wire[`MemBus] s7_data_i,
    output reg s7_we_o,

    output reg[`Hold_Flag_Bus] hold_flag_o
    );

    localparam GRANT_NONE = 2'h0;
    localparam GRANT_M0 = 2'h1;
    localparam GRANT_M1 = 2'h2;

    reg ext_busy;
    reg[1:0] pending_grant;
    reg[`MemAddrBus] pending_addr;
    reg m0_wait_has_if;
    reg[1:0] req_grant;
    reg[`MemAddrBus] sel_addr;
    reg[`MemBus] sel_wdata;
    reg sel_we;
    reg ext_selected;
    reg ext_start;
    reg stale_if_response;

    always @ (*) begin
        if (m0_req_i == `RIB_REQ) begin
            req_grant = GRANT_M0;
        end else if (m1_req_i == `RIB_REQ) begin
            req_grant = GRANT_M1;
        end else begin
            req_grant = GRANT_NONE;
        end
    end

    always @ (*) begin
        case (req_grant)
            GRANT_M0: begin
                sel_addr = m0_addr_i;
                sel_wdata = m0_data_i;
                sel_we = m0_we_i;
            end
            GRANT_M1: begin
                sel_addr = m1_addr_i;
                sel_wdata = m1_data_i;
                sel_we = m1_we_i;
            end
            default: begin
                sel_addr = `ZeroWord;
                sel_wdata = `ZeroWord;
                sel_we = `WriteDisable;
            end
        endcase
    end

    always @ (*) begin
        ext_selected = (req_grant != GRANT_NONE) &&
                       ((sel_addr[31:28] == 4'h0) || (sel_addr[31:28] == 4'h1));
        ext_start = (ext_busy == `False) && (ext_selected == `True);
        stale_if_response = (ext_busy == `True) && (ext_ready_i == `True) &&
                            (pending_grant == GRANT_M1) && (m1_addr_i != pending_addr);

        m0_data_o = `ZeroWord;
        m1_data_o = `INST_NOP;

        ext_req_o = ext_start ? `RIB_REQ : `RIB_NREQ;
        ext_addr_o = sel_addr;
        ext_data_o = sel_wdata;
        ext_we_o = sel_we;

        s3_addr_o = `ZeroWord;
        s3_data_o = `ZeroWord;
        s3_we_o = `WriteDisable;
        s6_addr_o = `ZeroWord;
        s6_data_o = `ZeroWord;
        s6_we_o = `WriteDisable;
        s7_addr_o = `ZeroWord;
        s7_data_o = `ZeroWord;
        s7_we_o = `WriteDisable;

        if ((ext_busy == `True) && (pending_grant == GRANT_M0) &&
            (ext_ready_i == `True) && (m0_wait_has_if == `False)) begin
            hold_flag_o = `Hold_If;
        end else if ((req_grant == GRANT_M0) && (ext_selected == `True) &&
            (ext_busy == `True) && (pending_grant == GRANT_M1) &&
            (ext_ready_i == `True) && (stale_if_response == `False)) begin
            hold_flag_o = `Hold_Id_Keep_If;
        end else if ((req_grant == GRANT_M0) && (ext_selected == `True) &&
            ((ext_start == `True) ||
             (ext_busy == `True && ((pending_grant != GRANT_M0) || (ext_ready_i == `False))))) begin
            hold_flag_o = `Hold_Id_Keep;
        end else if ((ext_start == `True) || (ext_busy == `True && ext_ready_i == `False) ||
            (stale_if_response == `True)) begin
            if ((ext_busy == `True && pending_grant == GRANT_M0) ||
                (ext_busy == `False && req_grant == GRANT_M0)) begin
                hold_flag_o = `Hold_Id_Keep;
            end else begin
                hold_flag_o = `Hold_If;
            end
        end else begin
            hold_flag_o = `Hold_None;
        end

        if (ext_busy == `True && ext_ready_i == `True && stale_if_response == `False) begin
            case (pending_grant)
                GRANT_M0: m0_data_o = ext_data_i;
                GRANT_M1: m1_data_o = ext_data_i;
                default: begin
                end
            endcase
        end

        case (sel_addr[31:28])
            4'h3: begin
                s3_addr_o = {4'h0, sel_addr[27:0]};
                s3_data_o = sel_wdata;
                s3_we_o = sel_we;
                case (req_grant)
                    GRANT_M0: m0_data_o = s3_data_i;
                    GRANT_M1: m1_data_o = s3_data_i;
                    default: begin
                    end
                endcase
            end
            4'h6: begin
                s6_addr_o = {4'h0, sel_addr[27:0]};
                s6_data_o = sel_wdata;
                s6_we_o = sel_we;
                case (req_grant)
                    GRANT_M0: m0_data_o = s6_data_i;
                    GRANT_M1: m1_data_o = s6_data_i;
                    default: begin
                    end
                endcase
            end
            4'h7: begin
                s7_addr_o = {4'h0, sel_addr[27:0]};
                s7_data_o = sel_wdata;
                s7_we_o = sel_we;
                case (req_grant)
                    GRANT_M0: m0_data_o = s7_data_i;
                    GRANT_M1: m1_data_o = s7_data_i;
                    default: begin
                    end
                endcase
            end
            default: begin
            end
        endcase
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ext_busy <= `False;
            pending_grant <= GRANT_NONE;
            pending_addr <= `ZeroWord;
            m0_wait_has_if <= `False;
        end else begin
            if (ext_busy == `True) begin
                if (ext_ready_i == `True) begin
                    ext_busy <= `False;
                    if ((pending_grant == GRANT_M1) && (req_grant == GRANT_M0) &&
                        (ext_selected == `True) && (stale_if_response == `False)) begin
                        m0_wait_has_if <= `True;
                    end else if (pending_grant == GRANT_M0) begin
                        m0_wait_has_if <= `False;
                    end
                    pending_grant <= GRANT_NONE;
                    pending_addr <= `ZeroWord;
                end
            end else if (ext_start == `True) begin
                ext_busy <= `True;
                pending_grant <= req_grant;
                pending_addr <= sel_addr;
            end
        end
    end

endmodule
