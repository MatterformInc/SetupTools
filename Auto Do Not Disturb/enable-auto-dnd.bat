@echo off
:: Do Not Disturb all day, every day: turns notifications off (current user).
:: Windows' own DND schedule can't cover a full 24 hours, so this turns toast notifications off instead,
:: which persists across restarts with nothing running at startup.
setlocal
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

echo Turning notifications off (24/7 Do Not Disturb)...
call "%~dp0scripts\DoNotDisturb.bat"
if errorlevel 1 (
    echo Failed to write notification settings.
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

:: Older versions copied a .bat to Startup, which Windows can flag with a prompt at logon. Remove it.
if exist "%STARTUP%\DoNotDisturb.bat" (
    del "%STARTUP%\DoNotDisturb.bat"
    echo Removed old DoNotDisturb.bat from Startup ^(no longer needed^).
)

:: Restart Explorer so the change applies now (the GUI does this once at the end).
if not defined SETUPTOOLS_GUI (taskkill /f /im explorer.exe >nul 2>&1 & start explorer.exe)

echo Done. Notifications are off all day; this stays set after restarts.
if not defined SETUPTOOLS_GUI pause
exit /b 0
