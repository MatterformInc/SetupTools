@echo off
:: Create autounattend.xml for a Windows install USB: local account, no Microsoft account screens.
:: No admin needed. See README.txt in this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-autounattend.ps1"
echo.
pause
