@echo off
cd /d %~dp0

echo ======================================
echo PC Log Export Tool
echo Version 0.2
echo ======================================
echo.
echo Enter dates in yyyy-MM-dd format.
echo Example: 2026-06-01
echo.
echo Note:
echo LogoffTime is rounded up to the next 10-minute mark.
echo.

set /p START_DATE=Start date: 
set /p END_DATE=End date  : 

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0export_pc_log.ps1" -StartDate "%START_DATE%" -EndDate "%END_DATE%"

echo.
echo Press any key to close.
pause > nul
