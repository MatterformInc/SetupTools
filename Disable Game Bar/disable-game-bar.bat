@echo off
:: Disable Xbox Game Bar, Record what happened, and Game DVR via registry.
:: Run as Administrator to also set machine policy (AllowGameDVR).
setlocal

set "GAMEBAR=HKCU\Software\Microsoft\GameBar"
set "GAMEDVR=HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"
set "GAMECONFIG=HKCU\System\GameConfigStore"
set "POLICY=HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR"

echo Disabling Xbox Game Bar, Record what happened, and Game DVR...
echo.

:: Game Bar - AllowAutoGameMode = 0
reg add "%GAMEBAR%" /v AllowAutoGameMode /t REG_DWORD /d 0 /f >nul 2>&1

:: Game DVR (Record what happened) - AppCaptureEnabled = 0
reg add "%GAMEDVR%" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1

:: Game DVR - GameDVR_Enabled = 0
reg add "%GAMECONFIG%" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1

:: Machine policy (requires admin) - AllowGameDVR = 0
reg add "%POLICY%" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
if errorlevel 1 (
    echo Policy key skipped ^(run as Administrator to disable for all users^).
) else (
    echo Policy key set.
)

echo.
echo Done. Xbox Game Bar, Record what happened, and Game DVR are disabled.
echo Sign out or restart for changes to take full effect.
if not defined SETUPTOOLS_GUI pause
