# Instalador con Menú – Versión 1.0

Este script en **PowerShell** permite instalar de manera interactiva y controlada un conjunto de aplicaciones comunes para entornos **General** y **Dev en Windows 11**.  
Incluye detección profunda de software ya instalado, instalación con **winget**, **Microsoft Store** o descarga directa, y salida clara con logs y estado final.

---

## ✨ Características principales

- Menú inicial con dos perfiles:
  - **General** → Microsoft 365 Apps, Zoom.
  - **Dev W11** → Todo lo anterior más VSCode, Cursor, Zen Browser, Thunderbird, SSMS, Termius, cliente API (Postman o Insomnia) y Docker Desktop.
- Escaneo profundo de estado actual usando:
  - `winget list`
  - Registro de Windows
  - `Get-Package`
  - Rutas conocidas de instalación
- Instalación automática desde:
  - **winget**
  - **Microsoft Store**
  - **Descarga directa** (cuando no está disponible en los anteriores)
- Progreso en vivo de cada instalación.
- Selección interactiva de pendientes a instalar.
- Logs detallados en `%TEMP%`.
- Salidas claras en consola (OK/ERROR).

---

## 📋 Requisitos

- Windows 10/11 con **PowerShell 5.1+** o **PowerShell Core**.
- **Permisos de Administrador**.
- **winget** instalado (viene con *App Installer* desde Microsoft Store).
- Conexión a internet.

---

## 🚀 Uso

1. Descargar el script `install_menu.ps1`.
2. Ejecutar **PowerShell como Administrador**.
3. Permitir ejecución de scripts (si es necesario):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope Process
4. Ejecución:
   ```powershell
   .\install_menu.ps1