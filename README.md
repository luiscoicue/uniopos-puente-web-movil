# 📱 uniOPOS PuenteWeb v2.0 (Comanda Móvil)

Sistema puente para conectar dispositivos móviles vía Wi-Fi con **uniCenta oPOS 5.0.1** sobre **MariaDB**, soportando mesas, productos auxiliares y sincronización automática.

[![Descargar Instalador v2.0](https://shields.io)](https://github.com)
[![Ver Release v2.0.0](https://shields.io)](https://github.com)

---

## ⚡ Instalación Express por PowerShell (Recomendada)

Ejecuta el comando de instalación automatizada en **PowerShell** sobre el PC servidor POS.

---

## 🏗️ Arquitectura del Proyecto

El paquete incluye dependencias autocontenidas, interfaz web móvil, scripts de configuración y el gestor interactivo de instalación.

---

## 🚀 Guía de Instalación Manual y Comandos

1. Descarga el instalador desde las **[Releases v2.0.0](https://github.com)** y ejecuta el instalador.
2. Configura los parámetros necesarios en uniCenta oPOS 5.0.1.

### Comandos de Desarrollo y Empaquetado
```powershell
cd E:\uniOPOS_APP\Repositorio_uniOPOS_PuenteWeb_v2.0
Compress-Archive -Path ".\uniOPOS_Installer.bat" -DestinationPath ".\uniOPOS_Installer_v2.0.zip" -Force
Remove-Item ".\uniOPOS_Installer_v2.0.zip" -Force
git add README.md
git commit -m "docs: restaurar guia completa, enlaces directos a v2.0.0 y comando express"
git push origin main
```
