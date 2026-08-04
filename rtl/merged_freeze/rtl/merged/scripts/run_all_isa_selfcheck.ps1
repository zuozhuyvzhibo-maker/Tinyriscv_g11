param(
    [string]$PythonExe = "",
    [string]$IverilogExe = "",
    [string]$VvpExe = "",
    [switch]$SkipGenerate
)

$ErrorActionPreference = "Stop"

$mergedRoot = Split-Path -Parent $PSScriptRoot
$rtlRoot = Split-Path -Parent $mergedRoot
$repoRoot = Split-Path -Parent $rtlRoot
$generator = Join-Path $PSScriptRoot "generate_all_isa_selfcheck.py"
$image = Join-Path $repoRoot "rtl\lhr\tests\programs\all_isa_selfcheck.data"
$manifest = Join-Path $mergedRoot "verification\all_isa_selfcheck_manifest.json"

function Resolve-Tool {
    param(
        [string]$Requested,
        [string]$CommandName,
        [string]$Fallback
    )
    if ($Requested) {
        if (-not (Test-Path -LiteralPath $Requested -PathType Leaf)) {
            throw "$CommandName executable not found: $Requested"
        }
        return (Resolve-Path -LiteralPath $Requested).Path
    }
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    if ($Fallback -and (Test-Path -LiteralPath $Fallback -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $Fallback).Path
    }
    throw "$CommandName executable was not found; pass -${CommandName}Exe explicitly"
}

function Resolve-Python {
    param([string]$Requested)
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Requested) {
        $candidates.Add($Requested)
    } else {
        if ($env:USERPROFILE) {
            $candidates.Add((Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"))
        }
        foreach ($name in @("python3", "python")) {
            $command = Get-Command $name -ErrorAction SilentlyContinue
            if ($command) {
                $candidates.Add($command.Source)
            }
        }
    }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        $version = & $candidate --version 2>&1
        if (($LASTEXITCODE -eq 0) -and (("$version") -match "Python 3\.")) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Python 3 was not found; pass -PythonExe or use -SkipGenerate with the checked image"
}

$stagedBefore = @(& git -C $repoRoot diff --cached --name-only | Where-Object { $_ })
if ($LASTEXITCODE -ne 0) {
    throw "git staged-state check failed"
}
if ($stagedBefore.Count -ne 0) {
    throw "staged area is not empty; refusing to cross the staging=0 boundary"
}

if (-not $SkipGenerate) {
    $python = Resolve-Python -Requested $PythonExe
    & $python $generator --output $image --manifest $manifest
    if ($LASTEXITCODE -ne 0) {
        throw "image generation failed"
    }
}

if (-not (Test-Path -LiteralPath $image -PathType Leaf)) {
    throw "image not found: $image"
}
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "manifest not found: $manifest"
}

$iverilog = Resolve-Tool -Requested $IverilogExe -CommandName "iverilog" -Fallback "C:\iverilog\bin\iverilog.exe"
$vvp = Resolve-Tool -Requested $VvpExe -CommandName "vvp" -Fallback "C:\iverilog\bin\vvp.exe"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$evidenceDir = Join-Path $mergedRoot "verification\all_isa_selfcheck_$stamp"
New-Item -ItemType Directory -Path $evidenceDir | Out-Null
$temporarySim = Join-Path ([System.IO.Path]::GetTempPath()) ("merged_all_isa_" + [guid]::NewGuid().ToString("N") + ".vvp")

try {
    Push-Location $mergedRoot
    try {
        & $iverilog -g2012 -s merged_all_isa_selfcheck_tb -o $temporarySim `
            -f filelist_fpga.f tb/merged_extensions_tb.v `
            tb/merged_all_isa_selfcheck_tb.v
        if ($LASTEXITCODE -ne 0) {
            throw "Icarus compilation failed"
        }
    } finally {
        Pop-Location
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($core in 0..3) {
        Push-Location $mergedRoot
        try {
            $lines = @(& $vvp $temporarySim "+CORE=$core" "+MEM=$image" "+LM75_WORD=1900" 2>&1)
        } finally {
            Pop-Location
        }
        $text = $lines -join [Environment]::NewLine
        $logPath = Join-Path $evidenceDir ("core_{0}.log" -f $core)
        $text | Set-Content -LiteralPath $logPath -Encoding UTF8

        $status = if ($text -match "TEST_PASS kind=ALL_ISA") { "PASS" } else { "FAIL" }
        $failureCode = if ($text -match "failure_code=(\d+)") { [int]$Matches[1] } else { 0 }
        $uartBytes = if ($text -match "uart_bytes=(\d+)") { [int]$Matches[1] } else { -1 }
        $rows.Add([pscustomobject]@{
            core_id = $core
            core_name = @("LHR", "LDK", "SY", "WJE")[$core]
            status = $status
            failure_code = $failureCode
            uart_bytes = $uartBytes
            log = Split-Path -Leaf $logPath
        })
        Write-Host ("CORE={0} NAME={1} STATUS={2} FAILURE_CODE={3} UART_BYTES={4}" -f `
            $core, @("LHR", "LDK", "SY", "WJE")[$core], $status, $failureCode, $uartBytes)
    }

    $resultsPath = Join-Path $evidenceDir "results.csv"
    $rows | Export-Csv -LiteralPath $resultsPath -NoTypeInformation -Encoding UTF8
    $manifestData = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json
    $passCount = @($rows | Where-Object status -eq "PASS").Count
    $failCount = @($rows | Where-Object status -eq "FAIL").Count
    $summaryPath = Join-Path $evidenceDir "summary.md"
    @(
        "# All-ISA single-image directed regression"
        ""
        "- Image: ``$image``"
        "- SHA-256: ``$($manifestData.sha256)``"
        "- Executable ROM use: $($manifestData.rom.used_words)/$($manifestData.rom.capacity_words) words"
        "- PASS: $passCount"
        "- FAIL: $failCount"
        "- Frozen 211-test regression was not invoked."
        "- Detailed failure-code mapping: ``$manifest``"
    ) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    $stagedAfter = @(& git -C $repoRoot diff --cached --name-only | Where-Object { $_ })
    if ($LASTEXITCODE -ne 0) {
        throw "final git staged-state check failed"
    }
    if ($stagedAfter.Count -ne 0) {
        throw "staged area changed during the run"
    }

    Write-Host "EVIDENCE=$evidenceDir"
    Write-Host "RESULTS=$resultsPath"
    Write-Host "SUMMARY=$summaryPath"
    if ($failCount -ne 0) {
        exit 1
    }
} finally {
    if (Test-Path -LiteralPath $temporarySim -PathType Leaf) {
        Remove-Item -LiteralPath $temporarySim -Force
    }
}
