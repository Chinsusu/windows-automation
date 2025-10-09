# Install-AutomationServer.ps1
# Automation Server Installer with Firewall Configuration

#Requires -RunAsAdministrator

param(
    [string]$InstallPath = "C:\Program Files\AutomationServer",
    [int]$Port = 8080
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Automation Server Installer v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create installation directory
Write-Host "[1/6] Creating installation directory..." -ForegroundColor Yellow
if (!(Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Host "  + Created: $InstallPath" -ForegroundColor Green
} else {
    Write-Host "  + Directory exists: $InstallPath" -ForegroundColor Green
}

# Create subdirectories
$subdirs = @("db", "logs", "manifests")
foreach ($dir in $subdirs) {
    $path = Join-Path $InstallPath $dir
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

# Step 2: Copy executable
Write-Host "[2/6] Installing AutomationServer.exe..." -ForegroundColor Yellow
$sourceExe = Join-Path $PSScriptRoot "AutomationServer.exe"
$destExe = Join-Path $InstallPath "AutomationServer.exe"

if (Test-Path $sourceExe) {
    Copy-Item $sourceExe $destExe -Force
    Write-Host "  + Installed: AutomationServer.exe" -ForegroundColor Green
} else {
    Write-Host "  - ERROR: AutomationServer.exe not found!" -ForegroundColor Red
    exit 1
}

# Step 3: Configure Firewall
Write-Host "[3/6] Configuring Windows Firewall..." -ForegroundColor Yellow

$ruleName = "AutomationServer-HTTP"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Remove-NetFirewallRule -DisplayName $ruleName
}

try {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Any -Program $destExe -Description "Allow HTTP traffic for Automation Server on port $Port" | Out-Null
    Write-Host "  + Firewall rule created" -ForegroundColor Green
    Write-Host "    Port: $Port (TCP)" -ForegroundColor Gray
} catch {
    Write-Host "  - Failed to create firewall rule" -ForegroundColor Red
}

# Step 4: Create scripts
Write-Host "[4/6] Creating startup scripts..." -ForegroundColor Yellow

$startBat = "@echo off`r`ncd /d `"$InstallPath`"`r`nstart `"`" `"$destExe`"`r`necho Server started!`r`ntimeout /t 3"
$startBat | Out-File -FilePath (Join-Path $InstallPath "Start-Server.bat") -Encoding ASCII -Force

$stopBat = "@echo off`r`ntaskkill /F /IM AutomationServer.exe /T`r`necho Server stopped!`r`ntimeout /t 3"
$stopBat | Out-File -FilePath (Join-Path $InstallPath "Stop-Server.bat") -Encoding ASCII -Force

Write-Host "  + Created batch scripts" -ForegroundColor Green

# Step 5: Create shortcuts
Write-Host "[5/6] Creating desktop shortcuts..." -ForegroundColor Yellow

$WshShell = New-Object -ComObject WScript.Shell
$startShortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Start Automation Server.lnk")
$startShortcut.TargetPath = Join-Path $InstallPath "Start-Server.bat"
$startShortcut.WorkingDirectory = $InstallPath
$startShortcut.Save()

$stopShortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Stop Automation Server.lnk")
$stopShortcut.TargetPath = Join-Path $InstallPath "Stop-Server.bat"
$stopShortcut.WorkingDirectory = $InstallPath
$stopShortcut.Save()

Write-Host "  + Created desktop shortcuts" -ForegroundColor Green

# Step 6: Create uninstaller
Write-Host "[6/6] Creating uninstaller..." -ForegroundColor Yellow

$uninstallContent = "#Requires -RunAsAdministrator`r`n`r`nWrite-Host 'Uninstalling...' -ForegroundColor Yellow`r`nStop-Process -Name AutomationServer -Force -ErrorAction SilentlyContinue`r`nRemove-NetFirewallRule -DisplayName AutomationServer-HTTP -ErrorAction SilentlyContinue`r`nRemove-Item `"`$env:USERPROFILE\Desktop\Start Automation Server.lnk`" -Force -ErrorAction SilentlyContinue`r`nRemove-Item `"`$env:USERPROFILE\Desktop\Stop Automation Server.lnk`" -Force -ErrorAction SilentlyContinue`r`nWrite-Host 'Done!' -ForegroundColor Green`r`npause"
$uninstallContent | Out-File -FilePath (Join-Path $InstallPath "Uninstall.ps1") -Encoding UTF8 -Force

Write-Host "  + Created uninstaller" -ForegroundColor Green

# Installation complete
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Install Location: $InstallPath" -ForegroundColor White
Write-Host "Server Port: $Port" -ForegroundColor White
Write-Host "Firewall: Configured" -ForegroundColor White
Write-Host ""
Write-Host "To start: Double-click 'Start Automation Server' on desktop" -ForegroundColor Yellow
Write-Host "To stop: Double-click 'Stop Automation Server' on desktop" -ForegroundColor Yellow
Write-Host ""

$startNow = Read-Host "Start server now? (y/n)"
if ($startNow -eq 'y') {
    Write-Host "Starting server..." -ForegroundColor Cyan
    Start-Process $destExe -WorkingDirectory $InstallPath
    Start-Sleep -Seconds 2
    Write-Host "Server started!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
