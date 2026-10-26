@echo off
chcp 65001 >nul
title TB371FC Opus phase 3 - restore stock KWin
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0opus-03-restore-baseline.ps1"
echo.
echo ---------------------------------------------
echo Gotovo.
pause
