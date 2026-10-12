@echo off
:: Stop Windows Update from downloading, installing and restarting on its own (installations / kiosks).
:: Uses the official Windows Update policies (Pro / Enterprise / Education; Home ignores some of them).
::   - Automatic Updates off: nothing installs or restarts by itself; update manually in Settings
::   - No driver updates through Windows Update (keeps your GPU driver as installed)
::   - Stay on the current Windows version (no feature upgrades, e.g. 24H2 -> 25H2)
:: Undo with enable-auto-updates.bat. Run as Administrator.
setlocal
set "WU=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

net session >nul 2>&1
if errorlevel 1 (
    echo This script needs Administrator rights. Right-click and choose "Run as administrator".
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo Turning off automatic Windows Updates...

:: --- Automatic Updates: disabled, and never auto-restart while someone is logged on ---
reg add "%WU%\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul
reg add "%WU%\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >nul

:: --- No drivers from Windows Update ---
reg add "%WU%" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f >nul

:: --- Pin the current feature version (TargetReleaseVersion) ---
for /f "tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion 2^>nul ^| findstr DisplayVersion') do set "FEATURE=%%b"
for /f "tokens=3" %%b in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| findstr CurrentBuildNumber') do set "BUILD=%%b"
set "PRODUCT=Windows 10"
if defined BUILD if %BUILD% GEQ 22000 set "PRODUCT=Windows 11"
if defined FEATURE (
    reg add "%WU%" /v TargetReleaseVersion /t REG_DWORD /d 1 /f >nul
    reg add "%WU%" /v ProductVersion /t REG_SZ /d "%PRODUCT%" /f >nul
    reg add "%WU%" /v TargetReleaseVersionInfo /t REG_SZ /d "%FEATURE%" /f >nul
    echo Pinned to %PRODUCT% %FEATURE%.
) else (
    echo Could not read the Windows version; feature version not pinned.
)

:: Apply now
gpupdate /target:computer /force >nul 2>&1

echo.
echo Done. Windows will no longer update or restart on its own.
echo Check for updates manually now and then: Settings ^> Windows Update ^> Check for updates.
if not defined SETUPTOOLS_GUI pause
exit /b 0
