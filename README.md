# uniOPOS PuenteWeb v2.0 (Colombia)

Sistema puente autocontenido para conectar dispositivos móviles (Android / iOS) con **uniCenta oPOS 5.0.1** y **MariaDB** mediante red Wi-Fi local, permitiendo la toma de comandas en mesas, productos auxiliares, notas libres y enrutamiento de impresión a cocina y barra.

---

## Descarga Directa (Windows)

Haz clic en el siguiente botón para descargar el instalador oficial:

[![Descargar uniOPOS PuenteWeb v2.0 para Windows](https://shields.io)](https://github.com)

*(Si el enlace directo descarga una versión previa, baja `uniOPOS_Installer.bat` desde la pestaña [Releases](https://github.com)).*

---

## Guía de Instalación Rápida (Modo Usuario)

1. Haz clic en el botón verde **Descargar para Windows** arriba para obtener `uniOPOS_Installer.bat`.
2. Abre tu carpeta **Descargas** y haz doble clic sobre **`uniOPOS_Installer.bat`** (acepta la solicitud de permisos de Administrador).
3. En el menú interactivo en pantalla, presiona **`1`** y **Enter**.
4. El instalador realizará todo automáticamente:
   * Descarga el entorno autocontenido (`Node.js v24` + `Java 21` + código fuente).
   * Extrae los archivos en `C:\uniOPOS_PuenteWeb`.
   * Lee la configuración de MariaDB desde `%USERPROFILE%\unicentaopos.properties`.
   * Abre el puerto **TCP 5000** en el Firewall de Windows.
   * Configura el arranque oculto en segundo plano con Windows.
   * Crea los **3 accesos directos en el Escritorio** (`Gestor uniOPOS PuenteWeb`, `uniOPOS Mesas` y `uniOPOS Cocina y Comandas`).

---

## Guía Técnica Paso a Paso y Comandos Aplicados (Mantenimiento / Respaldo)

### 1. Limpieza completa de instalación previa (PowerShell como Administrador)
```powershell
taskkill /F /IM node.exe /T 2>$null
Remove-NetFirewallRule -DisplayName "*uniOPOS*" -ErrorAction SilentlyContinue
netsh advfirewall firewall delete rule name="uniOPOS PuenteWeb 5000" 2>$null
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\*puente*" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\*uniOPOS*" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\uniOPOS_PuenteWeb" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\uniOPOS" -Recurse -Force -ErrorAction SilentlyContinue
```

### 2. Despliegue directo desde la nube sin navegador (PowerShell como Administrador)
```powershell
irm "https://githubusercontent.com" -OutFile "$(env:TEMP\uniOPOS_Installer.bat"; Start-Process "\)env:TEMP\uniOPOS_Installer.bat" -Verb RunAs
```

### 3. Verificación manual de red y procesos en Windows
```powershell
# Verificar proceso Node.js en segundo plano
tasklist /FI "IMAGENAME eq node.exe"

# Verificar escucha en puerto TCP 5000
netstat -ano | findstr :5000

# Verificar regla activa en Firewall de Windows
netsh advfirewall firewall show rule name="uniOPOS PuenteWeb 5000"
```

### 4. Parámetros requeridos en `unicentaopos.properties` (uniCenta oPOS 5.0.1)
Para que la caja principal actualice automáticamente las mesas tomadas desde celulares cada 5 segundos:
```properties
till.autoRefreshTableMap=true
till.autoRefreshTimer=5
```

---

## Estructura del Paquete Distribuible (`C:\uniOPOS_PuenteWeb`)

* `bin\node\node.exe`: Runtime Node.js v24 portable (sin dependencias externas).
* `bin\jre\bin\java.exe`: Runtime Java 21 compatible con clases v55.0 de uniCenta 5.0.1.
* `java-helper\`: `TicketBridge.class` y `plantilla.b64` para inyección nativa de tickets.
* `public\`: Interfaz web móvil (`index.html` y `comandas.html`).
* `server.js`: Servidor puente API REST y conexión MariaDB (`3316` / `3306`).
* `setup.ps1` e `iniciar_puente.vbs`: Configurador de entorno y lanzador silencioso.
* `uniOPOS_Installer.bat`: Gestor interactivo de instalación, IP, reinicio, diagnóstico y desinstalación.

