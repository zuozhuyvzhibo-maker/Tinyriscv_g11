# TinyRISC-V 四核合并项目工作说明

本文档记录目录 `D:\liudk\project\tinyriscv_dk\tinyriscv\rtl_tomerge\rtl` 下四份 TinyRISC-V 资源删减后 RTL 的项目背景、目录结构、当前合并方案、已经完成的工作、验证情况、用户提出过的主要问题，以及目前仍未完成或需要继续修正的事项。

文档生成时间：2026-08-04

## 1. 项目背景

本项目基于 TinyRISC-V 处理器教学工程。前期单人版本已经围绕基础 RV32I 指令、扩展指令、UART、IIC 温度读取、PWM 外设等内容做过多轮设计、调试和仿真。随后进入小组合并阶段：四位同学分别完成资源删减后的 RTL 版本，需要把四份代码合并到一个统一工程中，并通过 `chip_sel` 信号选择当前使用哪一个 core。

从用户提供的作业要求图片可知，合并前每个人都需要完成资源删减，主要包括：

1. 删除乘除法指令及对应模块。
2. 删除 CSR/CLINT/异常支持。
3. 删除 Timer/SPI/GPIO/JTAG 外设。
4. 保留 RV32I 指令集和扩展指令。

合并阶段的要求是资源公用，主要包括：

1. 公用通用寄存器 `regs`。
2. 公用 `pwm` 外设。
3. 公用 `uart_debug` 模块。
4. 通过 `chip_sel[1:0]` 进行四个 core 的选择。

需要特别说明：当前已经完成的是“四份 RTL 的功能级合并、统一顶层选择和统一回归仿真”。当前版本并没有真正完成上述三项硬件资源的物理共享，即没有做到综合后只有一份 `regs`、一份 `pwm`、一份 `uart_debug`。这一点在本文档后面的“未完成事项”中单独列出。

## 2. 工作目录结构

根目录：

```text
D:\liudk\project\tinyriscv_dk\tinyriscv\rtl_tomerge\rtl
```

当前主要目录如下：

```text
rtl_tomerge/rtl
|-- lhr
|-- ldk
|-- wje
|-- sy
`-- merge_version
```

各目录含义如下。

### 2.1 `lhr`

路径：

```text
rtl_tomerge/rtl/lhr
```

这是 LHR 同学的资源删减版本。其典型结构包括：

```text
lhr
|-- filelist.f
|-- filelist_fpga.f
|-- filelist_sim.f
|-- README.md
|-- fpga
|   |-- bridge_fpga.v
|   |-- fpga_uart_debug.v
|   |-- tinyriscv_soc_top_bridge_fpga.v
|   `-- constrs/tinyriscv.xdc
|-- rtl
|   |-- core
|   |   |-- ctrl.v
|   |   |-- defines.v
|   |   |-- ex.v
|   |   |-- id.v
|   |   |-- id_ex.v
|   |   |-- if_id.v
|   |   |-- pc_reg.v
|   |   |-- regs.v
|   |   |-- rib_ext_bridge.v
|   |   `-- tinyriscv.v
|   |-- perips
|   |   |-- ext_mem_bridge.v
|   |   |-- i2c.v
|   |   |-- pwm.v
|   |   `-- uart.v
|   |-- soc
|   |   `-- tinyriscv_chip_top_bridge.v
|   `-- utils
|       `-- gen_dff.v
|-- tb
|-- tests
`-- tools
```

LHR 版本自带测试数据，尤其 `tests/programs/basic` 中有 20 条基础 RV32I 非乘除法指令测试数据，后续合并回归脚本默认使用 LHR 的基础测试作为统一基础指令回归源。

### 2.2 `ldk`

路径：

```text
rtl_tomerge/rtl/ldk
```

这是 LDK 同学的资源删减版本。其核心路径为：

```text
ldk/rtl_liudk
|-- tinyriscv.f
|-- core
|   |-- ctrl_dk.v
|   |-- defines.v
|   |-- ex.v
|   |-- id.v
|   |-- id_ex.v
|   |-- if_id.v
|   |-- pc_reg.v
|   |-- regs.v
|   |-- rib.v
|   `-- tinyriscv.v
|-- debug
|   `-- uart_debug.v
|-- perips
|   |-- bridge_master.v
|   |-- bridge_slave.v
|   |-- iic_dk.v
|   |-- pwm.v
|   `-- uart.v
|-- soc
|   |-- bridge_slave_top.v
|   |-- tinyriscv_soc_top.v
|   `-- tinyriscv_soc_top_with_bridge.v
`-- utils
```

LDK 版本中包含用户此前设计和调试过的 `iic_dk.v`、`ctrl_dk.v`、扩展指令状态机、bridge 主从模块等。

### 2.3 `wje`

路径：

```text
rtl_tomerge/rtl/wje
```

这是 WJE 同学的资源删减版本。主要有效目录为：

```text
wje/rtl
|-- core
|-- debug
|-- perips
|-- soc
`-- utils
```

其中还保留了部分原 Vivado 工程导入目录：

```text
wje/tinyriscv_master.srcs
```

在合并版本中，主要使用 `wje/rtl` 下的源码，而不是完整 Vivado 工程导入目录。

### 2.4 `sy`

路径：

```text
rtl_tomerge/rtl/sy
```

这是后来新增的 SY 同学版本。其结构较完整：

```text
sy
|-- filelist.f
|-- README.md
|-- core
|-- debug
|-- perips
|-- soc
|-- Test
|-- utils
`-- XDC
```

SY 自带基础指令、扩展指令和外设测试数据：

```text
sy/Test/Baisc_Inst_Example
sy/Test/Extend_Inst_Example/IF
sy/Test/Extend_Inst_Example/sID
sy/Test/Extend_Inst_Example/Temp
sy/Test/Other_Example/PWM
```

在合并回归中，`chip_sel == 3` 时扩展指令和外设测试使用 SY 自己的测试数据。

### 2.5 `merge_version`

路径：

```text
rtl_tomerge/rtl/merge_version
```

这是当前合并版本目录。主要文件和目录如下：

```text
merge_version
|-- lhr
|-- ldk
|-- wje
|-- sy
|-- tb
|   `-- tinyriscv_merge_validation_tb.v
|-- verification
|   |-- build
|   |-- logs
|   `-- merge_regression_summary.txt
|-- tinyriscv_merge_top.v
|-- merge_filelist.f
|-- run_merge_regression.ps1
`-- MERGE_SUMMARY.md
```

`merge_version` 中四个子目录是从四个原始目录复制并进一步处理后的版本。处理内容包括模块名前缀、include 路径调整、少量顶层接口对齐和仿真修正。

## 3. 原始代码复位极性确认

用户曾专门询问四份原始代码中的复位极性。逐个确认如下：

### 3.1 LHR

文件：

```text
rtl_tomerge/rtl/lhr/rtl/core/defines.v
```

定义：

```verilog
`define RstEnable 1'b0
`define RstDisable 1'b1
```

### 3.2 LDK

文件：

```text
rtl_tomerge/rtl/ldk/rtl_liudk/core/defines.v
```

定义：

```verilog
`define RstEnable 1'b0
`define RstDisable 1'b1
```

### 3.3 WJE

文件：

```text
rtl_tomerge/rtl/wje/rtl/core/defines.v
```

定义：

```verilog
`define RstEnable 1'b0
`define RstDisable 1'b1
```

### 3.4 SY

文件：

```text
rtl_tomerge/rtl/sy/core/defines.v
```

定义：

```verilog
`define RstEnable 1'b0
`define RstDisable 1'b1
```

结论：四份原始代码全部为低电平复位有效，即：

```text
rst = 0: 复位有效
rst = 1: 正常运行
```

这会直接影响合并顶层中未选中 core 的复位控制逻辑。对于低有效复位，如果希望“全局 rst 为低时复位所有 core，某个 core 未被选中时也保持复位”，则每个 core 的内部复位输入应该为：

```verilog
rst_core = rst & sel_core;
```

而不是：

```verilog
rst_core = rst | ~sel_core;
```

当前 `merge_version/tinyriscv_merge_top.v` 中仍为 `.rst(rst | ~sel_xxx)`，这是一个已经识别出的待修正事项。

## 4. 当前合并版本总体方案

当前合并顶层文件为：

```text
rtl_tomerge/rtl/merge_version/tinyriscv_merge_top.v
```

该顶层做了以下工作：

1. 同时例化四份处理器 SoC 顶层。
2. 根据 `chip_sel` 判断当前选中哪一个 core。
3. 将未选中的 core 送入复位状态。
4. 将 UART 输出、PWM 输出、IIC 总线、`succ`、`over` 等信号通过 mux 或三态隔离方式汇聚到合并顶层。
5. 提供兼容旧顶层名的 wrapper：`tinyriscv_soc_top_with_bridge`。

当前选择关系为：

```verilog
chip_sel == 3'd0: LHR
chip_sel == 3'd1: LDK
chip_sel == 3'd2: WJE
chip_sel == 3'd3: SY
```

当前顶层端口中 `chip_sel` 为 3 位：

```verilog
input wire[2:0] chip_sel
```

作业图片要求是 `chip_sel[1:0]` 选择四个 core，因此这里仍需调整为 2 位。

## 5. 已经完成的工作

### 5.1 四份源码导入到合并目录

已经将 LHR、LDK、WJE、SY 四份代码复制到：

```text
rtl_tomerge/rtl/merge_version/lhr
rtl_tomerge/rtl/merge_version/ldk
rtl_tomerge/rtl/merge_version/wje
rtl_tomerge/rtl/merge_version/sy
```

合并版本只在 `merge_version` 目录下进行修改，不直接修改四个人原始目录。

### 5.2 模块名前缀隔离

由于四份代码中存在大量同名模块，例如：

```text
tinyriscv
regs
ctrl
ex
id
id_ex
if_id
pc_reg
rib
uart
pwm
uart_debug
bridge
bridge_fpga
```

如果直接放入同一个 filelist，会造成 Verilog 模块重定义。为解决该问题，合并版本中对四份源码做了模块名前缀隔离：

```text
LHR: lhr_
LDK: ldk_
WJE: wje_
SY : sy_
```

例如：

```text
lhr_tinyriscv
ldk_tinyriscv
wje_tinyriscv
sy_tinyriscv
```

该处理的目的是让四份源码能够在同一个仿真工程中同时编译。

### 5.3 include 路径调整

多份代码原本使用：

```verilog
`include "defines.v"
```

在合并环境中，这种写法可能被 `iverilog` 的 include 搜索路径影响，导致某个 core 错误引用另一个 core 的 `defines.v`。因此合并版本中把相关 include 修改为更明确的本地路径，例如：

```verilog
`include "../core/defines.v"
```

该处理降低了宏定义串扰风险。

### 5.4 新增合并顶层 `tinyriscv_merge_top.v`

文件：

```text
rtl_tomerge/rtl/merge_version/tinyriscv_merge_top.v
```

该文件中例化了四路顶层：

```verilog
lhr_tinyriscv_soc_top_bridge_fpga u_lhr_top(...)
ldk_tinyriscv_soc_top_with_bridge u_ldk_top(...)
wje_tinyriscv_board_top u_wje_top(...)
sy_tinyriscv_soc_top_FPGA u_sy_top(...)
```

并对输出做选择：

```verilog
assign uart_tx_pin = sel_lhr ? lhr_uart_tx :
                     sel_ldk ? ldk_uart_tx :
                     sel_wje ? wje_uart_tx :
                     sel_sy  ? sy_uart_tx  :
                     1'b1;
```

```verilog
assign pwm_o = sel_lhr ? lhr_pwm :
               sel_ldk ? ldk_pwm :
               sel_wje ? wje_pwm :
               sel_sy  ? sy_pwm  :
               4'b0000;
```

```verilog
assign succ = sel_lhr ? lhr_succ :
              sel_ldk ? ldk_succ :
              sel_wje ? wje_succ :
              sel_sy  ? sy_succ  :
              1'b1;
```

### 5.5 IIC 总线隔离

IIC 总线中 SDA 是开漏/三态风格信号，不同 core 如果同时挂在总线上，未选中 core 的复位态输出可能导致 `X` 或错误拉低。

当前合并顶层中对 SDA/SCL 做了隔离：

```verilog
tranif1 u_lhr_sda_sw(io_sda, lhr_sda, sel_lhr);
tranif1 u_ldk_sda_sw(io_sda, ldk_sda, sel_ldk);
tranif1 u_wje_sda_sw(io_sda, wje_sda, sel_wje);
tranif1 u_wje_scl_sw(io_scl, wje_scl, sel_wje);
tranif1 u_sy_sda_sw(io_sda, sy_sda, sel_sy);
```

SCL 对于 LHR、LDK、SY 当前采用 mux 输出，WJE 使用 `tranif1` 接入。

### 5.6 PWM 输出宽度对齐

SY 原始 FPGA 顶层只导出 3 位 PWM：

```verilog
output wire[2:0] PWM_o
```

但内部 PWM 为 4 路。为了统一四份代码的 PWM 输出宽度，合并版本中把 SY 顶层改为：

```verilog
output wire[3:0] PWM_o
assign PWM_o = PWM_o_inter;
```

相关文件：

```text
rtl_tomerge/rtl/merge_version/sy/soc/tinyriscv_soc_top_FPGA.v
```

### 5.7 LDK rT 控制状态修正

此前 LDK 的 rT 扩展指令测试中发现状态转换存在问题。合并版本中修正了 `ctrl_dk.v` 中 rT 状态跳转，使 rT 能进入：

```text
S_RT_R_REQ
S_RT_R_WAIT
```

并整理了 `S_MEM_R_WAIT` 的状态转换结构，使其更明确。

相关文件：

```text
rtl_tomerge/rtl/merge_version/ldk/rtl_liudk/core/ctrl_dk.v
```

### 5.8 LDK ROM/RAM 缺失文件补齐

在合并过程中，LDK 版本需要 `rom.v` 和 `ram.v` 支撑 bridge slave top。合并版本中已经补齐：

```text
rtl_tomerge/rtl/merge_version/ldk/rtl_liudk/perips/rom.v
rtl_tomerge/rtl/merge_version/ldk/rtl_liudk/perips/ram.v
```

### 5.9 新增统一 filelist

文件：

```text
rtl_tomerge/rtl/merge_version/merge_filelist.f
```

该文件列出合并顶层和四份 core 的所有设计文件，用于 `iverilog` 编译。

### 5.10 新增统一仿真 TB

文件：

```text
rtl_tomerge/rtl/merge_version/tb/tinyriscv_merge_validation_tb.v
```

该 TB 的主要能力：

1. 根据 `+CHIP_SEL=` 选择当前验证哪一路 core。
2. 根据 `+MEMFILE=` 把测试程序装入对应 ROM。
3. 检查基础指令测试中的 `x26/x27` 结束标志。
4. 检查 sID 指令 UART 输出字节。
5. 检查 IF/IFE 指令 UART 输出是否为 `0x8a`。
6. 检查 rT 温度指令 UART 输出。
7. 检查 PWM 四路输出是否都出现过高低变化。
8. 内置 LM75 slave 模型，供 IIC 温度测试使用。

### 5.11 SY rT 仿真初始化处理

SY 的 IIC 模块中温度输入寄存器 `in_reg` 在复位时没有初始化。rT 程序会较早读取该寄存器，如果仿真中它仍为 `X`，会导致后续 RAM 写数据带 `X`，进而使 bridge 内部 `same_req` 比较异常，PC 长时间 hold。

因此在统一 TB 中，对 SY 的 rT 测试做了仿真初始化：

```verilog
dut.u_sy_top.tinyriscv_soc_top_0.u_iic.in_reg = 32'h00000032;
```

这里 `0x32` 对应测试期望的 25 度输出字节。该处理只影响仿真初始化，不修改 SY 设计文件的行为。

### 5.12 新增统一回归脚本

文件：

```text
rtl_tomerge/rtl/merge_version/run_merge_regression.ps1
```

功能：

1. 使用 `iverilog` 编译合并版本。
2. 遍历 `chip_sel = 0, 1, 2, 3`。
3. 对每一路 core 跑基础 RV32I 非乘除法指令。
4. 对每一路 core 跑 sID、IF/IFE、rT、PWM 测试。
5. 每个测试生成独立 log。
6. 汇总生成 `merge_regression_summary.txt`。

运行命令：

```powershell
powershell -ExecutionPolicy Bypass -File rtl_tomerge\rtl\merge_version\run_merge_regression.ps1
```

### 5.13 新增简要总结文件

文件：

```text
rtl_tomerge/rtl/merge_version/MERGE_SUMMARY.md
```

该文件记录当前合并版本的简要说明、关键修正和验证结果。

## 6. 当前验证结果

统一回归脚本已经跑通过。覆盖范围如下：

### 6.1 基础 RV32I 非乘除法测试

共 20 条基础指令测试：

```text
inst_add
inst_andi
inst_auipc
inst_beq
inst_bge
inst_bgeu
inst_blt
inst_bltu
inst_bne
inst_jal
inst_jalr
inst_lui
inst_ori
inst_simple
inst_slli
inst_slti
inst_sltiu
inst_srai
inst_srli
inst_xori
```

每个 `chip_sel` 都跑上述 20 条：

```text
chip_sel=0: 20/20 PASS
chip_sel=1: 20/20 PASS
chip_sel=2: 20/20 PASS
chip_sel=3: 20/20 PASS
```

### 6.2 扩展指令和外设测试

测试项目：

```text
sID_inst
IF_inst
Temp
PWM_inst
```

每个 `chip_sel` 都跑上述 4 项：

```text
chip_sel=0: 4/4 PASS
chip_sel=1: 4/4 PASS
chip_sel=2: 4/4 PASS
chip_sel=3: 4/4 PASS
```

### 6.3 总计

```text
4 个 core * (20 个基础测试 + 4 个扩展/外设测试) = 96 个测试
96/96 PASS
```

最终脚本输出：

```text
ALL TESTS PASSED
```

汇总文件：

```text
rtl_tomerge/rtl/merge_version/verification/merge_regression_summary.txt
```

## 7. 用户提出过的主要问题整理

下面按时间和主题整理用户在整个项目推进过程中提出过的主要问题。由于早期内容较多，这里按工程主题合并整理，而不是逐字重复每一条自然语言请求。

### 7.1 IIC 主机时序与 `iic_dk.v` 检查

用户最开始要求检查 `iic_dk.v`，重点包括：

1. 是否符合 IIC 时序。
2. 是否存在 `if` 结构无 `else` 的情况。
3. 是否存在计数寄存器清零时机不完全的问题。
4. 状态之间转换是否正确。
5. 最后输出赋值是否正确。

随后用户解释了 `scl_reg` 与 `scl_phrase` 的更新关系，指出 `scl_phrase` 比 `iic_tick` 落后一个时钟周期，因此不同相位下 `scl_reg` 和 `sda_reg` 的赋值需要结合这个延迟理解。

后续又要求：

1. 编写简单 IIC TB。
2. 调用 ModelSim 或 VCS/Verdi 仿真查看波形。
3. 对比不同目录下的 `iic_dk.v`。
4. 将 `iic_dk.v` 中用到的宏定义搬移到 `defines.v`。
5. 解决 `iverilog` include 找不到 `defines.v` 的问题。

### 7.2 VSCode、iverilog、API 补全相关问题

用户提出过：

1. VSCode 中 `defines.v not found` 的报错如何解决。
2. VSCode 自动补全消失的原因。
3. 是否有代码补全平替方案。
4. 是否可以通过 API 调用云端模型实现补全。

这些问题属于开发环境和工具链层面。

### 7.3 大作业扩展指令设计

用户上传大作业要求后，围绕三条扩展指令进行了设计讨论，包括：

1. sID 指令状态机如何设计。
2. 状态机应该放在 `ctrl_dk.v` 还是 `ex.v`。
3. 从 FPGA 硬件资源角度应该如何选择。
4. `mem_we`、`mem_addr`、`mem_wdata` 如何传递到 RIB。
5. IF/IFE 指令状态机应该如何设计。
6. rT 指令是否需要状态机。
7. rT 指令中 req/ack 信号应如何处理。

其中 sID 和 IFE 采用了 UART 输出相关逻辑；rT 与 IIC 温度读取相关。

### 7.4 顶层接口删减与默认值处理

用户删除了 GPIO、JTAG、SPI 等模块后，要求处理顶层接口：

1. 输出信号悬空。
2. 输入信号赋默认值。
3. `jtag_reset_flag_i` 等复位/调试输入如何处理。
4. RIB 中部分 slave 接口默认值如何赋值。
5. IIC 顶层 `io_scl`、`io_sda` 三态连接是否正确。

### 7.5 编译整个 SoC 并修正报错

用户要求以 `soc_with_bridge` 或相关顶层为顶层进行编译，查看错误并修正。

期间出现过 VSCode 报告 unknown module 的问题，包括：

```text
tinyriscv
uart
rib
bridge_master
uart_debug
iic_dk
```

这类问题主要和 VSCode/iverilog 插件没有完整 filelist 或 include 路径有关。

### 7.6 sID 指令仿真

用户要求：

1. 阅读 sID 文件夹中说明。
2. 参考已有 TB。
3. 通过 UART_DEBUG 把 `sID_inst.data` 写入 ROM。
4. 启动处理器执行。
5. 检查 UART 端是否输出学号。

期间还要求回滚某些 `rtl/core` 改动，避免验证工作污染设计文件。

### 7.7 RAM 地址、load/store、bridge 握手问题

用户发现 `sw` 或 `load/store` 类指令等待 ack 时可能卡住，提出：

1. 判断 RAM 中数据为何看似只取高 30 位。
2. 对比 `.data` 与 `.dump` 是否一致。
3. 梳理 RAM 写入地址。
4. 查看仿真后整个 RAM 内容。
5. 构造最简单 load/store 程序进行验证。
6. 对 slave 地址高四位偏移进行修正。
7. load/store 访问非 bridge 对象时是否需要等待 ack。

这些问题推动了对 RIB 地址映射、bridge 访问、RAM 地址偏移和握手流程的排查。

### 7.8 bridge_master 状态修正

用户要求在 `bridge_master.v` 中：

1. `WE_RX_RESP` 之后多加一个 WAIT 状态。
2. `RD_RX_DATA3` 之后多加一个 WAIT 状态。
3. WAIT 之后无条件进入 IDLE。
4. 其他逻辑不改。

该问题与 bridge 通信节拍和写 ROM/读数据稳定性相关。

### 7.9 IFE、rT、PWM 测试

用户要求分别建立测试目录和 TB：

1. `IFE_test`：验证 IF/IFE 指令。
2. `temp_test`：验证 rT 温度读取。
3. `pwm_test`：验证 PWM 外设。

其中 rT 还涉及：

1. 查看 LM75 中文文档。
2. 检查 IIC slave 模型是否符合温度传感器时序。
3. 设置温度为 25 度。
4. 完成指令下载、执行、UART 输出检查。

PWM 相关问题包括：

1. 根据外设寄存器要求设计 PWM。
2. `PWM_o` 改为寄存器输出。
3. 使能关闭时不计数。
4. 使用 `<` 判断还是 `==` 判断面积更小。
5. 构造 `pwm_inst.data` 通过处理器实际写外设寄存器并验证输出。

### 7.10 FPGA 实测串口和温度问题

用户在板上测试时提出：

1. PowerShell 下载脚本是否能接收 UART 发送数据。
2. 串口上出现很多 `8A` 是否正常。
3. rT 复位后串口出现 `00` 的原因。
4. 复位时 UART 是否会发送 `00`。
5. 对比 FPGA 温度传感器例程和本设计 IIC 读过程、管脚约束。
6. 读到正确温度值前为什么会出现额外字节。
7. UART `tx_reg` 复位默认值是否会导致复位后发送 `00`。

这些问题主要围绕 FPGA 板级时序、UART 空闲电平、复位态输出、IIC 地址和约束展开。

### 7.11 时序报告和乘法器关键路径

用户提供 Vivado timing summary report 后，要求：

1. 教如何读懂时序报告。
2. 找关键路径。
3. 排查除乘法器之外的关键路径。
4. 讨论乘法器延迟如何解决。
5. 设计三周期乘法器。
6. 是否把 `mul_dk.v` 例化进 `ex.v`。
7. 后续又删除乘除法相关代码，需要重新验证。

这部分与资源删减和时序优化相关。

### 7.12 删除乘除法后基础指令和扩展外设回归

用户整理了验证范围：

1. `Baisc_Inst_Example` 中除乘除法外的基础指令。
2. sID 指令。
3. IFE 指令。
4. rT 温度指令。
5. PWM 外设。
6. 使用 `rtl_deleted` 或 `rtl_deleted copy` 等目录进行编译和仿真。

### 7.13 四人资源删减代码合并

用户最终提出：

1. 三个人的资源删减代码已放入 `rtl_tomerge/rtl/merge_version`。
2. 后来又加入 SY 第四份代码。
3. 要求根据图片要求合并。
4. 通过 `chip_sel` 选择四个 core。
5. 希望通过所有基础指令、扩展指令和外设测试。
6. 明确要求资源共享，包括 `regs`、`pwm`、`uart_debug`。

当前已经完成四路功能合并和统一回归，但资源共享尚未完成。

### 7.14 资源共享是否完成的追问

用户明确追问：

1. 是否实现了公用通用寄存器 `regs`。
2. 是否实现了公用 `pwm` 外设。
3. 是否实现了公用 `uart_debug` 模块。
4. 是否通过 `chip_sel[1:0]` 选择四个 core。

已经明确答复：没有实现严格意义上的资源共享。当前是四个独立 core 并列例化，通过顶层 mux 选择当前一路输出。

### 7.15 复位极性和复位门控关系

用户最后提出：

1. 四份原始代码复位是高有效还是低有效。
2. 如果全局 `rst` 为低时复位四个芯片，同时未被选中的 core 也保持复位，那么复位信号是否应为与门关系。

确认结论：

1. 四份原始代码均为低电平复位有效。
2. 对低有效复位，正确的 core 复位输入应为：

```verilog
.rst(rst & sel_core)
```

当前合并顶层中仍为：

```verilog
.rst(rst | ~sel_core)
```

因此这是必须修正的未完成事项。

## 8. 当前未完成事项和风险点

### 8.1 未真正实现 `regs` 资源共享

作业要求：

```text
公用通用寄存器 regs
```

当前状态：

```text
未完成
```

当前四个 core 内部仍然各自有自己的寄存器堆：

```text
lhr_regs
ldk_regs
wje_regs
sy_regs
```

合并顶层只是通过 `chip_sel` 选择哪一个 core 的输出，并没有把四个 core 的寄存器访问端口统一接到一个外部共享 `regs` 实例。

若要真正实现，需要深度重构：

1. 从每个 core 内部移除或旁路各自 `regs` 实例。
2. 将 ID/EX 等阶段对寄存器堆的读写端口上提到 core 顶层。
3. 在合并顶层或共享资源层例化唯一 `regs`。
4. 通过 `chip_sel` 选择当前 core 对共享 `regs` 的读写端口。
5. 确保未选中 core 不会写共享寄存器。
6. 重新验证流水线旁路、写回、x0 恒零等逻辑。

### 8.2 未真正实现 `pwm` 资源共享

作业要求：

```text
公用 pwm 外设
```

当前状态：

```text
未完成
```

当前每个 SoC 内部仍有自己的 PWM 实例。合并顶层只是选择当前 core 的 PWM 输出：

```verilog
assign pwm_o = sel_lhr ? lhr_pwm :
               sel_ldk ? ldk_pwm :
               sel_wje ? wje_pwm :
               sel_sy  ? sy_pwm  :
               4'b0000;
```

这属于输出 mux，不是资源共享。

若要真正实现，需要：

1. 从四个 SoC 内部移除 PWM 实例。
2. 将每个 core/RIB 对 PWM slave 的访问端口上提。
3. 在合并顶层例化唯一 PWM。
4. 用 `chip_sel` 选择当前 core 的 PWM RIB slave 请求、地址、写使能、写数据。
5. 将唯一 PWM 的读数据和 ack/hold 返回给当前 core。
6. 未选中 core 的 PWM 返回值需要给默认值，避免 hold 或 X。

### 8.3 未真正实现 `uart_debug` 资源共享

作业要求：

```text
公用 uart_debug 模块
```

当前状态：

```text
未完成
```

当前每份 SoC 中仍有各自的 `uart_debug` 或 FPGA 下载桥模块。合并顶层只做了：

```verilog
.uart_debug_pin(uart_debug_pin & sel_core)
```

这只是把 debug 使能送给当前选中 core，不是单一 `uart_debug` 实例。

若要真正实现，需要：

1. 从四个 SoC 内部移除各自的 `uart_debug`。
2. 将 debug master RIB 接口上提到各 SoC 顶层。
3. 在合并顶层例化唯一 `uart_debug`。
4. 根据 `chip_sel` 将唯一 `uart_debug` 的 master 请求连接到当前 core 的 RIB/debug master 入口。
5. 处理四份代码 bridge 协议差异，尤其 LHR、LDK、WJE、SY 下载 ROM 的路径和 bridge 结构并不完全相同。

### 8.4 `chip_sel` 位宽不符合图片要求

作业要求：

```text
chip_sel[1:0]
```

当前实现：

```verilog
input wire[2:0] chip_sel
```

当前状态：

```text
功能可用，但位宽不符合要求
```

应该改为：

```verilog
input wire[1:0] chip_sel
```

选择关系改为：

```verilog
2'd0: LHR
2'd1: LDK
2'd2: WJE
2'd3: SY
```

同时 wrapper 中的 `CHIP_SEL` 参数也应从 `[2:0]` 改为 `[1:0]`。

### 8.5 当前复位门控逻辑错误

作业和用户需求：

1. 全局 `rst` 为低时，四个 core 全部复位。
2. 当某个 core 未被 `chip_sel` 选中时，该 core 也保持复位。
3. 原始四份代码均为低有效复位。

当前合并顶层中写法类似：

```verilog
.rst(rst | ~sel_lhr)
.rst(rst | ~sel_ldk)
.rst(rst | ~sel_wje)
.rst(rst | ~sel_sy)
```

对低有效复位来说，这是错误的。未选中时 `sel_core=0`，`~sel_core=1`，导致 `rst | ~sel_core = 1`，反而释放复位。

正确写法应该是：

```verilog
.rst(rst & sel_lhr)
.rst(rst & sel_ldk)
.rst(rst & sel_wje)
.rst(rst & sel_sy)
```

真值表如下：

```text
rst sel_core rst & sel_core 结果
0   0        0              复位
0   1        0              复位
1   0        0              复位
1   1        1              运行
```

该问题尚未在代码中修正。

### 8.6 合并版本尚未从结构上减少资源

当前 `merge_version` 同时例化四份完整 core/SoC。虽然未选中 core 理论上会复位，但综合工具仍会综合出四份 core 及其内部资源，除非后续通过参数、generate、层次裁剪或更深层共享结构实现真正资源复用。

因此当前合并版本更准确地说是：

```text
四路功能合并 + 顶层选择 + 统一验证
```

而不是：

```text
四路 core 公用 regs/pwm/uart_debug 的资源共享实现
```

### 8.7 WJE 原始目录仍含完整 Vivado 导入工程和未删减文件

`wje` 目录中存在：

```text
wje/tinyriscv_master.srcs
```

其中包含完整导入源码、约束、JTAG、GPIO、SPI、Timer 等文件。合并版主要使用 `wje/rtl` 路径下的源码，但目录中仍有完整工程导入文件。后续如果交付目录需要精简，需要明确哪些文件参与最终综合，哪些只是备份或原始工程遗留。

### 8.8 合并版本仿真通过不等于 FPGA 综合通过

目前使用 `iverilog + vvp` 完成行为仿真回归。该回归证明：

1. 四个 core 在当前 TB 下可独立执行测试程序。
2. UART/PWM/IIC/扩展指令在仿真模型下通过。
3. 当前 filelist 可以被 `iverilog` 编译。

但它不能完全证明：

1. Vivado 综合无报错。
2. Vivado 实现后时序满足。
3. FPGA 板级管脚约束正确。
4. 真实 UART 下载流程和真实 IIC 传感器访问在板上稳定。
5. 资源共享要求已经满足。

后续若要面向最终提交，需要继续跑 Vivado synthesis/implementation。

## 9. 建议的后续工作顺序

建议按以下顺序继续推进。

### 9.1 先修正低有效复位门控

优先级：最高。

需要将：

```verilog
.rst(rst | ~sel_core)
```

改为：

```verilog
.rst(rst & sel_core)
```

同时把 `chip_sel` 位宽从 `[2:0]` 改为 `[1:0]`。

改完后必须重新运行：

```powershell
powershell -ExecutionPolicy Bypass -File rtl_tomerge\rtl\merge_version\run_merge_regression.ps1
```

### 9.2 明确资源共享的实现深度

需要和老师或组内明确：

1. 是否必须综合后只有一份 `regs`。
2. 是否必须综合后只有一份 `pwm`。
3. 是否必须综合后只有一份 `uart_debug`。
4. 还是只要求顶层接口公用、通过 `chip_sel` 选择当前 core。

如果严格按图片文字理解，应按真正资源共享实现。

### 9.3 先做 PWM 共享

PWM 是三项资源共享中最容易先做的，因为它是外设，不在 CPU 核心流水线内部。

建议步骤：

1. 修改四个 SoC，移除内部 PWM 实例。
2. 暴露 PWM slave 访问端口。
3. 合并顶层例化唯一 PWM。
4. 通过 `chip_sel` mux 当前 core 的 PWM 访问。
5. 回归 PWM 测试。

### 9.4 再做 uart_debug 共享

`uart_debug` 涉及 ROM 下载和 bridge 访问，不同人的 bridge 结构不同，复杂度高于 PWM。

建议先统一 debug master 接口，再共享 `uart_debug`。

### 9.5 最后考虑 regs 共享

`regs` 是 CPU 核心流水线内部资源，牵涉 ID 读寄存器、EX/WB 写寄存器、旁路和 x0 特殊处理。改动风险最大，建议最后做。

如果时间有限，需要和老师确认是否允许“每个 core 保留自己的 regs，只做顶层选择”。

## 10. 当前关键文件索引

### 10.1 合并顶层

```text
rtl_tomerge/rtl/merge_version/tinyriscv_merge_top.v
```

### 10.2 合并 filelist

```text
rtl_tomerge/rtl/merge_version/merge_filelist.f
```

### 10.3 统一回归脚本

```text
rtl_tomerge/rtl/merge_version/run_merge_regression.ps1
```

### 10.4 统一验证 TB

```text
rtl_tomerge/rtl/merge_version/tb/tinyriscv_merge_validation_tb.v
```

### 10.5 回归结果

```text
rtl_tomerge/rtl/merge_version/verification/merge_regression_summary.txt
```

### 10.6 简要合并说明

```text
rtl_tomerge/rtl/merge_version/MERGE_SUMMARY.md
```

### 10.7 本文档

```text
rtl_tomerge/rtl/RTL_TOMERGE_PROJECT_REPORT.md
```

## 11. 当前结论

目前工程已经完成：

1. 四份资源删减后 RTL 的功能级合并。
2. 四份源码的模块名前缀隔离。
3. 合并顶层 `tinyriscv_merge_top.v`。
4. 统一 `iverilog` filelist。
5. 统一验证 TB。
6. 统一 PowerShell 回归脚本。
7. 四个 `chip_sel` 下 96 项仿真测试全部通过。

但工程还没有完成：

1. 真正公用 `regs`。
2. 真正公用 `pwm`。
3. 真正公用 `uart_debug`。
4. `chip_sel[1:0]` 位宽要求。
5. 低有效复位下的正确复位门控。
6. Vivado 综合、实现、时序和板级验证。

因此当前版本可作为“功能合并和统一验证基线”，但还不能作为“严格满足资源共享要求的最终版本”。
