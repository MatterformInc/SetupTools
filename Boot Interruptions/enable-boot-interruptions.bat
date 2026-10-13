@echo off
:: Undo disable-boot-interruptions.bat.
:: Run as Administrator.
setlocal

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0boot-interruptions.ps1" -Undo
set "RC=%errorlevel%"

if not defined SETUPTOOLS_GUI pause
exit /b %RC%
