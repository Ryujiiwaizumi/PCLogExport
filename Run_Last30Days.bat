@echo off
cd /d %~dp0

echo ======================================
echo PC Log Export Tool - Last 30 Days
echo Version 0.2
echo ======================================
echo.
echo Note:
echo LogoffTime is rounded up to the next 10-minute mark.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0export_pc_log.ps1" -Days 30

echo.
echo Press any key to close.
pause > nul
