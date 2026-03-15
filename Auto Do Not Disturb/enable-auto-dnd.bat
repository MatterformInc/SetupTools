@echo off
:: Install: run DND now, copy DoNotDisturb.bat to Startup, open Startup folder.
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SCRIPTS=%~dp0scripts"

call "%SCRIPTS%\DoNotDisturb.bat"
taskkill /f /im explorer.exe >nul 2>&1 & start explorer.exe
copy /y "%SCRIPTS%\DoNotDisturb.bat" "%STARTUP%\DoNotDisturb.bat" >nul

echo On many Windows 11 PCs the registry is ignored — turn on DND in the Settings window (or set "During these times" for 24/7).
start ms-settings:notifications
explorer "%STARTUP%"
pause
