# uniOPOS Puente Web Móvil v2.0 (uniCenta 5.0.1 + MariaDB 3316 + Java 21)

Puente web autónomo y portable para toma de comandas móviles desde celulares Android/iOS sobre **uniCenta oPOS 5.0.1 MSI** sin modificar el código fuente del POS.

## Arquitectura y Entorno Estándar
- **uniCenta oPOS 5.0.1 MSI:** `C:\Program Files\unicenta-opos\app\unicentaopos.jar`
- **Base de Datos:** MariaDB en puerto `3316` (usuario `uniopos_app`)
- **Java 21 Portable:** `bin\jre\bin\` (`java.exe` y `javac.exe`)
- **Node.js Portable:** `bin\node\node.exe` (puerto `5000`)

## Soluciones Técnicas Documentadas (uniCenta 5.0.1)
1. **Eliminación de `WRN_00_0006` (Impuestos):** Cada `TicketLineInfo` se construye con el constructor de 5 parámetros (`productId, qty, price, tax, props`), poblando explícitamente `product.taxcategoryid`, `product.printer`, `ticket.updated=true`, `sendstatus=No` y ejecutando `ticket.setTaxes(null)` antes de serializar.
2. **Eliminación de `Duplicate entry ... for key PRIMARY`:** Como `TicketInfo` en uniCenta 5.0.1 no expone `setId(String)`, al clonar `plantilla.b64` se asigna un `UUID.randomUUID().toString()` nuevo mediante reflexión sobre el campo privado `m_sId`.
3. **Autenticación Nativa por PIN (`GET /api/meseros`, `POST /api/auth`):** Valida el hash `SHA1` de la tabla `people` mediante `Hashcypher.authenticate` en `TicketBridge.java`.
4. **Conexión Rápida por QR (`GET /api/info`):** Detecta la IP LAN (`http://IP:5000`) y genera el código QR en pantalla.

## Comandos Exactos de Compilación, Prueba y Arranque
```powershell
cd C:\uniOPOS_PuenteWeb
.\bin\jre\bin\javac.exe -cp "C:\Program Files\unicenta-opos\app\unicentaopos.jar" .\java-helper\TicketBridge.java
.\bin\jre\bin\java.exe -cp ".\java-helper;C:\Program Files\unicenta-opos\app\unicentaopos.jar" TicketBridge AUTH "1234" "sha1:7110EDA4D09E062AA5E4A390B0A572AC0D2C0220"
Start-Process -FilePath "C:\uniOPOS_PuenteWeb\bin\node\node.exe" -ArgumentList "C:\uniOPOS_PuenteWeb\server.js" -WorkingDirectory "C:\uniOPOS_PuenteWeb" -WindowStyle Hidden
```
## Actualización v2.0.1 - Suma de Adiciones y Comandas KDS

- **Adiciones en sharedtickets:** Corregida la lectura de `rows[0].content` y `allTaxes[0]` en `server.js` para fusionar nuevos productos con la cuenta activa de la mesa en uniCenta oPOS 5.0.1 sin sobreescribir los anteriores.
- **Agrupación en Cocina y Bar (/cocina, /bar):** Las adiciones en una mesa activa se suman a la tarjeta existente etiquetadas con `[ADICIÓN]`.

### Comandos de instalación y reinicio rápido

```powershell
# Reiniciar servicio Node.js
PowerShell -Command "Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Process wscript.exe 'C:\uniOPOS_PuenteWeb\iniciar_puente.vbs'"
```
