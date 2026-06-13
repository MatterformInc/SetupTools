@echo off
:: Open the Startup folder so you can pin it to Quick Access yourself.
:: Windows doesn't allow adding to Quick Access via script on 10/11.
:: No admin required.

set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

if not exist "%STARTUP_FOLDER%" (
    echo Startup folder not found: %STARTUP_FOLDER%
    pause
    exit /b 1
)

echo Opening Startup folder...
echo.
echo Then right-click the folder ^(or the address bar^) and choose "Pin to Quick access".
echo.

start "" explorer "%STARTUP_FOLDER%"

pause
