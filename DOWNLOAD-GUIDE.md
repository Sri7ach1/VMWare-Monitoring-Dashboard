# 📦 Guía de Descarga - VMware Monitoring Dashboard

Esta guía te indica qué archivos descargar y dónde colocarlos para tener el proyecto completo.

## 🎯 Estructura Final del Proyecto

```
VMware-Monitoring-Dashboard/
├── README.md
├── INSTALL.md
├── LICENSE
├── .gitignore
├── Install-SQLite.ps1
├── Initialize-MonitoringDatabase.ps1
├── Collect-VMwareData.ps1
├── Start-DashboardServer.ps1
├── Download-ChartJS.ps1
├── Test-Dashboard.ps1
├── Package-Project.ps1
├── connect.ps1.example
├── dashboard/
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       ├── api.js
│       ├── charts.js
│       └── app.js
├── data/
│   └── .gitkeep
└── docs/
    ├── API.md
    └── SCHEMA.md
```

## 📥 Archivos para Descargar

### 📄 Documentación (Raíz del proyecto)

1. **README.md** - Documentación principal
2. **INSTALL.md** - Guía de instalación detallada
3. **LICENSE** - Licencia del proyecto
4. **.gitignore** - Archivos a ignorar en Git

### 🔧 Scripts PowerShell (Raíz del proyecto)

5. **Install-SQLite.ps1** - Instalador de SQLite
6. **Initialize-MonitoringDatabase.ps1** - Crear base de datos
7. **Collect-VMwareData.ps1** - Script principal de recopilación
8. **Start-DashboardServer.ps1** - Servidor web
10. **Test-Dashboard.ps1** - Diagnóstico
11. **Package-Project.ps1** - Empaquetar proyecto
12. **connect.ps1.example** - Plantilla de conexión

### 🌐 Dashboard Web (dashboard/)

#### HTML
13. **dashboard/index.html** - Página principal

#### CSS (dashboard/css/)
14. **dashboard/css/style.css** - Estilos

#### JavaScript (dashboard/js/)
15. **dashboard/js/api.js** - API calls
16. **dashboard/js/charts.js** - Gráficos
17. **dashboard/js/app.js** - Aplicación principal
18. **dashboard/js/chart.js** - Librería Chart.js

### 📚 Documentación Adicional (docs/)

19. **docs/API.md** - Documentación API REST
20. **docs/SCHEMA.md** - Esquema de base de datos

### 📁 Directorios Adicionales

- **data/** - Directorio para la base de datos (crear vacío)

---

## 🚀 Pasos para Armar el Proyecto

### Opción A: Descarga Manual (Recomendado)

1. **Crea la estructura de carpetas:**
```powershell
mkdir VMware-Monitoring-Dashboard
cd VMware-Monitoring-Dashboard
mkdir dashboard, dashboard\css, dashboard\js, data, docs
```

2. **Descarga los archivos y colócalos según la estructura:**
   - Archivos raíz → en `VMware-Monitoring-Dashboard\`
   - Archivos HTML → en `dashboard\`
   - Archivos CSS → en `dashboard\css\`
   - Archivos JS → en `dashboard\js\`
   - Documentación → en `docs\`

3. **Configura tu conexión:**
```powershell
Copy-Item connect.ps1.example connect.ps1
notepad connect.ps1  # Edita con tus credenciales
```

4. **Ejecuta la instalación:**
```powershell
.\Install-SQLite.ps1
.\Download-ChartJS.ps1
.\Initialize-MonitoringDatabase.ps1
.\Collect-VMwareData.ps1
.\Start-DashboardServer.ps1
```

### Opción B: Usar Script de Empaquetado

Si ya tienes todos los archivos en una carpeta:

```powershell
# Ejecuta el script de empaquetado
.\Package-Project.ps1

# Obtendrás un ZIP listo para subir a tu nube:
# VMware-Monitoring-Dashboard-v1.0.0.zip
```

---

## ✅ Verificación Post-Descarga

Verifica que tienes todos los archivos:

```powershell
# Contar archivos
(Get-ChildItem -Recurse -File).Count
# Deberías tener al menos 20 archivos

# Verificar archivos principales
$required = @(
    "README.md",
    "INSTALL.md",
    "Collect-VMwareData.ps1",
    "Start-DashboardServer.ps1",
    "dashboard\index.html",
    "dashboard\js\api.js"
)

foreach ($file in $required) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file FALTA" -ForegroundColor Red
    }
}
```

---

## 📦 Para Subir a tu Nube

### Si usas Git:

```bash
cd VMware-Monitoring-Dashboard
git init
git add .
git commit -m "Initial commit - VMware Monitoring Dashboard v1.0.0"
git remote add origin tu-repositorio-url
git push -u origin main
```

### Si usas otro sistema:

1. Comprime toda la carpeta en ZIP
2. Súbela a tu servicio de nube (Nextcloud, OneDrive, etc.)
3. Documenta la ubicación para futuros despliegues

---

## ⚠️ IMPORTANTE - Antes de Subir

1. **NUNCA** subas el archivo `connect.ps1` con credenciales reales
2. Verifica que `.gitignore` está incluido
3. Asegúrate de que `data/` está vacío (sin bases de datos con datos reales)
4. Revisa que `connect.ps1.example` es una plantilla sin credenciales

---

## 🔄 Para Desplegar en Otro Servidor

1. Descarga el proyecto de tu nube
2. Extrae en el servidor de destino
3. Copia y edita `connect.ps1`:
```powershell
Copy-Item connect.ps1.example connect.ps1
notepad connect.ps1
```
4. Sigue INSTALL.md paso a paso

---

## 📞 Soporte

Si tienes problemas descargando o armando el proyecto:

1. Verifica que tienes todos los archivos listados arriba
2. Revisa los permisos de las carpetas
3. Ejecuta `.\Test-Dashboard.ps1` para diagnóstico

---

¡Todo listo! Ahora tienes el proyecto completo y profesional para subir a tu nube. ☁️🚀

**Versión:** 1.0.0  
**Fecha:** 2025-10-16  
**Autor:** Aridane Mirabal
