@echo off
title Instalador uniOPOS PuenteWeb v2.0
set "ZIP=%~dp0uniOPOS_PuenteWeb_v2.0_Portable.zip"
set "DEST=C:\uniOPOS_PuenteWeb"
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*uniOPOS_PuenteWeb*' -and $_.CommandLine -notlike '*Installer*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }"
if exist "%ZIP%" (
    if exist "%DEST%" rmdir /s /q "%DEST%"
    mkdir "%DEST%"
    tar.exe -xf "%ZIP%" -C "%DEST%"
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%DEST%\setup.ps1" %*