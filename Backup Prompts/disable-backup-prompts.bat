@echo off
:: Opt out of OneDrive folder backup and Windows Backup prompts by default.
::   OneDrive:       KFMBlockOptIn policy - OneDrive won't offer (or allow) moving Desktop/Documents/
::                   Pictures into OneDrive. OneDrive itself keeps working.
::   Windows Backup: "Do not sync" policy - no settings backup to the Microsoft account, no prompts for it.
::   Nags:           File Explorer sync-provider banners and Start menu recommendations off.
:: Undo with enable-backup-prompts.bat. Run as Administrator.
setlocal

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo Opting out of OneDrive folder backup and Windows Backup prompts...

:: --- OneDrive: block "Back up your folders" (Known Folder Move) ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v KFMBlockOptIn /t REG_DWORD /d 1 /f >nul

:: --- Windows Backup: do not sync / back up settings to the Microsoft account ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSync /t REG_DWORD /d 2 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSyncUserOverride /t REG_DWORD /d 1 /f >nul

:: --- Nags (current user) ---
set "ADV=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
:: File Explorer "sync provider" notifications (OneDrive backup banners)
reg add "%ADV%" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f >nul
:: Start menu "recommendations for tips, shortcuts, new apps and more" (where backup nudges appear)
reg add "%ADV%" /v Start_IrisRecommendations /t REG_DWORD /d 0 /f >nul

gpupdate /target:computer /force >nul 2>&1

echo.
echo Done. If OneDrive was already backing up your folders, turn that off once in
echo OneDrive ^> Settings ^> Sync and backup ^> Manage back up; this blocks it from coming back.
if not defined SETUPTOOLS_GUI pause
exit /b 0
