# uniOPOS Puente Web Móvil v2.0 (uniCenta 5.0.1 + MariaDB 3316 + Java 21)

Puente web autónomo y portable para toma de comandas móviles desde celulares Android/iOS sobre **uniCenta oPOS 5.0.1 MSI** sin modificar el código fuente del POS.

## Requisitos y Estructura
- **uniCenta oPOS 5.0.1 MSI** (`C:\Program Files\unicenta-opos\app\unicentaopos.jar`)
- **MariaDB** en el puerto `3316` (usuario `uniopos_app`)
- **Java 21 Portable** en `bin\jre\bin\` (`java.exe` y `javac.exe`)
- **Node.js Portable** en `bin\node\node.exe` (puerto `5000`)

## Funcionalidades Implementadas
1. **Login Táctil con PIN de uniCenta (`GET /api/meseros`, `POST /api/auth`)**: Valida el hash `SHA1` de la tabla `people` mediante `Hashcypher.authenticate` en `TicketBridge.java`.
2. **Conexión Rápida por QR (`GET /api/info`)**: Detecta automáticamente la IP LAN (`http://IP:5000`) y muestra el código QR en pantalla.
3. **Lectura y Escritura Binaria (`TicketBridge READ / WRITE`)**: Serializa objetos `TicketInfo` y `TicketLineInfo` con auxiliares/adiciones (`product.com`) y notas, actualizando `sharedtickets` y `places` con el mesero autenticado.
4. **Auto-refresco de Mesas cada 3 segundos** y separación automática de comandas **Cocina / Bar**.

## Comandos de Compilación y Arranque
```powershell
cd C:\uniOPOS_PuenteWeb
.\bin\jre\bin\javac.exe -cp "C:\Program Files\unicenta-opos\app\unicentaopos.jar" .\java-helper\TicketBridge.java
Start-Process -FilePath "C:\uniOPOS_PuenteWeb\bin\node\node.exe" -ArgumentList "C:\uniOPOS_PuenteWeb\server.js" -WorkingDirectory "C:\uniOPOS_PuenteWeb" -WindowStyle Hidden
```