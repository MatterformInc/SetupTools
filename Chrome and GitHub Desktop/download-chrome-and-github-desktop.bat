@echo off
:: Download the latest Google Chrome and GitHub Desktop installers
:: Saves to this script's folder. No admin required. Requires internet.

setlocal
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo ============================================
echo    Chrome + GitHub Desktop Downloader
echo ============================================
echo.
echo Saving to: %SCRIPT_DIR%
echo.

:: Use PowerShell for TLS 1.2 and reliable downloads
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
  "$dest = '%SCRIPT_DIR%';" ^
  "Write-Host 'Downloading Google Chrome (64-bit)...';" ^
  "try { Invoke-WebRequest -Uri 'https://www.google.com/chrome/?standalone=1&platform=win64' -OutFile (Join-Path $dest 'ChromeStandaloneSetup64.exe') -UseBasicParsing; Write-Host '  Chrome (standalone) saved.' } catch { Write-Host '  Chrome failed:' $_.Exception.Message };" ^
  "Write-Host '';" ^
  "Write-Host 'Downloading GitHub Desktop (Windows)...';" ^
  "try { Invoke-WebRequest -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32' -OutFile (Join-Path $dest 'GitHubDesktopSetup-x64.exe') -UseBasicParsing; Write-Host '  GitHub Desktop saved.' } catch { Write-Host '  GitHub Desktop failed:' $_.Exception.Message };"

echo.
echo Done. Run the .exe files in this folder to install.
echo.
pause
