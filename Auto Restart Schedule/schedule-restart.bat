@echo off
setlocal
set "TASKNAME=Restart PC"
echo.
echo   Daily restart at a specific time — runs every day, never expires.
echo   (24-hour, e.g. 04:00)
echo.
if "%~1"=="" (set /p RESTART_TIME="Enter time (HH:MM): ") else (set "RESTART_TIME=%~1")

if "%RESTART_TIME%"=="" (
    echo No time entered. Exiting.
    pause
    exit /b 1
)

:: Normalize to HH:MM and create daily task
powershell -NoProfile -Command ^
  "$t = [DateTime]::ParseExact('%RESTART_TIME%'.Trim(), 'H:mm', [Globalization.CultureInfo]::InvariantCulture); " ^
  "$st = $t.ToString('HH:mm'); " ^
  "Write-Host (\"Creating daily task '%TASKNAME%' at \" + $st); " ^
  "& schtasks /create /tn \"%TASKNAME%\" /tr \"shutdown.exe /r /f\" /sc daily /st $st /d \"Restart at: $st\" /f"
if errorlevel 1 (
    echo Invalid time or task creation failed. Use 24-hour format, e.g. 04:00
    pause
    exit /b 1
)
echo.
echo Done. PC will restart daily at %RESTART_TIME% (no expiration). To remove: run cancel-restart.bat
pause
