 /*
 Copyright 2026 Dickens Liu, [EMAIL_ADDRESS]

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
`include "ldk_defs.v"

 // LDK-prefixed private RTL module for the four-core integration.
 module ldk_bridge_master(


    input  wire                  clk ,
	input  wire                  rst ,


    input  wire                  rib_req_i ,
    input  wire                  rib_we_i ,
    input  wire[`LDK_MemAddrBus]     rib_addr_i ,
    input  wire[`LDK_MemBus]         rib_data_i ,
    output wire[`LDK_MemBus]         rib_data_o ,


    input  wire[`LDK_BridgeBus]      bmaster_RX_data ,
    output wire[`LDK_BridgeBus]      bmaster_TX_data ,


    output wire                   rib_ack_o,
    output reg                    hold_flag_o

    );

    parameter IDLE           = 5'b00000 ;

    parameter RD_TX_CMD      = 5'b00001 ;
    parameter WE_TX_CMD      = 5'b00010 ;

    parameter WE_RD_TX_ADDR0 = 5'b00011 ;
    parameter WE_RD_TX_ADDR1 = 5'b00100 ;
    parameter WE_RD_TX_ADDR2 = 5'b00101 ;
    parameter WE_RD_TX_ADDR3 = 5'b00110 ;

    parameter RD_TX_WAIT0    = 5'b00111 ;
    parameter RD_TX_WAIT1    = 5'b01000 ;
    parameter RD_RX_DATA0    = 5'b01001 ;
    parameter RD_RX_DATA1    = 5'b01010 ;
    parameter RD_RX_DATA2    = 5'b01011 ;
    parameter RD_RX_DATA3    = 5'b01100 ;

    parameter WE_TX_DATA0    = 5'b01101 ;
    parameter WE_TX_DATA1    = 5'b01110 ;
    parameter WE_TX_DATA2    = 5'b01111 ;
    parameter WE_TX_DATA3    = 5'b10000 ;
    parameter WE_RX_RESP     = 5'b10001 ;
    parameter WE_RESP_WAIT   = 5'b10010 ;
    parameter RD_RESP_WAIT   = 5'b10011 ;

    reg [`LDK_StatusBus]        cs, ns ;
    reg [`LDK_BridgeBus]        bmaster_TX_data_reg ;
    reg [`LDK_MemBus]           data_temp;
    reg [`LDK_MemAddrBus]       addr_temp;
    reg                     we_temp;

    reg rib_ack_o_reg ;

    always @ ( posedge clk ) begin
        if( rst == `LDK_RstEnable )
            cs <= IDLE;
        else
            cs <= ns;
    end

    always @ ( * ) begin
        case(cs)


            IDLE: begin
                if ( rib_req_i == `LDK_RIB_REQ ) begin
                    if ( rib_we_i == `LDK_WriteEnable ) begin
                        ns = WE_TX_CMD;
                    end
                    else begin
                        ns = RD_TX_CMD;
                    end
                end
                else begin
                    ns = IDLE;
                end
            end

            WE_TX_CMD:begin
                ns = WE_RD_TX_ADDR0;
            end

            RD_TX_CMD:begin
                ns = WE_RD_TX_ADDR0 ;
            end

            WE_RD_TX_ADDR0:begin
                ns = WE_RD_TX_ADDR1;
            end
            WE_RD_TX_ADDR1:begin
                ns = WE_RD_TX_ADDR2;
            end
            WE_RD_TX_ADDR2:begin
                ns = WE_RD_TX_ADDR3;
            end

            WE_RD_TX_ADDR3:begin
                if ( we_temp == `LDK_WriteEnable ) begin
                    ns = WE_TX_DATA0 ;
                end
                else begin
                    ns = RD_TX_WAIT0 ;
                end
            end

            WE_TX_DATA0:begin
                ns = WE_TX_DATA1;
            end
            WE_TX_DATA1:begin
                ns = WE_TX_DATA2;
            end
            WE_TX_DATA2:begin
                ns = WE_TX_DATA3;
            end
            WE_TX_DATA3:begin
                ns = WE_RX_RESP;
            end

            WE_RX_RESP:begin
                if ( bmaster_RX_data == `LDK_WE_RespCmd ) begin
                    ns = WE_RESP_WAIT ;
                end
                else begin
                    ns = WE_RX_RESP ;
                end
            end
            WE_RESP_WAIT:begin
                ns = IDLE ;
            end




            RD_TX_WAIT0:begin
                ns = RD_TX_WAIT1 ;
            end

            RD_TX_WAIT1:begin
                ns = RD_RX_DATA0;
            end

            RD_RX_DATA0:begin
                ns = RD_RX_DATA1;
            end
            RD_RX_DATA1:begin
                ns = RD_RX_DATA2;
            end
            RD_RX_DATA2:begin
                ns = RD_RX_DATA3;
            end
            RD_RX_DATA3:begin
                ns = RD_RESP_WAIT;
            end
            RD_RESP_WAIT:begin
                ns = IDLE;
            end

            default: begin
                ns = IDLE;
            end

        endcase
    end

    always @ ( posedge clk ) begin
        if (rst == `LDK_RstEnable) begin
            bmaster_TX_data_reg <= `LDK_ZeroTempReg;
        end
        else begin
            case ( cs )
                IDLE:begin
                    bmaster_TX_data_reg <= `LDK_ZeroTempReg ;
                end

                WE_TX_CMD:begin
                    bmaster_TX_data_reg <= `LDK_WriteCmd ;
                end
                RD_TX_CMD:begin
                    bmaster_TX_data_reg <= `LDK_ReadCmd ;
                end

                WE_RD_TX_ADDR0:begin
                    bmaster_TX_data_reg <= addr_temp[`LDK_AddrOrDataSlice0] ;
                end
                WE_RD_TX_ADDR1:begin
                    bmaster_TX_data_reg <= addr_temp[`LDK_AddrOrDataSlice1] ;
                end
                WE_RD_TX_ADDR2:begin
                    bmaster_TX_data_reg <= addr_temp[`LDK_AddrOrDataSlice2] ;
                end
                WE_RD_TX_ADDR3:begin
                    bmaster_TX_data_reg <= addr_temp[`LDK_AddrOrDataSlice3] ;
                end

                WE_TX_DATA0:begin
                    bmaster_TX_data_reg <= data_temp[`LDK_AddrOrDataSlice0] ;
                end
                WE_TX_DATA1:begin
                    bmaster_TX_data_reg <= data_temp[`LDK_AddrOrDataSlice1] ;
                end
                WE_TX_DATA2:begin
                    bmaster_TX_data_reg <= data_temp[`LDK_AddrOrDataSlice2] ;
                end
                WE_TX_DATA3:begin
                    bmaster_TX_data_reg <= data_temp[`LDK_AddrOrDataSlice3] ;
                end
                WE_RX_RESP:begin
                    bmaster_TX_data_reg <= `LDK_ZeroTempReg ;
                end

                default:begin
                    bmaster_TX_data_reg <= bmaster_TX_data_reg ;
                end

            endcase
        end
    end

    always @ ( posedge clk ) begin
        if (rst == `LDK_RstEnable) begin
            addr_temp <= `LDK_ZeroWord ;
            we_temp <= 1'b0 ;
        end
        else if ( rib_req_i && (cs == IDLE) ) begin
            addr_temp <= rib_addr_i ;
            we_temp <= rib_we_i ;
        end
    end

    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            data_temp <= `LDK_ZeroWord ;
        end
        else begin
            if ( rib_we_i && rib_req_i && (cs == IDLE) ) begin
                data_temp <= rib_data_i ;
            end
            else begin
                case (cs)
                    RD_RX_DATA0:begin
                        data_temp[`LDK_AddrOrDataSlice0] <= bmaster_RX_data ;
                    end
                    RD_RX_DATA1:begin
                        data_temp[`LDK_AddrOrDataSlice1] <= bmaster_RX_data ;
                    end
                    RD_RX_DATA2:begin
                        data_temp[`LDK_AddrOrDataSlice2] <= bmaster_RX_data ;
                    end
                    RD_RX_DATA3:begin
                        data_temp[`LDK_AddrOrDataSlice3] <= bmaster_RX_data ;
                    end
                    default:begin
                        data_temp <= data_temp ;
                    end
                endcase
            end
        end
    end

    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            rib_ack_o_reg <= `LDK_AckDisable;
        end
        else if ( (cs == RD_RX_DATA3) || (cs == WE_RX_RESP) && (bmaster_RX_data == `LDK_WE_RespCmd) ) begin
            rib_ack_o_reg <= `LDK_AckEnable;
        end
        else begin
            rib_ack_o_reg <= `LDK_AckDisable;
        end
    end

    assign rib_data_o = data_temp ;
    assign bmaster_TX_data = bmaster_TX_data_reg ;
    assign rib_ack_o = rib_ack_o_reg;

    // The shared downloader advances only after one complete busy transaction.
    always @(*) begin
        if (rst == `LDK_RstEnable)
            hold_flag_o = `LDK_HoldDisable;
        else if (cs != IDLE)
            hold_flag_o = `LDK_HoldEnable;
        else
            hold_flag_o = `LDK_HoldDisable;
    end

 endmodule
