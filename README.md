# Guía de Instalación y Despliegue — uniOPOS PuenteWeb v2.0

**Desarrollado por:** Ing. Luis Coicue Rodríguez — UNIOPOS S.A.S. (Puerto Carreño, Vichada, Colombia)  
**Compatibilidad:** Windows 10 / Windows 11 (x64) · uniCenta oPOS v5.0.1 · MariaDB 10.x / 11.x

---

## 1. Descripción General

**uniOPOS PuenteWeb v2.0** conecta teléfonos móviles Android/iOS y tablets de cocina/bar en la red Wi-Fi local directamente con **uniCenta oPOS v5.0.1** y **MariaDB**, sin modificar el código fuente del punto de venta.

### Características principales incluidas en este paquete
* **100 % Autónomo (Portable):** Incluye `bin\node.exe`, `bin\jre` y `node_modules` preinstalados; no requiere internet ni instalaciones globales previas en el equipo del cliente.
* **Acceso Rápido para Meseros:** Escaneo de código **QR** desde el navegador del celular y autenticación mediante **teclado PIN** (validación SHA-1 contra la tabla `people` de uniCenta oPOS).
* **Gestión Completa de Comandas:** Selección de mesas en tiempo real, productos por categoría, auxiliares nativos (`attributesetinstance`), adición de rondas sucesivas a mesas abiertas y vista de resumen de cuenta.
* **Trazabilidad en Tirilla (`Printer.Ticket.xml`):** Inyección automática en MariaDB (vía `FROM_BASE64`) para imprimir por separado el **Mesero** que tomó el pedido y el **Cajero** que realizó el cobro.
* **Monitor de Cocina y Bar:** Pantalla en tiempo real (`/comandas.html`) con alertas visuales de tiempo para tablets o pantallas en cocina.

---

## 2. Requisitos Previos en el Equipo del Cliente

1. **uniCenta oPOS v5.0.1** instalado y configurado contra su base de datos MariaDB (`unicentaopos.properties` existente en `%USERPROFILE%`).
2. **Servicio MariaDB** activo y en ejecución (puerto habitual `3306` o `3316`).
3. **Red Wi-Fi local** compartida entre el servidor POS (Windows) y los dispositivos móviles de los meseros.

---

## 3. Instalación Paso a Paso (Modo Automático Recomendado)

1. **Copiar y extraer el paquete:**
   * Copie el archivo **`uniOPOS_PuenteWeb_v2.0_Comercial.zip`** al Escritorio o a `C:\Temp` del servidor POS (evite ejecutarlo directamente desde carpetas de red o memorias USB).
   * Haga **clic derecho -> Extraer todo...** sobre el archivo `.zip`.
2. **Ejecutar el instalador como Administrador:**
   * Abra la carpeta extraída y haga **clic derecho sobre `instalar.bat` -> Ejecutar como administrador**.
3. **Ingresar credenciales de MariaDB:**
   * El asistente detectará automáticamente el usuario, puerto y esquema desde `unicentaopos.properties`.
   * Escriba la contraseña del usuario de MariaDB cuando el asistente la solicite y presione **ENTER**.
4. **Finalizar:**
   * Verifique que los **6 pasos (`[1/6]` a `[6/6]`)** finalicen en verde con el mensaje **`INSTALACION COMPLETADA CON EXITO (v2.0)`**.
   * Presione **ENTER** para cerrar la ventana; el servicio quedará ejecutándose en segundo plano y con inicio automático junto con Windows.

---

## 4. Verificación Post-Instalación

Para comprobar desde PowerShell en el servidor POS que el servicio web y la base de datos responden correctamente:

```powershell
Invoke-RestMethod "http://localhost:5000/api/mesas" | Select-Object ok, @{N='Mesas';E={\$_.places.Count}}
```

* **Acceso Meseros (Celulares Wi-Fi):** `http://<IP-DEL-SERVIDOR>:5000`
* **Monitor Cocina / Bar:** `http://<IP-DEL-SERVIDOR>:5000/comandas.html`
* **Recarga automática en uniCenta oPOS:** Reinicie uniCenta oPOS tras la instalación para que aplique `till.autoRefreshTableMap=true` (actualización cada 5 segundos).

---

## 5. Comandos de Mantenimiento, Respaldo y Desinstalación

### Reiniciar manualmente el servicio PuenteWeb
```powershell
Get-Process -Name node -EA 0 | Stop-Process -Force; Start-Process "wscript.exe" -ArgumentList "`"C:\uniOPOS_PuenteWeb\iniciar_puente.vbs`""
```

### Respaldar configuración y plantilla de recibo
```powershell
Copy-Item "C:\uniOPOS_PuenteWeb\config.json", "C:\uniOPOS_PuenteWeb\Printer.Ticket.xml" -Destination "C:\Backup_uniOPOS_PuenteWeb" -Force
```

### Desinstalación limpia (si se requiere reinstalar desde cero)
```powershell
Set-Location C:\; Get-Process -Name node, java, javaw, wscript -EA 0 | Stop-Process -Force; Start-Sleep 1; Remove-Item "C:\uniOPOS_PuenteWeb", "\(env:USERPROFILE\Desktop\uniOPOS*", "\)([Environment]::GetFolderPath('Startup'))\uniOPOS Puente Web.lnk" -Recurse -Force -EA 0; Remove-NetFirewallRule -DisplayName "uniOPOS PuenteWeb 5000", "uniOPOS Puente Web 5000" -EA 0
```