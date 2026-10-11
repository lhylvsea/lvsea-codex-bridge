[CmdletBinding()]
param(
    [string]$TaskName = "Codex-WeChat-Bridge",
    [string]$User = "",
    [string]$CodexPath = "",
    [string]$BunPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$bridgeScript = Join-Path $repoRoot "start-codex-bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) {
    throw "Bridge launcher not found: $bridgeScript"
}

if ([string]::IsNullOrWhiteSpace($User)) {
    $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

$shellCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $shellCommand) {
    $shellCommand = Get-Command powershell -ErrorAction Stop
}

$actionArguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $bridgeScript + '"'
if (-not [string]::IsNullOrWhiteSpace($CodexPath)) {
    $actionArguments += ' -CodexPath "' + $CodexPath + '"'
}
if (-not [string]::IsNullOrWhiteSpace($BunPath)) {
    $actionArguments += ' -BunPath "' + $BunPath + '"'
}

$action = New-ScheduledTaskAction -Execute $shellCommand.Source -Argument $actionArguments
$startupTrigger = New-ScheduledTaskTrigger -AtStartup
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $User
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 3650) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($startupTrigger, $logonTrigger) -Settings $settings -Principal $principal -Description "Keep the local WeChat to Codex bridge running." -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName
Write-Output "registered: $TaskName"
Write-Output "user: $User"
Write-Output "launcher: $bridgeScript"
