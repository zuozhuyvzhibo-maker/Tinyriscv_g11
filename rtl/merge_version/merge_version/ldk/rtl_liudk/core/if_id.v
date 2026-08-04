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

// 灏嗘寚浠ゅ悜璇戠爜妯″潡浼犻€?
module ldk_if_id(

    input wire clk,
    input wire rst,

    input wire[`InstBus] inst_i,            // 鎸囦护鍐呭
    input wire[`InstAddrBus] inst_addr_i,   // 鎸囦护鍦板潃

    input wire[`Hold_Flag_Bus] hold_flag_i, // 娴佹按绾挎殏鍋滄爣蹇?

    output wire[`InstBus] inst_o,           // 鎸囦护鍐呭
    output wire[`InstAddrBus] inst_addr_o   // 鎸囦护鍦板潃

    );

    wire hold_en = (hold_flag_i >= `Hold_If);

    wire[`InstBus] inst;
    ldk_gen_pipe_dk #(32) inst_ff(clk, rst, hold_en, `INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`InstAddrBus] inst_addr;
    ldk_gen_pipe_dk #(32) inst_addr_ff(clk, rst, hold_en, `ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

endmodule
