@echo off
title Instalador uniOPOS PuenteWeb v2.0
fltmc >nul 2>&1 || (
    powershell -NoProfile -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -Path '%~dp0setup.ps1' -EA 0; & '%~dp0setup.ps1'"
if %errorlevel% neq 0 pause
