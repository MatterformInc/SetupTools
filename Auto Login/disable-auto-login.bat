@echo off
:: Disable Windows Auto-Login - removes stored password from registry
:: Run as Administrator.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator: right-click, "Run as administrator"
    pause
    exit /b 1
)

set "KEY=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

reg add "%KEY%" /v AutoAdminLogon /t REG_SZ /d "0" /f >nul
reg delete "%KEY%" /v DefaultPassword /f >nul 2>&1

echo Auto-login has been DISABLED. You will need to enter your password again.
pause
