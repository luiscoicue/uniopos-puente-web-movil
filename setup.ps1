$ErrorActionPreference = "Stop"
$srcDir   = $PSScriptRoot
$destDir  = "C:\uniOPOS_PuenteWeb"
$propFile = Join-Path $env:USERPROFILE "unicentaopos.properties"

function Get-Entorno {
    $info = [ordered]@{
        DbHost = "localhost"; DbPort = 3316; DbUser = "unicenta"; DbName = "masterpos_dev"
        JarPath = "C:\Program Files\unicenta-opos\app\unicentaopos.jar"
        MysqlExe = (Get-ChildItem "C:\Program Files\MariaDB*\bin\mysql.exe" -EA 0 | Select-Object -First 1 -ExpandProperty FullName)
        MariaDBStatus = (Get-Service | Where-Object { $_.Name -match "mariadb|mysql" } | Select-Object -First 1).Status
        LocalIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|WSL" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
        PuenteActivo = [bool](Get-NetTCPConnection -LocalPort 5000 -State Listen -EA 0)
    }
    if (-not $info.LocalIP) { $info.LocalIP = "localhost" }
    if (Test-Path $propFile) {
        $props = Get-Content $propFile
        $uLine = $props | Where-Object { $_ -match "^db\.user=" } | Select-Object -First 1
        if ($uLine) { $info.DbUser = ($uLine -split "=", 2)[1].Trim() }
        $sLine = $props | Where-Object { $_ -match "^db\.schema=" } | Select-Object -First 1
        if ($sLine) { $info.DbName = ($sLine -split "=", 2)[1].Trim() }
        $urlLine = $props | Where-Object { $_ -match "^db\.URL=" } | Select-Object -First 1
        if ($urlLine -match ":(\d+)/") { $info.DbPort = [int]$matches[1] }
        $drvLine = $props | Where-Object { $_ -match "^db\.driverlib=" } | Select-Object -First 1
        if ($drvLine -match "(.+unicenta-opos\\app)") {
            $cand = ($matches[1] -replace "\\\\", "\") + "\unicentaopos.jar"
            if (Test-Path $cand) { $info.JarPath = $cand }
        }
    }
    return $info
}

function Invoke-Diagnostico {
    Clear-Host
    $e = Get-Entorno
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   DIAGNOSTICO DE ENTORNO - UNIOPOS S.A.S.                  " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host (" Servicio MariaDB   : " + $(if ($e.MariaDBStatus) { $e.MariaDBStatus } else { "NO DETECTADO" })) -ForegroundColor $(if ($e.MariaDBStatus -eq "Running") { "Green" } else { "Red" })
    Write-Host (" Base de Datos      : {0} ({1}:{2})" -f $e.DbName, $e.DbHost, $e.DbPort) -ForegroundColor White
    Write-Host (" Usuario uniCenta   : {0}" -f $e.DbUser) -ForegroundColor White
    Write-Host (" Archivo JAR        : " + $(if (Test-Path $e.JarPath) { "OK ($($e.JarPath))" } else { "NO ENCONTRADO" })) -ForegroundColor $(if (Test-Path $e.JarPath) { "Green" } else { "Yellow" })
    Write-Host (" IP Local Wi-Fi     : {0}" -f $e.LocalIP) -ForegroundColor Yellow
    Write-Host (" Puerto 5000 Puente : " + $(if ($e.PuenteActivo) { "ACTIVO Y ESCUCHANDO" } else { "DETENIDO" })) -ForegroundColor $(if ($e.PuenteActivo) { "Green" } else { "Yellow" })
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

function Invoke-InstalacionCompleta {
    Invoke-Diagnostico
    $e = Get-Entorno
    $dbUser = $e.DbUser; $dbPass = ""; $connected = $false
    while (-not $connected) {
        $inPass = Read-Host "[1/6] Contrasena de MariaDB para '$dbUser' [Enter='prospecta2026#', 'ROOT' para usuario dedicado, 'C' cancelar]"
        if ($inPass -eq "C") { return }
        if ($inPass -eq "ROOT") {
            $rPass = Read-Host "      Contrasena de 'root' de MariaDB"
            $sql = "GRANT ALL PRIVILEGES ON $($e.DbName).* TO 'puente_app'@'localhost' IDENTIFIED BY 'prospecta2026#'; GRANT ALL PRIVILEGES ON $($e.DbName).* TO 'puente_app'@'127.0.0.1' IDENTIFIED BY 'prospecta2026#'; FLUSH PRIVILEGES;"
            & $e.MysqlExe -u root "-p$rPass" -P $e.DbPort -e $sql 2>$null
            if ($LASTEXITCODE -eq 0) { $dbUser = "puente_app"; $dbPass = "prospecta2026#"; $connected = $true; Write-Host "      Usuario 'puente_app' creado." -ForegroundColor Green }
            else { Write-Host "      Clave de root incorrecta." -ForegroundColor Red }
        } else {
            $cand = if ([string]::IsNullOrWhiteSpace($inPass)) { "prospecta2026#" } else { $inPass.Trim() }
            if ($e.MysqlExe) {
                & $e.MysqlExe -u $dbUser "-p$cand" -P $e.DbPort -D $e.DbName -e "SELECT 1;" 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { $dbPass = $cand; $connected = $true; Write-Host "      Conexion verificada." -ForegroundColor Green }
                else { Write-Host "      Contrasena incorrecta para '$dbUser'." -ForegroundColor Yellow }
            } else { $dbPass = $cand; $connected = $true }
        }
    }

    Write-Host "[2/6] Configurando recarga automatica de mesas en uniCenta..." -ForegroundColor Cyan
    if (Test-Path $propFile) {
        $lines = Get-Content $propFile; $r = $false; $t = $false
        $newLines = foreach ($l in $lines) {
            if ($l -match "^till\.autoRefreshTableMap=") { $r = $true; "till.autoRefreshTableMap=true" }
            elseif ($l -match "^till\.autoRefreshTimer=") { $t = $true; "till.autoRefreshTimer=5" }
            else { $l }
        }
        if (-not $r) { $newLines += "till.autoRefreshTableMap=true" }
        if (-not $t) { $newLines += "till.autoRefreshTimer=5" }
        [System.IO.File]::WriteAllLines($propFile, [string[]]$newLines, (New-Object System.Text.UTF8Encoding $false))
    }

    Write-Host "[3/6] Desplegando archivos en $destDir..." -ForegroundColor Cyan
    Get-CimInstance Win32_Process -EA 0 | Where-Object { $_.CommandLine -match "uniOPOS_PuenteWeb|iniciar_puente|server\.js" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
    Start-Sleep -Seconds 1
    if ($srcDir.TrimEnd("\") -ne $destDir.TrimEnd("\")) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Get-ChildItem -Path $destDir -EA 0 | Remove-Item -Recurse -Force -EA 0
        Get-ChildItem -Path $srcDir -Exclude "setup.ps1","instalar.bat" | Copy-Item -Destination $destDir -Recurse -Force
    }
    $cfgObj = [ordered]@{ port = 5000; dbHost = $e.DbHost; dbPort = $e.DbPort; dbUser = $dbUser; dbPassword = $dbPass; dbName = $e.DbName; unicentaJarPath = $e.JarPath; javaPath = "bin\jre\bin\java.exe" }
    [System.IO.File]::WriteAllText((Join-Path $destDir "config.json"), ($cfgObj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))

    Write-Host "[4/6] Aplicando plantilla de recibo (Mesero / Cajero)..." -ForegroundColor Cyan
    if ($e.MysqlExe) {
        $tmpXml = Join-Path $destDir "Printer.Ticket.active.xml"
        $rawXml = (& $e.MysqlExe -u $dbUser "-p$dbPass" -P $e.DbPort -D $e.DbName -N -r -e "SELECT CAST(CONTENT AS CHAR) FROM resources WHERE NAME='Printer.Ticket';") -join "`n"
        if ($rawXml -and $rawXml -notmatch "mesero_app") {
            $oldTag = '<line><text align="left" length="14">Atendido por:</text><text>${ticket.printUser()}</text></line>'
            $newTag = "#set(`$meseroApp = `"`")`n#foreach (`$tl in `$ticket.getLines())`n#if (`"`$!tl.getProperty('mesero_app')`"!=`"`")#set(`$meseroApp = `$tl.getProperty('mesero_app'))#end`n#end`n        #if (`$meseroApp != `"`")`n        <line><text align=`"left`" length=`"14`">Mesero:</text><text>`${meseroApp}</text></line>`n        <line><text align=`"left`" length=`"14`">Cajero:</text><text>`${ticket.printUser()}</text></line>`n        #else`n        <line><text align=`"left`" length=`"14`">Atendido por:</text><text>`${ticket.printUser()}</text></line>`n        #end"
            if ($rawXml.Contains($oldTag)) {
                [System.IO.File]::WriteAllText($tmpXml, $rawXml.Replace($oldTag, $newTag), (New-Object System.Text.UTF8Encoding $false))
                $xmlEsc = $tmpXml.Replace("\", "/")
                & $e.MysqlExe -u $dbUser "-p$dbPass" -P $e.DbPort -D $e.DbName -e "UPDATE resources SET CONTENT = LOAD_FILE('$xmlEsc') WHERE NAME IN ('Printer.Ticket', 'Printer.TicketPreview');"
            }
        }
    }

    Write-Host "[5/6] Configurando Firewall TCP 5000 y red privada..." -ForegroundColor Cyan
    Remove-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000","uniOPOS PuenteWeb 5000" -EA 0
    New-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow | Out-Null
    Get-NetConnectionProfile -EA 0 | Set-NetConnectionProfile -NetworkCategory Private -EA 0

    Write-Host "[6/6] Creando accesos directos e iniciando servicio..." -ForegroundColor Cyan
    $ws = New-Object -ComObject WScript.Shell; $dk = [Environment]::GetFolderPath("Desktop"); $st = [Environment]::GetFolderPath("Startup")
    $s1 = $ws.CreateShortcut("$dk\uniOPOS - Mesas.url"); $s1.TargetPath = "http://localhost:5000"; $s1.Save()
    $s2 = $ws.CreateShortcut("$dk\uniOPOS - Cocina y Comandas.url"); $s2.TargetPath = "http://localhost:5000/comandas.html"; $s2.Save()
    $vbs = Join-Path $destDir "iniciar_puente.vbs"
    $s3 = $ws.CreateShortcut("$st\uniOPOS Puente Web.lnk"); $s3.TargetPath = "wscript.exe"; $s3.Arguments = """$vbs"""; $s3.WorkingDirectory = $destDir; $s3.Save()
    Start-Process "wscript.exe" -ArgumentList """$vbs"""
    Write-Host "`nDESPLIEGUE COMPLETADO. URL Celulares: http://$($e.LocalIP):5000" -ForegroundColor Green
}

while ($true) {
    Invoke-Diagnostico
    Write-Host " SELECCIONE UNA OPCION DE DESPLIEGUE O MANTENIMIENTO:" -ForegroundColor Yellow
    Write-Host "  [1] Instalacion / Actualizacion Completa (6 Pasos)"
    Write-Host "  [2] Probar API en Vivo y Abrir en Navegador"
    Write-Host "  [3] Reiniciar Servicio Puente Web"
    Write-Host "  [4] Respaldar Configuracion y Plantillas (C:\uniOPOS_Backups)"
    Write-Host "  [5] Desinstalar Servicio Puente Web"
    Write-Host "  [0] Salir`n"
    $op = Read-Host " Opcion"
    switch ($op) {
        "1" { Invoke-InstalacionCompleta; Read-Host "`nPresiona ENTER para volver al menu" }
        "2" {
            try {
                $res = Invoke-RestMethod -Uri "http://localhost:5000/api/mesas" -TimeoutSec 4
                Write-Host "`nAPI Activa: $($res.places.Count) mesas cargadas correctamente." -ForegroundColor Green
                Start-Process "http://localhost:5000"
            } catch { Write-Host "`nEl servicio no responde en el puerto 5000." -ForegroundColor Red }
            Read-Host "Presiona ENTER para continuar"
        }
        "3" {
            Get-CimInstance Win32_Process -EA 0 | Where-Object { $_.CommandLine -match "uniOPOS_PuenteWeb|iniciar_puente|server\.js" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
            Start-Sleep -Seconds 1
            if (Test-Path "$destDir\iniciar_puente.vbs") { Start-Process "wscript.exe" -ArgumentList "`"$destDir\iniciar_puente.vbs`"" }
            Write-Host "`nServicio reiniciado." -ForegroundColor Green; Start-Sleep -Seconds 2
        }
        "4" {
            $bk = "C:\uniOPOS_Backups\Backup_$(Get-Date -Format 'yyyyMMdd_HHmm')"
            New-Item -ItemType Directory -Force -Path $bk | Out-Null
            Copy-Item "$destDir\config.json","$destDir\Printer.Ticket*.xml",$propFile -Destination $bk -EA 0
            Write-Host "`nRespaldo guardado en: $bk" -ForegroundColor Green; Read-Host "Presiona ENTER para continuar"
        }
        "5" {
            Get-CimInstance Win32_Process -EA 0 | Where-Object { $_.CommandLine -match "uniOPOS_PuenteWeb|iniciar_puente|server\.js" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
            Remove-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000","uniOPOS PuenteWeb 5000" -EA 0
            Remove-Item "$([Environment]::GetFolderPath('Startup'))\uniOPOS Puente Web.lnk" -EA 0
            Write-Host "`nServicio detenido y autoarranque eliminado." -ForegroundColor Yellow; Read-Host "Presiona ENTER para continuar"
        }
        "0" { exit }
    }
}
        "3" {
            Get-CimInstance Win32_Process -EA 0 | Where-Object { $_.CommandLine -match "uniOPOS_PuenteWeb|iniciar_puente|server\.js" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
            Start-Sleep -Seconds 1
            if (Test-Path "$destDir\iniciar_puente.vbs") { Start-Process "wscript.exe" -ArgumentList "`"$destDir\iniciar_puente.vbs`"" }
            Write-Host "`nServicio reiniciado." -ForegroundColor Green; Start-Sleep -Seconds 2
        }
        "4" {
            $bk = "C:\uniOPOS_Backups\Backup_$(Get-Date -Format 'yyyyMMdd_HHmm')"
            New-Item -ItemType Directory -Force -Path $bk | Out-Null
            Copy-Item "$destDir\config.json","$destDir\Printer.Ticket*.xml",$propFile -Destination $bk -EA 0
            Write-Host "`nRespaldo guardado en: $bk" -ForegroundColor Green; Read-Host "Presiona ENTER para continuar"
        }
        "5" {
            Get-CimInstance Win32_Process -EA 0 | Where-Object { $_.CommandLine -match "uniOPOS_PuenteWeb|iniciar_puente|server\.js" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA 0 }
            Remove-NetFirewallRule -DisplayName "uniOPOS Puente Web 5000","uniOPOS PuenteWeb 5000" -EA 0
            Remove-Item "$([Environment]::GetFolderPath('Startup'))\uniOPOS Puente Web.lnk" -EA 0
            Write-Host "`nServicio detenido y autoarranque eliminado." -ForegroundColor Yellow; Read-Host "Presiona ENTER para continuar"
        }
        "0" { exit }
    }
}
