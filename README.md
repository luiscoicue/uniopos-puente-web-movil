# uniOPOS - Puente Web de Comandas Móviles (v2.0 Autocontenido)

Solución externa no invasiva para **uniCenta oPOS 5.0.1 + MariaDB** en Windows que habilita toma de pedidos desde celulares Android vía Wi-Fi local y monitor en tiempo real para Cocina y Bar.

## Novedades de la versión 2.0
* **Instalador Único Autocontenido (`dist/uniOPOS_PuenteWeb_v2.0_Setup.exe`):** Incluye Node.js portátil, JRE portátil y dependencias offline (`node_modules`).
* **Cálculo Nativo de Impuestos Blindado:** Consulta dinámicamente las tablas `products` y `taxes` de MariaDB e inyecta todas las propiedades nativas de `TicketLineInfo`, eliminando el error `WRN_00_0000` al imprimir comandas.
* **Despliegue 1-Clic (`src/instalar.bat` + `src/setup.ps1`):** Lee `%USERPROFILE%\unicentaopos.properties`, solicita y prueba la contraseña de MariaDB, instala en `C:\uniOPOS_PuenteWeb`, configura Firewall TCP 5000, cambia la red a `Private`, crea accesos directos y activa el autoarranque.

## Prueba en equipo de desarrollo
1. Detén cualquier instancia manual previa en `C:\PuenteWeb_uniopos\PuenteWeb`.
2. Ejecuta `dist\uniOPOS_PuenteWeb_v2.0_Setup.exe` como Administrador.
3. Ingresa la contraseña de MariaDB (`uniopos20262`) cuando el asistente la solicite.
