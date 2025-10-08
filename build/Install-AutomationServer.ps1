# Install-AutomationServer.ps1
# Automation Server Installer với Firewall Configuration
# Requires: Administrator privileges

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
    Write-Host "  ✓ Created: $InstallPath" -ForegroundColor Green
} else {
    Write-Host "  ✓ Directory exists: $InstallPath" -ForegroundColor Green
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
    Write-Host "  ✓ Installed: AutomationServer.exe" -ForegroundColor Green
} else {
    Write-Host "  ✗ ERROR: AutomationServer.exe not found in installer directory!" -ForegroundColor Red
    exit 1
}

# Step 3: Configure Firewall Rules
Write-Host "[3/6] Configuring Windows Firewall..." -ForegroundColor Yellow

# Remove existing rules first
$ruleName = "AutomationServer-HTTP"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Remove-NetFirewallRule -DisplayName $ruleName
    Write-Host "  ✓ Removed old firewall rule" -ForegroundColor Gray
}

# Add new inbound rule for HTTP server
try {
    New-NetFirewallRule -DisplayName $ruleName `
                        -Direction Inbound `
                        -Protocol TCP `
                        -LocalPort $Port `
                        -Action Allow `
                        -Profile Any `
                        -Program $destExe `
                        -Description "Allow inbound HTTP traffic for Automation Server on port $Port" | Out-Null
    
    Write-Host "  ✓ Firewall rule created successfully" -ForegroundColor Green
    Write-Host "    - Rule Name: $ruleName" -ForegroundColor Gray
    Write-Host "    - Port: $Port (TCP)" -ForegroundColor Gray
    Write-Host "    - Direction: Inbound" -ForegroundColor Gray
    Write-Host "    - Profile: Any (Domain, Private, Public)" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Failed to create firewall rule: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 4: Create startup script
Write-Host "[4/6] Creating startup scripts..." -ForegroundColor Yellow

$startScript = @"
@echo off
REM AutomationServer Startup Script
cd /d "$InstallPath"
start "" "$destExe"
echo Automation Server started!
timeout /t 3
"@

$startScriptPath = Join-Path $InstallPath "Start-Server.bat"
$startScript | Out-File -FilePath $startScriptPath -Encoding ASCII -Force
Write-Host "  ✓ Created: Start-Server.bat" -ForegroundColor Green

# Stop script
$stopScript = @"
@echo off
REM AutomationServer Stop Script
taskkill /F /IM AutomationServer.exe /T
echo Automation Server stopped!
timeout /t 3
"@

$stopScriptPath = Join-Path $InstallPath "Stop-Server.bat"
$stopScript | Out-File -FilePath $stopScriptPath -Encoding ASCII -Force
Write-Host "  ✓ Created: Stop-Server.bat" -ForegroundColor Green

# Step 5: Create desktop shortcuts
Write-Host "[5/6] Creating desktop shortcuts..." -ForegroundColor Yellow

$WshShell = New-Object -ComObject WScript.Shell

# Start shortcut
$startShortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Start Automation Server.lnk")
$startShortcut.TargetPath = $startScriptPath
$startShortcut.WorkingDirectory = $InstallPath
$startShortcut.IconLocation = $destExe
$startShortcut.Description = "Start Automation Server"
$startShortcut.Save()
Write-Host "  ✓ Created: Start Automation Server (Desktop)" -ForegroundColor Green

# Stop shortcut
$stopShortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Stop Automation Server.lnk")
$stopShortcut.TargetPath = $stopScriptPath
$stopShortcut.WorkingDirectory = $InstallPath
$stopShortcut.Description = "Stop Automation Server"
$stopShortcut.Save()
Write-Host "  ✓ Created: Stop Automation Server (Desktop)" -ForegroundColor Green

# Step 6: Create uninstaller
Write-Host "[6/6] Creating uninstaller..." -ForegroundColor Yellow

$uninstallScript = @"
# Uninstall-AutomationServer.ps1
#Requires -RunAsAdministrator

Write-Host "Uninstalling Automation Server..." -ForegroundColor Yellow

# Stop server
Stop-Process -Name "AutomationServer" -Force -ErrorAction SilentlyContinue

# Remove firewall rule
Remove-NetFirewallRule -DisplayName "AutomationServer-HTTP" -ErrorAction SilentlyContinue
Write-Host "  ✓ Removed firewall rule" -ForegroundColor Green

# Remove desktop shortcuts
Remove-Item "$env:USERPROFILE\Desktop\Start Automation Server.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\Stop Automation Server.lnk" -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Removed desktop shortcuts" -ForegroundColor Green

# Remove installation directory
`$remove = Read-Host "Remove all data including database? (y/n)"
if (`$remove -eq 'y') {
    Remove-Item "$InstallPath" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Removed installation directory" -ForegroundColor Green
}

Write-Host "`nUninstall complete!" -ForegroundColor Green
pause
"@

$uninstallScriptPath = Join-Path $InstallPath "Uninstall.ps1"
$uninstallScript | Out-File -FilePath $uninstallScriptPath -Encoding UTF8 -Force
Write-Host "  ✓ Created: Uninstall.ps1" -ForegroundColor Green

# Installation complete
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installation Details:" -ForegroundColor Cyan
Write-Host "  Location: $InstallPath" -ForegroundColor White
Write-Host "  Port: $Port" -ForegroundColor White
Write-Host "  Firewall: Configured ✓" -ForegroundColor White
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Yellow
Write-Host "  • Use desktop shortcut: 'Start Automation Server'" -ForegroundColor White
Write-Host "  • Or run: $startScriptPath" -ForegroundColor Gray
Write-Host "  • Access: http://localhost:$Port" -ForegroundColor Gray
Write-Host ""
Write-Host "To uninstall:" -ForegroundColor Yellow
Write-Host "  Run: $uninstallScriptPath" -ForegroundColor Gray
Write-Host ""

# Ask to start server now
$startNow = Read-Host "Start Automation Server now? (y/n)"
if ($startNow -eq 'y') {
    Write-Host "`nStarting server..." -ForegroundColor Cyan
    Start-Process $destExe -WorkingDirectory $InstallPath
    Start-Sleep -Seconds 2
    Write-Host "✓ Server started!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
