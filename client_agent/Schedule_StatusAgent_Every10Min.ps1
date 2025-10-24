Param(
  [Parameter(Mandatory=$true)][string]$ExePath,
  [string]$TaskName = 'StatusAgent_10min',
  [int]$RepeatMinutes = 10,
  [int]$StartDelayMinutes = 1
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path $ExePath)) {
  Write-Error "StatusAgent executable not found: $ExePath"
}

Write-Host "Configuring scheduled task '$TaskName' to run every $RepeatMinutes minutes..." -ForegroundColor Cyan

$action = New-ScheduledTaskAction -Execute $ExePath

# Start shortly after registration, then repeat indefinitely
$now = Get-Date
$first = $now.AddMinutes([math]::Max(0,$StartDelayMinutes))
$trigger = New-ScheduledTaskTrigger -Once -At $first -RepetitionInterval (New-TimeSpan -Minutes $RepeatMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

try {
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }
} catch {}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Run StatusAgent once every $RepeatMinutes minutes (exit after report)" | Out-Null

Write-Host "Task '$TaskName' installed successfully." -ForegroundColor Green
Write-Host "Start now:  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
Write-Host "Stop:       Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
Write-Host "Remove:     Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:\$false" -ForegroundColor Yellow

