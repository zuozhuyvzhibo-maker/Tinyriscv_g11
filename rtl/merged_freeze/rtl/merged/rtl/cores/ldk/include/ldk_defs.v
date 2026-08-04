`ifndef MERGED_LDK_DEFS_V
`define MERGED_LDK_DEFS_V
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

`define LDK_CpuResetAddr 32'h0

`define LDK_RstEnable 1'b0
`define LDK_RstDisable 1'b1
`define LDK_ZeroWord 32'h0
`define LDK_ZeroReg 5'h0
`define LDK_ZeroTempReg 8'h0
`define LDK_WriteEnable 1'b1
`define LDK_WriteDisable 1'b0
`define LDK_ReadEnable 1'b1
`define LDK_ReadDisable 1'b0 // --liudk 2026-05-05
`define LDK_True 1'b1
`define LDK_False 1'b0
`define LDK_ChipEnable 1'b1
`define LDK_ChipDisable 1'b0
`define LDK_JumpEnable 1'b1
`define LDK_JumpDisable 1'b0
`define LDK_HoldEnable 1'b1
`define LDK_HoldDisable 1'b0
`define LDK_Stop 1'b1
`define LDK_NoStop 1'b0
`define LDK_RIB_ACK 1'b1
`define LDK_RIB_NACK 1'b0
`define LDK_RIB_REQ 1'b1
`define LDK_RIB_NREQ 1'b0
`define LDK_INT_ASSERT 1'b1
`define LDK_INT_DEASSERT 1'b0

`define LDK_INT_BUS 7:0
`define LDK_INT_NONE 8'h0
`define LDK_INT_RET 8'hff
`define LDK_INT_TIMER0 8'b00000001
`define LDK_INT_TIMER0_ENTRY_ADDR 32'h4

`define LDK_Hold_Flag_Bus   2:0
`define LDK_Hold_None 3'b000
`define LDK_Hold_Pc   3'b001
`define LDK_Hold_If   3'b010
`define LDK_Hold_Id   3'b011

// I type inst
`define LDK_INST_TYPE_I 7'b0010011
`define LDK_INST_ADDI   3'b000
`define LDK_INST_SLTI   3'b010
`define LDK_INST_SLTIU  3'b011
`define LDK_INST_XORI   3'b100
`define LDK_INST_ORI    3'b110
`define LDK_INST_ANDI   3'b111
`define LDK_INST_SLLI   3'b001
`define LDK_INST_SRI    3'b101

// L type inst
`define LDK_INST_TYPE_L 7'b0000011
`define LDK_INST_LB     3'b000
`define LDK_INST_LH     3'b001
`define LDK_INST_LW     3'b010
`define LDK_INST_LBU    3'b100
`define LDK_INST_LHU    3'b101

// S type inst
`define LDK_INST_TYPE_S 7'b0100011
`define LDK_INST_SB     3'b000
`define LDK_INST_SH     3'b001
`define LDK_INST_SW     3'b010

// R and M type inst
`define LDK_INST_TYPE_R_M 7'b0110011
// R type inst
`define LDK_INST_ADD_SUB 3'b000
`define LDK_INST_SLL    3'b001
`define LDK_INST_SLT    3'b010
`define LDK_INST_SLTU   3'b011
`define LDK_INST_XOR    3'b100
`define LDK_INST_SR     3'b101
`define LDK_INST_OR     3'b110
`define LDK_INST_AND    3'b111
// M type inst
`define LDK_INST_MUL    3'b000
`define LDK_INST_MULH   3'b001
`define LDK_INST_MULHSU 3'b010
`define LDK_INST_MULHU  3'b011
`define LDK_INST_REM    3'b110
`define LDK_INST_REMU   3'b111

// J type inst
`define LDK_INST_JAL    7'b1101111
`define LDK_INST_JALR   7'b1100111

`define LDK_INST_LUI    7'b0110111
`define LDK_INST_AUIPC  7'b0010111
`define LDK_INST_NOP    32'h00000001
`define LDK_INST_NOP_OP 7'b0000001
`define LDK_INST_MRET   32'h30200073
`define LDK_INST_RET    32'h00008067

`define LDK_INST_FENCE  7'b0001111
`define LDK_INST_ECALL  32'h73
`define LDK_INST_EBREAK 32'h00100073

// J type inst
`define LDK_INST_TYPE_B 7'b1100011
`define LDK_INST_BEQ    3'b000
`define LDK_INST_BNE    3'b001
`define LDK_INST_BLT    3'b100
`define LDK_INST_BGE    3'b101
`define LDK_INST_BLTU   3'b110
`define LDK_INST_BGEU   3'b111

// CSR inst
`define LDK_INST_CSR    7'b1110011
`define LDK_INST_CSRRW  3'b001
`define LDK_INST_CSRRS  3'b010
`define LDK_INST_CSRRC  3'b011
`define LDK_INST_CSRRWI 3'b101
`define LDK_INST_CSRRSI 3'b110
`define LDK_INST_CSRRCI 3'b111

//rT inst
`define LDK_INST_EXTEND 7'b0101111
`define LDK_INST_SID    3'b000
`define LDK_INST_RT     3'b001
`define LDK_INST_IFE     3'b010

// CSR reg addr
`define LDK_CSR_CYCLE   12'hc00
`define LDK_CSR_CYCLEH  12'hc80
`define LDK_CSR_MTVEC   12'h305
`define LDK_CSR_MCAUSE  12'h342
`define LDK_CSR_MEPC    12'h341
`define LDK_CSR_MIE     12'h304
`define LDK_CSR_MSTATUS 12'h300
`define LDK_CSR_MSCRATCH 12'h340

`define LDK_RomNum 256   // shared FPGA ROM depth (words)

`define LDK_MemNum 16    // shared FPGA RAM physical depth (words)
`define LDK_MemBus 31:0
`define LDK_MemAddrBus 31:0

`define LDK_InstBus 31:0
`define LDK_InstAddrBus 31:0

// common regs
`define LDK_RegAddrBus 4:0
`define LDK_RegBus 31:0
`define LDK_DoubleRegBus 63:0
`define LDK_RegWidth 32
`define LDK_RegNum 32        // reg num
`define LDK_RegNumLog2 5

// bridge
`define LDK_BridgeBus 7:0
`define LDK_StatusBus 4:0
`define LDK_StatusBus_slave 3:0
`define LDK_WriteCmd 8'h01
`define LDK_ReadCmd 8'h02
`define LDK_CmdSimple 1:0
`define LDK_WriteCmd_simp 2'b01
`define LDK_ReadCmd_simp 2'b10

`define LDK_AddrOrDataSlice0 7:0
`define LDK_AddrOrDataSlice1 15:8
`define LDK_AddrOrDataSlice2 23:16
`define LDK_AddrOrDataSlice3 31:24
`define LDK_WE_RespCmd 8'h0F

`define LDK_ZeroCmdSimple 2'b00

//RIB
`define LDK_AckEnable 1'b1
`define LDK_AckDisable 1'b0

// IIC
`define LDK_Addr_AddrReg 32'h7001_0000
`define LDK_Addr_DataOutReg 32'h7002_0000
`define LDK_Addr_DataInReg 32'h7003_0000
`define LDK_IICWrite 2'b10
`define LDK_IICRead 2'b11

`define LDK_SYS_CLK_HZ 100_000_000
`define LDK_I2C_CLK_HZ 100_000
`define LDK_CLK_DIVIDER (`LDK_SYS_CLK_HZ / (4 * `LDK_I2C_CLK_HZ))

`define LDK_BusyEnable 1'b1
`define LDK_BusyDisable 1'b0

// INST_SID
`define LDK_SID_MEM_WADDR
`define LDK_EXT_INST_DONE 1'b1
`define LDK_EXT_INST_NOT_DONE 1'b0



`endif
