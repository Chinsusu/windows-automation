================================================================================
  AUTOMATION SERVER - Installation Package
  Version: 1.0
================================================================================

PACKAGE CONTENTS:
-----------------
  • AutomationServer.exe       - Main server executable
  • Install-AutomationServer.ps1 - Installer script
  • README.txt                  - This file

SYSTEM REQUIREMENTS:
--------------------
  • Windows 10/11 or Windows Server 2016+
  • Administrator privileges
  • PowerShell 5.1 or higher
  • .NET Framework 4.5+ (usually pre-installed)

INSTALLATION:
-------------
1. Extract all files to a temporary folder

2. Right-click on "Install-AutomationServer.ps1" and select
   "Run with PowerShell"
   
   OR
   
   Open PowerShell as Administrator and run:
   PS> .\Install-AutomationServer.ps1

3. The installer will:
   ✓ Copy files to C:\Program Files\AutomationServer
   ✓ Configure Windows Firewall (port 8080)
   ✓ Create desktop shortcuts
   ✓ Create start/stop scripts

4. When prompted, choose 'y' to start the server immediately

CUSTOM INSTALLATION:
--------------------
To install to a custom location or use a different port:

  PS> .\Install-AutomationServer.ps1 -InstallPath "D:\MyServer" -Port 9090

STARTING THE SERVER:
--------------------
  • Double-click the "Start Automation Server" shortcut on desktop
  • Or run: C:\Program Files\AutomationServer\Start-Server.bat

STOPPING THE SERVER:
--------------------
  • Double-click the "Stop Automation Server" shortcut on desktop
  • Or run: C:\Program Files\AutomationServer\Stop-Server.bat

ACCESSING THE SERVER:
---------------------
  • Local access: http://localhost:8080
  • Network access: http://YOUR_IP_ADDRESS:8080
  
  Note: The installer automatically configures Windows Firewall to allow
        incoming connections on port 8080.

FIREWALL CONFIGURATION:
-----------------------
The installer automatically creates a Windows Firewall rule:
  • Rule Name: AutomationServer-HTTP
  • Port: 8080 (TCP)
  • Direction: Inbound
  • Profiles: Domain, Private, Public
  • Action: Allow

To manually check the firewall rule:
  PS> Get-NetFirewallRule -DisplayName "AutomationServer-HTTP"

UNINSTALLATION:
---------------
1. Run: C:\Program Files\AutomationServer\Uninstall.ps1
   
2. Choose whether to keep or remove database files

3. The uninstaller will:
   ✓ Stop the server
   ✓ Remove firewall rules
   ✓ Delete desktop shortcuts
   ✓ Remove installation files (optional: keep database)

TROUBLESHOOTING:
----------------
Q: Installation fails with "Execution Policy" error
A: Run this command in PowerShell as Administrator:
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   Then run the installer again.

Q: Firewall rule not created
A: Ensure you're running PowerShell as Administrator.
   You can manually create the rule:
   New-NetFirewallRule -DisplayName "AutomationServer-HTTP" `
                       -Direction Inbound -Protocol TCP -LocalPort 8080 `
                       -Action Allow

Q: Server not accessible from other computers
A: Check:
   1. Windows Firewall is configured (see above)
   2. Server is running (check Task Manager)
   3. Your network firewall/router allows port 8080

Q: Server closes immediately after starting
A: Check logs at: C:\Program Files\AutomationServer\logs\

TECHNICAL SUPPORT:
------------------
For issues or questions, check the logs in:
  C:\Program Files\AutomationServer\logs\

Database location:
  C:\Program Files\AutomationServer\db\

Server configuration:
  - Default port: 8080
  - HTTP listener: 0.0.0.0 (all interfaces)
  - API Key: configurable via X_API_KEY environment variable

================================================================================
© 2025 Automation Server Project
================================================================================
