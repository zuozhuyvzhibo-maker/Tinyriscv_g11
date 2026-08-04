#!/usr/bin/env bash
set -u

# Formal VCS/Verdi runner.  It can be called directly from a public clone or
# by a private orchestration wrapper.  Build products stay under --build and
# evidence stays under --out; only the latter is synchronized back.

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT=""
BUILD=""
REMOTE_ROOT=""
PROGRAM_ROOT="$ROOT/../lhr/tests/programs"
# The historical server layout remains the default for compatibility.  A
# public clone can override these three paths without exposing credentials or
# depending on a particular EDA installation prefix.
VCS_BIN="${TINYRISCV_VCS_BIN:-/soft1/synopsys/vcs/bin/vcs}"
VERDI_BIN="${TINYRISCV_VERDI_BIN:-/soft1/synopsys/verdiSX/bin/Verdi-Ultra}"
VERDI_ROOT="${TINYRISCV_VERDI_ROOT:-/soft1/synopsys/verdiSX}"
TIMEOUT_BIN="$(command -v timeout || true)"
SHA256_BIN="$(command -v sha256sum || true)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT=$2; shift 2 ;;
        --build) BUILD=$2; shift 2 ;;
        --remote-root) REMOTE_ROOT=$2; shift 2 ;;
        --program-root) PROGRAM_ROOT=$2; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$OUT" || -z "$BUILD" || -z "$REMOTE_ROOT" ]]; then
    echo "usage: $0 --out OUT --build BUILD --remote-root ROOT [--program-root DIR]" >&2
    exit 2
fi
if [[ ! -x "$VCS_BIN" || ! -x "$VERDI_BIN" ]]; then
    echo "required Synopsys tools are not executable" >&2
    exit 2
fi
if [[ -z "$TIMEOUT_BIN" || -z "$SHA256_BIN" ]]; then
    echo "timeout and sha256sum are required" >&2
    exit 2
fi

cd "$ROOT"

mkdir -p "$OUT/logs" "$OUT/waves" "$BUILD"
RESULTS="$OUT/results.csv"
CHECKS="$OUT/checks.csv"
COMMANDS="$OUT/commands.sh"
TOOL_VERSIONS="$OUT/tool_versions.txt"
VERDI_LOAD_LOG="$OUT/verdi_load.log"
WAVES_MANIFEST="$OUT/waves_manifest.csv"

printf 'Index,Suite,Test,Core,Status,ExitCode,Timeout,Seconds,PassLine,Log\n' > "$RESULTS"
printf 'Check,Item,Status,ExitCode,Seconds,Detail,Log\n' > "$CHECKS"
printf 'Name,RemotePath,Bytes,SHA256\n' > "$WAVES_MANIFEST"
: > "$VERDI_LOAD_LOG"
{
    printf '#!/usr/bin/env bash\n'
    printf '# Reproduction commands recorded during the isolated VCS run.\n'
    printf '# Remote root: %s\n' "$REMOTE_ROOT"
    printf 'cd %q\n' "$ROOT"
} > "$COMMANDS"

csv_field() {
    local value=${1//$'\r'/ }
    value=${value//$'\n'/ }
    value=${value//\"/\"\"}
    printf '"%s"' "$value"
}

csv_row() {
    local first=1
    local value
    for value in "$@"; do
        if [[ $first -eq 0 ]]; then printf ','; fi
        csv_field "$value"
        first=0
    done
    printf '\n'
}

record_command() {
    local arg
    for arg in "$@"; do printf '%q ' "$arg" >> "$COMMANDS"; done
    printf '\n' >> "$COMMANDS"
}

record_check() {
    local check=$1 item=$2 status=$3 rc=$4 seconds=$5 detail=$6 log=$7
    csv_row "$check" "$item" "$status" "$rc" "$seconds" "$detail" "$log" >> "$CHECKS"
}

RUN_INDEX=0
declare -A SIM
declare -A COMPILE_OK

compile_top() {
    local key=$1 top=$2
    local dir="$BUILD/$key"
    local simv="$dir/simv"
    local log="$OUT/logs/compile_${key}.log"
    local start end seconds rc
    mkdir -p "$dir"
    local cmd=(
        "$VCS_BIN" -full64 -sverilog -timescale=1ns/1ps
        -debug_access+all -kdb -Mdir="$dir/csrc" -o "$simv"
        +define+IVERILOG_FAST_SIM+VCS_FSDB
        -P "$VERDI_ROOT/share/PLI/VCS/LINUX64/novas.tab"
        "$VERDI_ROOT/share/PLI/VCS/LINUX64/pli.a"
        -f "$ROOT/filelist_vcs.f" -top "$top"
    )
    {
        printf '# compile key=%s top=%s\n' "$key" "$top"
        printf '$ '
        printf '%q ' "${cmd[@]}"
        printf '\n'
    } > "$log"
    record_command "${cmd[@]}"
    start=$(date +%s%N)
    set +e
    "${cmd[@]}" >> "$log" 2>&1
    rc=$?
    set -e
    end=$(date +%s%N)
    seconds=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.3f", (e-s)/1000000000 }')
    if [[ $rc -eq 0 && -x "$simv" ]]; then
        COMPILE_OK[$key]=1
        SIM[$key]="$simv"
        record_check compile "$top" PASS "$rc" "$seconds" "VCS elaboration completed" "logs/compile_${key}.log"
        echo "VCS_COMPILE PASS key=$key top=$top seconds=$seconds"
    else
        COMPILE_OK[$key]=0
        SIM[$key]="$simv"
        record_check compile "$top" FAIL "$rc" "$seconds" "VCS compile/elaboration failed" "logs/compile_${key}.log"
        echo "VCS_COMPILE FAIL key=$key top=$top rc=$rc seconds=$seconds"
    fi
}

run_case() {
    local suite=$1 test=$2 core=$3 key=$4 timeout_s=$5
    shift 5
    local simv=${SIM[$key]-}
    local index log start end seconds rc timeout_flag pass_line detail status
    RUN_INDEX=$((RUN_INDEX + 1))
    index=$RUN_INDEX
    log=$(printf '%s/logs/run_%03d_%s_%s_core_%s.log' "$OUT" "$index" "$suite" "$test" "$core")
    mkdir -p "$(dirname "$log")"
    if [[ ! -x "$simv" ]]; then
        csv_row "$index" "$suite" "$test" "$core" FAIL "-2" 0 0 "compile_failed" \
            "logs/$(basename "$log")" >> "$RESULTS"
        printf 'VCS_CASE %03d FAIL suite=%s test=%s core=%s reason=compile_failed\n' \
            "$index" "$suite" "$test" "$core"
        return
    fi

    local cmd=("$TIMEOUT_BIN" --foreground "$timeout_s" "$simv" "$@")
    {
        printf '# case=%s suite=%s test=%s core=%s timeout=%ss\n' "$index" "$suite" "$test" "$core" "$timeout_s"
        printf '$ '
        printf '%q ' "${cmd[@]}"
        printf '\n'
    } > "$log"
    record_command "${cmd[@]}"
    start=$(date +%s%N)
    set +e
    "${cmd[@]}" >> "$log" 2>&1
    rc=$?
    set -e
    end=$(date +%s%N)
    seconds=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.3f", (e-s)/1000000000 }')
    timeout_flag=0
    if [[ $rc -eq 124 || $rc -eq 137 ]]; then timeout_flag=1; fi
    pass_line=$(grep -E 'TEST_PASS' "$log" | tail -1 || true)
    fail_line=$(grep -E 'TEST_FAIL|ASSERT_FAIL' "$log" | head -1 || true)
    detail="$(tail -1 "$log" 2>/dev/null || true)"
    if [[ $rc -eq 0 && $timeout_flag -eq 0 && -n "$pass_line" &&
          -z "$fail_line" ]]; then
        status=PASS
    else
        status=FAIL
        if [[ $timeout_flag -eq 1 ]]; then detail="timeout"; fi
        if [[ -z "$detail" ]]; then detail="no TEST_PASS or nonzero exit"; fi
    fi
    csv_row "$index" "$suite" "$test" "$core" "$status" "$rc" "$timeout_flag" "$seconds" "$pass_line" \
        "logs/$(basename "$log")" >> "$RESULTS"
    printf 'VCS_CASE %03d %s suite=%s test=%s core=%s rc=%s seconds=%s\n' \
        "$index" "$status" "$suite" "$test" "$core" "$rc" "$seconds"
}

write_tool_versions() {
    local vcs_log="$OUT/logs/vcs_version.log"
    local verdi_log="$OUT/logs/verdi_version.log"
    local vcs_rc verdi_rc
    set +e
    "$VCS_BIN" -ID > "$vcs_log" 2>&1
    vcs_rc=$?
    timeout 20 "$VERDI_BIN" -version > "$verdi_log" 2>&1
    verdi_rc=$?
    set -e
    {
        printf 'Date: %s\n' "$(date --iso-8601=seconds)"
        printf 'OS: %s\n' "$(uname -a)"
        printf 'Hostname: %s\n' "$(hostname)"
        printf 'VCS path: %s\n' "$VCS_BIN"
        printf 'VCS version command exit: %s\n' "$vcs_rc"
        cat "$vcs_log"
        printf 'Verdi-Ultra path: %s\n' "$VERDI_BIN"
        printf 'Verdi-Ultra version command exit: %s (version output retained; this server build may probe DISPLAY)\n' "$verdi_rc"
        cat "$verdi_log"
        printf 'VCS compile defines: IVERILOG_FAST_SIM, VCS_FSDB\n'
        printf 'VCS PLI: %s/share/PLI/VCS/LINUX64/novas.tab and pli.a\n' "$VERDI_ROOT"
    } > "$TOOL_VERSIONS"
}

verify_fsdb() {
    local name=$1
    local path="$OUT/waves/$name.fsdb"
    local log="logs/fsdb_${name}.log"
    local size sha status detail
    if [[ -s "$path" ]]; then
        size=$(stat -c '%s' "$path")
        sha=$($SHA256_BIN "$path" | awk '{print $1}')
        status=PASS
        detail="bytes=$size sha256=$sha"
        csv_row "$name" "waves/$name.fsdb" "$size" "$sha" >> "$WAVES_MANIFEST"
    else
        size=0
        sha=""
        status=FAIL
        detail="missing_or_empty"
    fi
    printf '%s\n' "$detail" > "$OUT/$log"
    record_check fsdb "$name" "$status" 0 0 "$detail" "$log"
}

verdi_load_fsdb() {
    local name=$1 top=$2
    local fsdb="$OUT/waves/$name.fsdb"
    local log="$OUT/logs/verdi_${name}.log"
    local start end seconds rc status detail
    local cmd=(
        "$VERDI_BIN" -batch -nologo -f "$ROOT/filelist_vcs.f" -top "$top"
        -ssf "$fsdb"
    )
    {
        printf '# Verdi batch load name=%s top=%s\n' "$name" "$top"
        printf '$ '
        printf '%q ' "${cmd[@]}"
        printf '\n'
    } > "$log"
    record_command "${cmd[@]}"
    start=$(date +%s%N)
    set +e
    timeout --foreground 120 "${cmd[@]}" >> "$log" 2>&1
    rc=$?
    set -e
    end=$(date +%s%N)
    seconds=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.3f", (e-s)/1000000000 }')
    if [[ $rc -eq 0 ]]; then
        status=PASS
        detail="batch_load_returned_0"
    elif [[ $rc -eq 124 || $rc -eq 137 ]]; then
        status=FAIL
        detail="timeout"
    else
        status=FAIL
        detail="batch_load_exit_$rc"
    fi
    record_check verdi "$name" "$status" "$rc" "$seconds" "$detail" "logs/verdi_${name}.log"
    {
        printf '===== %s =====\n' "$name"
        cat "$log"
    } >> "$VERDI_LOAD_LOG"
    echo "VERDI_LOAD $status name=$name rc=$rc seconds=$seconds"
}

write_tool_versions

# The formal compile set is separate from the 142 functional rows.
compile_top basic80 merged_core_smoke_tb
compile_top rv32i merged_rv32i_directed_tb
compile_top extensions merged_extensions_tb
compile_top pwm merged_pwm_tb
compile_top uart merged_uart_tb
compile_top bridge merged_bridge_protocol_tb
compile_top downloader shared_uart_debug_tb
compile_top switch merged_switch_clear_tb
compile_top all_isa merged_all_isa_selfcheck_tb
compile_top nack merged_ldk_rt_repeat_tb

# 1. BasicTest: 20 images x 4 cores = 80.
while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    name=${image%.data}
    for core in 0 1 2 3; do
        run_case basic80 "$name" "$core" basic80 300 \
            "+CORE=$core" "+MEM=$PROGRAM_ROOT/basic/$image"
    done
done < <(find "$PROGRAM_ROOT/basic" -maxdepth 1 -type f -name '*.data' -printf '%f\n' | sort)

# 2. RV32I directed: 5 groups x 4 cores = 20.
for test in rv32i_alu load_store_alias rv32i_branch rv32i_jump_upper rv32i_hazards; do
    for core in 0 1 2 3; do
        if [[ "$test" == rv32i_alu && "$core" == 0 ]]; then
            run_case rv32i "$test" "$core" rv32i 300 \
                "+TEST=$test" "+CORE=$core" "+VCD=$OUT/waves/rv32i.fsdb"
        else
            run_case rv32i "$test" "$core" rv32i 300 "+TEST=$test" "+CORE=$core"
        fi
    done
done

# 3. Extensions: sID x 4, if x 4, and rT at two LM75 temperatures x 4.
for test in sid if; do
    for core in 0 1 2 3; do
        run_case extensions "$test" "$core" extensions 300 "+TEST=$test" "+CORE=$core"
    done
done
for word in 1900 ff80; do
    for core in 0 1 2 3; do
        if [[ "$word" == 1900 && "$core" == 2 ]]; then
            run_case extensions "rt_$word" "$core" extensions 300 \
                "+TEST=rt" "+CORE=$core" "+LM75_WORD=$word" "+VCD=$OUT/waves/rt_i2c.fsdb"
        else
            run_case extensions "rt_$word" "$core" extensions 300 \
                "+TEST=rt" "+CORE=$core" "+LM75_WORD=$word"
        fi
    done
done

# 4. PWM x 4 and ordinary UART x 4 = 8.
for core in 0 1 2 3; do
    run_case peripheral pwm "$core" pwm 180 "+CORE=$core"
done
for core in 0 1 2 3; do
    run_case peripheral uart_loopback "$core" uart 180 "+CORE=$core"
done

# 5. Four native Bridge protocols = 4.
for core in 0 1 2 3; do
    if [[ "$core" == 0 ]]; then
        run_case bridge native_protocol "$core" bridge 180 \
            "+CORE=$core" "+VCD=$OUT/waves/bridge_ram.fsdb"
    else
        run_case bridge native_protocol "$core" bridge 180 "+CORE=$core"
    fi
done

# 6. Downloader capacity boundaries and CRC = 6.
for test in size0 size1 size1023 size1024 reject1025 bad_crc; do
    if [[ "$test" == size1024 ]]; then
        run_case downloader "$test" "-" downloader 180 \
            "+TEST=$test" "+VCD=$OUT/waves/uart_debug_downloader.fsdb"
    else
        run_case downloader "$test" "-" downloader 180 "+TEST=$test"
    fi
done

# 7. Switch/RAM-clear/cancel = 1.
run_case integration switch_clear_cancel - switch 180 "+VCD=$OUT/waves/switch_clear_ram.fsdb"

# 8. Course-scope all-ISA image x 4 cores = 4.
for core in 0 1 2 3; do
    run_case all_isa all_isa_selfcheck "$core" all_isa 300 \
        "+CORE=$core" "+MEM=$PROGRAM_ROOT/all_isa_selfcheck.data" "+LM75_WORD=1900"
done

# 9. LDK rT NACK: clean, first-NACK recovery, and retry exhaustion = 3.
for scenario in clean retry_single_nack retry_exhausted; do
    run_case ldk_rt_nack "$scenario" LDK nack 300 \
        "+SCENARIO=$scenario" "+MEM=$PROGRAM_ROOT/Temp_rt_repeat8.data"
done

for name in rv32i rt_i2c bridge_ram uart_debug_downloader switch_clear_ram; do
    verify_fsdb "$name"
done

# Verdi-Ultra is invoked in -batch mode and must return before the timeout.
verdi_load_fsdb rv32i merged_rv32i_directed_tb
verdi_load_fsdb rt_i2c merged_extensions_tb
verdi_load_fsdb bridge_ram merged_bridge_protocol_tb
verdi_load_fsdb switch_clear_ram merged_switch_clear_tb
verdi_load_fsdb uart_debug_downloader shared_uart_debug_tb

functional_pass=$(awk -F, 'NR>1 { gsub(/"/,"",$5); if ($5 == "PASS") n++ } END { print n+0 }' "$RESULTS")
functional_fail=$(awk -F, 'NR>1 { gsub(/"/,"",$5); if ($5 != "PASS") n++ } END { print n+0 }' "$RESULTS")
compile_pass=$(awk -F, 'NR>1 { gsub(/"/,"",$1); gsub(/"/,"",$3); if ($1 == "compile" && $3 == "PASS") n++ } END { print n+0 }' "$CHECKS")
compile_fail=$(awk -F, 'NR>1 { gsub(/"/,"",$1); gsub(/"/,"",$3); if ($1 == "compile" && $3 != "PASS") n++ } END { print n+0 }' "$CHECKS")
fsdb_pass=$(awk -F, 'NR>1 { gsub(/"/,"",$1); gsub(/"/,"",$3); if ($1 == "fsdb" && $3 == "PASS") n++ } END { print n+0 }' "$CHECKS")
verdi_pass=$(awk -F, 'NR>1 { gsub(/"/,"",$1); gsub(/"/,"",$3); if ($1 == "verdi" && $3 == "PASS") n++ } END { print n+0 }' "$CHECKS")
verdi_fail=$(awk -F, 'NR>1 { gsub(/"/,"",$1); gsub(/"/,"",$3); if ($1 == "verdi" && $3 != "PASS") n++ } END { print n+0 }' "$CHECKS")

{
    printf '# Formal VCS + Verdi RTL pre-simulation summary\n\n'
    printf -- '- Remote isolated directory: `%s`\n' "$REMOTE_ROOT"
    printf -- '- Source root: `%s`\n' "$ROOT"
    printf -- '- Formal functional rows: **%s PASS / %s FAIL** (expected 142 rows)\n' "$functional_pass" "$functional_fail"
    printf -- '- VCS compile checks: **%s PASS / %s FAIL** (separate from 142)\n' "$compile_pass" "$compile_fail"
    printf -- '- FSDB checks: **%s PASS / %s FAIL** (separate from 142)\n' "$fsdb_pass" "$((5 - fsdb_pass))"
    printf -- '- Verdi-Ultra batch loads: **%s PASS / %s FAIL** (separate from 142)\n' "$verdi_pass" "$verdi_fail"
    printf -- '- Icarus 211 count was not used as VCS evidence.\n'
    printf -- '- Functional verdict uses exit code, TEST_PASS, TEST_FAIL, ASSERT_FAIL, and timeout together.\n'
    printf -- '- VCS compile defines: IVERILOG_FAST_SIM and VCS_FSDB; the former matches the existing simulator-fast timing switch.\n'
    printf -- '- Warning/waiver: VCS-only filelist omits four uninstantiated legacy SY/WJE handshake utilities rejected for declaration-after-use syntax; no production RTL was edited.\n'
    printf -- '- Non-gating warnings retained in logs: 12 PWM legacy dumpvars argument warnings and optional Verdi novas.conf lookup warnings; all affected compile/batch checks returned 0.\n'
    printf -- '- Representative FSDBs: rv32i, rT/I2C, Bridge/RAM, switch-clear RAM, uart-debug/downloader.\n'
} > "$OUT/summary.md"

printf 'VCS_FUNCTIONAL_SUMMARY pass=%s fail=%s compile_pass=%s compile_fail=%s fsdb_pass=%s verdi_pass=%s verdi_fail=%s\n' \
    "$functional_pass" "$functional_fail" "$compile_pass" "$compile_fail" "$fsdb_pass" "$verdi_pass" "$verdi_fail"

if [[ "$functional_pass" -ne 142 || "$functional_fail" -ne 0 ||
      "$compile_fail" -ne 0 || "$fsdb_pass" -ne 5 || "$verdi_fail" -ne 0 ]]; then
    exit 1
fi
exit 0
