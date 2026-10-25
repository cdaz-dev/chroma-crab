@echo off
rem Puts claude-crab on PATH for cmd, PowerShell and anything else, and skips
rem the execution-policy prompt that running a .ps1 directly would hit.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\claude-crab.ps1" %*
exit /b %errorlevel%
