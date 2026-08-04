# Four-core TinyRISC-V merged freeze snapshot

本目录是四核合并候选的公开 RTL 快照。当前公开身份以 Vivado 83 项 relative source
manifest 为准；根目录的 [README.md](../../README.md) 负责 clone、VCS/Verdi、Vivado 和
GitHub 发布步骤，本页补充架构、目录和 filelist 细节。

## 当前身份与核选择

- 83 项 source manifest aggregate：
  86C8634566E391F8EC9BD7226131453539E3779F9139C228E880B96D4CFE769A
- keys-only bitstream SHA-256：
  B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF
- 当前 FPGA 交付顶层：tinyriscv_merged_fpga_key_top
- 当前候选没有 VIO 门禁；VIO 源码和历史产物不属于公开交付。

| chip_sel | 核 |
|---:|---|
| 2'b00 | LHR |
| 2'b01 | LDK |
| 2'b10 | SY |
| 2'b11 | WJE |

正常运行时 chip_sel 应保持稳定。切换时 bridge bank 取消旧协议事务，四个核和共享资源
停止；未选核保持复位。共享 RAM 逐 word 清零，memory_ready 重新有效后再保持至少三个
完整时钟周期的 guard。AX7035 上电默认选择 LHR；RESET 只重启当前核并保留选择。

## 顶层与共享结构

- ASIC/芯片顶层：tinyriscv_merged_chip_top
- FPGA 共享 wrapper：tinyriscv_merged_fpga_top
- AX7035 按键版顶层：tinyriscv_merged_fpga_key_top
- ASIC filelist：filelist_chip.f
- FPGA filelist：filelist_fpga.f
- VCS/Verdi filelist：filelist_vcs.f 与 filelist_vcs_rtl.f

芯片顶层保持原生 8-bit bridge_data_o/bridge_data_i。FPGA wrapper 内部例化 LHR、LDK、SY、
WJE 四种协议 adapter；adapter 只负责协议转换，板级端口统一为时钟、复位、核选择、UART、
I2C、PWM 和 succ。

共享资源只有一份：

- shared_regs：四核共享寄存器读写和 succ；
- shared_pwm：四路 PWM；
- shared_uart_debug：UART downloader；
- shared_fpga_memory：仅 FPGA 侧的一套 256 x 32 ROM 与一套 16 x 32 RAM。

ROM 使用地址位 [9:2]，RAM 使用 [5:2] 低位镜像；旧栈地址 0x10003ffc 映射到 RAM word 15。
共享存储只存在 FPGA wrapper，不进入 ASIC/后端 filelist_chip.f。

## 目录

~~~text
rtl/cores/       四套带 lhr_/ldk_/sy_/wje_ 前缀的生成快照
rtl/common/      shared_regs、shared_pwm、shared_uart_debug
rtl/soc/         四个 core tile 与 tinyriscv_merged_chip_top
rtl/fpga/        四协议 adapter、bridge bank、共享存储、FPGA top
fpga/            keys-only Vivado build/program TCL 与 AX7035 keys XDC
tb/              VCS/Verdi 公开 testbench 与 FSDB dump wrapper
scripts/         all-ISA 生成/运行和 Linux EDA VCS runner
verification/    非敏感身份摘要；原始日志/波形不属于公开清单
~~~

rtl/cores 是由本地个人 source-of-truth 生成的带前缀快照。公开冻结直接发布这些生成
文件并验证其 83 项 manifest，不依赖 clone 后重新执行个人源生成器；若未来修改上游源，
必须生成新的快照并重新跑全部门禁。

## Filelist 使用

filelist.f 只转发到 filelist_chip.f。filelist_chip.f 用于 ASIC/芯片 RTL；filelist_fpga.f
在其上增加 LDK FPGA bridge slave、四个 adapter、bridge bank、共享 FPGA memory 和
keys-capable top。filelist_vcs.f 额外加入公开 testbench，filelist_vcs_rtl.f 是严格
VCS 兼容的生产 RTL 子集：只排除四个未例化的旧 SY/WJE full-handshake utility，未替换
任何生产模块。

VCS runner 使用的 testbench 是：

- merged_core_smoke_tb.v
- merged_rv32i_directed_tb.v
- merged_extensions_tb.v
- merged_pwm_tb.v
- merged_uart_tb.v
- merged_bridge_protocol_tb.v
- shared_uart_debug_tb.v
- merged_switch_clear_tb.v
- merged_all_isa_selfcheck_tb.v
- merged_ldk_rt_repeat_tb.v
- vcs_fsdb_dump.vh

Linux EDA 服务器的安全复现命令、工具环境变量和预期 142/142、10/10、5/5、5/5 结果见
[根 README 的 VCS/Verdi 小节](../../README.md#linux-eda-服务器上的-vcs--verdi-复现)。本目录的
remote runner 不读取个人连接配置；原始服务器 evidence、FSDB 和日志保持在 clone 外。

## AX7035 keys-only 流程

Vivado 2019.1、器件 xc7a35tfgg484-2。先进入冻结包根目录
`clone/rtl/merged_freeze`；构建入口是
fpga/build_ax7035_merged.tcl，约束为 fpga/constrs/ax7035_keys.xdc。构建前设置
TINYRISCV_MERGED_USE_VIO=0，并把 TINYRISCV_MERGED_PROJ_DIR 指向 clone 外临时目录；
不要把 Vivado project、build、.Xil、JOU/LOG 放入源码清单。

~~~powershell
$env:REPO_ROOT = (Resolve-Path '.').Path
$env:BUILD_DIR = Join-Path ([IO.Path]::GetTempPath()) 'tinyriscv-merged-vivado'
$env:VIVADO_BIN = 'C:\path\to\vivado.bat'
$env:TINYRISCV_MERGED_USE_VIO = '0'
$env:TINYRISCV_MERGED_PROJ_DIR = Join-Path $env:BUILD_DIR 'project'
& $env:VIVADO_BIN -mode batch -source (Join-Path $env:REPO_ROOT 'rtl\merged\fpga\build_ax7035_merged.tcl')
~~~

keys-only 门禁应为 synthesis、implementation、write_bitstream 全部完成；四 tile 存在；
routing error=0；唯一共享 256 x 32 ROM 和 16 x 32 RAM；当前候选 WNS/TNS=1.189447/0 ns、
WHS/THS=0.057836/0 ns、DRC=0 Error / 1 Warning。逐文件哈希和 aggregate 应核对
[source_manifest.sha256](verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256)
及
[source_manifest_aggregate.txt](verification/vivado_keys_nackfix_20260804_140502/source_manifest_aggregate.txt)。

烧写使用 Release bitstream 附件和 fpga/program_ax7035_merged.tcl；必须先按根 README 的命令
强比较 B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF bitstream SHA-256，
再启动本机 hw_server 并等待 localhost:3121 ready，设置
TINYRISCV_MERGED_BIT_FILE 后才由本机 hw_server 编程。完整的共享 ROM 下载、KEY1/KEY2/KEY3/
KEY4 和四核板测步骤见根 README。物理 I2C 波形仍为 PENDING_WAVEFORM，不能用 UART 或
温度值替代。

## 全指令镜像与固件

[ALL_ISA_SELFTEST.md](ALL_ISA_SELFTEST.md) 说明课程范围的 RV32I、sID、rT、if、四核 UART
判定和 JALR waiver。镜像位于 rtl/lhr/tests/programs/all_isa_selfcheck.data；runner 可
在已有快照上使用 -SkipGenerate，编译 filelist_fpga.f 加 all-ISA testbench，结果摘要为
四核 4/4 PASS。失败码映射见
[all_isa_selfcheck_manifest.json](verification/all_isa_selfcheck_manifest.json)，结果见
[results.csv](verification/all_isa_selfcheck_20260804_170840/results.csv)。

LDK 首次地址 NACK 的 clean、单次重试和三次耗尽摘要见
[diagnostics/ldk_rt_nack_20260804/summary.md](verification/diagnostics/ldk_rt_nack_20260804/summary.md)。
本目录不发布该诊断中的 VCD/VVP 二进制。

## 验证摘要

- 本地 Icarus：211 PASS / 0 FAIL；[summary](verification/icarus/summary.md) 只作为摘要，
  不把 211 当成 VCS 结果。
- 正式 VCS functional：142/142 PASS。
- VCS compile、FSDB、Verdi batch：10/10、5/5、5/5。
- keys-only Vivado：综合、实现、bitstream 全部完成；四核层级与共享存储摘要分别见
  [four_core_hierarchy_check.txt](verification/vivado_keys_nackfix_20260804_140502/four_core_hierarchy_check.txt)
  和 [shared_memory_inference.txt](verification/vivado_keys_nackfix_20260804_140502/shared_memory_inference.txt)。
- 板级有效 BasicTest：80/80；实际实体 I2C 逻辑分析仪捕获仍是 PENDING_WAVEFORM。
- odd-address JALR bit-0 继续作为课程范围外 waiver，不是当前生产 RTL 门禁。

本 README 不再引用修复前的 manifest/bitstream，也不声称 VCS 尚未执行。发布选择和排除项
以根目录 GITHUB_UPLOAD_MANIFEST.md 为准。
