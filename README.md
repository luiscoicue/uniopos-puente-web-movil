# Guía de Instalación y Operación — uniOPOS PuenteWeb v2.0

**Empresa:** UNIOPOS S.A.S. (Puerto Carreño, Vichada, Colombia)  
**Compatibilidad:** Windows 10 / Windows 11 (64-bit), uniCenta oPOS 5.0.1 y MariaDB (puerto `3316`).  
**Requisitos previos:** Ninguno adicional (incluye Node.js v24 y JRE portables dentro de `bin\`).

---

## 1. Instalación Automática (Recomendada para Clientes)

1. Copie la carpeta `PuenteWeb_v2_FINAL` al equipo donde corre **uniCenta oPOS** (por ejemplo, en `C:\Temp\PuenteWeb_v2_FINAL`).
2. Haga doble clic sobre **`instalar.bat`** y acepte el permiso de Administrador de Windows.
3. Cuando el asistente lo solicite en el paso `[1/6]`:
   - Ingrese la contraseña del usuario de MariaDB detectado (ej. `adminprospecta` o `prospecta2026#`).
   - O escriba **`ROOT`** e ingrese la clave de `root` de MariaDB para que el instalador cree automáticamente el usuario dedicado `puente_app` sin alterar la configuración de uniCenta oPOS.
4. Al finalizar el paso `[6/6]`, cierre y vuelva a abrir **uniCenta oPOS** para activar la recarga automática de mesas (`autoRefreshTableMap=true` cada 5 segundos) y la plantilla de recibo con **Mesero** y **Cajero**.

### Instalación manual desde PowerShell (Administrador)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\Temp\PuenteWeb_v2_FINAL\setup.ps1"
```

---

## 2. Arquitectura y Funcionalidades Incluidas (v2.0)

- **Servicio Web Portable (`C:\uniOPOS_PuenteWeb`):** Opera en el puerto TCP `5000` mediante `iniciar_puente.vbs` (en segundo plano y con inicio automático con Windows).
- **Acceso Móvil por QR y Validación PIN:** Los meseros escanean el QR desde el navegador y se autentican con su PIN de uniCenta (validado por SHA-1 contra la tabla `people`).
- **Productos Auxiliares Nativos (`ISCOM=1`):** Lee las relaciones de `products_com` y serializa cada modificador con `product.com="true"` en `TicketBridge.java`.
- **Suma de Rondas en Mesa:** Permite agregar nuevos pedidos a mesas ya ocupadas conservando las líneas previas y generando un `UUID` único por ticket.
- **Botones Operativos:**
  - **Enviar (Azul):** Registra la orden en `sharedtickets` y la despacha al Monitor KDS (`comandas.html`) separada por estación (**Cocina P2** / **Barra P3**).
  - **Caja (Verde):** Carga los productos directamente a la cuenta de la mesa sin emitir comanda al Monitor KDS.
- **Trazabilidad en Factura (`Printer.Ticket`):** Guarda la propiedad `mesero_app` en `TicketLineInfo` para imprimir por separado **Mesero** (quien tomó la orden) y **Cajero** (quien cobró en caja).

---

## 3. URLs de Acceso en Red Local (Wi-Fi)

- **Toma de Pedidos (Meseros / Celulares):** `http://<IP_DEL_SERVIDOR>:5000`
- **Monitor de Cocina y Barra (KDS / Tablets):** `http://<IP_DEL_SERVIDOR>:5000/comandas.html`

Para consultar la IP local del servidor en PowerShell:
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \(_.InterfaceAlias -notmatch "Loopback\vert{}vEthernet\vert{}WSL" -and \)_.IPAddress -notlike "169.254.*" } | Select-Object InterfaceAlias, IPAddress
```

---

## 4. Comandos de Verificación y Mantenimiento

### Verificar estado del servicio y mesas cargadas
```powershell
Invoke-RestMethod -Uri "http://localhost:5000/api/mesas" | Select-Object ok, @{N='TotalMesas';E={\$_.places.Count}}
```

### Reiniciar manualmente el servidor Puente Web
```powershell
Get-CimInstance Win32_Process | Where-Object { \(_.CommandLine -match "uniOPOS_PuenteWeb\vert{}server\.js" } \vert{} ForEach-Object { Stop-Process -Id \)_.ProcessId -Force }
Start-Sleep -Seconds 1
Start-Process "wscript.exe" -ArgumentList "`"C:\uniOPOS_PuenteWeb\iniciar_puente.vbs`""
```

### Recompilar `TicketBridge.java` (solo si se modifica el puente Java)
```powershell
& "C:\uniOPOS_PuenteWeb\bin\jre\bin\javac.exe" -cp "C:\Program Files\unicenta-opos\app\unicentaopos.jar" "C:\uniOPOS_PuenteWeb\java-helper\TicketBridge.java"
```
