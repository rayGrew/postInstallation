# 📄 Plan Formal de Backup y Respaldo de Información  
**Versión 1.0**

---

## 1. Objetivo
Establecer un procedimiento estandarizado para el respaldo y recuperación de información de los usuarios con equipos asignados o identificados por nombre completo, garantizando la continuidad operativa y la protección de datos corporativos.

---

## 2. Alcance
Este plan aplica a los siguientes usuarios:

# 📋 Relación de Usuarios por Área (Plan de Backup)

## ✅ Administración
- kaori → **SI**
- gabriela → **SI**
- nestor → ❌ *No tiene equipo asignado, usa su equipo personal*

---

## ✅ Marketing
- alejandra → ❌ *No tiene equipo asignado, usa su equipo personal*
- mariana → **SI**
- yoshira → **SI**

## ✅ TI
- Raul → ❌ *No tiene equipo asignado, usa su equipo personal*
- Juan → **NO** --> Ubuntu
- Ray → **NO**  --> Ubuntu

---

## ✅ Guardadas
- humberto → **NO**
- cesar → **NO**
- kareem → **NO**
- gustavo → **NO**
- margarita → **NO** *(Pendiente recoger equipo)*

---

## 🚫 Usuarios sin área asignada
*(No considerados en el plan por no tener equipo corporativo o área definida)*

- *(ninguno en la lista actual)*

---

## 3. Frecuencia de Respaldo

| Tipo de respaldo | Frecuencia   | Contenido                               |
|------------------|-------------|------------------------------------------|
| **Diario**       | Continuo *(OneDrive sincroniza automáticamente los cambios en tiempo real)* | Documentos activos, archivos de trabajo |
| **Semanal**      | Copia de seguridad consolidada en la nube | Carpetas de usuario completas, correos, configuraciones (exportadas) |
| **Mensual**      | Respaldo administrativo en la nube | Exportación de usuarios y configuraciones clave desde OneDrive/Office 365 |

---

## 4. Método de Respaldo
- **Automatizado**:  
  - Sincronización nativa de **OneDrive corporativo** (todos los archivos se guardan en la nube).  
  - Versionado automático de archivos (historial de versiones de Office 365).  

- **Adicional (opcional)**:  
  - Descarga programada de respaldos desde OneDrive a almacenamiento externo (sólo como redundancia, no requerido en la operación diaria).

---

## 5. Ubicación del Respaldo
- **Primario y único**: Nube corporativa **OneDrive / Microsoft 365**.  
  *(No se usan discos externos ni NAS locales en este plan).*  

---

## 6. Política de Retención

| Tipo de respaldo | Retención   |
|------------------|-------------|
| **Versionado de archivos en OneDrive** | Hasta 500 versiones por archivo *(según configuración de tenant de M365)* |
| **Eliminados de OneDrive**             | 93 días en la papelera corporativa antes de eliminación definitiva |
| **Respaldo administrativo**            | 6 meses (archivos exportados/archivados opcionalmente por TI) |

---

## 7. Validación y Pruebas
- **Revisión trimestral** de recuperación de archivos desde OneDrive.  
- **Prueba de restauración** usando historial de versiones y recuperación desde papelera.  
- **Reporte semestral** de cumplimiento de política de backup en nube.

---

## 8. Responsabilidades
**Área de TI:**
- Configurar políticas de retención en OneDrive/Microsoft 365.  
- Monitorear alertas y estado de sincronización.  
- Apoyar en restauración de archivos si un usuario no puede hacerlo por sí mismo.  

**Usuarios:**
- Guardar **todos los documentos corporativos únicamente en OneDrive**.  
- No almacenar información relevante únicamente en el disco local.  
- Reportar inmediatamente cualquier incidencia de pérdida de acceso a archivos.

---

## 9. Contingencias
En caso de pérdida total de información en cuentas de usuario:  
1. Recuperación desde **papelera de OneDrive** (93 días de retención).  
2. Uso del **historial de versiones** en Office 365.  
3. Restauración desde copias administrativas exportadas por TI (si aplica).  
4. Comunicación inmediata a los usuarios afectados y restablecimiento de acceso.  

---

📌 **Nota:** Este documento debe revisarse y actualizarse al menos **una vez al año** o cuando haya cambios en la infraestructura tecnológica.
