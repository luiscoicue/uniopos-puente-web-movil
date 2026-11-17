@echo off
title Instalador uniOPOS PuenteWeb v2.0
setlocal EnableDelayedExpansion
set "INSTALL_DIR=C:\uniOPOS_PuenteWeb"
set "ZIP_URL=https://github.com/luiscoicue/uniopos-puente-web-movil/releases/download/v2.0.0/uniOPOS_PuenteWeb_v2.0_Portable.zip"
set "ZIP_FILE=%TEMP%\uniOPOS_PuenteWeb_v2.0_Portable.zip"
set "PROP_FILE=%USERPROFILE%\unicentaopos.properties"
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
echo [1/4] Descargando uniOPOS PuenteWeb v2.0...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%ZIP_FILE%'"
echo [2/4] Extrayendo en %INSTALL_DIR%...
powershell -NoProfile -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%INSTALL_DIR%' -Force"
del "%ZIP_FILE%" >nul 2>&1
set "DB_PORT=3316"
set "DB_NAME=masterpos_dev"
set "DB_USER=unicenta"
set "DB_PASS="
if exist "%PROP_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%PROP_FILE%") do (
        if "%%A"=="db.user" set "DB_USER=%%B"
        if "%%A"=="db.password" set "RAW_PASS=%%B"
    )
)
if defined RAW_PASS (
    echo !RAW_PASS! | findstr /b "crypt:" >nul
    if errorlevel 1 set "DB_PASS=!RAW_PASS!"
)
if not defined DB_PASS set /p "DB_PASS=Contrasena MariaDB para [!DB_USER!]: "
set /p "IN_PORT=Puerto MariaDB [Enter=!DB_PORT!]: "
if defined IN_PORT set "DB_PORT=!IN_PORT!"
set /p "IN_DB=Base de datos [Enter=!DB_NAME!]: "
if defined IN_DB set "DB_NAME=!IN_DB!"
powershell -NoProfile -Command "$c=Get-ChildItem '%INSTALL_DIR%' -Recurse -Filter 'config.json'|Select -First 1; if($c){$j=Get-Content $c.FullName -Raw|ConvertFrom-Json; $j.dbPort=[int]'%DB_PORT%'; $j.dbName='%DB_NAME%'; $j.dbUser='%DB_USER%'; $j.dbPassword='%DB_PASS%'; $j|ConvertTo-Json -Depth 10|Set-Content $c.FullName -Encoding UTF8}"
netsh advfirewall firewall show rule name="uniOPOS PuenteWeb 5000" >nul 2>&1 || netsh advfirewall firewall add rule name="uniOPOS PuenteWeb 5000" dir=in action=allow protocol=TCP localport=5000 >nul
echo Listo. Instalado en %INSTALL_DIR%.
pause
