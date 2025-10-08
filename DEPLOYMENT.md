# 🚀 Automation Server - Deployment Guide

## 📦 Installation Package

**Package:** `AutomationServer-v1.0-Setup.zip` (850 KB)

### Package Contents
- ✅ `AutomationServer.exe` - Server executable (1.29 MB)
- ✅ `Install-AutomationServer.ps1` - Automated installer
- ✅ `README.txt` - Complete documentation

## 🔧 Quick Installation (5 minutes)

### Step 1: Extract Package
```powershell
# Extract ZIP file to any temporary folder
Expand-Archive -Path "AutomationServer-v1.0-Setup.zip" -DestinationPath "C:\Temp\AutomationServer"
```

### Step 2: Run Installer
```powershell
# Right-click PowerShell and select "Run as Administrator"
cd C:\Temp\AutomationServer
.\Install-AutomationServer.ps1
```

### Step 3: Done! ✅
The installer will automatically:
- ✅ Install to `C:\Program Files\AutomationServer`
- ✅ Configure Windows Firewall (port 8080)
- ✅ Create desktop shortcuts
- ✅ Set up start/stop scripts

## 🔥 Firewall Configuration

The installer automatically creates this firewall rule:

```powershell
Rule Name:   AutomationServer-HTTP
Port:        8080 (TCP)
Direction:   Inbound
Action:      Allow
Profiles:    Domain, Private, Public
Program:     C:\Program Files\AutomationServer\AutomationServer.exe
```

### Manual Firewall Setup (if needed)
```powershell
New-NetFirewallRule -DisplayName "AutomationServer-HTTP" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort 8080 `
                    -Action Allow `
                    -Profile Any
```

### Verify Firewall Rule
```powershell
Get-NetFirewallRule -DisplayName "AutomationServer-HTTP" | Format-List *
```

## 📍 Custom Installation

### Install to Custom Location
```powershell
.\Install-AutomationServer.ps1 -InstallPath "D:\MyServer"
```

### Use Custom Port
```powershell
.\Install-AutomationServer.ps1 -Port 9090
```

### Both Custom Location and Port
```powershell
.\Install-AutomationServer.ps1 -InstallPath "D:\MyServer" -Port 9090
```

## 🎮 Usage

### Starting the Server
**Option 1:** Double-click desktop shortcut "Start Automation Server"

**Option 2:** Run batch file
```cmd
C:\Program Files\AutomationServer\Start-Server.bat
```

**Option 3:** Run executable directly
```cmd
cd "C:\Program Files\AutomationServer"
AutomationServer.exe
```

### Stopping the Server
**Option 1:** Double-click desktop shortcut "Stop Automation Server"

**Option 2:** Run batch file
```cmd
C:\Program Files\AutomationServer\Stop-Server.bat
```

**Option 3:** Kill process
```powershell
Stop-Process -Name "AutomationServer" -Force
```

## 🌐 Accessing the Server

### Local Access
```
http://localhost:8080/health
```

### Network Access
```
http://YOUR_SERVER_IP:8080/health
```

### Test Endpoints
```powershell
# Health check
Invoke-WebRequest -Uri "http://localhost:8080/health"

# Test callback (with API key)
$body = @{
    client_id = "TEST"
    status = "SUCCESS"
    message = "Test message"
    ip = "192.168.1.100"
    computer = "TEST-PC"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8080/cb" `
                  -Method POST `
                  -Body $body `
                  -ContentType "application/json" `
                  -Headers @{"X-Api-Key"="test-key"}
```

## 🔍 Verification

### Check if Server is Running
```powershell
Get-Process -Name "AutomationServer" -ErrorAction SilentlyContinue
```

### Check Listening Ports
```powershell
Get-NetTCPConnection -LocalPort 8080 -State Listen
```

### View Logs
```powershell
Get-Content "C:\Program Files\AutomationServer\logs\listener.log" -Tail 20
```

### View Database
```powershell
Get-Content "C:\Program Files\AutomationServer\db\clients.json"
```

## 🗑️ Uninstallation

### Run Uninstaller
```powershell
# As Administrator
cd "C:\Program Files\AutomationServer"
.\Uninstall.ps1
```

The uninstaller will:
- ✅ Stop the server process
- ✅ Remove firewall rules
- ✅ Delete desktop shortcuts
- ✅ Ask if you want to keep database files
- ✅ Remove program files

## 🐛 Troubleshooting

### Issue: "Execution Policy" Error
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\Install-AutomationServer.ps1
```

### Issue: Port 8080 Already in Use
**Check what's using the port:**
```powershell
Get-NetTCPConnection -LocalPort 8080 | Select-Object OwningProcess
Get-Process -Id <PROCESS_ID>
```

**Install on different port:**
```powershell
.\Install-AutomationServer.ps1 -Port 9090
```

### Issue: Firewall Blocking Connections
**Check firewall rule:**
```powershell
Get-NetFirewallRule -DisplayName "AutomationServer-HTTP"
```

**Re-create firewall rule:**
```powershell
Remove-NetFirewallRule -DisplayName "AutomationServer-HTTP"
New-NetFirewallRule -DisplayName "AutomationServer-HTTP" `
                    -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

### Issue: Server Not Accessible from Network
1. Check Windows Firewall (see above)
2. Check server is listening on all interfaces:
   ```powershell
   Get-NetTCPConnection -LocalPort 8080
   ```
3. Check router/network firewall settings
4. Verify server IP address:
   ```powershell
   Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4'}
   ```

## 📊 Monitoring

### CPU and Memory Usage
```powershell
Get-Process -Name "AutomationServer" | 
    Select-Object ProcessName, CPU, WorkingSet, StartTime
```

### Real-time Log Monitoring
```powershell
Get-Content "C:\Program Files\AutomationServer\logs\listener.log" -Wait
```

### Database Statistics
```powershell
$db = Get-Content "C:\Program Files\AutomationServer\db\clients.json" | ConvertFrom-Json
Write-Host "Total Clients: $($db.Count)"
$db | Select-Object client_id, ip_local, status, last_seen | Format-Table
```

## 🔐 Security Notes

1. **API Key:** Configure via environment variable `X_API_KEY`
   ```powershell
   [Environment]::SetEnvironmentVariable("X_API_KEY", "your-secret-key", "Machine")
   ```

2. **Firewall:** Ensure only necessary ports are open

3. **Updates:** Keep Windows and server software updated

4. **Backup:** Regularly backup the `db` folder

## 📝 Directory Structure

```
C:\Program Files\AutomationServer\
├── AutomationServer.exe    # Main executable
├── Start-Server.bat        # Start script
├── Stop-Server.bat         # Stop script
├── Uninstall.ps1          # Uninstaller
├── db\                    # Database files
│   ├── clients.json       # Client data
│   └── tasks.json         # Task queue
├── logs\                  # Log files
│   └── listener.log       # Server logs
└── manifests\             # Version manifests
```

## 🚀 Deployment on Multiple Machines

### Network Deployment
1. Share the ZIP package on network drive
2. Create deployment script:
   ```powershell
   $machines = @("PC1", "PC2", "PC3")
   foreach ($machine in $machines) {
       Invoke-Command -ComputerName $machine -ScriptBlock {
           # Copy and install
       }
   }
   ```

### Silent Installation
```powershell
# Non-interactive install
.\Install-AutomationServer.ps1 -Port 8080
# Auto-start without prompt (modify script as needed)
```

---

## 📞 Support

- **Logs:** `C:\Program Files\AutomationServer\logs\`
- **Database:** `C:\Program Files\AutomationServer\db\`
- **GitHub:** https://github.com/yourusername/automation

---

**Version:** 1.0  
**Last Updated:** 2025-10-09
