@echo off
:: Turn off "Show my taskbar on all displays" so the taskbar is only on the main display.
:: Current user. Restarts Explorer to apply.
setlocal

echo Showing the taskbar on the main display only...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v MMTaskbarEnabled /t REG_DWORD /d 0 /f >nul

:: --- Restart Explorer so the change takes effect now ---
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo Done.
pause
