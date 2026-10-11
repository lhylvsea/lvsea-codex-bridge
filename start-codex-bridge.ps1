[CmdletBinding()]
param(
    [string]$CodexPath = "",
    [string]$BunPath = "",
    [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

$bridgeDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -LiteralPath $bridgeDir

function Resolve-FirstFile {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

$bunCandidates = @($BunPath)
$bunCommand = Get-Command bun.cmd -ErrorAction SilentlyContinue
if (-not $bunCommand) {
    $bunCommand = Get-Command bun -ErrorAction SilentlyContinue
}
if ($bunCommand) {
    $bunCandidates += $bunCommand.Source
}
if ($env:APPDATA) {
    $bunCandidates += (Join-Path $env:APPDATA "npm\bun.cmd")
}
if ($env:USERPROFILE) {
    $bunCandidates += (Join-Path $env:USERPROFILE "scoop\shims\bun.exe")
}
$bunCandidates += "C:\Program Files\bun\bun.exe"
$bun = Resolve-FirstFile $bunCandidates
if (-not $bun) {
    throw "Bun was not found. Install Bun or pass -BunPath with the full path to bun.exe/bun.cmd."
}

$codexCandidates = @($CodexPath, $env:CODEX_PATH)
$codexCommand = Get-Command codex.exe -ErrorAction SilentlyContinue
if (-not $codexCommand) {
    $codexCommand = Get-Command codex -ErrorAction SilentlyContinue
}
if ($codexCommand) {
    $codexCandidates += $codexCommand.Source
}
if ($env:LOCALAPPDATA) {
    $codexCandidates += @(
        (Join-Path $env:LOCALAPPDATA "Programs\Codex\resources\codex.exe"),
        (Join-Path $env:LOCALAPPDATA "Codex\resources\codex.exe")
    )
}
if ($env:ProgramFiles) {
    $codexCandidates += (Join-Path $env:ProgramFiles "Codex\resources\codex.exe")
}
# This is the path used by the verified local Codex desktop installation.
$codexCandidates += "C:\Codex\app\resources\codex.exe"
$codex = Resolve-FirstFile $codexCandidates
if (-not $codex) {
    throw "Codex executable was not found. Pass -CodexPath with the full path to codex.exe."
}

$env:CODEX_PATH = $codex
$logDir = Join-Path $bridgeDir "runtime-logs"
$logPath = Join-Path $logDir "bridge.log"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$startArguments = @("run", "start", "--backend", "codex")
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $startArguments += @("--config", $ConfigPath)
}

"[$(Get-Date -Format s)] bridge starting; bun=$bun; codex=$codex" | Add-Content -LiteralPath $logPath -Encoding UTF8
& $bun @startArguments 2>&1 | Tee-Object -FilePath $logPath -Append
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) {
    $exitCode = 0
}
"[$(Get-Date -Format s)] bridge exited with code $exitCode" | Add-Content -LiteralPath $logPath -Encoding UTF8
exit $exitCode
