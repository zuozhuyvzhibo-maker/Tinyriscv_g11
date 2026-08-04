`ifndef MERGED_LHR_DEFS_V
`define MERGED_LHR_DEFS_V
/*
 * Copyright 2019 Blue Liang, liangkangnan@163.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`ifndef LHR_TINYRISCV_DEFINES_V
`define LHR_TINYRISCV_DEFINES_V

// Global control values.
`define LHR_CpuResetAddr 32'h00000000
`define LHR_RstEnable 1'b0
`define LHR_RstDisable 1'b1
`define LHR_ZeroWord 32'h00000000
`define LHR_ZeroReg 5'h00
`define LHR_WriteEnable 1'b1
`define LHR_WriteDisable 1'b0
`define LHR_True 1'b1
`define LHR_False 1'b0
`define LHR_JumpEnable 1'b1
`define LHR_JumpDisable 1'b0
`define LHR_HoldEnable 1'b1
`define LHR_HoldDisable 1'b0
`define LHR_RIB_REQ 1'b1
`define LHR_RIB_NREQ 1'b0

// Pipeline hold levels. Larger values stall more pipeline stages.
`define LHR_Hold_Flag_Bus 2:0
`define LHR_Hold_None 3'b000
`define LHR_Hold_Pc 3'b001
`define LHR_Hold_If 3'b010
`define LHR_Hold_Id 3'b011
`define LHR_Hold_Id_Keep 3'b100
`define LHR_Hold_Id_Keep_If 3'b101

// RV32I immediate arithmetic instructions.
`define LHR_INST_TYPE_I 7'b0010011
`define LHR_INST_ADDI 3'b000
`define LHR_INST_SLTI 3'b010
`define LHR_INST_SLTIU 3'b011
`define LHR_INST_XORI 3'b100
`define LHR_INST_ORI 3'b110
`define LHR_INST_ANDI 3'b111
`define LHR_INST_SLLI 3'b001
`define LHR_INST_SRI 3'b101

// RV32I load instructions.
`define LHR_INST_TYPE_L 7'b0000011
`define LHR_INST_LB 3'b000
`define LHR_INST_LH 3'b001
`define LHR_INST_LW 3'b010
`define LHR_INST_LBU 3'b100
`define LHR_INST_LHU 3'b101

// RV32I store instructions.
`define LHR_INST_TYPE_S 7'b0100011
`define LHR_INST_SB 3'b000
`define LHR_INST_SH 3'b001
`define LHR_INST_SW 3'b010

// RV32I register arithmetic instructions. RV32M is intentionally absent.
`define LHR_INST_TYPE_R 7'b0110011
`define LHR_INST_ADD_SUB 3'b000
`define LHR_INST_SLL 3'b001
`define LHR_INST_SLT 3'b010
`define LHR_INST_SLTU 3'b011
`define LHR_INST_XOR 3'b100
`define LHR_INST_SR 3'b101
`define LHR_INST_OR 3'b110
`define LHR_INST_AND 3'b111

// RV32I control-flow and upper-immediate instructions.
`define LHR_INST_JAL 7'b1101111
`define LHR_INST_JALR 7'b1100111
`define LHR_INST_LUI 7'b0110111
`define LHR_INST_AUIPC 7'b0010111
`define LHR_INST_TYPE_B 7'b1100011
`define LHR_INST_BEQ 3'b000
`define LHR_INST_BNE 3'b001
`define LHR_INST_BLT 3'b100
`define LHR_INST_BGE 3'b101
`define LHR_INST_BLTU 3'b110
`define LHR_INST_BGEU 3'b111
`define LHR_INST_FENCE 7'b0001111

// TinyRISC-V uses this non-standard encoding as a pipeline bubble.
`define LHR_INST_NOP 32'h00000001
`define LHR_INST_NOP_OP 7'b0000001

// Course custom instructions (shared opcode, selected by funct3).
`define LHR_INST_CUSTOM 7'b0101111
`define LHR_INST_SID 3'b000
`define LHR_INST_RT 3'b001
`define LHR_INST_IF 3'b010

// Memory map retained by the reduced design.
`define LHR_ROM_BASE_ADDR 32'h00000000
`define LHR_RAM_BASE_ADDR 32'h10000000
`define LHR_UART_BASE_ADDR 32'h30000000
`define LHR_UART_CTRL_REG 32'h30000000
`define LHR_UART_STATUS_REG 32'h30000004
`define LHR_UART_BAUD_REG 32'h30000008
`define LHR_UART_TX_REG 32'h3000000c
`define LHR_UART_RX_REG 32'h30000010
`define LHR_UART_SEND_ID_REG 32'h30000014
`define LHR_PWM_BASE_ADDR 32'h60000000
`define LHR_I2C_BASE_ADDR 32'h70000000
`define LHR_I2C_SLAVE_ADDR_REG 32'h70010000
`define LHR_I2C_OUTPUT_REG 32'h70020000
`define LHR_I2C_INPUT_REG 32'h70030000

// FPGA-side program and data memory sizes used by bridge_fpga.
`define LHR_RomNum 256
// The supplied software links a 16 KiB data/stack region at 0x10000000.
// This storage is implemented by the FPGA-side bridge, not inside the ASIC.
`define LHR_MemNum 16

// Common bus widths.
`define LHR_MemBus 31:0
`define LHR_MemAddrBus 31:0
`define LHR_InstBus 31:0
`define LHR_InstAddrBus 31:0
`define LHR_RegAddrBus 4:0
`define LHR_RegBus 31:0
`define LHR_RegNum 32

`endif

`endif
