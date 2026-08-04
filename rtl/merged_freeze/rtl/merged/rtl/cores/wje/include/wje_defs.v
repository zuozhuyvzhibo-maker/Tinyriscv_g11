`ifndef MERGED_WJE_DEFS_V
`define MERGED_WJE_DEFS_V
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

`define WJE_CpuResetAddr 32'h0

`define WJE_RstEnable 1'b0
`define WJE_RstDisable 1'b1
`define WJE_ZeroWord 32'h0
`define WJE_ZeroReg 5'h0
`define WJE_WriteEnable 1'b1
`define WJE_WriteDisable 1'b0
`define WJE_ReadEnable 1'b1
`define WJE_ReadDisable 1'b0
`define WJE_True 1'b1
`define WJE_False 1'b0
`define WJE_ChipEnable 1'b1
`define WJE_ChipDisable 1'b0
`define WJE_JumpEnable 1'b1
`define WJE_JumpDisable 1'b0
`define WJE_DivResultNotReady 1'b0
`define WJE_DivResultReady 1'b1
`define WJE_DivStart 1'b1
`define WJE_DivStop 1'b0
`define WJE_HoldEnable 1'b1
`define WJE_HoldDisable 1'b0
`define WJE_Stop 1'b1
`define WJE_NoStop 1'b0
`define WJE_RIB_ACK 1'b1
`define WJE_RIB_NACK 1'b0
`define WJE_RIB_REQ 1'b1
`define WJE_RIB_NREQ 1'b0
`define WJE_INT_ASSERT 1'b1
`define WJE_INT_DEASSERT 1'b0

`define WJE_INT_BUS 7:0
`define WJE_INT_NONE 8'h0
`define WJE_INT_RET 8'hff
`define WJE_INT_TIMER0 8'b00000001
`define WJE_INT_TIMER0_ENTRY_ADDR 32'h4

`define WJE_Hold_Flag_Bus   2:0
`define WJE_Hold_None 3'b000
`define WJE_Hold_Pc   3'b001
`define WJE_Hold_If   3'b010
`define WJE_Hold_Id   3'b011
`define WJE_Hold_Mem  3'b100

// I type inst
`define WJE_INST_TYPE_I 7'b0010011
`define WJE_INST_ADDI   3'b000
`define WJE_INST_SLTI   3'b010
`define WJE_INST_SLTIU  3'b011
`define WJE_INST_XORI   3'b100
`define WJE_INST_ORI    3'b110
`define WJE_INST_ANDI   3'b111
`define WJE_INST_SLLI   3'b001
`define WJE_INST_SRI    3'b101

// L type inst
`define WJE_INST_TYPE_L 7'b0000011
`define WJE_INST_LB     3'b000
`define WJE_INST_LH     3'b001
`define WJE_INST_LW     3'b010
`define WJE_INST_LBU    3'b100
`define WJE_INST_LHU    3'b101

// S type inst
`define WJE_INST_TYPE_S 7'b0100011
`define WJE_INST_SB     3'b000
`define WJE_INST_SH     3'b001
`define WJE_INST_SW     3'b010

// R and M type inst
`define WJE_INST_TYPE_R_M 7'b0110011
// R type inst
`define WJE_INST_ADD_SUB 3'b000
`define WJE_INST_SLL    3'b001
`define WJE_INST_SLT    3'b010
`define WJE_INST_SLTU   3'b011
`define WJE_INST_XOR    3'b100
`define WJE_INST_SR     3'b101
`define WJE_INST_OR     3'b110
`define WJE_INST_AND    3'b111
// M type inst
`define WJE_INST_MUL    3'b000
`define WJE_INST_MULH   3'b001
`define WJE_INST_MULHSU 3'b010
`define WJE_INST_MULHU  3'b011
`define WJE_INST_DIV    3'b100
`define WJE_INST_DIVU   3'b101
`define WJE_INST_REM    3'b110
`define WJE_INST_REMU   3'b111

// J type inst
`define WJE_INST_JAL    7'b1101111
`define WJE_INST_JALR   7'b1100111

`define WJE_INST_LUI    7'b0110111
`define WJE_INST_AUIPC  7'b0010111
`define WJE_INST_NOP    32'h00000001
`define WJE_INST_NOP_OP 7'b0000001
`define WJE_INST_MRET   32'h30200073
`define WJE_INST_RET    32'h00008067

`define WJE_INST_FENCE  7'b0001111
`define WJE_INST_ECALL  32'h73
`define WJE_INST_EBREAK 32'h00100073

// J type inst
`define WJE_INST_TYPE_B 7'b1100011
`define WJE_INST_BEQ    3'b000
`define WJE_INST_BNE    3'b001
`define WJE_INST_BLT    3'b100
`define WJE_INST_BGE    3'b101
`define WJE_INST_BLTU   3'b110
`define WJE_INST_BGEU   3'b111

// CSR inst
`define WJE_INST_CSR    7'b1110011
`define WJE_INST_CSRRW  3'b001
`define WJE_INST_CSRRS  3'b010
`define WJE_INST_CSRRC  3'b011
`define WJE_INST_CSRRWI 3'b101
`define WJE_INST_CSRRSI 3'b110
`define WJE_INST_CSRRCI 3'b111

// Custom inst
`define WJE_INST_TYPE_CUSTOM 7'b0101111
`define WJE_INST_SID         3'b000
`define WJE_INST_RT          3'b001
`define WJE_INST_IF          3'b010

// CSR reg addr
`define WJE_CSR_CYCLE   12'hc00
`define WJE_CSR_CYCLEH  12'hc80
`define WJE_CSR_MTVEC   12'h305
`define WJE_CSR_MCAUSE  12'h342
`define WJE_CSR_MEPC    12'h341
`define WJE_CSR_MIE     12'h304
`define WJE_CSR_MSTATUS 12'h300
`define WJE_CSR_MSCRATCH 12'h340

// `define RomNum 4096  // rom depth(how many words)
`define WJE_RomNum 256  // rom depth(how many words)

// `define MemNum 4096  // memory depth(how many words)
`define WJE_MemNum 16  // memory depth(how many words)
`define WJE_MemBus 31:0
`define WJE_MemAddrBus 31:0

`define WJE_InstBus 31:0
`define WJE_InstAddrBus 31:0

// common regs
`define WJE_RegAddrBus 4:0
`define WJE_RegBus 31:0
`define WJE_DoubleRegBus 63:0
`define WJE_RegWidth 32
`define WJE_RegNum 32        // reg num
`define WJE_RegNumLog2 5

`endif
