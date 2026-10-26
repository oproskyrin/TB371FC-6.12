@echo off
chcp 65001 >nul
title TB371FC Opus phase 1
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0opus-01-phase1.ps1"
echo.
echo ---------------------------------------------
echo Gotovo.
pause
