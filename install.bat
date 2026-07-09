@echo off
:: Double-click launcher — runs the PowerShell installer with admin elevation.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
exit /b %ERRORLEVEL%
