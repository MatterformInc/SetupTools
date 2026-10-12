@echo off
:: Add Windows Defender exclusions for Unreal Engine and TouchDesigner (fewer scans, less instability).
:: Run as Administrator.
setlocal

echo Adding Defender exclusions for Unreal and TouchDesigner...
echo.

set "PS="
set "PS=%PS%Add-MpPreference -ExclusionProcess 'UE4Editor.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'UE5Editor.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'UnrealEditor.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'UnrealEditor-Cmd.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'UnrealHeaderTool.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'ShaderCompileWorker.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'TouchDesigner.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionProcess 'TouchDesigner099.exe' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionPath 'C:\Program Files\Epic Games' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionPath 'C:\Program Files\Unreal Engine' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionPath 'C:\Program Files\Derivative' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionExtension '.uasset' -ErrorAction SilentlyContinue; "
set "PS=%PS%Add-MpPreference -ExclusionExtension '.umap' -ErrorAction SilentlyContinue; "

powershell -NoProfile -ExecutionPolicy Bypass -Command "%PS%"
if errorlevel 1 (
    echo Run this script as Administrator.
    if not defined SETUPTOOLS_GUI pause
    exit /b 1
)

echo.
echo Done. Add your own project/cache paths in Defender if needed.
if not defined SETUPTOOLS_GUI pause
