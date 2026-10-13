@echo off
:: Undo disable-backup-prompts.bat. Run as Administrator.
setlocal

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

reg delete "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v KFMBlockOptIn /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSync /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSyncUserOverride /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_IrisRecommendations /t REG_DWORD /d 1 /f >nul
gpupdate /target:computer /force >nul 2>&1

echo Backup prompts restored.
if not defined SETUPTOOLS_GUI pause
exit /b 0
