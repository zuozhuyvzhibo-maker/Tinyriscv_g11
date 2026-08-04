# 四核 TinyRISC-V 冻结候选公开上传清单

状态日期：2026-08-04。本文档与同目录的 github_freeze_files.txt 是选择性上传计划，
不是暂存、提交或远端上传操作。机器可读清单当前共有 **143 个实际存在的文件**；其中
Vivado 冻结源码基线为 **83 项**，其余 **60 项**是 VCS/Verdi 复现输入、必要固件、公开
文档和非敏感身份摘要。

本包在上游 `Tinyriscv_g11` 中的发布目录为 `rtl/merged_freeze/`；本文的 `REPO_ROOT`
均指该冻结包根目录，而不是外层 Git clone 根目录。

## 冻结身份与边界

- pre-release base：e45a48e30867848cd5948b9568f1ea171ee222c9；这不是最终 freeze commit。
  freeze commit/tag 尚待发布时确定，且必须映射到当前 aggregate 与 bitstream SHA-256。
- 当前候选的 83 项 relative source manifest aggregate：
  86C8634566E391F8EC9BD7226131453539E3779F9139C228E880B96D4CFE769A。
- keys-only FPGA 候选 bitstream SHA-256：
  B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF。
- 83 项的逐文件哈希和 aggregate 保存在
  [source_manifest.sha256](rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256)
  和 [source_manifest_aggregate.txt](rtl/merged/verification/vivado_keys_nackfix_20260804_140502/source_manifest_aggregate.txt)。
- 这 83 项覆盖 filelist_chip.f、filelist_fpga.f、keys-only Vivado TCL/XDC、共享资源、
  四个带前缀核、四种 bridge adapter、四个 tile、ASIC 顶层和 keys-only FPGA 顶层。
  它们是公开快照的 RTL 基线；不得用其他目录的同名文件替换。

## 必须提交的源码与文件

github_freeze_files.txt 是唯一逐文件上传清单：每行一个 nested-repository-relative
文件，已排序、无目录、无通配符、无重复。清单分为以下几类：

1. **83 项 Vivado 源码基线。** 这是集成 RTL、ASIC/FPGA filelist 和 keys-only
   Vivado 构建所需的最小生产快照。rtl/merged/rtl/cores/** 是带前缀生成快照，
   rtl/merged/rtl/common/**、rtl/merged/rtl/soc/** 和 rtl/merged/rtl/fpga/**
   是共享资源、四核封装、bridge bank、统一顶层和 FPGA 存储。
2. **13 项公开 VCS 输入。** rtl/merged/filelist_vcs.f、filelist_vcs_rtl.f、
   tb/ 中由 VCS filelist 引用的十个 testbench 以及 tb/vcs_fsdb_dump.vh。
   它们不改变生产 RTL；VCS 专用 filelist 只排除四个未例化、会触发严格语法兼容性
   问题的旧 handshake utility。
3. **4 项公开脚本与 FPGA 编程入口。** 清单中的 run_vcs_pre_sim_remote.sh、
   generate_all_isa_selfcheck.py、run_all_isa_selfcheck.ps1 和
   fpga/program_ax7035_merged.tcl 只使用仓库相对输入或显式环境变量。keys-only
   构建 TCL 属于 83 项基线；VIO 构建和控制入口不在本次公开快照。
4. **26 项必要固件与下载工具。** rtl/lhr/tests/programs/basic/ 的 20 个 BasicTest 镜像，课程范围
   全指令镜像 all_isa_selfcheck.data，以及 VCS/板测需要的
   Temp_rt_repeat8.data、bridge_ram_selfcheck.data、IF_uart_once.data、
   shared_ram_clear.data。串口下载工具为
   rtl/lhr/tools/tinyriscv_fw_downloader.py。
5. **17 项公开文档和非敏感摘要。** 根 README、合并目录 README、全指令说明、根
   `.gitattributes`/`.gitignore`、本清单、source manifest、四核层级/共享存储摘要、
   Icarus summary、LDK NACK 诊断摘要和 4/4 all-ISA 结果。根 `.gitattributes` 禁止 Git
   改写 83 项冻结输入的既有混合换行，并把 checksum manifest 与公开仿真资产固定为 LF；
   原始日志、波形和工程目录不由这些摘要隐式包含。

## prepare_prefixed_sources.ps1 与 source-of-truth

个人目录 rtl/lhr、rtl/ldk、rtl/sy、rtl/wje 中的 RTL 是本地 source-of-truth；
历史上由 prepare_prefixed_sources.ps1 读取这些目录，统一模块/宏前缀、外置寄存器堆、
标准化 I2C 开漏端口，并生成 rtl/merged/rtl/cores/**。本次公开候选直接发布并哈希锁定
生成后的 83 项快照，因此生成器和个人源目录不加入 github_freeze_files.txt；这样
clone 后的 VCS/Vivado 输入不会依赖个人工作树，也不会让一次未审查的重新生成覆盖冻结 RTL。
这里的 source-of-truth 仅用于审计生成关系；默认发布模型不包含个人 source-of-truth、生成器
或个人源树。

LDK 首次地址 NACK 修复已经反映在 source-of-truth 与生成版的对应哈希中；本清单不要求
队友重新生成。若未来修改个人 source-of-truth，必须重新运行生成、VCS、Vivado 和板级门禁，
并建立新的 manifest/bitstream 身份，不能沿用本候选的 aggregate。

根 `.gitattributes` 将 83 项哈希覆盖的输入标记为 `-text`，保留冻结时的原始字节；checksum
manifest 固定为 LF，避免 Windows `core.autocrlf` 改变冻结身份或破坏 Linux 校验命令。
可从冻结包根目录核对冻结输入：

~~~bash
export REPO_ROOT="/path/to/clone/rtl/merged_freeze"
(cd "$REPO_ROOT/rtl/merged" && sha256sum --check verification/vivado_keys_nackfix_20260804_140502/source_manifest.sha256)
~~~

本地工作树可能同时存在个人源树修改、删除或历史验证资产；这些状态不因 dirty 计数而自动
进入发布。公开交付只以逐项 allowlist 和冻结 manifest 为准，清单外改动必须另行审查。

工作树状态与本清单的对应关系如下：

| 工作树项目 | 公开处理 |
|---|---|
| 既有 tracked 修改 | 不因“工作树脏”而自动纳入；只有本文件、README、冻结源码或下表明确的公开辅助文件才进入选择性清单。其余仍由用户单独审阅。 |
| 11 个 tracked 删除 | 不放入 `github_freeze_files.txt`；仅在下面“个人源树待审删除”表中记录，不属于默认发布，默认不执行删除。 |
| untracked 文件 | 仅清单中逐项列出的、实际存在且已完成敏感扫描的文件可公开；不使用 `git add -A`。 |
| `prepare_prefixed_sources.ps1` 与个人 source-of-truth | 作为本地生成关系留在说明中，不公开生成器、个人源目录或私有编排器；`rtl/merged/rtl/**` 的 83 项冻结生成快照才是本候选的可复现输入。 |

## VCS/Verdi 公开复现

在具备许可证的 Linux EDA 服务器上 clone 后，将冻结包根目录和构建/证据目录显式设为
环境变量。工具路径由使用者填写，凭据和服务器连接由服务器环境管理；不要把原始服务器
日志、命令回放或波形同步回仓库。

~~~bash
export REPO_ROOT="/path/to/clone/rtl/merged_freeze"
export EDA_WORK_DIR="/tmp/tinyriscv-merged-vcs"
export TINYRISCV_VCS_BIN="/eda/path/to/vcs"
export TINYRISCV_VERDI_BIN="/eda/path/to/Verdi-Ultra"
export TINYRISCV_VERDI_ROOT="/eda/path/to/verdiSX"
mkdir -p "$EDA_WORK_DIR"

bash "$REPO_ROOT/rtl/merged/scripts/run_vcs_pre_sim_remote.sh" --out "$EDA_WORK_DIR/evidence" --build "$EDA_WORK_DIR/build" --remote-root "$EDA_WORK_DIR/run" --program-root "$REPO_ROOT/rtl/lhr/tests/programs"
~~~

公开 runner 会从 filelist_vcs.f 编译四核 smoke、RV32I、扩展指令、PWM、UART、Bridge、
downloader、切核清 RAM、全指令镜像和 LDK NACK 用例，并把构建产物和证据写入
EDA_WORK_DIR。预期结果是 **142/142 functional PASS、10/10 VCS compile、5/5 FSDB、
5/5 Verdi-Ultra batch**。VCS 版本基线为 R-2020.12-SP1，Verdi-Ultra 为
P-2019.06-SP2-12；Icarus 的 211 项计数不并入 VCS 142 项。

当前门禁保留两类非阻断警告：FSDB dumper 与 VCS 版本组合的兼容性横幅，以及旧 PWM
$dumpvars 参数/可选 Verdi 配置查找警告。它们不能替代 compile、运行、FSDB 非空和
Verdi batch 的独立判定。

本地 Windows 编排器 rtl/merged/scripts/run_vcs_pre_sim.ps1 不公开；它依赖本地服务器
凭据和固定连接参数。公开复现只使用 clone 后在 EDA 服务器运行的 remote runner。

## Vivado keys-only 复现与 bitstream

当前 FPGA 交付顶层为 tinyriscv_merged_fpga_key_top，器件为 xc7a35tfgg484-2，
Vivado 版本为 2019.1。VIO 顶层、VIO XDC、.ltx 和旧 VIO 产物均不属于当前候选。

在 Windows PowerShell 中使用仓库相对 TCL，并把工程目录放到 clone 外的临时目录：

~~~powershell
# 当前 PowerShell 已先 Set-Location 到 clone\rtl\merged_freeze
$env:REPO_ROOT = (Resolve-Path '.').Path
$env:BUILD_DIR = Join-Path ([IO.Path]::GetTempPath()) 'tinyriscv-merged-vivado'
$env:VIVADO_BIN = 'C:\path\to\vivado.bat'
$env:TINYRISCV_MERGED_USE_VIO = '0'
$env:TINYRISCV_MERGED_PROJ_DIR = Join-Path $env:BUILD_DIR 'project'

New-Item -ItemType Directory -Force -Path $env:BUILD_DIR | Out-Null
& $env:VIVADO_BIN -mode batch -source (Join-Path $env:REPO_ROOT 'rtl\merged\fpga\build_ax7035_merged.tcl')
~~~

门禁应确认 synthesis、implementation 和 write_bitstream 均完成；四个 tile 均存在；
推断出唯一 256 x 32 ROM 和唯一 16 x 32 RAM；routing error 为 0；当前候选报告为
WNS/TNS 1.189447/0 ns、WHS/THS 0.057836/0 ns、DRC 0 Error / 1 Warning。
构建后按 83 项 manifest 逐项核对，并将 aggregate 与
86C8634566E391F8EC9BD7226131453539E3779F9139C228E880B96D4CFE769A 比较。

当前 bitstream 建议作为 GitHub Release 附件，而不是 Git 源码文件：

rtl/merged/verification/vivado_keys_nackfix_20260804_140502/tinyriscv_merged_fpga_key_top.bit

其 SHA-256 必须为
B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF。使用 Release 附件
烧写时，必须先在本地计算并强比较 SHA-256；通过后启动本机 hw_server，并等待
localhost:3121 ready，再调用仓库内 rtl/merged/fpga/program_ax7035_merged.tcl。TCL 只连接
本机 hw_server，不需要公开任何服务器地址或认证信息。

~~~powershell
# 当前 PowerShell 已先 Set-Location 到 clone\rtl\merged_freeze
$env:REPO_ROOT = (Resolve-Path '.').Path
$env:VIVADO_BIN = 'C:\path\to\vivado.bat'
$env:TINYRISCV_MERGED_USE_VIO = '0'
$env:TINYRISCV_MERGED_BIT_FILE = 'C:\path\to\tinyriscv_merged_fpga_key_top.bit'
$expectedBitHash = 'B4EB184FD9F010B2C7822BEA72DF51DF177AFA9A1C076080B5D98BC43E17D6DF'
$actualBitHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $env:TINYRISCV_MERGED_BIT_FILE).Hash.ToUpperInvariant()
if ($actualBitHash -ne $expectedBitHash) { throw "bitstream SHA-256 mismatch: $actualBitHash" }
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

烧写后用 rtl/lhr/tools/tinyriscv_fw_downloader.py 下载一次共享 ROM；示例使用
课程全指令镜像，串口号由操作者替换为 COMx：

~~~powershell
# 当前 PowerShell 已先 Set-Location 到 clone\rtl\merged_freeze
$env:REPO_ROOT = (Resolve-Path '.').Path
$env:PYTHON_BIN = 'python'
& $env:PYTHON_BIN (Join-Path $env:REPO_ROOT 'rtl\lhr\tools\tinyriscv_fw_downloader.py') (Join-Path $env:REPO_ROOT 'rtl\lhr\tests\programs\all_isa_selfcheck.data') --port COMx
~~~

KEY1 进入/保持 downloader 与运行模式；KEY2/KEY3 正向或反向切换 LHR、LDK、SY、WJE；
每次切核后按板级流程复位并等待 RAM 清零与 guard 完成，再观察 LED/UART。共享 ROM 只需
下载一次；共享 RAM 会在切核时清零。预期每核得到全灯 PASS 和 11 字节 all-ISA UART。

## 当前验证结果与边界

| 门禁 | 当前身份/结果 |
|---|---|
| 本地 Icarus | 211 PASS / 0 FAIL；不冒充 VCS 结果 |
| 正式 VCS functional | 142 PASS / 0 FAIL |
| VCS compile / FSDB / Verdi | 10/10、5/5、5/5 |
| all-ISA 单镜像 Icarus | 四核 4/4 PASS；每核 11 字节 |
| 有效板级 BasicTest | 20 镜像 × 四核 = 80/80 PASS |
| 实体 I2C 逻辑分析仪波形 | PENDING_WAVEFORM，不是 PASS |

课程范围之外的 odd-address JALR bit-0 严格一致性仍是已记录 waiver；本候选按课程使用的
字对齐 JALR 验证，不因此修改生产 RTL。UART、温度值或仿真总线模型不能替代实体 I2C
START、地址 ACK/NACK、数据、末字节 NACK、STOP 波形。

## 个人源树待审删除（不属于默认上传清单）

下列文件当前在 Git 中是 tracked deletion。它们不写入 github_freeze_files.txt，也不属于默认
143 项公开快照；默认发布不要求提交这些删除。若未来另做 source-of-truth commit，必须把
相关个人源修改、删除和生成器作为一个整体审查，不能只提交下面这 11 项：

| deletion path | 说明 |
|---|---|
| rtl/wje/core/clint.v | 旧单核外设，当前合并快照未使用 |
| rtl/wje/core/csr_reg.v | 旧单核 CSR，当前课程范围未使用 |
| rtl/wje/core/div.v | 旧单核 M 扩展路径，当前课程范围未使用 |
| rtl/wje/debug/jtag_dm.v | 旧 JTAG 调试路径 |
| rtl/wje/debug/jtag_driver.v | 旧 JTAG 调试路径 |
| rtl/wje/debug/jtag_top.v | 旧 JTAG 调试路径 |
| rtl/wje/perips/gpio.v | 旧单核 GPIO |
| rtl/wje/perips/ram.v | 旧私有 RAM，已由共享 FPGA RAM 取代 |
| rtl/wje/perips/rom.v | 旧私有 ROM，已由共享 FPGA ROM 取代 |
| rtl/wje/perips/spi.v | 旧单核 SPI |
| rtl/wje/perips/timer.v | 旧单核 timer |

## 必须排除的本地、历史和敏感项

- 任何个人绝对路径、凭据字段、私钥、SSH 认证材料、固定服务器连接参数和本地编排器
  输出；公开文档只使用 repo-relative 路径、环境变量和 COMx 占位符。
- rtl/merged/verification/vcs_pre_sim_* 的原始服务器 summary、CSV、compile/run 日志、
  tool version、命令回放、FSDB 和 Verdi 工作目录；这些是不可公开的原始服务器证据。
- rtl/merged/verification/vivado_keys/ 的旧按键证据、vivado_vio/ 的 VIO 证据，
  board_keys_*/硬件日志，以及旧 bitstream、.ltx、debug core 和历史失败/重试附件。
- verification/icarus/waves/、诊断目录中的 .vcd/.vvp、任何 simv/csrc、
  build/、.Xil/、.jou、.log、临时工程目录和缓存；这些均不是 GitHub 源码。
- 未被本清单点名的旧固件、短文件实验镜像、长延时诊断镜像、旧 VIO 脚本和历史 CSV。
  公共板测只使用清单中的全指令、Bridge RAM、IF once 和 shared RAM 镜像。

## 选择性提交示例

完成逐文件 review 和远端策略后，主代理可以把清单作为 pathspec 输入；个人 source-of-truth
删除不属于默认选择性命令，若未来另做 source-of-truth commit，必须先成组审查。禁止按整个
工作树展开路径。

~~~powershell
Set-Location $env:REPO_ROOT
git add --pathspec-from-file=github_freeze_files.txt
~~~

以上只是用户确认后的示例；冻结身份、提交、tag、远端和发布附件仍由主代理决定。
