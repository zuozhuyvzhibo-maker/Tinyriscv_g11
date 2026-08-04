`ifndef MERGED_SY_DEFS_V
`define MERGED_SY_DEFS_V
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

`define SY_CpuResetAddr 32'h0

`define SY_RstEnable 1'b0
`define SY_RstDisable 1'b1
`define SY_ZeroWord 32'h0
`define SY_ZeroReg 5'h0
`define SY_WriteEnable 1'b1
`define SY_WriteDisable 1'b0
`define SY_ReadEnable 1'b1
`define SY_ReadDisable 1'b0
`define SY_True 1'b1
`define SY_False 1'b0
`define SY_ChipEnable 1'b1
`define SY_ChipDisable 1'b0
`define SY_JumpEnable 1'b1
`define SY_JumpDisable 1'b0
`define SY_HoldEnable 1'b1
`define SY_HoldDisable 1'b0
`define SY_Stop 1'b1
`define SY_NoStop 1'b0
`define SY_RIB_REQ 1'b1
`define SY_RIB_NREQ 1'b0

`define SY_Hold_Flag_Bus   2:0
`define SY_Hold_None 3'b000
`define SY_Hold_Pc   3'b001
`define SY_Hold_If   3'b010
`define SY_Hold_Id   3'b011
`define SY_Hold_Rib  3'b100

// I type inst
`define SY_INST_TYPE_I 7'b0010011
`define SY_INST_ADDI   3'b000
`define SY_INST_SLTI   3'b010
`define SY_INST_SLTIU  3'b011
`define SY_INST_XORI   3'b100
`define SY_INST_ORI    3'b110
`define SY_INST_ANDI   3'b111
`define SY_INST_SLLI   3'b001
`define SY_INST_SRI    3'b101

// L type inst
`define SY_INST_TYPE_L 7'b0000011
`define SY_INST_LB     3'b000
`define SY_INST_LH     3'b001
`define SY_INST_LW     3'b010
`define SY_INST_LBU    3'b100
`define SY_INST_LHU    3'b101

// S type inst
`define SY_INST_TYPE_S 7'b0100011
`define SY_INST_SB     3'b000
`define SY_INST_SH     3'b001
`define SY_INST_SW     3'b010

// R and M type inst
`define SY_INST_TYPE_R_M 7'b0110011
// R type inst
`define SY_INST_ADD_SUB 3'b000
`define SY_INST_SLL    3'b001
`define SY_INST_SLT    3'b010
`define SY_INST_SLTU   3'b011
`define SY_INST_XOR    3'b100
`define SY_INST_SR     3'b101
`define SY_INST_OR     3'b110
`define SY_INST_AND    3'b111

// J type inst
`define SY_INST_JAL    7'b1101111
`define SY_INST_JALR   7'b1100111

`define SY_INST_LUI    7'b0110111
`define SY_INST_AUIPC  7'b0010111
`define SY_INST_NOP    32'h00000001
`define SY_INST_NOP_OP 7'b0000001

`define SY_INST_FENCE  7'b0001111

// Extend inst
`define SY_INST_EXT    7'b0101111
`define SY_INST_EXTSID 3'b000
`define SY_INST_EXTRT  3'b001
`define SY_INST_EXTIF  3'b010
`define SY_UART_EXTREG 32'h30000014
`define SY_UART_DATREG 32'h3000000c
`define SY_UART_SIDFLG 2'b01
`define SY_UART_IFFLG  2'b10
`define SY_IIC_RDATA   32'h70030000
// IIC addr
`define SY_IIC_SLV_ADDR 7'b1001000
`define SY_STDID_CODE0 8'h32
`define SY_STDID_CODE1 8'h30
`define SY_STDID_CODE2 8'h32
`define SY_STDID_CODE3 8'h35
`define SY_STDID_CODE4 8'h32
`define SY_STDID_CODE5 8'h31
`define SY_STDID_CODE6 8'h30
`define SY_STDID_CODE7 8'h38
`define SY_STDID_CODE8 8'h37
`define SY_STDID_CODE9 8'h30

// J type inst
`define SY_INST_TYPE_B 7'b1100011
`define SY_INST_BEQ    3'b000
`define SY_INST_BNE    3'b001
`define SY_INST_BLT    3'b100
`define SY_INST_BGE    3'b101
`define SY_INST_BLTU   3'b110
`define SY_INST_BGEU   3'b111

`define SY_RomNum 256

`define SY_MemNum 16
`define SY_MemBus 31:0
`define SY_MemAddrBus 31:0

`define SY_InstBus 31:0
`define SY_InstAddrBus 31:0

// common regs
`define SY_RegAddrBus 4:0
`define SY_RegBus 31:0
`define SY_DoubleRegBus 63:0
`define SY_RegWidth 32
`define SY_RegNum 32        // reg num
`define SY_RegNumLog2 5

`endif
