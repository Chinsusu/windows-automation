# StatusAgent - Windows Client Status Reporter

## Overview
StatusAgent is a lightweight client agent that reports system status and network information to the Automation Server.

## Features
- Reports local IP address
- Detects and reports public IP address
- Sends status (online/offline) based on internet connectivity
- Can run once or in service mode (every 10 minutes)

## Usage

### Run Once (Single Report)
```cmd
StatusAgent.exe
```

### Run as Service (Continuous Mode)
```cmd
StatusAgent.exe /service
```

In service mode, the agent will send status reports every 10 minutes.

### Run via Scheduled Task (every 10 minutes)
Recommended for reliability: run once and exit, repeat every 10 minutes.

```powershell
# Run as Administrator
cd client_agent
./Schedule_StatusAgent_Every10Min.ps1 -ExePath "C:\ProgramData\StatusAgent\StatusAgent.exe" -RepeatMinutes 10

# Start immediately (optional)
Start-ScheduledTask -TaskName 'StatusAgent_10min'
```

This avoids a long-running process; each run sends status once and exits.

## Server Configuration
- **Server URL**: `http://192.168.2.101:8080/status`
- Change this in source code if needed (`$SERVER_URL` constant)

## Data Sent to Server
```json
{
  "client_id": "client_XXXXXXXX",
  "local_ip": "192.168.1.100",
  "public_ip": "203.xxx.xxx.xxx",
  "status": "online",
  "computer": "PC-NAME",
  "timestamp": "2025-10-09 05:45:00"
}
```

## Log File
- Location: `%TEMP%\StatusAgent.log`
- Check this file for debugging

## Requirements
- Windows 7+ (x86/x64)
- Administrator rights
- Internet connection (for public IP detection)
- `curl` command available (built-in on Windows 10+)

## Installation
1. Copy `StatusAgent.exe` to client machine
2. Run with Administrator rights
3. For service mode, use Task Scheduler to run at startup with `/service` parameter

## Creating Windows Service
Use Task Scheduler:
1. Open Task Scheduler
2. Create Task
3. General tab: "Run with highest privileges"
4. Triggers: At startup
5. Actions: Start program → `StatusAgent.exe /service`
6. Conditions: Uncheck "Start only if on AC power"

## Public IP Detection
The agent tries multiple services in order:
1. https://api.ipify.org
2. http://icanhazip.com
3. http://ifconfig.me/ip

If all fail, public IP is reported as "N/A" and status as "offline".

## Version
- Version: 1.0
- Built: 2025-10-09
- Compatible: Windows 7+ (x86/x64)
