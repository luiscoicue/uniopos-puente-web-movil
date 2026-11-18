param([string]$DbPassword = "")
$ErrorActionPreference = "Stop"
$destDir = "C:\uniOPOS_PuenteWeb"
$propFile = Join-Path $env:USERPROFILE "unicentaopos.properties"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   INSTALADOR AUTOMATICO uniOPOS PuenteWeb v2.0" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Detectar entorno de uniCenta oPOS
$dbHost = "localhost"
$dbPort = 3316
$dbUser = "uniopos_app"
$dbName = "masterpos_dev"
$jarPath = "C:\Program Files\unicenta-opos\app\unicentaopos.jar"

if (Test-Path $propFile) {
    $props = Get-Content $propFile
    $uLine = $props | Where-Object { $_ -match "^db\.user=" } | Select-Object -First 1
    if ($uLine) { $dbUser = ($uLine -split "=", 2)[1].Trim() }
    $sLine = $props | Where-Object { $_ -match "^db\.schema=" } | Select-Object -First 1
    if ($sLine) { $dbName = ($sLine -split "=", 2)[1].Trim() }
    $urlLine = $props | Where-Object { $_ -match "^db\.URL=" } | Select-Object -First 1
    if ($urlLine -match ":(\d+)/") { $dbPort = [int]$matches[1] }
}

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    $inputPass = Read-Host "Contrasena de MariaDB para '$dbUser' [Enter para 'uniopos20262']"
    $dbPass = if ([string]::IsNullOrWhiteSpace($inputPass)) { "uniopos20262" } else { $inputPass.Trim() }
} else {
    $dbPass = $DbPassword.Trim()
}

# 2. Activar recarga automatica de mesas en uniCenta
if (Test-Path $propFile) {
    $lines = Get-Content $propFile
    $hasRefresh = $false; $hasTimer = $false
    $newLines = foreach ($line in $lines) {
        if ($line -match "^till\.autoRefreshTableMap=") { $hasRefresh = $true; "till.autoRefreshTableMap=true" }
        elseif ($line -match "^till\.autoRefreshTimer=") { $hasTimer = $true; "till.autoRefreshTimer=5" }
        else { $line }
    }
    if (-not $hasRefresh) { $newLines += "till.autoRefreshTableMap=true" }
    if (-not $hasTimer)   { $newLines += "till.autoRefreshTimer=5" }
    Set-Content -Path $propFile -Value $newLines -Encoding UTF8
}

# 3. Generar config.json en UTF-8 sin BOM
$cfgObj = @{
    port = 5000
    db = @{ host = $dbHost; port = $dbPort; user = $dbUser; password = $dbPass; database = $dbName }
    unicentaJar = $jarPath
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$destDir\config.json", ($cfgObj | ConvertTo-Json -Depth 5), $utf8NoBom)

# 4. Compilar TicketBridge.java con Java 21 Portable
$javac = "$destDir\bin\jre\bin\javac.exe"
if ((Test-Path $javac) -and (Test-Path $jarPath)) {
    & $javac -cp $jarPath "$destDir\java-helper\TicketBridge.java"
}

# 5. Regla de Firewall, Inicio Automatico y Arranque
if (-not (Get-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000" -EA SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow | Out-Null
}
$startupDir = [Environment]::GetFolderPath("Startup")
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("$startupDir\uniOPOS_PuenteWeb.lnk")
$sc.TargetPath = "wscript.exe"
$sc.Arguments = "`"$destDir\iniciar_puente.vbs`""
$sc.WorkingDirectory = $destDir
$sc.Save()

Start-Process -FilePath "$destDir\bin\node\node.exe" -ArgumentList "$destDir\server.js" -WorkingDirectory $destDir -WindowStyle Hidden
Start-Sleep -Seconds 2
Write-Host "Instalacion completada con exito en $destDir" -ForegroundColor Green