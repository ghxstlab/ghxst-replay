@echo off
title GHX Replay Toolkit UI

where python >nul 2>nul
if %errorlevel%==0 (
    python "%~dp0_app\ui\ghx_replay_toolkit.py"
    pause
    exit /b
)

where py >nul 2>nul
if %errorlevel%==0 (
    py -3 "%~dp0_app\ui\ghx_replay_toolkit.py"
    pause
    exit /b
)

echo Python was not found.
echo.
echo Install Python first:
echo winget install -e --id Python.Python.3.13
echo.
echo Then close and reopen PowerShell / Command Prompt.
pause