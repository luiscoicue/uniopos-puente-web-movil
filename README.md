# uniOPOS PuenteWeb v2.0 (Comanda Movil + Instalador Offline)

Sistema puente externo y portatil para conectar telefonos moviles via Wi-Fi con **uniCenta oPOS 5.0.1** sobre **MariaDB** sin modificar el codigo fuente del POS.

- **Instalador Offline Local:** `uniOPOS_Installer_Local.bat` + `uniOPOS_PuenteWeb_v2.0_Portable.zip`
- **Release v2.0.0:** 
https://github.com/luiscoicue/uniopos-puente-web-movil/releases/tag/v2.0.0
- **Descarga directa ZIP:** 
https://github.com/luiscoicue/uniopos-puente-web-movil/releases/download/v2.0.0
/uniOPOS_PuenteWeb_v2.0_Portable.zip

## 1. Instalacion 100% Offline (Recomendada en Restaurante)

1. Copie `uniOPOS_Installer_Local.bat` y `uniOPOS_PuenteWeb_v2.0_Portable.zip` en una misma carpeta (por ejemplo `C:\UNIOPOS` o una memoria USB).
2. Haga doble clic en **`uniOPOS_Installer_Local.bat`** (aceptar permisos de Administrador).
3. El instalador extrae el paquete en `C:\uniOPOS_PuenteWeb`, detecta `unicentaopos.properties`, solicita la clave de MariaDB, configura el firewall TCP 5000 y arranca el puente oculto.

## 2. Arranque Oculto y Bandeja del Sistema (System Tray)

- `iniciar_puente.vbs` ejecuta Node.js (`server.js`) y `tray_monitor.ps1` en modo 100% oculto sin ventanas de consola.
- En el area de notificaciones (junto al reloj de Windows) aparece un indicador de estado:
  - **Verde:** Puente activo en puerto 5000.
  - **Rojo:** Puente detenido.
- Clic derecho sobre el icono permite abrir **Mesas (Celular)**, **Cocina / Comandas**, **Reiniciar Puente** o **Detener y Salir**.

## 3. Acceso desde Celulares Android y Cocina

- **Mesas y Toma de Pedidos (PIN Mesero):** `
http://192.168.1.160:5000
` (local: `
http://localhost:5000
`)
- **Monitor de Cocina / Comandas:** `
http://192.168.1.160:5000
/comandas.html`

## 4. Estructura del Proyecto

- `uniOPOS_Installer_Local.bat`: Instalador 100% offline con elevacion UAC y extraccion via `tar.exe`.
- `setup.ps1`: Configurador automatico de `config.json` (UTF-8 sin BOM), `till.autoRefreshTableMap=true`, Firewall y autoarranque.
- `iniciar_puente.vbs`: Lanzador silencioso (`WshShell.Run ..., 0, False`).
- `tray_monitor.ps1`: Indicador de estado Verde/Rojo en la bandeja del sistema.
- `server.js`: Servidor Node.js (puerto 5000) conectado a MariaDB y puente Java.
- `java-helper/TicketBridge.java`: Serializador Java (`--release 11`) y autenticacion `Hashcypher` contra `unicentaopos.jar`.
- `public/`: Interfaz web movil (`index.html`) y monitor de cocina (`comandas.html`).

## 5. Guia de Respaldo, Empaquetado y Actualizacion en GitHub

### Reempaquetar paquete portable offline (sin `config.json`)
```powershell
\$tmp="C:\UNIOPOS\_stage_v2"; if(Test-Path tmp)Remove-Item tmp -Recurse -Force}; New-Item -ItemType Directory -Path \(tmp \vert{} Out-Null; Get-ChildItem "C:\uniOPOS_PuenteWeb" -Exclude "config.json","instalar.bat","uniOPOS_Installer.bat" \vert{} Copy-Item -Destination \)tmp -Recurse -Force; \(zipOut="C:\UNIOPOS\uniOPOS_PuenteWeb_v2.0_Portable.zip"; if(Test-Path \)zipOut){Remove-Item zipOut -Force; tar.exe -a -cf zipOut -C tmp *; Remove-Item tmp -Recurse -Force
```

### Subir cambios a la rama `main`
```powershell
cd "C:\uniOPOS_PuenteWeb"; git --no-pager add .; git --no-pager commit -m "docs(v2.0): guia paso a paso instalacion offline y system tray"; git --no-pager push origin main
```