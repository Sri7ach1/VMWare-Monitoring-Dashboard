# VMware Infrastructure Monitoring Dashboard

Dashboard web en tiempo real para monitorización de infraestructura VMware con histórico en SQLite.


## 🎯 Características

- ✅ Monitorización de 2000+ hosts ESXi en paralelo (6 hilos)
- ✅ Dashboard web interactivo con gráficos en tiempo real (Chart.js)
- ✅ Histórico completo almacenado en SQLite
- ✅ Detección de hosts desconectados con histórico temporal
- ✅ Bulk insert optimizado (100 hosts por batch)
- ✅ API REST para consultas personalizadas
- ✅ Procesamiento paralelo de múltiples vCenters

## 📊 Dashboard Features

### KPIs en Tiempo Real
- Total de hosts monitorizados
- Porcentaje de disponibilidad
- Hosts desconectados
- vCenters conectados
- Datacenters monitorizados
- Clusters totales

### Gráficos Interactivos
- Tendencia de disponibilidad (línea temporal)
- Distribución de versiones ESXi (donut chart)
- Estadísticas por datacenter (barras horizontales)
- Histórico de ejecuciones

### Tablas Detalladas
- Hosts desconectados (última ejecución)
- Histórico de desconexiones (con filtros: última ejecución, 7 días, 30 días, todo)
- Últimas ejecuciones del script

## 🚀 Instalación Rápida

### 1. Configurar conexión a vCenters

```powershell
# Copia la plantilla y edítala con tus datos
Copy-Item connect.ps1.example connect.ps1
# Edita connect.ps1 con tus credenciales de vCenter
notepad connect.ps1
```

### 2. Instalar SQLite

```powershell
.\Install-SQLite.ps1
```

### 3. Crear base de datos

```powershell
.\Initialize-MonitoringDatabase.ps1
```

### 4. Primera recopilación de datos

```powershell
.\Collect-VMwareData.ps1
```

### 5. Iniciar el servidor del dashboard

```powershell
.\Start-DashboardServer.ps1
```

### 6. Abrir dashboard en navegador

```
http://localhost:8080
```

## 📁 Estructura del Proyecto

```
VMware-Monitoring-Dashboard/
├── README.md                              # Este archivo
├── INSTALL.md                             # Guía detallada de instalación
├── LICENSE                                # Licencia del proyecto
│
├── Install-SQLite.ps1                     # Instalador de SQLite
├── Initialize-MonitoringDatabase.ps1      # Crear estructura de BD
├── Collect-VMwareData.ps1                 # Script principal de recopilación
├── Start-DashboardServer.ps1              # Servidor web con API REST
├── Test-Dashboard.ps1                     # Script de diagnóstico
│
├── connect.ps1.example                    # Plantilla de conexión (SIN credenciales)
├── .gitignore                             # Archivos a ignorar en git
│
├── dashboard/                             # Frontend del dashboard
│   ├── index.html                         # Página principal
│   ├── css/
│   │   └── style.css                      # Estilos del dashboard
│   └── js/
│       ├── api.js                         # Módulo de API calls
│       ├── charts.js                      # Configuración de gráficos
│       ├── app.js                         # Aplicación principal
│       └── chart.js                       # Librería Chart.js (descargada)
│
├── data/                                  # Base de datos (creada al inicializar)
│   └── vmware_monitoring.db               # SQLite database
│
└── docs/                                  # Documentación adicional
    ├── INSTALL.md                         # Guía de instalación detallada
    ├── API.md                             # Documentación de la API REST
    └── SCHEMA.md                          # Esquema de base de datos
```

## ⚙️ Automatización con Tareas Programadas

### Opción 1: Tarea programada cada 4 horas

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\ruta\completa\Collect-VMwareData.ps1"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours 4) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

Register-ScheduledTask -TaskName "VMware Data Collection" `
    -Action $action -Trigger $trigger -Description "Recopilación automática de datos VMware"
```

### Opción 2: Ejecución diaria a las 2 AM

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\ruta\completa\Collect-VMwareData.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

Register-ScheduledTask -TaskName "VMware Daily Collection" `
    -Action $action -Trigger $trigger
```

## 🔧 Requisitos del Sistema

### Software
- Windows Server 2016+ o Windows 10+
- PowerShell 5.1 o superior
- VMware PowerCLI 12.0 o superior
- Acceso de lectura a los vCenters

### Hardware (recomendado para 2000+ hosts)
- CPU: 4 cores o más
- RAM: 4 GB mínimo
- Disco: 1 GB para la aplicación + espacio para histórico

### Permisos
- Usuario con permisos de lectura en vCenters
- Sin necesidad de permisos de escritura

## 📈 Performance

Benchmarks con 2184 hosts, 18 vCenters, 1092 clusters:

| Operación | Tiempo | Detalles |
|-----------|--------|----------|
| Recopilación de datos | ~90 segundos | 6 hilos paralelos |
| Inserción en BD | ~30 segundos | Bulk insert (100/batch) |
| Respuesta del dashboard | <500ms | API REST |
| **Total por ejecución** | **~2 minutos** | End-to-end |

## 🛠️ Troubleshooting

### El dashboard muestra "Error al cargar datos"

```powershell
# Ejecuta el diagnóstico
.\Test-Dashboard.ps1
```

### La recopilación tarda mucho

```powershell
# Aumenta los hilos paralelos (por defecto: 6)
.\Collect-VMwareData.ps1 -MaxThreads 12
```

### Error de conexión a vCenters

```powershell
# Verifica tus credenciales en connect.ps1
# Prueba la conexión manualmente
.\connect.ps1
$global:DefaultVIServers
```

## 📊 API REST Endpoints

El servidor expone los siguientes endpoints:

| Endpoint | Descripción |
|----------|-------------|
| `/api/latest` | Última ejecución (resumen) |
| `/api/availability-trend?days=7` | Tendencia de disponibilidad |
| `/api/version-distribution` | Distribución de versiones ESXi |
| `/api/datacenter-stats` | Estadísticas por datacenter |
| `/api/disconnected-hosts` | Hosts desconectados (última ejecución) |
| `/api/disconnected-history?period=7` | Histórico de desconexiones |
| `/api/recent-executions?limit=10` | Últimas ejecuciones |
| `/api/datacenters` | Lista de datacenters |

Ver documentación completa en [docs/API.md](docs/API.md)

## 🔐 Seguridad

### ⚠️ IMPORTANTE - Antes de subir a repositorio

1. **NUNCA** incluyas `connect.ps1` con credenciales reales
2. Usa `connect.ps1.example` como plantilla
3. Añade `connect.ps1` al `.gitignore`
4. Usa variables de entorno o secretos para credenciales en producción

### Buenas prácticas

- Ejecuta el servidor solo en redes internas
- Considera añadir autenticación si expones el dashboard
- Usa cuentas de servicio con permisos mínimos
- Revisa los logs regularmente

## 🗄️ Esquema de Base de Datos

### Tabla: executions
Almacena información de cada ejecución del script de recopilación.

### Tabla: hosts
Histórico completo de todos los hosts detectados en cada ejecución.

### Tabla: version_distribution
Distribución de versiones ESXi por ejecución.

### Tabla: datacenter_stats
Estadísticas agregadas por datacenter.

Ver esquema completo en [docs/SCHEMA.md](docs/SCHEMA.md)

## 🔄 Actualización

Para actualizar a una nueva versión:

```powershell
# 1. Hacer backup de la base de datos
Copy-Item .\data\vmware_monitoring.db .\data\vmware_monitoring.db.backup

# 2. Descargar nueva versión
# 3. Reemplazar archivos (mantener connect.ps1 y data/)
# 4. Reiniciar el servidor
```

## 📝 Changelog

### v1.0.0 (2025-10-16)
- ✅ Release inicial
- ✅ Dashboard web completo
- ✅ Bulk insert optimizado
- ✅ Histórico de desconexiones con filtros
- ✅ API REST completa
- ✅ Procesamiento paralelo

## 🤝 Contribuciones

Este es un proyecto de uso interno. Si quieres adaptarlo:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Proyecto de uso interno privado.

## 👨‍💻 Autor

**Aridane Mirabal**  
Administrador de Sistemas Linux e Infraestructura VMware

## 🙏 Agradecimientos

- VMware PowerCLI Team
- Chart.js
- SQLite

---

**¿Necesitas ayuda?** Revisa la documentación en `docs/` o ejecuta `.\Test-Dashboard.ps1` para diagnóstico automático.
