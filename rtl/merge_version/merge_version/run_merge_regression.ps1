$ErrorActionPreference = "Stop"

$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$build = Join-Path $base "verification\build"
$logDir = Join-Path $base "verification\logs"
$summaryFile = Join-Path $base "verification\merge_regression_summary.txt"

New-Item -ItemType Directory -Force $build | Out-Null
New-Item -ItemType Directory -Force $logDir | Out-Null

$files = Get-Content (Join-Path $base "merge_filelist.f") |
    Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") }

$compileArgs = @(
    "-g2012",
    "-I", (Join-Path $base "lhr\rtl\core"),
    "-I", (Join-Path $base "lhr\fpga"),
    "-I", (Join-Path $base "ldk\rtl_liudk\core"),
    "-I", (Join-Path $base "wje\rtl\core"),
    "-I", (Join-Path $base "sy\core"),
    "-s", "tinyriscv_merge_validation_tb",
    "-o", (Join-Path $build "merge_validation.vvp")
) + $files + @(
    "liudk_test\IIC_test\iic_slave.v",
    (Join-Path $base "tb\tinyriscv_merge_validation_tb.v")
)

& iverilog @compileArgs 2>&1 | Tee-Object (Join-Path $build "compile.log")
if ($LASTEXITCODE -ne 0) {
    throw "iverilog compile failed"
}

$programRoot = Join-Path $base "lhr\tests\programs"
$syProgramRoot = Join-Path $base "sy\Test"
$tests = @()
Get-ChildItem (Join-Path $programRoot "basic") -Filter "*.data" | Sort-Object Name | ForEach-Object {
    $tests += [pscustomobject]@{
        Name = $_.BaseName
        Kind = "BASIC"
        File = $_.FullName
        SyFile = (Join-Path $syProgramRoot ("Baisc_Inst_Example\{0}" -f $_.Name))
        Max = 300000
    }
}
$tests += [pscustomobject]@{ Name = "sID_inst"; Kind = "SID"; File = (Join-Path $programRoot "sID_inst.data"); SyFile = (Join-Path $syProgramRoot "Extend_Inst_Example\sID\sID_inst.data"); Max = 3000000 }
$tests += [pscustomobject]@{ Name = "IF_inst"; Kind = "IF"; File = (Join-Path $programRoot "IF_inst.data"); SyFile = (Join-Path $syProgramRoot "Extend_Inst_Example\IF\IF_inst.data"); Max = 500000 }
$tests += [pscustomobject]@{ Name = "Temp"; Kind = "RT"; File = (Resolve-Path "liudk_test\temp_test\Temp.data").Path; SyFile = (Join-Path $syProgramRoot "Extend_Inst_Example\Temp\Temp.data"); Max = 3000000 }
$tests += [pscustomobject]@{ Name = "PWM_inst"; Kind = "PWM"; File = (Join-Path $programRoot "PWM_inst.data"); SyFile = (Join-Path $syProgramRoot "Other_Example\PWM\PWM_inst.data"); Max = 700000 }

$repoRoot = (Resolve-Path ".").Path
$summary = @()

foreach ($sel in 0..3) {
    foreach ($test in $tests) {
        $testFile = if ($sel -eq 3) { (Resolve-Path $test.SyFile).Path } else { (Resolve-Path $test.File).Path }
        $words = (Get-Content $testFile | Where-Object { $_.Trim() -ne "" }).Count
        $memFile = $testFile.Replace($repoRoot + "\", "").Replace("\", "/")
        $log = Join-Path $logDir ("merge_sel{0}_{1}.log" -f $sel, $test.Name)

        $out = & vvp (Join-Path $build "merge_validation.vvp") `
            "+CHIP_SEL=$sel" `
            "+TEST=$($test.Kind)" `
            "+MEMFILE=$memFile" `
            "+MEM_WORDS=$words" `
            "+MAX_CYCLES=$($test.Max)" 2>&1
        $out | Set-Content $log

        $pass = ($LASTEXITCODE -eq 0) -and (($out -join "`n") -match "TEST_PASS")
        $summary += [pscustomobject]@{
            ChipSel = $sel
            Test = $test.Name
            Kind = $test.Kind
            Pass = $pass
            Exit = $LASTEXITCODE
            Log = $log
        }
        Write-Host ("chip_sel={0} test={1} kind={2} pass={3}" -f $sel, $test.Name, $test.Kind, $pass)
    }
}

$summary | Format-Table -AutoSize | Out-String | Set-Content $summaryFile
$failed = $summary | Where-Object { -not $_.Pass }

if ($failed) {
    Write-Host "FAILED:"
    $failed | Format-Table -AutoSize
    exit 1
}

Write-Host "ALL TESTS PASSED"
