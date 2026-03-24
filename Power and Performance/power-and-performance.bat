@echo off
:: High performance power profile, no sleep/display off on AC, USB selective suspend off.
:: Run as Administrator.
setlocal

echo Applying power and performance settings...
echo.

:: --- Set High Performance as active plan (use Ultimate if available) ---
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
if errorlevel 1 powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e

:: --- Never sleep, never turn off display, no hibernate on AC ---
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change disk-timeout-ac 0

:: --- Disable USB selective suspend (avoids USB dropouts) ---
powercfg /setacvalueindex SCHEME_CURRENT 2a737f69-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737f69-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT

:: --- PCIe Link State Power Management: Off (reduces latency) ---
powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
powercfg /setactive SCHEME_CURRENT

echo.
echo Done. High performance plan active; USB selective suspend and PCIe ASPM disabled.
pause
