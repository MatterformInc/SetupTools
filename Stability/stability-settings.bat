@echo off
:: Reduce instability: delivery optimization off, visual effects = performance.
:: Run as Administrator for delivery optimization.
setlocal

echo Applying stability settings...
echo.

:: --- Delivery optimization: do not upload to other PCs ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
if errorlevel 1 (
    echo Delivery Optimization policy skipped ^(run as Administrator^).
) else (
    echo Delivery Optimization set to local-only.
)

:: --- Visual effects: adjust for best performance (current user) ---
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v MinAnimate /t REG_SZ /d 0 /f >nul 2>&1

:: --- Disable taskbar animations (Windows 11) ---
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul 2>&1

echo.
echo Done. Sign out or restart for visual changes to apply.
if not defined SETUPTOOLS_GUI pause
