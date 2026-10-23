param(
    [string]$Top,
    [string]$Sources,
    [string]$Out = "sim/out.vvp"
)

$ErrorActionPreference = "Stop"
if (-not $Top -or -not $Sources) {
    Write-Host "usage: run.ps1 -Top <tb.sv> -Sources <rtl.sv[,rtl2.sv]> [-Out name.vvp]" -ForegroundColor Yellow
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    Write-Host "==> iverilog -g2012 $Sources $Top" -ForegroundColor Cyan
    iverilog -g2012 -Wall -o $Out $Sources $Top
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed" }

    Write-Host "==> vvp $Out" -ForegroundColor Cyan
    vvp $Out
    if ($LASTEXITCODE -ne 0) { throw "vvp failed" }
}
finally {
    Pop-Location
}
