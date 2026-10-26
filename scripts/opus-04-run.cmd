@echo off
chcp 65001 >nul
title TB371FC Opus phase 4 - dumbsync visual test
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0opus-04-dumbsync-test.ps1"
echo.
echo ---------------------------------------------
echo Gotovo.
pause
