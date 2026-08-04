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

 module ldk_bridge_slave_top (
    // 鏃堕挓鍜屽浣嶄俊鍙?
    input  wire                 clk , 
    input  wire                 rst ,
    // 澶勭悊鍣ㄦ€荤嚎妗ユ帴璁惧鐨勬暟鎹俊鍙?
    input  wire  [`BridgeBus]   bslave_RX_data ,
    output wire  [`BridgeBus]   bslave_TX_data 
 ) ;

    wire                 ram_we_o ;                   
    wire  [`MemAddrBus]  ram_addr_o ;    
    wire  [`MemBus]      ram_data_o ;
    wire  [`MemBus]      ram_data_i ;     
    // 涓嶳OM鐩镐氦浜掔殑淇″彿缁?
    wire                 rom_we_o ;                   
    wire  [`MemAddrBus]  rom_addr_o ;    
    wire  [`MemBus]      rom_data_o ;
    wire  [`MemBus]      rom_data_i ;

    ldk_bridge_slave u_bridge_slave (
        .clk(clk),
        .rst(rst),
        .bslave_RX_data(bslave_RX_data),
        .bslave_TX_data(bslave_TX_data),
        .ram_we_o(ram_we_o),
        .ram_addr_o(ram_addr_o),
        .ram_data_o(ram_data_o),
        .ram_data_i(ram_data_i),
        .rom_we_o(rom_we_o),
        .rom_addr_o(rom_addr_o),
        .rom_data_o(rom_data_o),
        .rom_data_i(rom_data_i)
    ) ;
    
    //---------------------------------------------------------
    // ROM (addr[28] == 1'b0 鏃惰閫変腑)
    //---------------------------------------------------------
    ldk_rom u_rom (
        .clk    (clk      ),
        .rst    (rst      ),
        .we_i   (rom_we_o   ),
        .addr_i (rom_addr_o ),
        .data_i (rom_data_o),
        .data_o (rom_data_i)
    );

    //---------------------------------------------------------
    // RAM (addr[28] == 1'b1 鏃惰閫変腑)
    //---------------------------------------------------------
    ldk_ram u_ram (
        .clk    (clk      ),
        .rst    (rst      ),
        .we_i   (ram_we_o   ),
        .addr_i (ram_addr_o ),
        .data_i (ram_data_o),
        .data_o (ram_data_i)
    );


 endmodule