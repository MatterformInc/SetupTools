@echo off
:: Turn on "Set time zone automatically" (and keep the clock synced).
:: Windows needs Location services on to detect the time zone, so this enables them too.
:: Run as Administrator.
setlocal

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo Enabling automatic time zone...
echo.

:: --- Location services on (required for time zone detection) ---
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Allow /f >nul
sc config lfsvc start= demand >nul

:: --- Auto time zone updater service: 3 = enabled (manual trigger), 4 = disabled ---
reg add "HKLM\SYSTEM\CurrentControlSet\Services\tzautoupdate" /v Start /t REG_DWORD /d 3 /f >nul
sc start tzautoupdate >nul 2>&1

:: --- Set time automatically (sync with time.windows.com) ---
sc config w32time start= auto >nul
net start w32time >nul 2>&1
w32tm /resync >nul 2>&1

echo Done. Time zone will be detected from location; clock synced.
echo It can take a minute (or a restart) for the time zone to update.
if not defined SETUPTOOLS_GUI pause
