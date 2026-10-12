@echo off
:: Opens the SetupTools GUI. It asks for Administrator once, then runs the selected steps silently.
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0SetupTools-GUI.ps1"
