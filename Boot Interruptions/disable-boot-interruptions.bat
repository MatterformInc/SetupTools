@echo off
:: Block every screen that can stop an unattended PC on boot or sign-in, for all users:
:: Startup Repair after power loss, "finish setting up" / account / backup screens after updates,
:: privacy screen, first sign-in animation, Windows Hello setup prompt, Ctrl+Alt+Del.
:: Undo with enable-boot-interruptions.bat.
:: Run as Administrator.
setlocal

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0boot-interruptions.ps1"
set "RC=%errorlevel%"

if not defined SETUPTOOLS_GUI pause
exit /b %RC%
