# 全指令单镜像离线测试

## 1. 测试范围

all_isa_selfcheck.data 是四核共用的单一 ROM 镜像，位于
rtl/lhr/tests/programs/all_isa_selfcheck.data。它覆盖项目当前保留的全部指令：

- RV32I 算术/逻辑：ADD、SUB、SLL、SLT、SLTU、XOR、SRL、SRA、OR、AND；
- RV32I 立即数：ADDI、SLTI、SLTIU、XORI、ORI、ANDI、SLLI、SRLI、SRAI；
- 访存：LB、LBU、LH、LHU、LW、SB、SH、SW；
- 分支：BEQ、BNE、BLT、BGE、BLTU、BGEU，每条均检查 taken 和 not-taken；
- 跳转/高位/顺序：JAL、JALR、LUI、AUIPC、FENCE 和 NOP 伪指令；
- 课程扩展：sID、rT、if。

不属于当前项目 ISA 的 M/A/C/F/D 扩展、CSR、ECALL/EBREAK、中断返回和 FENCE.I 不编码进
镜像。

镜像不使用栈，只使用共享 RAM 的 word 0 和 word 1。当前可执行代码占 251/256 word
（1004/1024 byte），文件末尾用 5 个 NOP 补齐物理 ROM 深度。

## 2. 判定方式

程序首先自检 RV32I 和数据相关，再执行 sID、LM75 rT、if 不触发路径和 if UART 触发路径，
最后用字对齐目标检查 JALR 跳转和 PC+4 链接值。

- 通过：x26=1、x27=1、x25=0，四盏状态 LED 全亮；UART 为本核 10 字节 sID，随后一个 A5。
- 失败：x26=1、x27=0，x25 保存失败码；若 IF/UART 可用，UART 还会输出一个失败码字节。
- 失败码到检查项的完整映射位于
  verification/all_isa_selfcheck_manifest.json。

成功 UART 字节为：

| 核 | 期望十六进制 |
|---|---|
| LHR | 32 30 32 33 33 31 30 39 33 36 A5 |
| LDK | 32 30 32 35 32 31 30 39 30 35 A5 |
| SY | 32 30 32 35 32 31 30 38 37 30 A5 |
| WJE | 32 30 32 35 33 31 36 31 39 31 A5 |

rT 的返回值不能由固件假定为某个固定温度；Icarus 用总线级 LM75 模型检查 START、ACK、
数据、末字节 NACK、STOP，并以 16'h1900 验证 x14=0x32。板上则以真实 LM75 应答和程序
继续完成作为判据，合法的 0°C 不视为错误。

## 3. 一键离线 Icarus

先 Set-Location 到冻结包根目录 `clone\rtl\merged_freeze`，或显式设置 REPO_ROOT，再运行
公开 runner。下面的命令不写入
个人绝对路径，也不会把尖括号作为 shell 重定向：

~~~powershell
# 当前 shell 已先 Set-Location 到 clone\rtl\merged_freeze；否则显式设置：
# $env:REPO_ROOT = 'C:\path\to\clone\rtl\merged_freeze'
$env:REPO_ROOT = (Get-Location).Path
Set-Location (Join-Path $env:REPO_ROOT 'rtl\merged')
$env:PYTHON_BIN = 'python'
$env:IVERILOG_BIN = 'iverilog'
$env:VVP_BIN = 'vvp'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $env:REPO_ROOT 'rtl\merged\scripts\run_all_isa_selfcheck.ps1') -PythonExe $env:PYTHON_BIN -IverilogExe $env:IVERILOG_BIN -VvpExe $env:VVP_BIN -SkipGenerate
~~~

SkipGenerate 使用清单中的既有镜像和覆盖 manifest；若需要重新生成镜像，去掉
SkipGenerate 并在修改后的候选上重新计算门禁。runner 会：

1. 确认 staging=0；
2. 编译 filelist_fpga.f、merged_extensions_tb.v 和 merged_all_isa_selfcheck_tb.v；
3. 用 CORE=0..3 运行四个核并写入本地 evidence 目录；
4. 输出四核结果 CSV，再次确认 staging=0；
5. 不调用 211 项回归，不构建 VIO，不执行任何 Git 写入。

当前保存的公开结果为四核 4/4 PASS；结果表见
verification/all_isa_selfcheck_20260804_170840/results.csv，覆盖和失败码见
verification/all_isa_selfcheck_manifest.json。

## 4. 板上离线执行

在课程范围 Icarus 四核全通过后再执行本节。保持 uart_debug_pin 为高，用实际串口号
下载一次：

~~~powershell
# 先 Set-Location 到 clone\rtl\merged_freeze，或把 REPO_ROOT 显式设置为该冻结包根目录
$env:REPO_ROOT = (Get-Location).Path
$env:PYTHON_BIN = 'python'
$env:IMAGE = Join-Path $env:REPO_ROOT 'rtl\lhr\tests\programs\all_isa_selfcheck.data'
& $env:PYTHON_BIN (Join-Path $env:REPO_ROOT 'rtl\lhr\tools\tinyriscv_fw_downloader.py') $env:IMAGE --port COMx
~~~

下载完成后把 uart_debug_pin 拉低。依次选择 LHR、LDK、SY、WJE；每次切换后按既有
keys-only 按键流程复位并运行，记录 LED 和 UART。ROM 是共享的，因此四核期间不需要
重复下载；每个核都必须得到四灯全亮及对应的 11 字节 UART 序列。切核会取消旧事务、清空
共享 RAM，并在 guard 完成后再释放当前核。

## 5. 课程范围与已知边界

本镜像的目标是验证现有课程程序实际使用的 RV32I 指令和 sID、rT、if 扩展。JALR 使用
现有软件采用的字对齐目标，并检查：

- JALR 指令确实执行并到达期望目标；
- 目标地址与课程程序的字对齐用法一致；
- 目的寄存器得到 JALR 指令地址加 4 的链接值。

RV32I 规范另外要求 JALR 目标为 (rs1 + imm) & ~1。已知上游 TinyRISC-V 的 LDK、SY、
WJE 路径没有显式清 bit 0；共享 ROM 又用地址 [9:2] 取指，因此现有字对齐课程程序不会
观察到该差异。严格奇地址 bit-0 证据仅作为历史审计，不属于本课程范围镜像的 PASS 门禁，
也没有因此修改生产 RTL。

因此，本测试通过只表示“项目当前课程指令范围 + 字对齐 JALR 用法 + 三条课程扩展”通过，
不表示已完成奇地址 JALR bit-0 的严格 RV32I 一致性认证。实体 I2C 波形同样仍为
PENDING_WAVEFORM；本镜像和仿真模型不能代替真实逻辑分析仪捕获。
