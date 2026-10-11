[CmdletBinding()]
param(
    [string]$TaskName = "Codex-WeChat-Bridge"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$taskInfo = $null
if ($task) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
}

$bridgeProcesses = @(
    Get-CimInstance Win32_Process -Filter "Name = 'bun.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and
            $_.CommandLine -like "*start.js start*" -and
            $_.CommandLine -like "*--backend codex*"
        }
)

function Get-FileStatus {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return "missing"
    }
    $item = Get-Item -LiteralPath $Path
    return "$($item.LastWriteTime.ToString('s')); $($item.Length) bytes"
}

$logPath = Join-Path $repoRoot "runtime-logs\bridge.log"
$stateDir = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE ".wechat-ai-bridge" } else { Join-Path $HOME ".wechat-ai-bridge" }
$cursorPath = Join-Path $stateDir "sync-buf.json"

[pscustomobject]@{
    TaskName = $TaskName
    TaskState = if ($task) { [string]$task.State } else { "NotFound" }
    RunAs = if ($task) { $task.Principal.UserId } else { "" }
    LastRunTime = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
    LastTaskResult = if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
    BridgeProcessCount = $bridgeProcesses.Count
    BridgeLog = Get-FileStatus $logPath
    SyncCursor = Get-FileStatus $cursorPath
} | Format-List
