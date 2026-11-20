$ErrorActionPreference = "Stop"
$srcDir = $PSScriptRoot
$destDir = "C:\uniOPOS_PuenteWeb"
$propFile = Join-Path $env:USERPROFILE "unicentaopos.properties"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   INSTALADOR AUTOMATICO uniOPOS PuenteWeb v2.0" -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

# 1. Detectar configuracion de uniCenta oPOS y MariaDB
Write-Host "[1/6] Detectando entorno de uniCenta oPOS y MariaDB..." -ForegroundColor Cyan
$dbHost = "localhost"; $dbPort = 3316; $dbUser = "unicenta"; $dbName = "masterpos_dev"
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

Write-Host "  Base de datos detectada : $dbName ($dbHost`:$dbPort) | Usuario: $dbUser" -ForegroundColor Gray
$inputPass = Read-Host "  Contrasena de MariaDB para '$dbUser' [Enter para usar 'prospecta2026#']"
$dbPass = if ([string]::IsNullOrWhiteSpace($inputPass)) { "prospecta2026#" } else { $inputPass.Trim() }

# 2. Activar actualizacion automatica de mesas en unicentaopos.properties
Write-Host "`n[2/6] Activando recarga automatica de mesas en uniCenta oPOS..." -ForegroundColor Cyan
if (Test-Path $propFile) {
    $lines = Get-Content $propFile
    $hasRefresh = $false; $hasTimer = $false
    $newLines = foreach ($line in $lines) {
        if ($line -match "^till\.autoRefreshTableMap=") { $hasRefresh = $true; "till.autoRefreshTableMap=true" }
        elseif ($line -match "^till\.autoRefreshTimer=") { $hasTimer = $true; "till.autoRefreshTimer=5" }
        else { $line }
    }
    if (-not $hasRefresh) { $newLines += "till.autoRefreshTableMap=true" }
    if (-not $hasTimer) { $newLines += "till.autoRefreshTimer=5" }
    [System.IO.File]::WriteAllLines($propFile, [string[]]$newLines, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  Mapa de mesas configurado (autoRefresh=true, cada 5 seg)." -ForegroundColor Green
}

# 3. Copiar paquete completo a C:\uniOPOS_PuenteWeb y escribir config.json
Write-Host "`n[3/6] Instalando archivos y binarios portables en $destDir..." -ForegroundColor Cyan
Get-Process node -EA 0 | Where-Object { $_.Path -like "*uniOPOS*" } | Stop-Process -Force -EA 0
if ($srcDir.TrimEnd("\") -ne $destDir.TrimEnd("\")) {
    if (Test-Path $destDir) { Get-ChildItem $destDir -Force | Remove-Item -Recurse -Force -EA 0 }
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Get-ChildItem -Path $srcDir -Exclude "setup.ps1","instalar.bat" | Copy-Item -Destination $destDir -Recurse -Force
}

$cfgObj = [ordered]@{
    port = 5000; dbHost = $dbHost; dbPort = $dbPort
    dbUser = $dbUser; dbPassword = $dbPass; dbName = $dbName
    unicentaJarPath = $jarPath; javaPath = "bin\jre\bin\java.exe"
}
[System.IO.File]::WriteAllText((Join-Path $destDir "config.json"), ($cfgObj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))

# 4. Aplicar plantilla de recibo Printer.Ticket.xml (trazabilidad Mesero/Cajero)
Write-Host "`n[4/6] Aplicando formato de recibo con trazabilidad de Mesero..." -ForegroundColor Cyan
$mysqlExe = Get-ChildItem "C:\Program Files\MariaDB*\bin\mysql.exe" -EA 0 | Select-Object -First 1 -ExpandProperty FullName
$xmlFile = Join-Path $destDir "Printer.Ticket.xml"
if ($mysqlExe -and (Test-Path $xmlFile)) {
    $xmlB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($xmlFile))
    & $mysqlExe -u $dbUser "-p$dbPass" -h $dbHost -P $dbPort -D $dbName -e "UPDATE resources SET CONTENT = FROM_BASE64('$xmlB64') WHERE NAME IN ('Printer.Ticket', 'Printer.TicketPreview');" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  Plantilla Printer.Ticket actualizada en MariaDB." -ForegroundColor Green }
    else { Write-Host "  Aviso: No se pudo actualizar Printer.Ticket (verifica privilegio FILE o hazlo manualmente)." -ForegroundColor Yellow }
}

# 5. Configurar Firewall TCP 5000 y perfil de red Private
Write-Host "`n[5/6] Configurando Firewall de Windows y perfil de red..." -ForegroundColor Cyan
Remove-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000", "uniOPOS PuenteWeb 5000" -EA 0
New-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow | Out-Null
Get-NetConnectionProfile -EA 0 | Set-NetConnectionProfile -NetworkCategory Private -EA 0

# 6. Crear accesos directos, autoarranque e iniciar servidor
Write-Host "`n[6/6] Creando accesos directos e iniciando servicio..." -ForegroundColor Cyan
$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [Environment]::GetFolderPath("Desktop"); $Startup = [Environment]::GetFolderPath("Startup")
$s1 = $WshShell.CreateShortcut("$Desktop\uniOPOS - Mesas.url"); $s1.TargetPath = "http://localhost:5000"; $s1.Save()
$s2 = $WshShell.CreateShortcut("$Desktop\uniOPOS - Cocina y Comandas.url"); $s2.TargetPath = "http://localhost:5000/comandas.html"; $s2.Save()
$vbsDest = Join-Path $destDir "iniciar_puente.vbs"
$s3 = $WshShell.CreateShortcut("$Startup\uniOPOS Puente Web.lnk")
$s3.TargetPath = "wscript.exe"; $s3.Arguments = """$vbsDest"""; $s3.WorkingDirectory = $destDir; $s3.Save()

Start-Process -FilePath "wscript.exe" -ArgumentList """$vbsDest"""
Start-Sleep -Seconds 2

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
