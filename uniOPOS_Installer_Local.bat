@echo off
title Instalador Offline uniOPOS PuenteWeb v2.0
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
set "ZIP=%~dp0uniOPOS_PuenteWeb_v2.0_Portable.zip"
set "DEST=C:\uniOPOS_PuenteWeb"
if not exist "%ZIP%" (
    echo [ERROR] No se encontro uniOPOS_PuenteWeb_v2.0_Portable.zip en %~dp0
    pause
    exit /b 1
)
echo [1/3] Deteniendo procesos previos...
powershell -NoProfile -Command "Get-Process node -EA SilentlyContinue | Where-Object { $_.Path -like '*uniOPOS*' } | Stop-Process -Force -EA SilentlyContinue; Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" -EA SilentlyContinue | Where-Object { $_.CommandLine -like '*tray_monitor.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }"
echo [2/3] Extrayendo paquete offline en %DEST%...
if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%"
tar.exe -xf "%ZIP%" -C "%DEST%"
echo [3/3] Ejecutando configuracion automatica...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DEST%\setup.ps1"
