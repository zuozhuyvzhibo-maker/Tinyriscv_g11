# tinyriscv — RISC-V RV32I Processor SoC

精简 RISC-V 处理器 SoC 项目，面向 FPGA 流片课程实践。

## 架构

```
┌─────────────────────────────────────────────────────────┐
│  tinyriscv_soc_top                                      │
│  ┌──────────────────────────────────────────────────┐   │
│  │  tinyriscv (core)                                │   │
│  │  ┌──────┐   ┌──────┐   ┌──────┐                 │   │
│  │  │pc_reg│ → │if_id │ → │  id  │                 │   │
│  │  └──────┘   └──────┘   └──────┘                 │   │
│  │                           ↓                      │   │
│  │  ┌──────┐   ┌──────┐   ┌──────┐                 │   │
│  │  │ ctrl │ ← │id_ex │ ← │ regs │                 │   │
│  │  └──────┘   └──────┘   └──────┘                 │   │
│  │                ↓                                 │   │
│  │            ┌──────┐                              │   │
│  │            │  ex  │ (组合逻辑 ALU)                │   │
│  │            └──────┘                              │   │
│  └──────────────────────────────────────────────────┘   │
│                         │ RIB 总线                       │
│    ┌──────┬──────┬──────┬──────┬──────┐                 │
│    │bridge│bridge│ uart │ pwm  │ i2c  │                 │
│    │(rom) │(ram) │      │      │      │                 │
│    └──────┴──────┴──────┴──────┴──────┘                 │
│                                                         │
│  uart_debug (串口下载)                                   │
│  over / succ 测试监控 (regs[26]/[27])                    │
└─────────────────────────────────────────────────────────┘
```

## 特性

| 项目 | 说明 |
|------|------|
| 指令集 | RV32I (37 条) + 3 条 EXT 扩展指令 |
| 流水线 | 3 级：IF → ID → EX |
| 总线 | RIB (4 主 5 从)，地址高 4 位译码 |
| 通用寄存器 | 32 × 32bit，支持写优先转发 |
| 外设 | UART (115200/8N1)、PWM (4 通道)、I2C Master (~400kHz) |
| 片外访问 | bridge 模块，32-bit ↔ 8-bit 串行帧协议 |
| 调试 | `uart_debug` 串口下载固件 (CRC16) |
| 复位 | 低电平复位 (`RstEnable = 1'b0`) |
| 时钟 | 50MHz |

## 指令集

### RV32I 基础指令

| 类别 | 指令 |
|------|------|
| I-type | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRI |
| R-type | ADD, SUB, SLL, SLT, SLTU, XOR, SR, OR, AND |
| L-type | LB, LH, LW, LBU, LHU |
| S-type | SB, SH, SW |
| B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| J-type | JAL, JALR |
| U-type | LUI, AUIPC |
| 其他 | FENCE, NOP |

### EXT 扩展指令

| 指令 | funct3 | 功能 |
|------|--------|------|
| EXTSID | 000 | UART 流输出 STDiD 标识序列 |
| EXTRT | 001 | 读取 I2C 数据寄存器 (`0x70030000`) |
| EXTIF | 010 | 条件 UART 发送 / 寄存器复制 / 立即数加 |

### 已删除指令

乘除法 (MUL/MULH/MULHU/MULHSU/DIV/DIVU/REM/REMU)、CSR 操作、ECALL/EBREAK/MRET

## Hold 流水线控制

| 级别 | 值 | 行为 | 触发场景 |
|------|-----|------|----------|
| Hold_None | 000 | 正常流水 | — |
| Hold_Pc | 001 | 冻结 PC | 外设寄存器访问 (UART/PWM/I2C) |
| Hold_If | 010 | PC + IF 冻结，IF/ID flush | (预留) |
| Hold_Id | 011 | PC + IF + ID 冻结，ID/EX flush | 跳转指令 (flush 下一条的 NOP) |
| Hold_Rib | 100 | 整条流水线 stall | bridge 串行访问片外 ROM/RAM |

## 地址映射

| 地址 [31:28] | 从设备 | 模块 |
|-------------|--------|------|
| 0x0 | slave_0 | ROM (需 bridge) |
| 0x1 | slave_1 | RAM (需 bridge) |
| 0x3 | slave_3 | UART |
| 0x6 | slave_6 | PWM |
| 0x7 | slave_7 | I2C |

## 文件清单

```
rtl/
├── core/          处理器核
│   ├── defines.v       全局宏定义
│   ├── pc_reg.v        PC 寄存器
│   ├── if_id.v         IF→ID 流水线寄存器
│   ├── id.v            译码模块
│   ├── id_ex.v         ID→EX 流水线寄存器
│   ├── ex.v            执行模块
│   ├── regs.v          通用寄存器堆
│   ├── ctrl.v          流水线控制器
│   ├── tinyriscv.v     核顶层
│   └── rib.v           RIB 总线互连
├── soc/           系统顶层
│   ├── tinyriscv_soc_top.v       SOC 顶层
│   └── tinyriscv_soc_top_FPGA.v  FPGA 板级顶层
├── perips/        外设与桥
│   ├── bridge.v        片外访问桥 (32b→8b)
│   ├── bridge_fpga.v   片外端桥 (8b→片外ROM/RAM)
│   ├── rom_ext.v       片外 ROM 模型
│   ├── ram_ext.v       片外 RAM 模型
│   ├── uart.v          UART 外设
│   ├── pwm.v           PWM 外设
│   └── i2c.v           I2C Master 外设
├── debug/         调试
│   └── uart_debug.v    串口固件下载模块
├── utils/         工具库
│   ├── gen_dff.v       参数化 DFF (含流水线 stall/flush)
│   ├── full_handshake_rx.v  全握手 RX
│   ├── full_handshake_tx.v  全握手 TX
│   └── gen_buf.v       多级同步器
└── Test/          仿真
    └── tinyriscv_soc_tb.v   SOC 测试平台
```

## 仿真 (VCS)

```bash
vcs -f filelist.f -full64 -sverilog -timescale=1ns/1ps
```

## 测试

测试结果通过寄存器监控：
- `regs[26] = 1` → 测试结束 (over)
- `regs[27] = 1` → 测试通过 (succ)，`0` → 失败

## 已删除模块

div (除法器)、csr_reg (CSR 寄存器)、clint (中断控制器)、jtag_top/jtag_dm/jtag_driver (JTAG 调试)、timer (定时器)、spi (SPI 控制器)、gpio (GPIO 控制器)、iic (I2C 重复文件)

## 注意事项

1. **复位极性**：低电平复位 (`RstEnable = 1'b0`)
2. **测试平台 `TEST_JTAG` 路径已失效**：JTAG 相关端口已从顶层删除，仅 `TEST_PROG` 模式可用
3. **`$readmemh` 路径**：测试平台和 `rom_ext.v` 中的初始化路径需根据实际环境修改
4. **I2C 模块名为 `iic`**：文件 `perips/i2c.v` 中模块名为 `iic`，顶层例化时使用 `iic`
