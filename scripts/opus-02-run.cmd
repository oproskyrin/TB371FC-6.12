@echo off
chcp 65001 >nul
title TB371FC Opus phase 2
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0opus-02-phase2.ps1"
echo.
echo ---------------------------------------------
echo Gotovo.
pause
