# LDK first-address NACK diagnostic and repair

## Frozen input identity

- Git HEAD: `e45a48e30867848cd5948b9568f1ea171ee222c9`
- Staged files before diagnostic: `0`
- Historical Icarus summary: `9B180D99A9F356762ECCFD744C5B216C28D960C8C8F8C74AF199B69131D20E5A`
- Historical Icarus results: `C2B9AA88DAC903AF7E7FE60700CDEDF9153494862978FCF5578404F98D2E9B6C`
- Historical keys bitstream: `448A7BC8571BA797389A2A807465B24262E9B130F1C13EC72916A975FD5D8373`
- Pre-fix source-of-truth `iic_dk.v`: `E48AEFF325B85FB2BFDA724D5533489A82AD0C848F1C50E8C95812F63E4BF51A`

## Pre-fix signature gate

Only the first LM75 `0x90` address ACK bit was forced to NACK. The unmodified production RTL
completed that CPU request with zero, then completed the next seven requests normally:

```text
TEST_PASS scenario=legacy_single_nack
uart=00_32_32_32_32_32_32_32
starts=15 stops=8 address_attempts=8 successful_reads=7
injected_nacks=1 cpu_acks=8
```

This matches the physical relative signature `00 39 39 39 39 39 39 39` and permitted the
source-of-truth repair.

## Repair behavior

The source-of-truth controller now waits for two high SDA quarter-ticks before START, retries a
slave NACK after STOP, and allows at most three total attempts. Retry decisions use the sampled
ACK bit only. The module interface is unchanged.

After running `prepare_prefixed_sources.ps1`, all 68 generated-source hashes were compared with
the pre-generation baseline. Only `ldk/perips/iic_dk.v` changed.

| Scenario | UART | START | STOP | Address attempts | Successful reads | NACK | CPU ACK | Minimum bus free |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| clean | `32` x 8 | 16 | 8 | 8 | 8 | 0 | 8 | 4480 ns |
| first address NACK | `32` x 8 | 17 | 9 | 9 | 8 | 1 | 8 | 200 ns |
| first three addresses NACK | `00` + `32` x 7 | 17 | 10 | 10 | 7 | 3 | 8 | 200 ns |

The exhausted case proves that the first CPU request completes after exactly three attempts; the
next address attempt belongs to the second CPU request, so there is no fourth internal retry.

## Post-fix regression identity

- Source-of-truth `iic_dk.v`: `452C3CCBC331CA35F588EF6965E65FC2419E6A82C4022B86424A5581D4FF5C50`
- Generated LDK `iic_dk.v`: `2C0E9A786A87CAEB91C080964CD5C868A3425538D2C28ED021B87FD25FECEE18`
- Directed testbench: `0C8B52E90E19E03A5F584F184CFD2B147AE9F24CAA6069481E2F8FDD7CCA530E`
- Icarus result: `211 PASS / 0 FAIL`, elapsed `95.22 s`
- Icarus summary: `9FEFBC916ACCBBD8E42C9554878853B2E35904F6C2B4729D0D6BB10BFAD77439`
- Icarus results: `A25191584B5FB98EEB356DC46B5A127C0963DF0737A339576A0088DA6EC21EC8`
- Staged files after regression: `0`

The historical bitstream is now stale because production RTL changed. No VIO build, staging,
commit, tag, or push was performed.

## Binary diagnostic artifacts

| File | SHA-256 |
|---|---|
| `pre_fix_ldk_rt_repeat.vvp` | `B6251442B3F18D2E59D22AC380ECF1F80ADFEAE081905A959B1CEE429C45BC91` |
| `pre_fix_single_nack.vcd` | `10D5F932FB90CA614B2D0C19AA31764D6C8F4B460617F207C018B71AACA9A9A4` |
| `post_fix_ldk_rt_repeat.vvp` | `50D4FA40AEF184F0F2CD98B7FA0120E50703AF109E483F1BC2725F4A43B9DCE9` |
| `post_fix_clean.vcd` | `352F0D2CD6D667B89D2C2B04FDCC7E385642280F8E95AD7D824002AF19249C1B` |
| `post_fix_retry_single_nack.vcd` | `B9C9C2FB6EFA3CD67510187B23D3D20767027DA1604858923A3A48AB9A430B7C` |
| `post_fix_retry_exhausted.vcd` | `6F2B5C779E812393BA48E98F21A97C0E042328B0315BC97CB1F24D50648B2540` |
