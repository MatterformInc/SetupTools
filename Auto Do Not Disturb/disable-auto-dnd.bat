@echo off
:: Uninstall: turn DND off and remove DoNotDisturb.bat from Startup.
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v NOC_GLOBAL_SETTING_TOASTS_ENABLED /t REG_DWORD /d 1 /f >nul 2>&1
if exist "%STARTUP%\DoNotDisturb.bat" del "%STARTUP%\DoNotDisturb.bat"

echo Do Not Disturb disabled. Removed from Startup.
pause
