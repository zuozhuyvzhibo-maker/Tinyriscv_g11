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

// 閫氱敤瀵勫瓨鍣ㄦā鍧?
module ldk_regs(

    input wire clk,
    input wire rst,

    // from ldk_ex
    input wire we_i,                      // 鍐欏瘎瀛樺櫒鏍囧織
    input wire[`RegAddrBus] waddr_i,      // 鍐欏瘎瀛樺櫒鍦板潃
    input wire[`RegBus] wdata_i,          // 鍐欏瘎瀛樺櫒鏁版嵁

    // from ldk_id
    input wire[`RegAddrBus] raddr1_i,     // 璇诲瘎瀛樺櫒1鍦板潃

    // to ldk_id
    output reg[`RegBus] rdata1_o,         // 璇诲瘎瀛樺櫒1鏁版嵁

    // from ldk_id
    input wire[`RegAddrBus] raddr2_i,     // 璇诲瘎瀛樺櫒2鍦板潃

    // to ldk_id
    output reg[`RegBus] rdata2_o         // 璇诲瘎瀛樺櫒2鏁版嵁


    );

    reg[`RegBus] ldk_regs[0:`RegNum - 1];

    // 鍐欏瘎瀛樺櫒
    always @ (posedge clk) begin
        if (rst == `RstDisable) begin
            // 浼樺厛ldk_ex妯″潡鍐欐搷浣?
            if ((we_i == `WriteEnable) && (waddr_i != `ZeroReg)) begin
                ldk_regs[waddr_i] <= wdata_i;
            end 
        end
    end

    // 璇诲瘎瀛樺櫒1
    always @ (*) begin
        if (raddr1_i == `ZeroReg) begin
            rdata1_o = `ZeroWord;
        // 濡傛灉璇诲湴鍧€绛変簬鍐欏湴鍧€锛屽苟涓旀鍦ㄥ啓鎿嶄綔锛屽垯鐩存帴杩斿洖鍐欐暟鎹?
        end else if (raddr1_i == waddr_i && we_i == `WriteEnable) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = ldk_regs[raddr1_i];
        end
    end

    // 璇诲瘎瀛樺櫒2
    always @ (*) begin
        if (raddr2_i == `ZeroReg) begin
            rdata2_o = `ZeroWord;
        // 濡傛灉璇诲湴鍧€绛変簬鍐欏湴鍧€锛屽苟涓旀鍦ㄥ啓鎿嶄綔锛屽垯鐩存帴杩斿洖鍐欐暟鎹?
        end else if (raddr2_i == waddr_i && we_i == `WriteEnable) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = ldk_regs[raddr2_i];
        end
    end



endmodule
