@echo off
rem Removes UraxOS and its Start menu shortcuts. Asks before deleting your saved data.
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
