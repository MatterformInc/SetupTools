@echo off
set "TASKNAME=Restart PC"
schtasks /delete /tn "%TASKNAME%" /f >nul 2>&1
echo Scheduled task "%TASKNAME%" removed. No more daily restart.
if not defined SETUPTOOLS_GUI pause
