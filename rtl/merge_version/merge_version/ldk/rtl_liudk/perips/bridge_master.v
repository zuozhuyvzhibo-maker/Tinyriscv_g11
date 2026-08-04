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
`include "defines.v"

 module ldk_bridge_master(

    // 鏃堕挓鍜屽浣嶆帴鍙?
    input  wire                  clk ,
	input  wire                  rst ,

    // RIB杈撳叆鎺ュ彛
    input  wire                  rib_req_i ,     // RIB杈撳叆璇锋眰鏍囧織
    input  wire                  rib_we_i ,      // RIB杈撳叆鍐欐爣蹇?
    input  wire[`MemAddrBus]     rib_addr_i ,    // RIB杈撳叆鍦板潃
    input  wire[`MemBus]         rib_data_i ,    // RIB杈撳叆鏁版嵁
    output wire[`MemBus]         rib_data_o ,    // RIB杈撳嚭鏁版嵁

    // Master鎺ュ彛
    input  wire[`BridgeBus]      bmaster_RX_data ,
    output wire[`BridgeBus]      bmaster_TX_data ,

    // 娴佹按绾垮仠姝㈡爣蹇椾俊鍙?
    output wire                   rib_ack_o,
    output reg                    hold_flag_o

    );
    // 绌洪棽鐘舵€?
    parameter IDLE           = 5'b00000 ;
    // 璇诲啓鍛戒护浼犺緭
    parameter RD_TX_CMD      = 5'b00001 ;
    parameter WE_TX_CMD      = 5'b00010 ;
    // 璇诲啓鍦板潃浼犺緭
    parameter WE_RD_TX_ADDR0 = 5'b00011 ;
    parameter WE_RD_TX_ADDR1 = 5'b00100 ;
    parameter WE_RD_TX_ADDR2 = 5'b00101 ;
    parameter WE_RD_TX_ADDR3 = 5'b00110 ;
    // 璇昏繃绋?(鏁版嵁绛夊緟鍙婁紶杈撹繃绋?
    parameter RD_TX_WAIT0    = 5'b00111 ;
    parameter RD_TX_WAIT1    = 5'b01000 ;
    parameter RD_RX_DATA0    = 5'b01001 ;
    parameter RD_RX_DATA1    = 5'b01010 ;
    parameter RD_RX_DATA2    = 5'b01011 ;
    parameter RD_RX_DATA3    = 5'b01100 ;
    // 鍐欒繃绋嬶紙鏁版嵁鎺ユ敹浠ュ強鍐欏洖鍝嶅簲锛?
    parameter WE_TX_DATA0    = 5'b01101 ;
    parameter WE_TX_DATA1    = 5'b01110 ;
    parameter WE_TX_DATA2    = 5'b01111 ;
    parameter WE_TX_DATA3    = 5'b10000 ;
    parameter WE_RX_RESP     = 5'b10001 ;
    parameter WE_RESP_WAIT   = 5'b10010 ;
    parameter RD_RESP_WAIT   = 5'b10011 ;

    reg [`StatusBus]        cs, ns ;
    reg [`BridgeBus]        bmaster_TX_data_reg ;
    reg [`MemBus]           data_temp;
    reg [`MemAddrBus]       addr_temp;
    reg                     we_temp;

    reg rib_ack_o_reg ;

    always @ ( posedge clk ) begin
        if( rst == `RstEnable )
            cs <= IDLE;
        else
            cs <= ns;
    end

    always @ ( * ) begin
        case(cs)

            // 浼犺緭璇诲啓杩囩▼鐨勫懡浠?
            IDLE: begin
                if ( rib_req_i == `RIB_REQ ) begin
                    if ( rib_we_i == `WriteEnable ) begin
                        ns = WE_TX_CMD; // 鍐欏懡浠?
                    end
                    else begin
                        ns = RD_TX_CMD; // 璇诲懡浠?
                    end
                end
                else begin
                    ns = IDLE;
                end
            end
            // 浼犺緭鍐欒繃绋嬬殑鍦板潃
            WE_TX_CMD:begin
                ns = WE_RD_TX_ADDR0;
            end
            // 浼犺緭璇昏繃绋嬬殑鍦板潃
            RD_TX_CMD:begin
                ns = WE_RD_TX_ADDR0 ;
            end
            // 浼犺緭璇诲啓杩囩▼鐨勫湴鍧€
            WE_RD_TX_ADDR0:begin
                ns = WE_RD_TX_ADDR1;
            end
            WE_RD_TX_ADDR1:begin
                ns = WE_RD_TX_ADDR2;
            end
            WE_RD_TX_ADDR2:begin
                ns = WE_RD_TX_ADDR3;
            end
            // 鏍规嵁we_temp鐨勫€奸€夋嫨鍚庣画鎵ц璇昏繃绋嬫垨鑰呭啓杩囩▼
            WE_RD_TX_ADDR3:begin
                if ( we_temp == `WriteEnable ) begin
                    ns = WE_TX_DATA0 ;
                end
                else begin
                    ns = RD_TX_WAIT0 ;
                end
            end
            // 鍐欒繃绋嬶細浼犺緭鏁版嵁锛圧IB -> RAM/ROM锛?
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
            // 鍐欏洖鍝嶅簲
            WE_RX_RESP:begin
                if ( bmaster_RX_data == `WE_RespCmd ) begin
                    ns = WE_RESP_WAIT ;
                end
                else begin
                    ns = WE_RX_RESP ;
                end
            end
            WE_RESP_WAIT:begin
                ns = IDLE ;
            end

            // 璇昏繃绋嬶細绛夊緟鏁版嵁璇诲嚭鍜屾暟鎹紶杈?
            
            // 绛夊緟鏁版嵁璇诲嚭锛堝疄闄呬笂鏄瓑寰卻lave鎺ユ敹鍒版渶鍚庝竴娈靛湴鍧€锛?
            RD_TX_WAIT0:begin
                ns = RD_TX_WAIT1 ;
            end
            // 绛夊緟鏁版嵁璇诲嚭锛堝疄闄呬笂鏄瓑寰匯AM/ROM寮傛璇诲嚭鐨勬暟鎹啓鍏ヨ嚦杈撳嚭绔彛鐨勫瘎瀛樺櫒锛?
            RD_TX_WAIT1:begin
                ns = RD_RX_DATA0;
            end
            // 瀹為檯鐨勬暟鎹紶杈?
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
            // 榛樿缁撴灉
            default: begin
                ns = IDLE;
            end

        endcase
    end

    always @ ( posedge clk ) begin
        if (rst == `RstEnable) begin
            bmaster_TX_data_reg <= `ZeroTempReg;
        end
        else begin
            case ( cs )
                IDLE:begin
                    bmaster_TX_data_reg <= `ZeroTempReg ;
                end

                WE_TX_CMD:begin
                    bmaster_TX_data_reg <= `WriteCmd ;
                end
                RD_TX_CMD:begin
                    bmaster_TX_data_reg <= `ReadCmd ;
                end

                WE_RD_TX_ADDR0:begin
                    bmaster_TX_data_reg <= addr_temp[`AddrOrDataSlice0] ; 
                end
                WE_RD_TX_ADDR1:begin
                    bmaster_TX_data_reg <= addr_temp[`AddrOrDataSlice1] ; 
                end
                WE_RD_TX_ADDR2:begin
                    bmaster_TX_data_reg <= addr_temp[`AddrOrDataSlice2] ; 
                end
                WE_RD_TX_ADDR3:begin
                    bmaster_TX_data_reg <= addr_temp[`AddrOrDataSlice3] ; 
                end

                WE_TX_DATA0:begin
                    bmaster_TX_data_reg <= data_temp[`AddrOrDataSlice0] ; 
                end
                WE_TX_DATA1:begin
                    bmaster_TX_data_reg <= data_temp[`AddrOrDataSlice1] ; 
                end
                WE_TX_DATA2:begin
                    bmaster_TX_data_reg <= data_temp[`AddrOrDataSlice2] ; 
                end
                WE_TX_DATA3:begin
                    bmaster_TX_data_reg <= data_temp[`AddrOrDataSlice3] ; 
                end
                WE_RX_RESP:begin
                    bmaster_TX_data_reg <= `ZeroTempReg ;
                end

                default:begin
                    bmaster_TX_data_reg <= bmaster_TX_data_reg ;
                end

            endcase 
        end
    end

    always @ ( posedge clk ) begin
        if (rst == `RstEnable) begin
            addr_temp <= `ZeroWord ;
            we_temp <= 1'b0 ;
        end
        else if ( rib_req_i && (cs == IDLE) ) begin
            addr_temp <= rib_addr_i ;
            we_temp <= rib_we_i ;
        end
    end

    always @ ( posedge clk ) begin
        if ( rst == `RstEnable ) begin
            data_temp <= `ZeroWord ;
        end
        else begin
            if ( rib_we_i && rib_req_i && (cs == IDLE) ) begin
                data_temp <= rib_data_i ;
            end
            else begin
                case (cs) 
                    RD_RX_DATA0:begin
                        data_temp[`AddrOrDataSlice0] <= bmaster_RX_data ;
                    end
                    RD_RX_DATA1:begin
                        data_temp[`AddrOrDataSlice1] <= bmaster_RX_data ;
                    end
                    RD_RX_DATA2:begin
                        data_temp[`AddrOrDataSlice2] <= bmaster_RX_data ;
                    end
                    RD_RX_DATA3:begin
                        data_temp[`AddrOrDataSlice3] <= bmaster_RX_data ;
                    end
                    default:begin
                        data_temp <= data_temp ;
                    end
                endcase
            end
        end
    end

    always @ ( posedge clk ) begin
        if ( rst == `RstEnable ) begin
            rib_ack_o_reg <= `AckDisable;
        end
        else if ( (cs == RD_RX_DATA3) || (cs == WE_RX_RESP) && (bmaster_RX_data == `WE_RespCmd) ) begin
            rib_ack_o_reg <= `AckEnable;
        end
        else begin
            rib_ack_o_reg <= `AckDisable;
        end
    end

    assign rib_data_o = data_temp ;
    assign bmaster_TX_data = bmaster_TX_data_reg ;
    assign rib_ack_o = rib_ack_o_reg;

    always @(posedge clk) begin
        if (rst == `RstEnable)
            hold_flag_o <= `HoldDisable;
        else
            hold_flag_o <= `HoldDisable;   // 鏆傛椂姘歌繙涓嶆殏鍋?
    end
                    
 endmodule
