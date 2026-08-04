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

`ifndef TINYRISCV_DEFINES_V
`define TINYRISCV_DEFINES_V

// Global control values.
`define CpuResetAddr 32'h00000000
`define RstEnable 1'b0
`define RstDisable 1'b1
`define ZeroWord 32'h00000000
`define ZeroReg 5'h00
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define True 1'b1
`define False 1'b0
`define JumpEnable 1'b1
`define JumpDisable 1'b0
`define HoldEnable 1'b1
`define HoldDisable 1'b0
`define RIB_REQ 1'b1
`define RIB_NREQ 1'b0

// Pipeline hold levels. Larger values stall more pipeline stages.
`define Hold_Flag_Bus 2:0
`define Hold_None 3'b000
`define Hold_Pc 3'b001
`define Hold_If 3'b010
`define Hold_Id 3'b011
`define Hold_Id_Keep 3'b100
`define Hold_Id_Keep_If 3'b101

// RV32I immediate arithmetic instructions.
`define INST_TYPE_I 7'b0010011
`define INST_ADDI 3'b000
`define INST_SLTI 3'b010
`define INST_SLTIU 3'b011
`define INST_XORI 3'b100
`define INST_ORI 3'b110
`define INST_ANDI 3'b111
`define INST_SLLI 3'b001
`define INST_SRI 3'b101

// RV32I load instructions.
`define INST_TYPE_L 7'b0000011
`define INST_LB 3'b000
`define INST_LH 3'b001
`define INST_LW 3'b010
`define INST_LBU 3'b100
`define INST_LHU 3'b101

// RV32I store instructions.
`define INST_TYPE_S 7'b0100011
`define INST_SB 3'b000
`define INST_SH 3'b001
`define INST_SW 3'b010

// RV32I register arithmetic instructions. RV32M is intentionally absent.
`define INST_TYPE_R 7'b0110011
`define INST_ADD_SUB 3'b000
`define INST_SLL 3'b001
`define INST_SLT 3'b010
`define INST_SLTU 3'b011
`define INST_XOR 3'b100
`define INST_SR 3'b101
`define INST_OR 3'b110
`define INST_AND 3'b111

// RV32I control-flow and upper-immediate instructions.
`define INST_JAL 7'b1101111
`define INST_JALR 7'b1100111
`define INST_LUI 7'b0110111
`define INST_AUIPC 7'b0010111
`define INST_TYPE_B 7'b1100011
`define INST_BEQ 3'b000
`define INST_BNE 3'b001
`define INST_BLT 3'b100
`define INST_BGE 3'b101
`define INST_BLTU 3'b110
`define INST_BGEU 3'b111
`define INST_FENCE 7'b0001111

// TinyRISC-V uses this non-standard encoding as a pipeline bubble.
`define INST_NOP 32'h00000001
`define INST_NOP_OP 7'b0000001

// Course custom instructions (shared opcode, selected by funct3).
`define INST_CUSTOM 7'b0101111
`define INST_SID 3'b000
`define INST_RT 3'b001
`define INST_IF 3'b010

// Memory map retained by the reduced design.
`define ROM_BASE_ADDR 32'h00000000
`define RAM_BASE_ADDR 32'h10000000
`define UART_BASE_ADDR 32'h30000000
`define UART_CTRL_REG 32'h30000000
`define UART_STATUS_REG 32'h30000004
`define UART_BAUD_REG 32'h30000008
`define UART_TX_REG 32'h3000000c
`define UART_RX_REG 32'h30000010
`define UART_SEND_ID_REG 32'h30000014
`define PWM_BASE_ADDR 32'h60000000
`define I2C_BASE_ADDR 32'h70000000
`define I2C_SLAVE_ADDR_REG 32'h70010000
`define I2C_OUTPUT_REG 32'h70020000
`define I2C_INPUT_REG 32'h70030000

// FPGA-side program and data memory sizes used by lhr_bridge_fpga.
`define RomNum 256
`define MemNum 16

// Common bus widths.
`define MemBus 31:0
`define MemAddrBus 31:0
`define InstBus 31:0
`define InstAddrBus 31:0
`define RegAddrBus 4:0
`define RegBus 31:0
`define RegNum 32

// Merge compatibility aliases. They let the three reduced submissions compile
// in one Verilog translation unit even when an include path resolves this file
// for all cores.
`ifndef RIB_ACK
`define RIB_ACK 1'b1
`endif
`ifndef RIB_NACK
`define RIB_NACK 1'b0
`endif
`ifndef INST_EXTEND
`define INST_EXTEND `INST_CUSTOM
`endif
`ifndef INST_TYPE_CUSTOM
`define INST_TYPE_CUSTOM `INST_CUSTOM
`endif
`ifndef INST_IFE
`define INST_IFE `INST_IF
`endif
`ifndef EXT_INST_DONE
`define EXT_INST_DONE 1'b1
`endif
`ifndef EXT_INST_NOT_DONE
`define EXT_INST_NOT_DONE 1'b0
`endif
`ifndef Hold_Mem
`define Hold_Mem 3'b100
`endif
`ifndef BridgeBus
`define BridgeBus 7:0
`endif
`ifndef AckEnable
`define AckEnable 1'b1
`endif
`ifndef AckDisable
`define AckDisable 1'b0
`endif
`ifndef SYS_CLK_HZ
`define SYS_CLK_HZ 100_000_000
`endif
`ifndef I2C_CLK_HZ
`define I2C_CLK_HZ 100_000
`endif
`ifndef CLK_DIVIDER
`define CLK_DIVIDER (`SYS_CLK_HZ / (4 * `I2C_CLK_HZ))
`endif

`endif
