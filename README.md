# 📱 uniOPOS PuenteWeb v2.0 (Comanda Móvil)

Sistema puente externo y portátil para conectar teléfonos móviles vía Wi-Fi con **uniCenta oPOS 5.0.1** sobre **MariaDB** sin modificar el código fuente del POS. Soporta mapa de mesas en tiempo real, productos auxiliares (`isCom`), notas de cocina/bar y sincronización directa con `sharedtickets`.

- **Descargar Instalador directo (v2.0.0):** https://github.com
- **Descargar Paquete Portable ZIP (v2.0.0):** https://github.com
- **Ver Release v2.0.0:** https://github.com

---

## ⚡ Instalación Express por PowerShell (Recomendada)

Abre **PowerShell como Administrador** en el PC servidor de uniCenta oPOS y ejecuta esta única línea:

```powershell
New-Item -ItemType Directory -Force -Path "C:\uniOPOS_PuenteWeb" | Out-Null; curl.exe -L --fail --retry 3 "https://github.com" -o "C:\uniOPOS_PuenteWeb\uniOPOS_Installer.bat"; Start-Process "C:\uniOPOS_PuenteWeb\uniOPOS_Installer.bat" -Verb RunAs
```

1. En el menú interactivo selecciona **Opción 1 (Instalar / Actualizar)**.
2. El asistente descargará el paquete portable, configurará `C:\uniOPOS_PuenteWeb\config.json` (UTF-8 sin BOM), abrirá el puerto **TCP 5000** (`uniOPOS PuenteWeb 5000`) e iniciará el servicio en segundo plano.
3. Desde cualquier teléfono conectado al mismo Wi-Fi abre `http://<IP-DEL-SERVIDOR>:5000` (ejemplo: `http://192.168.1.160:5000`).

---

## 🏗 Estructura del Proyecto

- `uniOPOS_Installer.bat`: Gestor interactivo de instalación, reinicio, estado y desinstalación.
- `src/server.js`: Servidor Node.js (puerto `5000`) conectado a MariaDB (`masterpos_dev`).
- `src/java-helper/TicketBridge.java`: Serializador Java (`--release 11`) compatible con `TicketInfo` de uniCenta oPOS 5.0.1 con generación de UUID único por comanda (`m_sId`).
- `src/setup.ps1`: Configurador automático de credenciales, Firewall y arranque silencioso (`iniciar_puente.vbs`).
- `src/public/`: Interfaz web móvil para toma de pedidos por mesa.
- `src/bin/`: Runtime autocontenido (`node` v24 y `jre` 21).

---

## 🛠 Guía de Respaldo, Empaquetado y Actualización en GitHub (Paso a Paso)

### 1. Recompilar `TicketBridge.java` (si se modifica el puente Java)
```powershell
& "C:\Program Files\JetBrains\PyCharm Community Edition 2024.3.1.1\jbr\bin\javac.exe" --release 11 -cp "C:\Program Files\unicenta-opos\app\unicentaopos.jar" "E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0\src\java-helper\TicketBridge.java"
```

### 2. Reempaquetar el archivo portable ZIP con `tar.exe`
```powershell
tar.exe -a -cf "E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0\dist\uniOPOS_PuenteWeb_v2.0_Portable.zip" -C "E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0\src" *
```

### 3. Subir cambios de código y documentación a la rama `main`
```powershell
cd "E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0"; git add .; git commit -m "fix: UUID unico por comanda en TicketBridge, password MariaDB y README v2.0.0"; git push origin main
```

### 4. Actualizar el asset `uniOPOS_PuenteWeb_v2.0_Portable.zip` en el Release `v2.0.0`
```powershell
gh release upload v2.0.0 "E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0\dist\uniOPOS_PuenteWeb_v2.0_Portable.zip" --clobber --repo luiscoicue/uniopos-puente-web-movil
```