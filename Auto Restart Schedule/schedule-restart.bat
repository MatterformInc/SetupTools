@echo off
:: Create a daily "Restart PC" scheduled task (shutdown /r /f) at a given time. Never expires.
:: Usage: schedule-restart.bat [HH:MM]   (prompts if no time is given)
:: Run as Administrator: the task runs as SYSTEM so it fires even when nobody is logged in.
setlocal
set "TASKNAME=Restart PC"

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo.
echo   Daily restart at a specific time - runs every day, never expires.
echo   (24-hour, e.g. 04:00)
echo.
if "%~1"=="" (set /p RESTART_TIME="Enter time (HH:MM): ") else (set "RESTART_TIME=%~1")

if "%RESTART_TIME%"=="" (
    echo No time entered. Exiting.
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

:: Validate and normalize to HH:MM (accepts 4:00 or 04:00)
set "ST="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "try { [DateTime]::ParseExact('%RESTART_TIME%'.Trim(), 'H:mm', $null).ToString('HH:mm') } catch { }"`) do set "ST=%%t"
if "%ST%"=="" (
    echo Invalid time "%RESTART_TIME%". Use 24-hour format, e.g. 04:00 or 22:30.
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo Creating daily task "%TASKNAME%" at %ST%...
schtasks /create /tn "%TASKNAME%" /tr "shutdown.exe /r /f /t 0" /sc daily /st %ST% /ru SYSTEM /rl HIGHEST /f
if errorlevel 1 (
    echo Task creation failed.
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo.
echo Done. PC will restart daily at %ST% (no expiration). To remove: run cancel-restart.bat
if not defined SETUPTOOLS_GUI pause
exit /b 0
