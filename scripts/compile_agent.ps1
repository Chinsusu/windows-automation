Param([string]$Version = "0.3.0")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "agent\agent_main.au3"
$out = Join-Path $root ("dist\AutoAgent-{0}.exe" -f $Version)
$aut2exe = "C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2Exe.exe"

if (!(Test-Path $aut2exe)) {
  Write-Error "Aut2Exe not found at $aut2exe"
}

& $aut2exe /in $src /out $out /x64 /comp 4
Write-Host "Built $out"
