@echo off
title uniOPOS PuenteWeb v2.0 - Instalador y Gestor Oficial
color 0B

set "REPO_URL=https://github.com"
set "INSTALL_DIR=C:\uniOPOS_PuenteWeb"
set "TEMP_ZIP=%TEMP%\uniOPOS_PuenteWeb_v2.0.zip"

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Solicitando permisos de Administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

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
if "%opcion%"=="6" exit
goto MENU

:INSTALAR_GITHUB
cls
echo ============================================================================
echo   INSTALACION AUTOMATIZADA DESDE REPOSITORIO GITHUB
echo ============================================================================
echo.
echo [1/4] Deteniendo procesos previos si existen...
taskkill /F /IM node.exe /T >nul 2>&1

echo [2/4] Descargando paquete oficial desde GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%REPO_URL%' -OutFile '%TEMP_ZIP%'"

if not exist "%TEMP_ZIP%" (
    echo.
    echo [ERROR] No se pudo descargar el paquete. Verifica que el repo sea Publico y el Release v2.0.0 exista.
    pause
    goto MENU
)

echo [3/4] Extrayendo archivos en %INSTALL_DIR%...
if exist "%INSTALL_DIR%" rmdir /S /Q "%INSTALL_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%INSTALL_DIR%' -Force"
del "%TEMP_ZIP%" /F /Q >nul 2>&1

for /d %%D in ("%INSTALL_DIR%\*") do (
    if exist "%%D\setup.ps1" (
        xcopy "%%D\*" "%INSTALL_DIR%\" /E /H /Y >nul
        rmdir /S /Q "%%D"
    )
)

echo [4/4] Ejecutando configuracion automatica (setup.ps1)...
echo.
if exist "%INSTALL_DIR%\setup.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\setup.ps1"
) else (
    echo [ERROR] No se encontro setup.ps1 dentro del paquete descargado.
)
echo.
echo ============================================================================
echo [OK] PROCESO DE INSTALACION COMPLETADO.
echo ============================================================================
pause
goto MENU

:VER_IP
cls
echo ============================================================================
echo   DIRECCION DE CONEXION PARA CELULARES (MESEROS / COCINA)
echo ============================================================================
echo.
echo Conecta los telefonos al mismo Wi-Fi de este PC y abre en Chrome/Safari:
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /R /C:"IPv4"') do (
    for /f "tokens=* delims= " %%b in ("%%a") do echo    --^>  http://%%b:5000
)
echo.
echo ============================================================================
pause
goto MENU

:REINICIAR
cls
echo [*] Reiniciando servicio PuenteWeb...
taskkill /F /IM node.exe /T >nul 2>&1
timeout /t 2 >nul
if exist "%INSTALL_DIR%\iniciar_puente.vbs" (
    wscript.exe "%INSTALL_DIR%\iniciar_puente.vbs"
    echo [OK] Servicio reiniciado en segundo plano.
) else (
    echo [ERROR] No se encontro iniciar_puente.vbs en %INSTALL_DIR%.
)
pause
goto MENU

:DIAGNOSTICO
cls
echo ============================================================================
echo   DIAGNOSTICO DE ESTADO - uniOPOS PuenteWeb v2.0
echo ============================================================================
echo.
echo Proceso Node.js activo:
tasklist /FI "IMAGENAME eq node.exe" | findstr /I "node.exe" || echo     [!] Node.js NO esta ejecutandose.
echo.
echo Escucha en Puerto TCP 5000:
netstat -ano | findstr :5000 || echo     [!] El puerto 5000 no esta escuchando.
echo.
echo Regla de Firewall:
netsh advfirewall firewall show rule name="uniOPOS PuenteWeb 5000" | findstr /I "Nombre Habilitada" || echo     [!] Regla de Firewall no encontrada.
echo.
echo ============================================================================
pause
goto MENU

:DESINSTALAR
cls
echo [!] ADVERTENCIA: Se detendra el servidor y se eliminara %INSTALL_DIR%.
set /p confirm="Escribe SI para confirmar la desinstalacion: "
if /I not "%confirm%"=="SI" goto MENU

taskkill /F /IM node.exe /T >nul 2>&1
netsh advfirewall firewall delete rule name="uniOPOS PuenteWeb 5000" >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*puente*" /F /Q >nul 2>&1
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*uniOPOS*" /F /Q >nul 2>&1
if exist "%INSTALL_DIR%" rmdir /S /Q "%INSTALL_DIR%"
echo.
echo [OK] uniOPOS PuenteWeb v2.0 ha sido desinstalado completamente.
pause
goto MENU
