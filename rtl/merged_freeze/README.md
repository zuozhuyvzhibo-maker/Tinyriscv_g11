# Tinyriscv_g11：四核 TinyRISC-V 冻结候选

本仓库保留课程早期 LHR、LDK、SY、WJE 四个单核版本的历史背景；当前公开交付目标是
四核 TinyRISC-V 合并候选。冻结候选的逐文件上传选择见
[GITHUB_UPLOAD_MANIFEST.md](GITHUB_UPLOAD_MANIFEST.md)，机器可读文件清单见
[github_freeze_files.txt](github_freeze_files.txt)。

在上游 `Tinyriscv_g11` 仓库中，本冻结包发布于 `rtl/merged_freeze/`。下文的
`REPO_ROOT` 均指这个冻结包根目录，而不是外层 Git clone 根目录。

## 当前冻结身份

- pre-release base：e45a48e30867848cd5948b9568f1ea171ee222c9；这不是最终 freeze commit。
  freeze commit/tag 尚待发布时确定，并且必须映射到本页的 aggregate 与 bitstream SHA-256。
- Vivado 冻结源码：83 项 relative manifest，aggregate 为
  86C8634566E391F8EC9BD7226131453539E3779F9139C228E880B96D4CFE769A。
- 唯一当前 FPGA 候选：keys-only 顶层 tinyriscv_merged_fpga_key_top。
- 当前 bitstream SHA-256：
  B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF。
83 项 source manifest 的逐文件哈希位于
[rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256](rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256)，
aggregate 位于
[rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest_aggregate.txt](rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest_aggregate.txt)。
这两个文件与 keys-only 构建输入共同定义当前候选身份。

## 从四个单核版本到四核合并

早期任务先分别修改 LHR、LDK、SY、WJE 单核 RTL，再进行接口和共享资源合并。当前候选的
主要结构性改动是：

- 私有模块名和宏名分别加入 lhr、ldk、sy、wje 前缀，避免四套同名 RTL 冲突；
- 统一四核 SoC 顶层和 2-bit chip_sel：00=LHR、01=LDK、10=SY、11=WJE；
- 共享一套 regs、PWM、UART downloader 和 succ 输出；
- FPGA 侧只保留唯一共享 ROM（256 x 32）与唯一共享 RAM（16 x 32）；
- 为四套原生 Bridge 协议各提供一个 bridge adapter；
- 切核时取消旧事务、停止未选核、清零共享 RAM，并在 memory_ready 后加入三周期 guard；
- 统一 CPU、UART、I2C 开漏和 FPGA 外设接口；
- 修复指令、外设和下载握手的一致性边界；
- LDK I2C 首次地址 NACK 在采到真实 NACK 后 STOP、等待总线空闲并重试，最多三次；
- 增加课程全指令单镜像、四核 testbench、VCS/Verdi 输入和可审计验证资产。

这些改动不等于完成所有物理或严格 ISA 认证：实体 I2C START/ACK/NACK/STOP 逻辑分析仪
波形仍是 PENDING_WAVEFORM；奇地址 JALR bit-0 是课程范围外的已知上游 waiver，本候选
按课程程序使用的字对齐目标验证，未因此修改生产 RTL。

## 顶层与 filelist

| 用途 | 顶层 | filelist / 约束 |
|---|---|---|
| ASIC/芯片 RTL | tinyriscv_merged_chip_top | rtl/merged/filelist_chip.f |
| FPGA 共享 wrapper | tinyriscv_merged_fpga_top | rtl/merged/filelist_fpga.f |
| AX7035 当前板级交付 | tinyriscv_merged_fpga_key_top | rtl/merged/fpga/constrs/ax7035_keys.xdc |
| VCS/Verdi RTL 前仿真 | 各公开 testbench | rtl/merged/filelist_vcs.f、filelist_vcs_rtl.f |

rtl/merged/filelist.f 仅转发到 chip filelist。keys-only Vivado 构建入口是
rtl/merged/fpga/build_ax7035_merged.tcl；VIO 顶层、VIO XDC、VIO filelist、.ltx 和
历史 VIO 产物不属于当前交付。

更详细的目录、共享存储和切核时序说明见
[rtl/merged/README.md](rtl/merged/README.md)。全指令镜像的覆盖、判定和 JALR 边界见
[rtl/merged/ALL_ISA_SELFTEST.md](rtl/merged/ALL_ISA_SELFTEST.md)。

## 已有验证结果

| 门禁 | 当前结果 | 解释 |
|---|---:|---|
| 本地 Icarus 完整回归 | 211 PASS / 0 FAIL | 独立于 VCS 计数；summary 见 [verification/icarus/summary.md](rtl/merged/verification/icarus/summary.md) |
| 正式服务器 VCS functional | 142 PASS / 0 FAIL | 20 BasicTest 镜像四核展开，加 directed、扩展、外设、Bridge、downloader、切核、all-ISA、LDK NACK |
| VCS compile | 10/10 PASS | 十个 VCS 顶层 |
| FSDB | 5/5 PASS | 非空并有 SHA-256 清单；原始 FSDB 不公开 |
| Verdi-Ultra batch | 5/5 PASS | 原始服务器日志不公开 |
| 课程全指令单镜像 | Icarus 四核 4/4 PASS | 251/256 words 可执行、每核 11 字节；[结果 CSV](rtl/merged/verification/all_isa_selfcheck_20260804_170840/results.csv) |
| AX7035 keys-only Vivado | synthesis、implementation、write_bitstream 完成 | 四 tile 保留，唯一共享 ROM/RAM，routing error=0，DRC 0 Error / 1 Warning |
| 有效板级 BasicTest | 20 镜像 x 四核 = 80/80 PASS | 原始 append-only 记录的早期 FAIL/SKIP 不被改写 |
| LDK NACK 定向门禁 | clean、单次重试、三次耗尽均 PASS | 摘要见 [diagnostic summary](rtl/merged/verification/diagnostics/ldk_rt_nack_20260804/summary.md) |

keys-only Vivado 当前报告的时序摘要为 WNS/TNS=1.189447/0 ns、WHS/THS=0.057836/0 ns；
15257/15257 routable nets fully routed。单一共享存储的层级摘要见
[shared_memory_inference.txt](rtl/merged/verification/vivado_keys_nackfix_20260804_140502/shared_memory_inference.txt)，
四核层级见
[four_core_hierarchy_check.txt](rtl/merged/verification/vivado_keys_nackfix_20260804_140502/four_core_hierarchy_check.txt)。

## Linux EDA 服务器上的 VCS + Verdi 复现

公开安全路径是在具备许可证的 Linux EDA 服务器上 clone 后，直接运行仓库内的
rtl/merged/scripts/run_vcs_pre_sim_remote.sh。它不读取个人凭据配置；工具路径、许可证和
服务器账号由使用者自己的 EDA 环境提供。把 build 与 evidence 放到 clone 外的
EDA_WORK_DIR，避免把 simv、csrc、FSDB、命令回放或原始日志带进仓库。

~~~bash
export REPO_ROOT="/path/to/clone/rtl/merged_freeze"
export EDA_WORK_DIR="/tmp/tinyriscv-vcs"
export TINYRISCV_VCS_BIN="/eda/path/to/vcs"
export TINYRISCV_VERDI_BIN="/eda/path/to/Verdi-Ultra"
export TINYRISCV_VERDI_ROOT="/eda/path/to/verdiSX"
mkdir -p "$EDA_WORK_DIR"
bash "$REPO_ROOT/rtl/merged/scripts/run_vcs_pre_sim_remote.sh" --out "$EDA_WORK_DIR/evidence" --build "$EDA_WORK_DIR/build" --remote-root "$EDA_WORK_DIR/run" --program-root "$REPO_ROOT/rtl/lhr/tests/programs"
~~~

VCS 版本基线为 R-2020.12-SP1，Verdi-Ultra 为 P-2019.06-SP2-12。脚本使用
IVERILOG_FAST_SIM 与 VCS_FSDB 编译定义；VCS 专用 filelist 排除四个未例化、仅因严格
语法风格而不兼容的旧 utility，不引入替代生产 RTL。预期独立结果为 142/142、10/10、
5/5、5/5；Icarus 的 211 不等于 VCS 的 142。

已知非阻断警告包括 FSDB dumper/VCS 版本兼容性横幅、旧 PWM $dumpvars 参数警告和可选
Verdi 配置查找警告。正式判定仍以退出码、TEST_PASS/TEST_FAIL、timeout、FSDB 非空和
Verdi -batch 返回值为准。项目级未关闭事项仍是实体 I2C 波形 PENDING_WAVEFORM 与
odd-address JALR bit-0 waiver。

在 Linux 上可从冻结包根目录核对 83 项冻结输入：

~~~bash
export REPO_ROOT="/path/to/clone/rtl/merged_freeze"
(cd "$REPO_ROOT/rtl/merged" && sha256sum --check verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256)
~~~

## Vivado 2019.1 keys-only 复现

目标器件为 AX7035 的 xc7a35tfgg484-2，Vivado 为 2019.1。先设置仓库根、临时工程目录
和 Vivado 可执行文件；尖括号只在 prose 中表示占位符，PowerShell 命令使用环境变量。

~~~powershell
$env:REPO_ROOT = 'C:\path\to\clone\rtl\merged_freeze'
Set-Location $env:REPO_ROOT
$env:BUILD_DIR = Join-Path ([IO.Path]::GetTempPath()) 'tinyriscv-merged-vivado'
$env:VIVADO_BIN = 'C:\path\to\vivado.bat'
$env:TINYRISCV_MERGED_USE_VIO = '0'
$env:TINYRISCV_MERGED_PROJ_DIR = Join-Path $env:BUILD_DIR 'project'
New-Item -ItemType Directory -Force -Path $env:BUILD_DIR | Out-Null
& $env:VIVADO_BIN -mode batch -source (Join-Path $env:REPO_ROOT 'rtl\merged\fpga\build_ax7035_merged.tcl')
~~~

构建门禁必须同时确认 synthesis、implementation 和 write_bitstream 完成、四个 tile 未被
优化掉、唯一 256 x 32 ROM 与唯一 16 x 32 RAM 被推断、routing error=0、无 Vivado Error
或 Critical Warning。构建输出的 83 项哈希必须和
rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256 逐项
核对，aggregate 必须保持本页的冻结值。工程目录由 TINYRISCV_MERGED_PROJ_DIR 指定到
clone 外，生成的 report/build/log 不应加入源码提交。

当前 bitstream 建议作为 GitHub Release 附件，而不是 Git 源码文件。附件名建议为
tinyriscv_merged_fpga_key_top.bit，SHA-256 必须为
B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF。若使用附件烧写，
将附件放在本地任意临时位置并设置环境变量，再用 repo-relative program TCL：

~~~powershell
$env:BIT_FILE = 'C:\path\to\tinyriscv_merged_fpga_key_top.bit'
$expectedBitHash = 'B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF'
$actualBitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $env:BIT_FILE).Hash.ToUpperInvariant()
if ($actualBitHash -ne $expectedBitHash) { throw "bitstream SHA-256 mismatch: $actualBitHash" }
$env:TINYRISCV_MERGED_BIT_FILE = $env:BIT_FILE
$env:HW_SERVER_BIN = 'C:\path\to\hw_server.bat'
$hwServer = Start-Process -FilePath $env:HW_SERVER_BIN -ArgumentList '-s tcp::3121' -PassThru -WindowStyle Hidden
$hwServerReady = $false
for ($i = 0; $i -lt 60; $i++) {
    if (Test-NetConnection -ComputerName 'localhost' -Port 3121 -InformationLevel Quiet) {
        $hwServerReady = $true
        break
    }
    Start-Sleep -Seconds 1
}
if (-not $hwServerReady) { throw 'localhost:3121 hw_server did not become ready' }
& $env:VIVADO_BIN -mode batch -source (Join-Path $env:REPO_ROOT 'rtl\merged\fpga\program_ax7035_merged.tcl')
~~~

烧写前必须先通过上述 SHA-256 比较，再启动本机 hw_server 并等待 localhost:3121 ready；只有
确认连接就绪后才调用 program TCL，不能烧写后才检查哈希。

烧写和四核板测流程：

1. 通过当前 keys-only bitstream 编程；确认板卡为 AX7035/xc7a35tfgg484-2、JTAG 正常。
2. KEY1 保持 downloader/运行模式；用公开工具下载一次
   rtl/lhr/tests/programs/all_isa_selfcheck.data，串口参数使用本机的 COMx。
3. 上电默认选择 LHR；KEY2 选择下一个核，KEY3 选择上一个核，按既有板级流程复位并
   等待切核取消、共享 RAM 清零和三周期 guard 完成。
4. 依次验证 LHR、LDK、SY、WJE 的 LED、succ 和 11 字节 UART。共享 ROM 不需重复下载；
   切核后 RAM 内容不保留。
5. 需要下载其他公开镜像时，替换 image 变量，仍使用 repo-relative 路径：

~~~powershell
$env:IMAGE = Join-Path $env:REPO_ROOT 'rtl\lhr\tests\programs\all_isa_selfcheck.data'
$env:PYTHON_BIN = 'python'
& $env:PYTHON_BIN (Join-Path $env:REPO_ROOT 'rtl\lhr\tools\tinyriscv_fw_downloader.py') $env:IMAGE --port COMx
~~~

实体串行/UART 结果不能替代 I2C 物理波形。当前有效板级矩阵为 80/80 BasicTest、四核
rT/Bridge RAM/shared RAM/sID/IF/PWM 与按键矩阵通过；START、地址 ACK/NACK、数据、末字节
NACK、STOP 波形仍明确标为 PENDING_WAVEFORM。

## GitHub 发布建议

- 先逐项审查 [github_freeze_files.txt](github_freeze_files.txt)，再选择性暂存；不按整个
  工作树展开路径。默认发布为清单中的 143 项公开快照及复现资产。根 `.gitattributes`
  禁止 Git 改写 83 项冻结输入的既有混合换行，并把 checksum manifest 与公开仿真资产固定
  为 LF，保证 Windows/Linux clone 的冻结字节身份一致。
- 11 个旧 WJE 路径只在 [GITHUB_UPLOAD_MANIFEST.md](GITHUB_UPLOAD_MANIFEST.md) 的“个人源树待审删除”
  表中记录，不属于默认发布，也不应只凭这张表提交删除。
- Git 仓库发布 83 项 RTL、VCS/Verdi 输入、必要固件和公开文档；keys-only bitstream
  作为 Release 附件并附 SHA-256。
- 不公开原始服务器日志、FSDB/VCD 波形、simv/csrc、Vivado 工程、JOU/LOG、旧 VIO 产物、
  历史失败证据、个人绝对路径、认证材料或私钥。
- 冻结 commit/tag、远端和分支策略由用户确认后决定；发布时必须把最终 commit/tag 映射到同一个
  freeze identity，不把旧 bitstream 与新 RTL 混用。

历史任务说明仍保留在版本记录中；本 README 只把当前四核冻结候选作为默认入口。
