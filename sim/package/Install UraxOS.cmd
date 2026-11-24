@echo off
rem Installs UraxOS for the current user (no admin needed) and adds it to the Start menu.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
