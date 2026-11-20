# Regression: run every testbench; exit non-zero if any of them fails.
#
# Usage (from the rv32i-cpu directory):
#   powershell -File sim/regress.ps1
#
# Why this exists:
#   Testbenches used to only $display("FAIL"), so vvp always exited 0 and
#   automation had no way to tell pass from fail. This script turns
#   "read the output" into "check the exit code".
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads
#   UTF-8-without-BOM as ANSI and garbles CJK comments, which breaks parsing.

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

$tbs = Get-ChildItem "tb/*_tb.sv" | Sort-Object Name
$rtl = Get-ChildItem "rtl/*.sv" | ForEach-Object { $_.FullName }

$failCount = 0

Write-Host ""
Write-Host ("{0,-22} {1,6} {2,6}  {3}" -f "TESTBENCH", "PASS", "FAIL", "RESULT")
Write-Host ("{0,-22} {1,6} {2,6}  {3}" -f ("-" * 22), ("-" * 6), ("-" * 6), ("-" * 8))

foreach ($tb in $tbs) {
    $name = $tb.BaseName
    $out  = "sim/$name.vvp"

    $null = & iverilog -g2012 -o $out @rtl $tb.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("{0,-22} {1,6} {2,6}  {3}" -f $name, "-", "-", "COMPILE FAIL")
        $failCount++
        continue
    }

    $res     = (& vvp $out 2>&1 | Out-String)
    $vvpCode = $LASTEXITCODE            # $fatal makes vvp return non-zero

    $p = ([regex]::Matches($res, "PASS")).Count
    $f = ([regex]::Matches($res, "FAIL")).Count

    # Exit code is the hard signal; text counts are just for humans.
    if ($vvpCode -ne 0 -or $f -gt 0) {
        $verdict = "FAIL"
        $failCount++
    } elseif ($res -match "EQUIVALENT") {
        $verdict = "EQUIVALENT"         # forward_unit_cmp_tb reports this word
    } else {
        $verdict = "ok"
    }

    Write-Host ("{0,-22} {1,6} {2,6}  {3}" -f $name, $p, $f, $verdict)
}

Write-Host ("{0,-22} {1,6} {2,6}  {3}" -f ("-" * 22), ("-" * 6), ("-" * 6), ("-" * 8))
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "==> FAILED: $failCount testbench(es)" -ForegroundColor Red
    $code = 1
} else {
    Write-Host "==> ALL PASS" -ForegroundColor Green
    $code = 0
}

Pop-Location
exit $code
