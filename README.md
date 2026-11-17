# 📱 uniOPOS PuenteWeb v2.0 (Comanda Móvil)

Sistema puente ligero y portátil diseñado para conectar dispositivos móviles (tablets y smartphones en red local Wi-Fi) con **uniCenta oPOS 5.0.1** sobre **MariaDB** (`3316` / `3306`), permitiendo la toma de comandas en tiempo real para salón (**24 mesas**), manejo de productos auxiliares (`isCom: true`) y sincronización automática (`autoRefreshTimer=5`).

[![Descargar Instalador v2.0](https://shields.io)](https://github.com)
[![Ver Último Release](https://shields.io)](https://github.com)

---

## 🏗️ Arquitectura del Proyecto

El paquete portable (`uniOPOS_PuenteWeb_v2.0_Portable.zip`, 263 MB) incluye todas las dependencias autocontenidas para operar en `C:\uniOPOS_PuenteWeb` sin afectar instalaciones previas de Java o Node.js en el equipo servidor:

* **`bin\node`** (Node.js v24 portable): Ejecuta el servidor backend y la API REST/WebSocket (`server.js`).
* **`bin\jre`** (Java Runtime Environment 21 portable): Ejecuta el conector puente con la base de datos (`java-helper`).
* **`public\`**: Interfaz web móvil responsiva para meseros.
* **`setup.ps1`**: Script de configuración inicial, reglas de firewall y acceso directo.
* **`iniciar_puente.vbs`**: Lanzador silencioso en segundo plano (sin ventanas de consola visibles).
* **`uniOPOS_Installer.bat`**: Gestor interactivo de 6 opciones para instalación, diagnóstico y mantenimiento.

---

## 🚀 Guía de Instalación Rápida (PC Servidor POS)

1. Descarga el archivo **[uniOPOS_Installer_v2.0.zip](https://github.com)** (o accede a **[Releases](https://github.com)**).
2. Extrae el contenido y haz doble clic sobre **`uniOPOS_Installer.bat`**.
3. Selecciona la **Opción 1 (Instalar / Actualizar desde GitHub)** para desplegar en `C:\uniOPOS_PuenteWeb` y crear los **3 accesos directos en el Escritorio**.

### Opciones de `uniOPOS_Installer.bat`
* **Opción 1:** Instalar o actualizar desde GitHub en `C:\uniOPOS_PuenteWeb`.
* **Opción 2:** Ver dirección IP local y URL para conectar celulares.
* **Opción 3:** Reiniciar servicio PuenteWeb (Node y Java).
* **Opción 4:** Diagnóstico de red, firewall y puertos MariaDB (`3316` / `3306`).
* **Opción 5:** Regenerar los 3 accesos directos en el Escritorio.
* **Opción 6:** Desinstalar y limpiar `C:\uniOPOS_PuenteWeb`.

---

## ⚙️ Parámetros de Sincronización (uniCenta oPOS 5.0.1)

* **Base de datos:** MariaDB (puerto `3316` o `3306`).
* **Salón y auxiliares:** Configurado para **24 mesas** e ítems auxiliares (`isCom: true`).
* **Refresco en caja:** Configurar `autoRefreshTimer=5` en uniCenta oPOS.

---

## 🛠️ Comandos de Mantenimiento y Empaquetado

```powershell
cd E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0
Compress-Archive -Path ".\uniOPOS_Installer.bat" -DestinationPath ".\uniOPOS_Installer_v2.0.zip" -Force
Remove-Item ".\uniOPOS_Installer_v2.0.zip" -Force
git add README.md
git commit -m "docs: actualizar badges de descarga a releases/latest y documentar comandos"
git push origin main
```
