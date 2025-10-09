@echo off
title EarnApp Client - Configure Server URL
echo.
echo ===============================================
echo    EARNAPP CLIENT - SERVER CONFIGURATION
echo ===============================================
echo.

REM Get current server URL from Main.au3
for /f "tokens=*" %%i in ('findstr /C:"SERVER_URL" Main.au3 2^>nul') do (
    echo Current setting: %%i
)

echo.
echo Example: http://192.168.1.100:8080/cb
set /p "NEW_URL=Enter new server URL: "

if "%NEW_URL%"=="" (
    echo No URL entered, keeping current settings.
    pause
    exit /b
)

echo.
echo Updating server URL to: %NEW_URL%

REM Backup original file
copy Main.au3 Main.au3.backup >nul 2>&1

REM Replace the SERVER_URL line
powershell -NoProfile -Command "(Get-Content 'Main.au3') -replace 'Global Const \$SERVER_URL = \".*\"', 'Global Const `$SERVER_URL = \"%NEW_URL%\"' | Set-Content 'Main.au3.tmp'"

if exist Main.au3.tmp (
    move Main.au3.tmp Main.au3 >nul
    echo + Server URL updated successfully!
    echo.
    echo You need to recompile the EXE for changes to take effect.
    echo Run: Recompile-Client.bat
) else (
    echo - Failed to update server URL
)

echo.
pause