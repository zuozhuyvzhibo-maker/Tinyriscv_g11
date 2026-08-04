# Icarus/GTKWave four-core verification summary

- Date: 2026-08-04 14:03:09 +08:00
- Icarus: Icarus Verilog version 12.0 (devel) (s20150603-1539-g2693dd32b)
- GTKWave: GTKWave Analyzer v3.3.100 (w)1999-2019 BSI
- Command: powershell -ExecutionPolicy Bypass -File scripts\run_full_icarus_regression.ps1
- Elapsed: 95.22 s
- Result: **211 PASS / 0 FAIL**

## Suite matrix

| Suite | PASS | FAIL |
|---|---:|---:|
| basic80 | 80 | 0 |
| bridge | 4 | 0 |
| compile | 8 | 0 |
| downloader | 6 | 0 |
| extensions | 16 | 0 |
| gtkwave | 1 | 0 |
| integration | 1 | 0 |
| legacy45 | 45 | 0 |
| peripheral | 8 | 0 |
| prepare | 1 | 0 |
| rv32i | 20 | 0 |
| structure | 6 | 0 |
| waveform | 7 | 0 |
| waveform_file | 7 | 0 |
| waveform_inspection | 1 | 0 |

## Waveforms

- verification/icarus/waves/rv32i_alu.vcd
- verification/icarus/waves/load_store_alias.vcd
- verification/icarus/waves/sid_if.vcd
- verification/icarus/waves/rt_i2c.vcd
- verification/icarus/waves/pwm.vcd
- verification/icarus/waves/switch_clear.vcd
- verification/icarus/waves/uart_download.vcd
- verification/icarus/merged.gtkw
- verification/icarus/wave_inspection.md

All required assertions passed; no timeout, protocol error,
unexpected X/Z on audited active signals, or out-of-range write was observed.
