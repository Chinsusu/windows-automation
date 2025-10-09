# Install StatusAgent as Scheduled Task
# Run this script as Administrator

$exePath = "C:\Users\Admin\Documents\automation\client_agent\StatusAgent.exe"

Write-Host "Installing StatusAgent as scheduled task..." -ForegroundColor Green

# Create scheduled task
$action = New-ScheduledTaskAction -Execute $exePath -Argument "/service"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "StatusAgent_Service" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Status Agent - Reports to automation server every 10 minutes" -Force

Write-Host "✓ Task 'StatusAgent_Service' installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "The agent will run:" -ForegroundColor Yellow
Write-Host "  - At Windows startup" -ForegroundColor Yellow
Write-Host "  - Every 10 minutes continuously" -ForegroundColor Yellow
Write-Host ""
Write-Host "To start now, run: Start-ScheduledTask -TaskName 'StatusAgent_Service'" -ForegroundColor Cyan
Write-Host "To stop: Stop-ScheduledTask -TaskName 'StatusAgent_Service'" -ForegroundColor Cyan
Write-Host "To remove: Unregister-ScheduledTask -TaskName 'StatusAgent_Service' -Confirm:`$false" -ForegroundColor Cyan
