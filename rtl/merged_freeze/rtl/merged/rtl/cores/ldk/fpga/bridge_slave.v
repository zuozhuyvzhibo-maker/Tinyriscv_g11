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
module ldk_bridge_slave (


    input  wire                 clk ,
    input  wire                 rst ,

    input  wire  [`LDK_BridgeBus]   bslave_RX_data ,
    output wire  [`LDK_BridgeBus]   bslave_TX_data ,

    output wire                 ram_we_o ,
    output wire  [`LDK_MemAddrBus]  ram_addr_o ,
    output wire  [`LDK_MemBus]      ram_data_o ,
    input  wire  [`LDK_MemBus]      ram_data_i ,

    output wire                 rom_we_o ,
    output wire  [`LDK_MemAddrBus]  rom_addr_o ,
    output wire  [`LDK_MemBus]      rom_data_o ,
    input  wire  [`LDK_MemBus]      rom_data_i

) ;


    parameter IDLE           = 4'b0000 ;

    parameter WE_RD_RX_ADDR0 = 4'b0001 ;
    parameter WE_RD_RX_ADDR1 = 4'b0010 ;
    parameter WE_RD_RX_ADDR2 = 4'b0011 ;
    parameter WE_RD_RX_ADDR3 = 4'b0100 ;

    parameter WE_RX_DATA0    = 4'b0101 ;
    parameter WE_RX_DATA1    = 4'b0110 ;
    parameter WE_RX_DATA2    = 4'b0111 ;
    parameter WE_RX_DATA3    = 4'b1000 ;
    parameter WE_TX_RESP     = 4'b1001 ;

    parameter RD_TX_DATA0    = 4'b1010 ;
    parameter RD_TX_DATA1    = 4'b1011 ;
    parameter RD_TX_DATA2    = 4'b1100 ;
    parameter RD_TX_DATA3    = 4'b1101 ;
    // Regs
    reg [`LDK_StatusBus_slave]        cs, ns ;
    reg [`LDK_BridgeBus]              bslave_TX_data_reg ;
    reg [`LDK_MemBus]                 data_temp ;
    reg [`LDK_MemAddrBus]             addr_temp ;
    reg [`LDK_CmdSimple]              cmd_simple_temp ;
    reg                           ram_we_reg ;
    reg                           rom_we_reg ;

    reg [`LDK_MemBus]                 rom_ram_data_out ;

    localparam [`LDK_MemAddrBus] RAM_ADDR_BASE = 32'h1000_0000 ;

    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            cs <= IDLE ;
        end
        else begin
            cs <= ns ;
        end
    end

    always @ ( * ) begin
        case ( cs )
            // Switch to Write or Read Addr Transmission Status according to " RX_data ( Cmd ) "
            IDLE:begin
                if ( (bslave_RX_data == `LDK_ReadCmd) || (bslave_RX_data == `LDK_WriteCmd) ) begin
                    ns = WE_RD_RX_ADDR0 ;
                end
                else begin
                    ns = IDLE ;
                end
            end
            // Addr transmission status
            WE_RD_RX_ADDR0: begin ns = WE_RD_RX_ADDR1 ; end
            WE_RD_RX_ADDR1: begin ns = WE_RD_RX_ADDR2 ; end
            WE_RD_RX_ADDR2: begin ns = WE_RD_RX_ADDR3 ; end
            // Switch to read or write status according to cmd_simple_temp
            WE_RD_RX_ADDR3:begin
                if ( cmd_simple_temp == `LDK_WriteCmd_simp ) begin
                    ns = WE_RX_DATA0 ;
                end
                else if ( cmd_simple_temp == `LDK_ReadCmd_simp ) begin
                    ns = RD_TX_DATA0 ;
                end
                else begin
                    ns = IDLE ; // need to be cautious -- liudk
                end
            end
            // Switch to writing status ( Data transmission  )
            WE_RX_DATA0: begin ns = WE_RX_DATA1 ; end
            WE_RX_DATA1: begin ns = WE_RX_DATA2 ; end
            WE_RX_DATA2: begin ns = WE_RX_DATA3 ; end
            WE_RX_DATA3: begin ns = WE_TX_RESP  ; end
            WE_TX_RESP:  begin ns = IDLE        ; end
            // Switch to reading status ( Data fetching from Ram/Rom and transmission )
            RD_TX_DATA0: begin ns = RD_TX_DATA1 ; end
            RD_TX_DATA1: begin ns = RD_TX_DATA2 ; end
            RD_TX_DATA2: begin ns = RD_TX_DATA3 ; end
            RD_TX_DATA3: begin ns = IDLE        ; end
            default:     begin ns = IDLE        ; end
        endcase
    end

    // the logic of addr_temp regs: reset when rst validate and update addr values in the status of ADDR TRANSMISSION
    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            addr_temp <= `LDK_ZeroWord ;
        end
        else begin
            case ( cs )
                WE_RD_RX_ADDR0:begin
                    addr_temp[`LDK_AddrOrDataSlice0] <= bslave_RX_data ;
                end
                WE_RD_RX_ADDR1:begin
                    addr_temp[`LDK_AddrOrDataSlice1] <= bslave_RX_data ;
                end
                WE_RD_RX_ADDR2:begin
                    addr_temp[`LDK_AddrOrDataSlice2] <= bslave_RX_data ;
                end
                WE_RD_RX_ADDR3:begin
                    addr_temp[`LDK_AddrOrDataSlice3] <= bslave_RX_data ;
                end
                default:begin

                end
            endcase
        end
    end

    //the logic of data_temp:reset when rst validate, receive RX_data when cs enters WE_RX_DATA status
    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            data_temp <= `LDK_ZeroWord ;
        end
        else begin
            case ( cs )
                WE_RX_DATA0:begin
                    data_temp[`LDK_AddrOrDataSlice0] <= bslave_RX_data ;
                end
                WE_RX_DATA1:begin
                    data_temp[`LDK_AddrOrDataSlice1] <= bslave_RX_data ;
                end
                WE_RX_DATA2:begin
                    data_temp[`LDK_AddrOrDataSlice2] <= bslave_RX_data ;
                end
                WE_RX_DATA3:begin
                    data_temp[`LDK_AddrOrDataSlice3] <= bslave_RX_data ;
                end
                default:begin

                end
            endcase
        end
    end

    // the logic of bslave_TX_data_reg : reset when rst validate update when cs enters the RD_TX Status and update when WE_TX_RESP
    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            bslave_TX_data_reg <= `LDK_ZeroTempReg ;
        end
        else begin
            case ( cs )
                RD_TX_DATA0:begin
                    bslave_TX_data_reg <= rom_ram_data_out[`LDK_AddrOrDataSlice0] ;
                end
                RD_TX_DATA1:begin
                    bslave_TX_data_reg <= rom_ram_data_out[`LDK_AddrOrDataSlice1] ;
                end
                RD_TX_DATA2:begin
                    bslave_TX_data_reg <= rom_ram_data_out[`LDK_AddrOrDataSlice2] ;
                end
                RD_TX_DATA3:begin
                    bslave_TX_data_reg <= rom_ram_data_out[`LDK_AddrOrDataSlice3] ;
                end
                WE_RX_DATA2:begin
                    bslave_TX_data_reg <= `LDK_WE_RespCmd ;
                end
                WE_RX_DATA3:begin
                    bslave_TX_data_reg <= `LDK_WE_RespCmd ;
                end
                WE_TX_RESP:begin
                    bslave_TX_data_reg <= `LDK_WE_RespCmd ;
                end
                default:begin

                end
            endcase
        end
    end

    // the logic of cmd_simple_temp : reset when rst validate, update when cs enters IDLE status
    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            cmd_simple_temp <= `LDK_ZeroCmdSimple ;
        end
        else begin
            if ( cs == IDLE ) begin
                cmd_simple_temp <= bslave_RX_data[`LDK_CmdSimple] ;
            end
        end
    end

    always @ ( * ) begin
        if ( addr_temp[28] == 1'b0 ) begin
            rom_ram_data_out = rom_data_i ;
        end
        else begin
            rom_ram_data_out = ram_data_i ;
        end
    end

    // the logic of ram_we_reg and rom_we_reg
    always @ ( posedge clk ) begin
        if ( rst == `LDK_RstEnable ) begin
            ram_we_reg <= `LDK_WriteDisable ;
            rom_we_reg <= `LDK_WriteDisable ;
        end
        else begin
            if ( cs == WE_RX_DATA3 ) begin
                if ( addr_temp[28] == 1'b0 ) begin
                    rom_we_reg <= `LDK_WriteEnable ;
                end
                else begin
                    ram_we_reg <= `LDK_WriteEnable ;
                end
            end
            else begin
                rom_we_reg <= `LDK_WriteDisable ;
                ram_we_reg <= `LDK_WriteDisable ;
            end
        end
    end

    assign rom_we_o   = rom_we_reg ;
    assign rom_addr_o = {4'b0, addr_temp[27:0]}  ;
    assign rom_data_o = data_temp  ;

    assign ram_we_o   = ram_we_reg ;
    assign ram_addr_o = {4'b0, addr_temp[27:0]} ;
    assign ram_data_o = data_temp  ;

    assign bslave_TX_data = bslave_TX_data_reg ;

endmodule
