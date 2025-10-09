@echo off
title EarnApp Client - Recompile EXE
echo.
echo ===============================================
echo    EARNAPP CLIENT - RECOMPILE EXE
echo ===============================================
echo.

set "AUT2EXE=C:\Program Files (x86)\AutoIt3\Aut2Exe\Aut2exe.exe"

if not exist "%AUT2EXE%" (
    echo ERROR: AutoIt3 Aut2Exe not found!
    echo Please install AutoIt3 first.
    echo Download: https://www.autoitscript.com/site/autoit/downloads/
    pause
    exit /b 1
)

if not exist "Main.au3" (
    echo ERROR: Main.au3 not found in current directory!
    pause
    exit /b 1
)

echo Compiling Main.au3 to EarnApp_Installer.exe...

"%AUT2EXE%" /in "Main.au3" /out "EarnApp_Installer.exe" /comp 4 /x86

if exist "EarnApp_Installer.exe" (
    echo.
    echo + Compilation successful!
    
    for %%F in (EarnApp_Installer.exe) do (
        set size=%%~zF
        set /a sizeMB=!size! / 1048576
        echo + File size: !sizeMB! MB
    )
    
    echo.
    echo Ready to deploy EarnApp_Installer.exe
) else (
    echo.
    echo - Compilation failed!
    echo Check for errors above.
)

echo.
pause