@echo off
:: Check that the GPU is running at full PCIe link width (e.g. x16, not x1).
:: Reports the cause checklist if it isn't. No admin needed.
setlocal

echo Checking GPU PCIe link...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-gpu-pcie.ps1"
set "RC=%errorlevel%"

echo.
if not defined SETUPTOOLS_GUI pause
exit /b %RC%
