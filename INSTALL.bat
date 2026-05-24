@echo off
title GHX Replay Toolkit - Install Tools

set "SCRIPT=%~dp0_app\scripts\Install-GHX-Tools.ps1"

where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT%"
)

pause