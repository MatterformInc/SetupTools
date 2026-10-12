@echo off
:: Undo enable-auto-dnd.bat: turn notifications back on (current user).
setlocal
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 1 /f >nul
reg delete "HKCU\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /f >nul 2>&1
reg delete "HKCU\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotificationOnLockScreen /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /t REG_DWORD /d 1 /f >nul
if exist "%STARTUP%\DoNotDisturb.bat" del "%STARTUP%\DoNotDisturb.bat"

if not defined SETUPTOOLS_GUI (taskkill /f /im explorer.exe >nul 2>&1 & start explorer.exe)

echo Notifications turned back on.
if not defined SETUPTOOLS_GUI pause
exit /b 0
