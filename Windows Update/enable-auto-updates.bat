@echo off
:: Undo disable-auto-updates.bat: back to normal automatic Windows Updates. Run as Administrator.
setlocal
set "WU=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

reg delete "%WU%\AU" /v NoAutoUpdate /f >nul 2>&1
reg delete "%WU%\AU" /v NoAutoRebootWithLoggedOnUsers /f >nul 2>&1
reg delete "%WU%" /v ExcludeWUDriversInQualityUpdate /f >nul 2>&1
reg delete "%WU%" /v TargetReleaseVersion /f >nul 2>&1
reg delete "%WU%" /v ProductVersion /f >nul 2>&1
reg delete "%WU%" /v TargetReleaseVersionInfo /f >nul 2>&1
gpupdate /target:computer /force >nul 2>&1

echo Automatic Windows Updates restored.
if not defined SETUPTOOLS_GUI pause
exit /b 0
