$ErrorActionPreference = "Stop"
$srcDir  = $PSScriptRoot
$destDir = "C:\uniOPOS\PuenteWeb"
$propFile = Join-Path $env:USERPROFILE "unicentaopos.properties"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   INSTALADOR AUTOMATICO uniOPOS PuenteWeb v2.0" -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

# 1. Detectar configuracion de uniCenta oPOS
Write-Host "[1/5] Detectando entorno de uniCenta oPOS y MariaDB..." -ForegroundColor Cyan
$dbHost  = "localhost"
$dbPort  = 3316
$dbUser  = "unicenta"
$dbName  = "masterpos_dev"
$jarPath = "C:\Program Files\unicenta-opos\app\unicentaopos.jar"

if (Test-Path $propFile) {
    $props = Get-Content $propFile
    $uLine = $props | Where-Object { $_ -match "^db\.user=" } | Select-Object -First 1
    if ($uLine) { $dbUser = ($uLine -split "=", 2)[1].Trim() }

    $sLine = $props | Where-Object { $_ -match "^db\.schema=" } | Select-Object -First 1
    if ($sLine) { $dbName = ($sLine -split "=", 2)[1].Trim() }

    $urlLine = $props | Where-Object { $_ -match "^db\.URL=" } | Select-Object -First 1
    if ($urlLine -match ":(\d+)/") { $dbPort = [int]$matches[1] }

    $drvLine = $props | Where-Object { $_ -match "^db\.driverlib=" } | Select-Object -First 1
    if ($drvLine -match "(.+unicenta-opos\\app)") {
        $candidateJar = ($matches[1] -replace "\\\\", "\") + "\unicentaopos.jar"
        if (Test-Path $candidateJar) { $jarPath = $candidateJar }
    }
}

Write-Host "   Base de datos detectada : $dbName ($dbHost`:$dbPort) | Usuario: $dbUser" -ForegroundColor Gray
$inputPass = Read-Host "   Contrasena de MariaDB [Enter para usar 'prospecta2026#']"
$dbPass = if ([string]::IsNullOrWhiteSpace($inputPass)) { "prospecta2026#" } else { $inputPass.Trim() }

# 2. Activar actualizacion automatica de mesas en unicentaopos.properties
Write-Host "`n[2/5] Activando recarga automatica de mesas en uniCenta oPOS..." -ForegroundColor Cyan
if (Test-Path $propFile) {
    $lines = Get-Content $propFile
    $hasRefresh = $false
    $hasTimer   = $false
    $newLines = foreach ($line in $lines) {
        if ($line -match "^till\.autoRefreshTableMap=") {
            $hasRefresh = $true
            "till.autoRefreshTableMap=true"
        } elseif ($line -match "^till\.autoRefreshTimer=") {
            $hasTimer = $true
            "till.autoRefreshTimer=5"
        } else {
            $line
        }
    }
    if (-not $hasRefresh) { $newLines += "till.autoRefreshTableMap=true" }
    if (-not $hasTimer)   { $newLines += "till.autoRefreshTimer=5" }
    Set-Content -Path $propFile -Value $newLines -Encoding UTF8
    Write-Host "   Mapa de mesas configurado (autoRefresh=true, cada 5 seg)." -ForegroundColor Green
} else {
    Write-Host "   Aviso: No se encontro unicentaopos.properties en $propFile (se omitio este paso)." -ForegroundColor Yellow
}

# 3. Copiar paquete completo a C:\uniOPOS\PuenteWeb y escribir config.json
Write-Host "`n[3/5] Instalando archivos en $destDir..." -ForegroundColor Cyan
Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*uniOPOS*" } | Stop-Process -Force -ErrorAction SilentlyContinue
if (Test-Path $destDir) { Remove-Item $destDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

Get-ChildItem -Path $srcDir -Exclude "setup.ps1","instalar.bat" | Copy-Item -Destination $destDir -Recurse -Force

$cfgObj = [ordered]@{
    port            = 5000
    dbHost          = $dbHost
    dbPort          = $dbPort
    dbUser          = $dbUser
    dbPassword      = $dbPass
    dbName          = $dbName
    unicentaJarPath = $jarPath
    javaPath        = "bin\jre\bin\java.exe"
}
$cfgObj | ConvertTo-Json | Set-Content -Path (Join-Path $destDir "config.json") -Encoding UTF8

# 4. Configurar Firewall TCP 5000 y perfil de red Private
Write-Host "[4/5] Configurando Firewall de Windows y perfil de red..." -ForegroundColor Cyan
Remove-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow | Out-Null
Get-NetConnectionProfile -ErrorAction SilentlyContinue | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

# 5. Crear accesos directos, autoarranque e iniciar servidor
Write-Host "[5/5] Creando accesos directos e iniciando servicio..." -ForegroundColor Cyan
$WshShell = New-Object -ComObject WScript.Shell
$Desktop  = [Environment]::GetFolderPath("Desktop")
$Startup  = [Environment]::GetFolderPath("Startup")

$s1 = $WshShell.CreateShortcut("$Desktop\uniOPOS - Mesas.url"); $s1.TargetPath = "http://localhost:5000"; $s1.Save()
$s2 = $WshShell.CreateShortcut("$Desktop\uniOPOS - Cocina y Comandas.url"); $s2.TargetPath = "http://localhost:5000/comandas.html"; $s2.Save()

$vbsDest = Join-Path $destDir "iniciar_puente.vbs"
$s3 = $WshShell.CreateShortcut("$Startup\uniOPOS Puente Web.lnk")
$s3.TargetPath = "wscript.exe"
$s3.Arguments  = """$vbsDest"""
$s3.WorkingDirectory = $destDir
$s3.Save()

Start-Process -FilePath "wscript.exe" -ArgumentList """$vbsDest"""

$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|WSL" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
if (-not $localIP) { $localIP = "localhost" }

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "   INSTALACION COMPLETADA CON EXITO (v2.0)" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Conecta los celulares Android via Wi-Fi a:" -ForegroundColor White
Write-Host "   http://${localIP}:5000" -ForegroundColor Yellow
Write-Host "Monitor de Cocina/Bar:" -ForegroundColor White
Write-Host "   http://${localIP}:5000/comandas.html" -ForegroundColor Yellow
Write-Host "====================================================`n" -ForegroundColor Green
Read-Host "Presiona ENTER para finalizar"
