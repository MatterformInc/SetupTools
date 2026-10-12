@echo off
:: Reduce interruptions: no sleep/display-off on AC, disable tips & suggestions.
:: Run as Administrator for full effect (power settings apply to all users).
setlocal

echo Reducing interruptions for activations / long runs...
echo.

:: --- Power: never sleep, never turn off display when plugged in ---
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change disk-timeout-ac 0

:: --- Disable tips, suggestions, welcome experience (current user) ---
set "CDM=HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
reg add "%CDM%" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "%CDM%" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "%CDM%" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "%CDM%" /v SoftLandingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "%CDM%" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1

:: --- Disable "Show me the Windows welcome experience" ---
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1

echo.
echo Done. Display and sleep set to Never on AC; tips/suggestions disabled.
echo Sign out or restart for some changes to apply.
if not defined SETUPTOOLS_GUI pause
