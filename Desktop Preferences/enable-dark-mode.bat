@echo off
:: Set Windows and apps to dark mode (current user).
setlocal

echo Setting dark mode...
set "PERS=HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
reg add "%PERS%" /v AppsUseLightTheme /t REG_DWORD /d 0 /f >nul
reg add "%PERS%" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f >nul

echo Done. Some apps update after they are reopened.
pause
