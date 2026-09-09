@echo off
cd /d %~dp0

if not exist "%~dp0output" mkdir "%~dp0output"
start "" "%~dp0output"
