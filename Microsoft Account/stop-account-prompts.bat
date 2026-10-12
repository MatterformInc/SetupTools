@echo off
:: Stop Windows nagging to sign in with / finish setting up a Microsoft account (current user).
:: Covers the "Let's finish setting up your device" screen after updates, Start menu account
:: notifications and Settings account banners. No admin needed. Local accounts keep working as-is.
setlocal

echo Turning off Microsoft account prompts...

:: "Suggest ways to get the most out of Windows and finish setting up this device" (post-update setup screen)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f >nul
:: "Show me the Windows welcome experience after updates"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul
:: Start menu "account-related notifications"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_AccountNotifications /t REG_DWORD /d 0 /f >nul
:: Settings > Accounts notifications / banners
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" /v EnableAccountNotifications /t REG_DWORD /d 0 /f >nul

echo Done. Sign out or restart for the Start menu change to apply.
if not defined SETUPTOOLS_GUI pause
exit /b 0
