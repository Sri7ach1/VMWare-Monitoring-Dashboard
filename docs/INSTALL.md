# Guía de Instalación Detallada

Esta guía te llevará paso a paso por la instalación completa del VMware Monitoring Dashboard.

## 📋 Pre-requisitos

### 1. Verificar PowerShell

```powershell
# Verificar versión de PowerShell (necesitas 5.1+)
$PSVersionTable.PSVersion
```

### 2. Instalar VMware PowerCLI

```powershell
# Instalar PowerCLI desde PowerShell Gallery
Install-Module -Name VMware.PowerCLI -Scope CurrentUser

# Verificar instalación
Get-Module -ListAvailable VMware.PowerCLI
```

### 3. Configurar PowerCLI

```powershell
# Ignorar certificados inválidos (común en entornos corporativos)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Participar en CEIP (opcional)
Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false
```

## 🚀 Instalación Paso a Paso

### Paso 1: Descargar el Proyecto

```powershell
# Opción A: Desde Git
git clone https://tu-repositorio/VMware-Monitoring-Dashboard.git
cd VMware-Monitoring-Dashboard

# Opción B: Descargar ZIP y extraer
# Luego navegar a la carpeta extraída
```

### Paso 2: Configurar Conexión a vCenters

```powershell
# 1. Copiar la plantilla
Copy-Item connect.ps1.example connect.ps1

# 2. Editar con tus datos
notepad connect.ps1
```

Edita estas secciones:

```powershell
# CAMBIAR ESTAS CREDENCIALES:
$esxiUsername = "tu_usuario@vsphere.local"
$esxiPassword = "tu_password_seguro"

# CAMBIAR ESTA LISTA:
$esxiServers = @(
    "vcenter01.tudominio.com",
    "vcenter02.tudominio.com",
    "vcenter03.tudominio.com"
)
```

### Paso 3: Probar Conexión

```powershell
# Ejecutar script de conexión
.\connect.ps1

# Verificar conexiones establecidas
$global:DefaultVIServers

# Deberías ver una lista de tus vCenters conectados
```

Si hay errores:
- ✅ Verifica las credenciales
- ✅ Verifica conectividad de red al vCenter
- ✅ Verifica que el usuario tiene permisos de lectura

### Paso 4: Instalar SQLite

```powershell
# Ejecutar instalador
.\Install-SQLite.ps1

# Verificar instalación
.\sqlite3.exe --version
# Debería mostrar: 3.46.1 o similar
```

### Paso 5: Crear Base de Datos

```powershell
# Inicializar esquema de base de datos
.\Initialize-MonitoringDatabase.ps1

# Verificar creación
Test-Path .\data\vmware_monitoring.db
# Debería devolver: True
```

### Paso 6: Primera Recopilación de Datos

```powershell
# Ejecutar primera recopilación (puede tardar 2-3 minutos)
.\Collect-VMwareData.ps1

# Deberías ver:
# ✓ Conexiones establecidas: X vCenter(s)
# ✓ Recopilación completada
# ✓ X hosts insertados
# ✓ X versiones registradas
# ✓ X datacenters registrados
```

### Paso 7: Iniciar Dashboard

```powershell
# Iniciar servidor web
.\Start-DashboardServer.ps1

# Deberías ver:
# ✅ Servidor iniciado
# 🌐 Dashboard: http://localhost:8080
```

### Paso 8: Abrir Dashboard

1. Abre tu navegador
2. Ve a: http://localhost:8080
3. ¡Deberías ver el dashboard funcionando!

## ✅ Verificación Post-Instalación

### Test 1: Verificar Conexiones

```powershell
.\connect.ps1
$global:DefaultVIServers | Select-Object Name, IsConnected
```

Todas las conexiones deben mostrar `IsConnected: True`

### Test 2: Verificar Base de Datos

```powershell
.\sqlite3.exe .\data\vmware_monitoring.db "SELECT COUNT(*) FROM hosts;"
```

Debe devolver un número mayor a 0.

### Test 3: Verificar API

Con el servidor corriendo:

```powershell
# En otra ventana de PowerShell
Invoke-WebRequest "http://localhost:8080/api/latest" | Select-Object StatusCode
```

Debe devolver `StatusCode: 200`

### Test 4: Diagnóstico Completo

```powershell
.\Test-Dashboard.ps1
```

Revisa que todos los checks sean ✓

## 🔧 Configuración Avanzada

### Cambiar Puerto del Servidor

```powershell
# Usar puerto personalizado
.\Start-DashboardServer.ps1 -Port 9090

# Luego acceder en: http://localhost:9090
```

### Aumentar Hilos Paralelos

```powershell
# Para entornos grandes, aumentar paralelismo
.\Collect-VMwareData.ps1 -MaxThreads 12
```

### Base de Datos en Otra Ubicación

```powershell
# Especificar ruta personalizada
.\Collect-VMwareData.ps1 -DatabasePath "D:\datos\vmware.db"
.\Start-DashboardServer.ps1 -DatabasePath "D:\datos\vmware.db"
```

## 🔄 Configurar Ejecución Automática

### Opción 1: Tarea Programada Repetitiva

```powershell
# Crear tarea que se repite cada 4 horas
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\ruta\completa\Collect-VMwareData.ps1"

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours 4) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$principal = New-ScheduledTaskPrincipal `
    -UserId "DOMAIN\ServiceAccount" `
    -LogonType Password `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "VMware Monitoring - Data Collection" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Recopilación automática de datos de infraestructura VMware"
```

### Opción 2: Ejecución Diaria

```powershell
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\ruta\completa\Collect-VMwareData.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

Register-ScheduledTask `
    -TaskName "VMware Monitoring - Daily Collection" `
    -Action $action `
    -Trigger $trigger
```

### Opción 3: Servidor como Servicio (NSSM)

```powershell
# 1. Descargar NSSM: https://nssm.cc/download

# 2. Instalar como servicio
nssm install "VMware Dashboard" "PowerShell.exe" `
    "-ExecutionPolicy Bypass -File C:\ruta\completa\Start-DashboardServer.ps1"

# 3. Configurar recuperación automática
nssm set "VMware Dashboard" AppStdout "C:\ruta\logs\dashboard-output.log"
nssm set "VMware Dashboard" AppStderr "C:\ruta\logs\dashboard-error.log"

# 4. Iniciar servicio
nssm start "VMware Dashboard"
```

## 🐛 Solución de Problemas Comunes

### Error: "No se puede cargar VMware.PowerCLI"

```powershell
# Reinstalar PowerCLI
Remove-Module VMware.PowerCLI -Force -ErrorAction SilentlyContinue
Install-Module -Name VMware.PowerCLI -Force -AllowClobber

# Importar manualmente
Import-Module VMware.PowerCLI
```

### Error: "sqlite3.exe no encontrado"

```powershell
# Reinstalar SQLite
.\Install-SQLite.ps1

# Verificar que está en PATH o en directorio actual
Get-Command sqlite3.exe -ErrorAction SilentlyContinue
```

### Error: "Chart is not defined"

```powershell
# Limpiar caché del navegador
# Presiona Ctrl+Shift+Delete, borra caché
# O usa modo incógnito: Ctrl+Shift+N

# Volver a descargar Chart.js
.\Download-ChartJS.ps1

# Verificar archivo
(Get-Item .\dashboard\js\chart.js).Length / 1KB
# Debe ser más de 200 KB
```

### Dashboard muestra "undefined" o datos incorrectos

```powershell
# 1. Para el servidor (Ctrl+C)

# 2. Limpia la base de datos y recrea
Remove-Item .\data\vmware_monitoring.db
.\Initialize-MonitoringDatabase.ps1

# 3. Recopila datos nuevamente
.\Collect-VMwareData.ps1

# 4. Reinicia servidor
.\Start-DashboardServer.ps1
```

### Recopilación muy lenta

```powershell
# Aumentar hilos paralelos
.\Collect-VMwareData.ps1 -MaxThreads 12

# O reducir si hay errores de memoria
.\Collect-VMwareData.ps1 -MaxThreads 3
```

## 📊 Verificar que Todo Funciona

Después de la instalación, verifica:

1. ✅ Conexión a vCenters: `.\connect.ps1`
2. ✅ SQLite instalado: `.\sqlite3.exe --version`
3. ✅ Base de datos creada: `dir .\data\`
4. ✅ Datos recopilados: `.\sqlite3.exe .\data\vmware_monitoring.db "SELECT COUNT(*) FROM hosts;"`
5. ✅ Servidor corriendo: `http://localhost:8080`
6. ✅ API funcionando: `Invoke-WebRequest http://localhost:8080/api/latest`

## 🎓 Próximos Pasos

Una vez instalado:

1. **Automatiza**: Configura tarea programada
2. **Monitoriza**: Revisa el dashboard regularmente
3. **Optimiza**: Ajusta hilos según tu hardware
4. **Documenta**: Añade tus propias notas de configuración
5. **Respalda**: Haz backup de `connect.ps1` y `data/`

## 📞 Soporte

Si encuentras problemas:

1. Ejecuta `.\Test-Dashboard.ps1` para diagnóstico
2. Revisa los logs del servidor
3. Consulta la documentación en `docs/`
4. Revisa el código fuente

---

¡Instalación completada! Ahora tienes un sistema de monitorización profesional para tu infraestructura VMware. 🎉
