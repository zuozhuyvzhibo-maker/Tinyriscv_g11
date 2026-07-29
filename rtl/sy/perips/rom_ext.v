/*
 Copyright 2020 Blue Liang, liangkangnan@163.com

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

module rom_ext(

    input wire clk,
    input wire rst,

    input wire we_i,
    input wire[7:0] addr_i,
    input wire[`MemBus] data_i,

    output reg[`MemBus] data_o

    );

    reg[`MemBus] _rom[0:`RomNum - 1];
    
initial begin
/*
    //basic
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_add.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_andi.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_auipc.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_beq.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bge.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bgeu.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_blt.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bltu.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_bne.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_div.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_divu.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_jal.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_jalr.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_lui.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_or.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_rem.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_remu.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_simple.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_slli.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_slti.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_sltiu.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_srai.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_srli.data", _rom);
 $readmemh("D:/projectCH/reference/tinyriscv/tests/Basic_Inst_Example/inst_xor.data", _romm);
*/
//extend
    //$readmemh ("D:/projectCH/reference/tinyriscv/tests/Extend_Inst_Example/sID/sID.data", _rom);
    //$readmemh ("D:/projectCH/reference/IF.data", _rom);
    //$readmemh("D:/projectCH/reference/Temp.data", _rom);
        
//other 
    //$readmemh("D:/projectCH/reference/tinyriscv/tests/Other_Example/PWM/PWM.data", _rom);        
    end
    
    always @ (posedge clk) begin
        if (we_i == `WriteEnable) begin
            _rom[addr_i] <= data_i;
        end
    end

    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = `ZeroWord;
        end else begin
            data_o = _rom[addr_i];
        end
    end

endmodule
