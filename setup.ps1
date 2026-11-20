$ErrorActionPreference = "Stop"
$srcDir   = $PSScriptRoot
$destDir  = "C:\uniOPOS_PuenteWeb"
$propFile = Join-Path $env:USERPROFILE "unicentaopos.properties"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   INSTALADOR AUTOMATICO uniOPOS PuenteWeb v2.0     " -ForegroundColor Cyan
Write-Host "====================================================`n" -ForegroundColor Cyan

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

$mysqlExe = Get-ChildItem "C:\Program Files\MariaDB*\bin\mysql.exe" -EA 0 | Select-Object -First 1 -ExpandProperty FullName
Write-Host "      Base detectada: $dbName ($dbHost`:$dbPort) | Usuario: $dbUser" -ForegroundColor Gray

$dbPass = ""; $connected = $false
while (-not $connected) {
    $inputPass = Read-Host "      Contrasena de MariaDB para '$dbUser' [Enter='prospecta2026#', o 'ROOT' para crear usuario dedicado]"
    if ($inputPass -eq "ROOT") {
        $rootPass = Read-Host "      Contrasena de 'root' de MariaDB"
        $sql = "GRANT ALL PRIVILEGES ON $dbName.* TO 'puente_app'@'localhost' IDENTIFIED BY 'prospecta2026#'; GRANT ALL PRIVILEGES ON $dbName.* TO 'puente_app'@'127.0.0.1' IDENTIFIED BY 'prospecta2026#'; FLUSH PRIVILEGES;"
        & $mysqlExe -u root "-p$rootPass" -P $dbPort -e $sql 2>$null
        if ($LASTEXITCODE -eq 0) { $dbUser = "puente_app"; $dbPass = "prospecta2026#"; $connected = $true; Write-Host "      Usuario 'puente_app' creado." -ForegroundColor Green }
        else { Write-Host "      Clave de root incorrecta." -ForegroundColor Red }
    } else {
        $cand = if ([string]::IsNullOrWhiteSpace($inputPass)) { "prospecta2026#" } else { $inputPass.Trim() }
        if ($mysqlExe) {
            & $mysqlExe -u $dbUser "-p$cand" -P $dbPort -D $dbName -e "SELECT 1;" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $dbPass = $cand; $connected = $true; Write-Host "      Conexion verificada." -ForegroundColor Green }
            else { Write-Host "      Contrasena incorrecta para '$dbUser'." -ForegroundColor Yellow }
        } else { $dbPass = $cand; $connected = $true }
    }
}

Write-Host "`n[2/6] Activando recarga automatica de mesas en uniCenta oPOS..." -ForegroundColor Cyan
if (Test-Path $propFile) {
    $lines = Get-Content $propFile; $hasRefresh = $false; $hasTimer = $false
    $newLines = foreach ($line in $lines) {
        if ($line -match "^till\.autoRefreshTableMap=") { $hasRefresh = $true; "till.autoRefreshTableMap=true" }
        elseif ($line -match "^till\.autoRefreshTimer=") { $hasTimer = $true; "till.autoRefreshTimer=5" }
        else { $line }
    }
    if (-not $hasRefresh) { $newLines += "till.autoRefreshTableMap=true" }
    if (-not $hasTimer)   { $newLines += "till.autoRefreshTimer=5" }
    [System.IO.File]::WriteAllLines($propFile, [string[]]$newLines, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "      Mapa de mesas configurado (autoRefresh=true, cada 5 seg)." -ForegroundColor Green
}

Write-Host "`n[3/6] Instalando archivos en $destDir..." -ForegroundColor Cyan
Get-CimInstance Win32_Process -Filter "Name='node.exe'" -EA 0 | Where-Object { $_.CommandLine -match "server\.js|uniOPOS" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }; Start-Sleep -Seconds 1
if ($srcDir.TrimEnd("\") -ne $destDir.TrimEnd("\")) {
    Get-CimInstance Win32_Process -EA 0 | Where-Object { $_.CommandLine -match "uniOPOS_PuenteWeb|iniciar_puente|server\.js" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
    Start-Sleep -Seconds 1
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Get-ChildItem -Path $destDir -EA 0 | Remove-Item -Recurse -Force -EA 0
    Get-ChildItem -Path $srcDir -Exclude "setup.ps1","instalar.bat" | Copy-Item -Destination $destDir -Recurse -Force
}

$cfgObj = [ordered]@{ port = 5000; dbHost = $dbHost; dbPort = $dbPort; dbUser = $dbUser; dbPassword = $dbPass; dbName = $dbName; unicentaJarPath = $jarPath; javaPath = "bin\jre\bin\java.exe" }
[System.IO.File]::WriteAllText((Join-Path $destDir "config.json"), ($cfgObj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))

Write-Host "`n[4/6] Configurando recibo de venta (Mesero / Cajero) en MariaDB..." -ForegroundColor Cyan
if ($mysqlExe) {
    $tmpXml = Join-Path $destDir "Printer.Ticket.active.xml"
    $rawXml = (& $mysqlExe -u $dbUser "-p$dbPass" -P $dbPort -D $dbName -N -r -e "SELECT CAST(CONTENT AS CHAR) FROM resources WHERE NAME='Printer.Ticket';") -join "`n"
    if ($rawXml -and $rawXml -notmatch "mesero_app") {
        $oldTag = '<line><text align="left" length="14">Atendido por:</text><text>${ticket.printUser()}</text></line>'
        $newTag = "#set(`$meseroApp = `"`")`n#foreach (`$tl in `$ticket.getLines())`n#if (`"`$!tl.getProperty('mesero_app')`"!=`"`")#set(`$meseroApp = `$tl.getProperty('mesero_app'))#end`n#end`n        #if (`$meseroApp != `"`")`n        <line><text align=`"left`" length=`"14`">Mesero:</text><text>`${meseroApp}</text></line>`n        <line><text align=`"left`" length=`"14`">Cajero:</text><text>`${ticket.printUser()}</text></line>`n        #else`n        <line><text align=`"left`" length=`"14`">Atendido por:</text><text>`${ticket.printUser()}</text></line>`n        #end"
        if ($rawXml.Contains($oldTag)) {
            $rawXml = $rawXml.Replace($oldTag, $newTag)
            [System.IO.File]::WriteAllText($tmpXml, $rawXml, (New-Object System.Text.UTF8Encoding $false))
            $xmlEsc = $tmpXml.Replace("\", "/")
            & $mysqlExe -u $dbUser "-p$dbPass" -P $dbPort -D $dbName -e "UPDATE resources SET CONTENT = LOAD_FILE('$xmlEsc') WHERE NAME IN ('Printer.Ticket', 'Printer.TicketPreview');"
            Write-Host "      Recibo actualizado con trazabilidad de Mesero y Cajero." -ForegroundColor Green
        }
    } else { Write-Host "      Recibo ya contaba con soporte de Mesero." -ForegroundColor Gray }
}

Write-Host "`n[5/6] Configurando Firewall de Windows y perfil de red..." -ForegroundColor Cyan
Remove-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000" -EA 0
Remove-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000" -EA 0
New-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow | Out-Null
Get-NetConnectionProfile -EA 0 | Set-NetConnectionProfile -NetworkCategory Private -EA 0

Write-Host "`n[6/6] Creando accesos directos e iniciando servicio..." -ForegroundColor Cyan
$WshShell = New-Object -ComObject WScript.Shell
$Desktop  = [Environment]::GetFolderPath("Desktop")
$Startup  = [Environment]::GetFolderPath("Startup")

$s1 = $WshShell.CreateShortcut("$Desktop\uniOPOS - Mesas.url"); $s1.TargetPath = "http://localhost:5000"; $s1.Save()
$s2 = $WshShell.CreateShortcut("$Desktop\uniOPOS - Cocina y Comandas.url"); $s2.TargetPath = "http://localhost:5000/comandas.html"; $s2.Save()

$vbsDest = Join-Path $destDir "iniciar_puente.vbs"
$s3 = $WshShell.CreateShortcut("$Startup\uniOPOS Puente Web.lnk")
$s3.TargetPath = "wscript.exe"; $s3.Arguments = """$vbsDest"""; $s3.WorkingDirectory = $destDir; $s3.Save()

Start-Process -FilePath "wscript.exe" -ArgumentList """$vbsDest"""

$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|WSL" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
if (-not $localIP) { $localIP = "localhost" }

Write-Host "`n====================================================" -ForegroundColor Green
Write-Host "   INSTALACION COMPLETADA CON EXITO (v2.0)          " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Conecta los celulares Android via Wi-Fi a: http://${localIP}:5000" -ForegroundColor Yellow
Write-Host "Monitor de Cocina/Bar: http://${localIP}:5000/comandas.html" -ForegroundColor Yellow
Write-Host "====================================================`n" -ForegroundColor Green
Read-Host "Presiona ENTER para finalizar"
