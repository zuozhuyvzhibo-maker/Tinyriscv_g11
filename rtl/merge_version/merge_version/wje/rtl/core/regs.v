 /*                                                                      
 Copyright 2019 Blue Liang, liangkangnan@163.com
                                                                         
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

`include "../core/defines.v"

// 通用寄存器模块
module wje_regs(

    input wire clk,
    input wire rst,

    // from wje_ex
    input wire we_i,                      // 写寄存器标志
    input wire[`RegAddrBus] waddr_i,      // 写寄存器地址
    input wire[`RegBus] wdata_i,          // 写寄存器数据

    // from wje_id
    input wire[`RegAddrBus] raddr1_i,     // 读寄存器1地址

    // to wje_id
    output reg[`RegBus] rdata1_o,         // 读寄存器1数据

    // from wje_id
    input wire[`RegAddrBus] raddr2_i,     // 读寄存器2地址

    // to wje_id
    output reg[`RegBus] rdata2_o          // 读寄存器2数据

    );

    reg[`RegBus] wje_regs[0:`RegNum - 1];

    // 写寄存器
    always @ (posedge clk) begin
        if (rst == `RstDisable) begin
            // 优先wje_ex模块写操作
            if ((we_i == `WriteEnable) && (waddr_i != `ZeroReg)) begin
                wje_regs[waddr_i] <= wdata_i;
            end
        end
    end

    // 读寄存器1
    always @ (*) begin
        if (raddr1_i == `ZeroReg) begin
            rdata1_o = `ZeroWord;
        // 如果读地址等于写地址，并且正在写操作，则直接返回写数据
        end else if (raddr1_i == waddr_i && we_i == `WriteEnable) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = wje_regs[raddr1_i];
        end
    end

    // 读寄存器2
    always @ (*) begin
        if (raddr2_i == `ZeroReg) begin
            rdata2_o = `ZeroWord;
        // 如果读地址等于写地址，并且正在写操作，则直接返回写数据
        end else if (raddr2_i == waddr_i && we_i == `WriteEnable) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = wje_regs[raddr2_i];
        end
    end

endmodule
