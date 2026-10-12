@echo off
:: Enable Windows Auto-Login
:: WARNING: This stores your password in the registry in plain text.
:: Only use on a trusted, physically secure PC. Run as Administrator.
::
:: Works on both Windows Home and Pro. Home cannot join a domain (always Local).
:: If it doesn't work: use Local vs Domain correctly, run as Admin,
:: and on domain PCs enter the exact domain name (ask IT if unsure).

setlocal enabledelayedexpansion

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator"
    pause
    exit /b 1
)

echo ============================================
echo    Windows Auto-Login Setup
echo ============================================
echo.
echo SECURITY WARNING: Your password will be stored
echo in the registry. Anyone with PC access could
echo read it. Use only on a trusted machine.
echo.
echo Password is entered in the next step so special
echo characters ^(%% ^! ^& etc.^) are stored correctly.
echo.

set /p "USERNAME=Enter your Windows username: "

if "%USERNAME%"=="" (
    echo Username cannot be empty.
    pause
    exit /b 1
)

echo.
:: Detect if PC is domain-joined (Windows Home is never domain-joined)
set "ACCT_TYPE="
for /f "tokens=2 delims= " %%a in ('wmic computersystem get partofdomain 2^>nul ^| findstr /i "TRUE FALSE"') do set "PART_OF_DOMAIN=%%a"
if /i "%PART_OF_DOMAIN%"=="TRUE" (
    echo This PC is joined to a domain. Is your logon a DOMAIN account?
    echo   Local  = local account on this PC only
    echo   Domain = your work/school domain account
    echo.
    set /p "ACCT_TYPE=Type L for Local, D for Domain [D]: "
    if "!ACCT_TYPE!"=="" set "ACCT_TYPE=D"
) else (
    echo This PC is not domain-joined ^(Windows Home or standalone Pro^).
    echo Using Local account.
    set "ACCT_TYPE=L"
)
if "%ACCT_TYPE%"=="" set "ACCT_TYPE=L"
if /i "%ACCT_TYPE%"=="D" (
    set /p "DOMAIN=Enter domain name (e.g. CONTOSO or company.net): "
    if "!DOMAIN!"=="" (
        echo Domain cannot be empty for domain accounts.
        pause
        exit /b 1
    )
)
if /i not "%ACCT_TYPE%"=="D" (
    :: Local account: use computer name as domain (required by Winlogon)
    set "DOMAIN=%COMPUTERNAME%"
)

:: Pass to PowerShell via env (password is prompted there so special chars work)
set "WL_USERNAME=%USERNAME%"
set "WL_DOMAIN=%DOMAIN%"

echo.
echo Enter your Windows password when prompted...
echo.
:: Checks the password, then writes the registry. Exit 0 = ok, 2 = password rejected, 3 = registry failed.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0set-auto-login.ps1"
set "RC=%errorlevel%"
if "%RC%"=="2" goto :done
if not "%RC%"=="0" goto :reg_fail

echo.
echo Auto-login has been ENABLED.
echo Restart your PC to test. You will log in automatically.
goto :done

:reg_fail
if "%RC%"=="0" set "RC=1"
echo.
echo Registry update failed. Common causes:
echo   - Not run as Administrator (right-click ^> Run as administrator)
echo   - Domain name or username wrong for domain-joined PCs
echo   - Microsoft account: use your actual Windows password, not PIN
echo   - Group Policy may block auto-logon on some work PCs
echo   - Works on both Windows Home and Pro; edition is not the cause
echo   - Passwords with %% ^! ^& etc. are now handled correctly
goto :done

:done

echo.
pause
:: Report the real result (pause would otherwise make every run exit 0 = "success").
exit /b %RC%
