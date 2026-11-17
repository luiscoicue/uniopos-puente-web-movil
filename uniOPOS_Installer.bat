@echo off
if /I "%~dp0"=="C:\uniOPOS_PuenteWeb\" (copy /Y "%~f0" "%TEMP%\uniOPOS_Installer.bat" >nul & start "" "%TEMP%\uniOPOS_Installer.bat" & exit /b)
title uniOPOS PuenteWeb v2.0 - Instalador y Gestor Oficial
color 0B
set "GH_HOST=https://github.com/luiscoicue/uniopos-puente-web-movil"
set "REPO_URL=%GH_HOST%/releases/download/v2.0.0/uniOPOS_PuenteWeb_v2.0_Portable.zip"
set "INSTALL_DIR=C:\uniOPOS_PuenteWeb"
set "TEMP_ZIP=%TEMP%\uniOPOS_PuenteWeb_v2.0_Portable.zip"
net session >nul 2>&1
if %errorLevel% neq 0 (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)
:MENU
cls
echo ============================================================================
echo               uniOPOS PuenteWeb v2.0 - GESTOR DE DESPLIEGUE
echo ============================================================================
echo.
echo   1. Instalar / Actualizar desde GitHub (Descarga e instalacion limpia)
echo   2. Ver direccion IP para conectar celulares (Comandas)
echo   3. Reiniciar servidor PuenteWeb en segundo plano
echo   4. Verificar estado del sistema (Puerto 5000 y MariaDB)
echo   5. Desinstalar completamente de este equipo
echo   6. Salir
echo.
echo ============================================================================
set /p opcion="Selecciona una opcion (1-6): "
if "%opcion%"=="1" goto INSTALAR_GITHUB
if "%opcion%"=="2" goto VER_IP
if "%opcion%"=="3" goto REINICIAR
if "%opcion%"=="4" goto DIAGNOSTICO
if "%opcion%"=="5" goto DESINSTALAR
if "%opcion%"=="6" exit /b
goto MENU
:INSTALAR_GITHUB
cls
echo [1/4] Deteniendo procesos previos...
taskkill /F /IM node.exe /T >nul 2>&1
echo [2/4] Descargando paquete desde GitHub (263 MB)...
if exist "%TEMP_ZIP%" del "%TEMP_ZIP%" /F /Q >nul 2>&1
curl.exe -L --fail --retry 3 --progress-bar "%REPO_URL%" -o "%TEMP_ZIP%"
if not exist "%TEMP_ZIP%" (echo [ERROR] Descarga fallida. & pause & goto MENU)
powershell -NoProfile -Command "if ((Get-Item '%TEMP_ZIP%').Length -lt 104857600) { exit 1 }"
if %errorLevel% neq 0 (echo [ERROR] Archivo menor a 100 MB. & pause & goto MENU)
echo [3/4] Extrayendo en %INSTALL_DIR%...
if exist "%INSTALL_DIR%" rmdir /S /Q "%INSTALL_DIR%"
mkdir "%INSTALL_DIR%" & copy /Y "%~f0" "%INSTALL_DIR%\uniOPOS_Installer.bat" >nul
tar.exe -xf "%TEMP_ZIP%" -C "%INSTALL_DIR%"
for /d %%D in ("%INSTALL_DIR%\*") do if exist "%%D\setup.ps1" robocopy "%%D" "%INSTALL_DIR%" /E /MOVE /NFL /NDL /NJH /NJS >nul
if not exist "%INSTALL_DIR%\iniciar_puente.vbs" (echo [ERROR] Falta iniciar_puente.vbs. & pause & goto MENU)
del "%TEMP_ZIP%" /F /Q >nul 2>&1
echo [4/4] Ejecutando setup.ps1...
powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\setup.ps1"
echo [OK] INSTALACION COMPLETADA.
pause
goto MENU
:VER_IP
cls
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /R /C:"IPv4"') do for /f "tokens=* delims= " %%b in ("%%a") do echo    --^>  http://%%b:5000
pause
goto MENU
:REINICIAR
cls
taskkill /F /IM node.exe /T >nul 2>&1
timeout /t 2 >nul
if exist "%INSTALL_DIR%\iniciar_puente.vbs" (wscript.exe "%INSTALL_DIR%\iniciar_puente.vbs" & echo [OK] Reiniciado.) else (echo [ERROR] No encontrado.)
pause
goto MENU
:DIAGNOSTICO
cls
tasklist /FI "IMAGENAME eq node.exe" | findstr /I "node.exe" || echo [!] Node.js NO activo.
netstat -ano | findstr :5000 || echo [!] Puerto 5000 cerrado.
netsh advfirewall firewall show rule name="uniOPOS PuenteWeb 5000" | findstr /I "Nombre Habilitada" || echo [!] Sin regla Firewall.
pause
goto MENU
:DESINSTALAR
cls
set /p confirm="Escribe SI para desinstalar: "
if /I not "%confirm%"=="SI" goto MENU
taskkill /F /IM node.exe /T >nul 2>&1
netsh advfirewall firewall delete rule name="uniOPOS PuenteWeb 5000" >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*puente*" /F /Q >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*uniOPOS*" /F /Q >nul 2>&1
if exist "%INSTALL_DIR%" rmdir /S /Q "%INSTALL_DIR%"
echo [OK] Desinstalado.
pause
goto MENU
