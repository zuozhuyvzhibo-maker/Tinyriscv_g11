# LHR TinyRISC-V stage-1 reduced RTL

This directory is the single-design RTL freeze prepared for Mission 1.

## Implemented design

- ISA: RV32I plus the course `sID`, `rT`, and `IF` instructions.
- Retained peripherals: UART, four-channel PWM, and I2C/LM75.
- Innovation: on-chip ROM/RAM were replaced by an 8-bit bidirectional
  chip-to-FPGA memory bridge (`bridge_data_o[7:0]` and
  `bridge_data_i[7:0]`).
- Removed resources: RV32M multiply/divide/remainder, CSR, CLINT,
  exceptions, interrupts, JTAG, GPIO, SPI, Timer, and on-chip ROM/RAM.
- All Verilog, XDC, and Tcl source text is ASCII with English comments.

## Top-level interfaces

The FPGA verification top is `tinyriscv_soc_top_bridge_fpga`:

```text
clk, rst, succ, uart_debug_pin, uart_tx_pin, uart_rx_pin,
pwm_o[2:0], io_scl, io_sda
```

The ASIC-side top is `tinyriscv_chip_top_bridge`. It exposes the same
functional UART/PWM/I2C signals, all four PWM channels, and the two 8-bit
bridge buses required by the project innovation. The AX7035 wrapper exposes
three PWM pins because the course board constraint file assigns three pins;
the fourth channel remains implemented and is checked in simulation.

Reset is active low. `uart_debug_pin=1` selects the FPGA UART downloader and
holds the processor in reset; `uart_debug_pin=0` selects normal CPU UART.

## Filelists

- `filelist.f`: ASIC-side synthesizable RTL, top
  `tinyriscv_chip_top_bridge`.
- `filelist_fpga.f`: ASIC RTL plus FPGA memory/debug wrapper, top
  `tinyriscv_soc_top_bridge_fpga`.
- `filelist_sim.f`: FPGA filelist plus the self-checking Icarus testbench.

## Simulation

The uploaded package has no dependency on a simulator-specific project. Run
the following commands from this directory. This example compiles the common
self-checking testbench with Icarus Verilog and runs `inst_add`:

```powershell
$simImage = Join-Path $env:TEMP 'tinyriscv_stage1.vvp'
C:\iverilog\bin\iverilog.exe -g2012 -Wall -Wno-timescale `
  -Wno-sensitivity-entire-array -s tinyriscv_bridge_validation_tb `
  -o $simImage -c filelist_sim.f
$program = 'tests/programs/basic/inst_add.data'
$words = (Get-Content -LiteralPath $program).Count
C:\iverilog\bin\vvp.exe $simImage +TEST=BASIC +MEMFILE=$program `
  +MEM_WORDS=$words +MAX_CYCLES=20000
```

A passing run ends with `TEST_PASS`. The same filelist can be used with VCS:

```bash
vcs -full64 -sverilog -top tinyriscv_bridge_validation_tb \
  -f filelist_sim.f -o /tmp/tinyriscv_stage1_simv
/tmp/tinyriscv_stage1_simv +TEST=BASIC \
  +MEMFILE=tests/programs/basic/inst_add.data \
  +MEM_WORDS=223 +MAX_CYCLES=20000
```

Select `TEST` from `BASIC`, `BRIDGE_RAM`, `M_REMOVED`, `RT`, `SID`, `IF`,
`PWM`, or `I2C`, and set `MEMFILE` to the corresponding file under
`tests/programs`. Use the actual line count of each `.data` file for
`MEM_WORDS`. The regression recorded in `verification/results.csv` covers 20
RV32I BasicTest programs, external-memory bridge read/write, safe rejection
of removed M encodings, `rT`, `sID`, `IF`, four PWM channels, and a complete
I2C transaction against a behavioral LM75.

## Recorded stage-1 result

- Frozen-directory Icarus regression: 27/27 passed, 0 failed.
- Vivado 2019.1: synthesis and `write_bitstream` completed for
  `xc7a35tfgg484-2`.
- Implemented utilization: 3922 LUTs, 2790 registers, 2 FPGA-wrapper BRAM
  tiles, and 0 DSPs.
- Timing at 50 MHz: WNS 5.826 ns, TNS 0; DRC has no errors and one benign
  `IOSR-1` IOB packing warning.
- AX7035 board validation was completed on 2026-07-27: the 20 BasicTest
  programs, bridge test, `rT`, `sID`, `IF`, PWM, and I2C tests passed. For the
  temperature test, the UART capture `00 32` contains one reset-time zero byte
  followed by the expected `0x32` payload.

Detailed machine-readable results are in `verification/results.csv`, and the
complete table is in `verification/summary.md`. The `Log` fields preserve the
paths used by the local regression; raw logs, waveforms, generated simulator
images, Vivado projects, and bitstreams are intentionally excluded from this
source-only package.

## FPGA build

Vivado 2019.1 batch build:

```powershell
C:\Xilinx\Vivado\2019.1\bin\vivado.bat -mode batch `
  -source .\fpga\build_ax7035_bridge_final_named.tcl
```

The current FPGA debug RTL uses the course 35-byte packet protocol. Download
a hexadecimal course program directly (the tool converts words to
little-endian binary bytes) with:

```powershell
python .\tools\tinyriscv_fw_downloader.py `
  .\tests\programs\basic\inst_add.data --port COM3
```

Use `--dry-run` without `--port` to validate the program conversion and packet
construction when no board is connected. Keep `uart_debug_pin` high during
download, then set it low to release the processor and observe `succ`/UART or
the relevant peripheral output.
