@echo off
chcp 65001 >nul
title TB371FC Opus phase 0
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0opus-00-discover-and-snapshot.ps1"
echo.
echo ---------------------------------------------
echo Gotovo. Okno ne zakryvaetsya - skopiruy vyvod.
pause
