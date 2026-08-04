`include "lhr_defs.v"

module lhr_rib_ext_bridge(
    input wire clk,
    input wire rst,

    input wire[`LHR_MemAddrBus] m0_addr_i,
    input wire[`LHR_MemBus] m0_data_i,
    output reg[`LHR_MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,
    input wire[3:0] m0_byte_en_i,

    input wire[`LHR_MemAddrBus] m1_addr_i,
    input wire[`LHR_MemBus] m1_data_i,
    output reg[`LHR_MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,

    output reg ext_req_o,
    output reg[`LHR_MemAddrBus] ext_addr_o,
    output reg[`LHR_MemBus] ext_data_o,
    input wire[`LHR_MemBus] ext_data_i,
    input wire ext_ready_i,
    output reg ext_we_o,
    output reg[3:0] ext_byte_en_o,

    output reg[`LHR_MemAddrBus] s3_addr_o,
    output reg[`LHR_MemBus] s3_data_o,
    input wire[`LHR_MemBus] s3_data_i,
    output reg s3_we_o,

    output reg[`LHR_MemAddrBus] s6_addr_o,
    output reg[`LHR_MemBus] s6_data_o,
    input wire[`LHR_MemBus] s6_data_i,
    output reg s6_we_o,

    output reg[`LHR_MemAddrBus] s7_addr_o,
    output reg[`LHR_MemBus] s7_data_o,
    input wire[`LHR_MemBus] s7_data_i,
    output reg s7_we_o,

    output reg[`LHR_Hold_Flag_Bus] hold_flag_o
    );

    localparam GRANT_NONE = 2'h0;
    localparam GRANT_M0 = 2'h1;
    localparam GRANT_M1 = 2'h2;

    reg ext_busy;
    reg[1:0] pending_grant;
    reg[`LHR_MemAddrBus] pending_addr;
    reg m0_wait_has_if;
    reg[1:0] req_grant;
    reg[`LHR_MemAddrBus] sel_addr;
    reg[`LHR_MemBus] sel_wdata;
    reg sel_we;
    reg[3:0] sel_byte_en;
    reg ext_selected;
    reg ext_start;
    reg stale_if_response;

    always @ (*) begin
        if (m0_req_i == `LHR_RIB_REQ) begin
            req_grant = GRANT_M0;
        end else if (m1_req_i == `LHR_RIB_REQ) begin
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
                sel_byte_en = m0_byte_en_i;
            end
            GRANT_M1: begin
                sel_addr = m1_addr_i;
                sel_wdata = m1_data_i;
                sel_we = m1_we_i;
                sel_byte_en = 4'hf;
            end
            default: begin
                sel_addr = `LHR_ZeroWord;
                sel_wdata = `LHR_ZeroWord;
                sel_we = `LHR_WriteDisable;
                sel_byte_en = 4'hf;
            end
        endcase
    end

    always @ (*) begin
        ext_selected = (req_grant != GRANT_NONE) &&
                       ((sel_addr[31:28] == 4'h0) || (sel_addr[31:28] == 4'h1));
        ext_start = (ext_busy == `LHR_False) && (ext_selected == `LHR_True);
        stale_if_response = (ext_busy == `LHR_True) && (ext_ready_i == `LHR_True) &&
                            (pending_grant == GRANT_M1) && (m1_addr_i != pending_addr);

        m0_data_o = `LHR_ZeroWord;
        m1_data_o = `LHR_INST_NOP;

        ext_req_o = ext_start ? `LHR_RIB_REQ : `LHR_RIB_NREQ;
        ext_addr_o = sel_addr;
        ext_data_o = sel_wdata;
        ext_we_o = sel_we;
        ext_byte_en_o = sel_byte_en;

        s3_addr_o = `LHR_ZeroWord;
        s3_data_o = `LHR_ZeroWord;
        s3_we_o = `LHR_WriteDisable;
        s6_addr_o = `LHR_ZeroWord;
        s6_data_o = `LHR_ZeroWord;
        s6_we_o = `LHR_WriteDisable;
        s7_addr_o = `LHR_ZeroWord;
        s7_data_o = `LHR_ZeroWord;
        s7_we_o = `LHR_WriteDisable;

        if ((ext_busy == `LHR_True) && (pending_grant == GRANT_M0) &&
            (ext_ready_i == `LHR_True) && (m0_wait_has_if == `LHR_False)) begin
            hold_flag_o = `LHR_Hold_If;
        end else if ((req_grant == GRANT_M0) && (ext_selected == `LHR_True) &&
            (ext_busy == `LHR_True) && (pending_grant == GRANT_M1) &&
            (ext_ready_i == `LHR_True) && (stale_if_response == `LHR_False)) begin
            hold_flag_o = `LHR_Hold_Id_Keep_If;
        end else if ((req_grant == GRANT_M0) && (ext_selected == `LHR_True) &&
            ((ext_start == `LHR_True) ||
             (ext_busy == `LHR_True && ((pending_grant != GRANT_M0) || (ext_ready_i == `LHR_False))))) begin
            hold_flag_o = `LHR_Hold_Id_Keep;
        end else if ((ext_start == `LHR_True) || (ext_busy == `LHR_True && ext_ready_i == `LHR_False) ||
            (stale_if_response == `LHR_True)) begin
            if ((ext_busy == `LHR_True && pending_grant == GRANT_M0) ||
                (ext_busy == `LHR_False && req_grant == GRANT_M0)) begin
                hold_flag_o = `LHR_Hold_Id_Keep;
            end else begin
                hold_flag_o = `LHR_Hold_If;
            end
        end else begin
            hold_flag_o = `LHR_Hold_None;
        end

        if (ext_busy == `LHR_True && ext_ready_i == `LHR_True && stale_if_response == `LHR_False) begin
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
        if (rst == `LHR_RstEnable) begin
            ext_busy <= `LHR_False;
            pending_grant <= GRANT_NONE;
            pending_addr <= `LHR_ZeroWord;
            m0_wait_has_if <= `LHR_False;
        end else begin
            if (ext_busy == `LHR_True) begin
                if (ext_ready_i == `LHR_True) begin
                    ext_busy <= `LHR_False;
                    if ((pending_grant == GRANT_M1) && (req_grant == GRANT_M0) &&
                        (ext_selected == `LHR_True) && (stale_if_response == `LHR_False)) begin
                        m0_wait_has_if <= `LHR_True;
                    end else if (pending_grant == GRANT_M0) begin
                        m0_wait_has_if <= `LHR_False;
                    end
                    pending_grant <= GRANT_NONE;
                    pending_addr <= `LHR_ZeroWord;
                end
            end else if (ext_start == `LHR_True) begin
                ext_busy <= `LHR_True;
                pending_grant <= req_grant;
                pending_addr <= sel_addr;
            end
        end
    end

endmodule
