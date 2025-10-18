# Script de Recopilación de Datos VMware para Histórico
# Solo recopila datos y los guarda en SQLite - Sin alertas ni exportaciones

param(
    [string]$DatabasePath = "C:\Users\aridane.mirabal\Desktop\tpm\reports_bbdd\data\vmware_monitoring.db",
    [int]$MaxThreads = 6,
    [string]$ConnectScript = $null
)

$ErrorActionPreference = "Continue"
$scriptStartTime = Get-Date

# Añadir ruta de módulos globales antes de importar PowerCLI
$env:PSModulePath += ";C:\Program Files\PowerShell\Modules"
# Importar módulo principal
Import-Module VMware.PowerCLI -ErrorAction Stop

# Detectar directorio del script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Si no se especificó ConnectScript, usar el del mismo directorio
if (-not $ConnectScript) {
    $ConnectScript = Join-Path $scriptDir "connect.ps1"
}

# Si DatabasePath es relativa, convertirla a absoluta basada en directorio del script
if (-not [System.IO.Path]::IsPathRooted($DatabasePath)) {
    $DatabasePath = Join-Path $scriptDir $DatabasePath
}

# Cargar ensamblados necesarios para procesamiento paralelo
Add-Type -AssemblyName System.Management.Automation

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Recopilación de Datos VMware - Histórico" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Base de datos: $DatabasePath" -ForegroundColor White
Write-Host "Hilos paralelos: $MaxThreads" -ForegroundColor White
Write-Host ""

# Verificar que existe connect.ps1
if (-not (Test-Path $ConnectScript)) {
    Write-Host "✗ Error: No se encuentra el archivo de conexión: $ConnectScript" -ForegroundColor Red
    Write-Host "  Asegúrate de tener un script de conexión disponible" -ForegroundColor Yellow
    exit 1
}

# Verificar que existe la base de datos
if (-not (Test-Path $DatabasePath)) {
    Write-Host "✗ Error: Base de datos no encontrada: $DatabasePath" -ForegroundColor Red
    Write-Host "  Ejecuta primero: .\Initialize-MonitoringDatabase.ps1" -ForegroundColor Yellow
    exit 1
}

# Verificar SQLite
$sqlite3Path = $null
$searchPaths = @(
    (Join-Path $scriptDir "sqlite3.exe"),
    ".\sqlite3.exe",
    "$PSScriptRoot\sqlite3.exe"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $sqlite3Path = $path
        break
    }
}

if (-not $sqlite3Path) {
    Write-Host "✗ Error: sqlite3.exe no encontrado" -ForegroundColor Red
    Write-Host "  Ejecuta primero: .\Install-SQLite.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ sqlite3.exe encontrado" -ForegroundColor Green
Write-Host ""

# Función para ejecutar SQL en SQLite
function Invoke-SQLite {
    param(
        [string]$Query,
        [switch]$ReturnResult
    )
    
    try {
        # Crear archivo temporal con la query
        $tempFile = Join-Path $env:TEMP "query_$(Get-Random).sql"
        $Query | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
        
        # Ejecutar con sqlite3
        if ($ReturnResult) {
            $result = & $sqlite3Path $DatabasePath ".read $tempFile" 2>&1
        } else {
            $result = & $sqlite3Path $DatabasePath ".read $tempFile" 2>&1 | Out-Null
        }
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($ReturnResult) {
            return $result
        }
        
        return $true
    }
    catch {
        Write-Host "  ⚠ Error SQL: $($_.Exception.Message)" -ForegroundColor Yellow
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $null
    }
}

# ScriptBlock para procesar cada vCenter en paralelo
$vCenterProcessingScript = {
    param($vCenterName)
    
    try {
        # Buscar clusters en este vCenter
        $clusters = Get-Cluster -Server $vCenterName -ErrorAction Stop
        
        $hostResults = @()
        
        foreach ($cluster in $clusters) {
            try {
                # Obtener hosts del cluster
                $vmHosts = Get-VMHost -Location $cluster -Server $vCenterName -ErrorAction Stop
                
                foreach ($vmHost in $vmHosts) {
                    try {
                        # Obtener datacenter del host
                        $datacenter = (Get-Datacenter -VMHost $vmHost -Server $vCenterName -ErrorAction Stop).Name
                        
                        # Crear objeto con información del host
                        $hostInfo = [PSCustomObject]@{
                            HostName = $vmHost.Name
                            Datacenter = $datacenter
                            Cluster = $cluster.Name
                            vCenter = $vCenterName
                            Version = $vmHost.Version
                            Build = $vmHost.Build
                            ConnectionState = $vmHost.ConnectionState.ToString()
                            IsConnected = ($vmHost.ConnectionState -eq 'Connected')
                        }
                        
                        $hostResults += $hostInfo
                    }
                    catch {
                        # Error con un host específico, continuar
                        continue
                    }
                }
            }
            catch {
                # Error con un cluster, continuar
                continue
            }
        }
        
        # Retornar resultados
        return [PSCustomObject]@{
            vCenter = $vCenterName
            Success = $true
            Hosts = $hostResults
            ClustersProcessed = $clusters.Count
            ErrorMessage = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            vCenter = $vCenterName
            Success = $false
            Hosts = @()
            ClustersProcessed = 0
            ErrorMessage = $_.Exception.Message
        }
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host "Conectando a vCenters..." -ForegroundColor Cyan

# Ejecutar script de conexión
try {
    # Suprimir outputs informativos durante la conexión
    $WarningPreference = 'SilentlyContinue'
    . $ConnectScript
    $WarningPreference = 'Continue'
}
catch {
    Write-Host "✗ Error ejecutando script de conexión: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Obtener conexiones activas
$activeConnections = $global:DefaultVIServers

if (-not $activeConnections -or $activeConnections.Count -eq 0) {
    Write-Host "✗ No hay conexiones activas a vCenters" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Conexiones establecidas: $($activeConnections.Count) vCenter(s)" -ForegroundColor Green
Write-Host ""

# Procesar vCenters en paralelo
Write-Host "Recopilando datos de $($activeConnections.Count) vCenter(s)..." -ForegroundColor Cyan
$processingStartTime = Get-Date

# Crear runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$runspacePool.Open()

$jobs = @()
foreach ($connection in $activeConnections) {
    $runspace = [powershell]::Create()
    $runspace.RunspacePool = $runspacePool
    
    [void]$runspace.AddScript($vCenterProcessingScript)
    [void]$runspace.AddArgument($connection.Name)
    
    $jobs += [PSCustomObject]@{
        Runspace = $runspace
        Handle = $runspace.BeginInvoke()
        vCenter = $connection.Name
    }
}

# Esperar a que terminen todos los jobs
$allResults = @()
$completedCount = 0

while ($jobs.Handle.IsCompleted -notcontains $false) {
    Start-Sleep -Milliseconds 500
    
    $currentCompleted = ($jobs.Handle.IsCompleted | Where-Object { $_ -eq $true }).Count
    if ($currentCompleted -gt $completedCount) {
        Write-Host "." -NoNewline -ForegroundColor Green
        $completedCount = $currentCompleted
    }
}

Write-Host ""

# Recopilar resultados
foreach ($job in $jobs) {
    try {
        $result = $job.Runspace.EndInvoke($job.Handle)
        $allResults += $result
        $job.Runspace.Dispose()
    }
    catch {
        Write-Host "  ⚠ Error procesando $($job.vCenter): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$runspacePool.Close()
$runspacePool.Dispose()

$processingEndTime = Get-Date
$processingDuration = $processingEndTime - $processingStartTime

Write-Host "✓ Recopilación completada en $($processingDuration.ToString('mm\:ss'))" -ForegroundColor Green
Write-Host ""

# Consolidar todos los hosts
$allHosts = @()
$successfulVCenters = 0
$totalClusters = 0

foreach ($result in $allResults) {
    if ($result.Success) {
        $successfulVCenters++
        $totalClusters += $result.ClustersProcessed
        $allHosts += $result.Hosts
    }
}

# Calcular estadísticas
$totalHosts = $allHosts.Count
$connectedHosts = ($allHosts | Where-Object { $_.IsConnected }).Count
$disconnectedHosts = $totalHosts - $connectedHosts
$availabilityPercent = if ($totalHosts -gt 0) { 
    [math]::Round(($connectedHosts / $totalHosts) * 100, 2) 
} else { 
    0 
}

# Obtener lista de datacenters únicos
$datacenters = $allHosts | Select-Object -ExpandProperty Datacenter -Unique
$datacenterCount = $datacenters.Count

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "RESUMEN DE RECOPILACIÓN" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total de hosts: $totalHosts" -ForegroundColor White
Write-Host "Hosts conectados: $connectedHosts" -ForegroundColor Green
Write-Host "Hosts desconectados: $disconnectedHosts" -ForegroundColor $(if ($disconnectedHosts -gt 0) { "Red" } else { "Green" })
Write-Host "Disponibilidad: $availabilityPercent%" -ForegroundColor $(if ($availabilityPercent -ge 95) { "Green" } elseif ($availabilityPercent -ge 90) { "Yellow" } else { "Red" })
Write-Host ""
Write-Host "vCenters procesados: $successfulVCenters / $($activeConnections.Count)" -ForegroundColor White
Write-Host "Clusters totales: $totalClusters" -ForegroundColor White
Write-Host "Datacenters: $datacenterCount" -ForegroundColor White
Write-Host ""

# ============================================================
# GUARDAR EN BASE DE DATOS
# ============================================================

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "GUARDANDO EN BASE DE DATOS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$scriptEndTime = Get-Date
$totalDuration = $scriptEndTime - $scriptStartTime

# Insertar registro de ejecución y obtener su ID
Write-Host "Insertando registro de ejecución..." -ForegroundColor Cyan

$executionSQL = @"
BEGIN TRANSACTION;

INSERT INTO executions (
    execution_date,
    total_hosts,
    connected_hosts,
    disconnected_hosts,
    availability_percent,
    vcenters_processed,
    vcenters_total,
    clusters_processed,
    datacenters_count,
    processing_time_seconds,
    total_time_seconds,
    alert_sent,
    alert_type
) VALUES (
    datetime('now','localtime'),
    $totalHosts,
    $connectedHosts,
    $disconnectedHosts,
    $availabilityPercent,
    $successfulVCenters,
    $($activeConnections.Count),
    $totalClusters,
    $datacenterCount,
    $([int]$processingDuration.TotalSeconds),
    $([int]$totalDuration.TotalSeconds),
    0,
    NULL
);

SELECT last_insert_rowid();

COMMIT;
"@

$executionIdResult = Invoke-SQLite -Query $executionSQL -ReturnResult

# El resultado viene como array, tomar el valor numérico
$executionId = 0
if ($executionIdResult) {
    # Buscar la línea que contiene el número
    foreach ($line in $executionIdResult) {
        if ($line -match '^\d+$') {
            $executionId = [int]$line
            break
        }
    }
}

if ($executionId -gt 0) {
    Write-Host "✓ Ejecución registrada (ID: $executionId)" -ForegroundColor Green
} else {
    Write-Host "✗ Error obteniendo ID de ejecución" -ForegroundColor Red
    Write-Host "  Resultado: $executionIdResult" -ForegroundColor Yellow
    exit 1
}

# Insertar hosts en lotes (bulk insert)
Write-Host "Insertando datos de hosts..." -ForegroundColor Cyan
$hostsInserted = 0
$batchSize = 250
$hostBatches = @()
$currentBatch = @()

foreach ($hostInfo in $allHosts) {
    $isConnected = if ($hostInfo.IsConnected) { 1 } else { 0 }
    
    # Crear línea de INSERT para este host
    $hostValues = @"
($executionId, '$($hostInfo.HostName -replace "'", "''")', '$($hostInfo.Datacenter -replace "'", "''")', '$($hostInfo.Cluster -replace "'", "''")', '$($hostInfo.vCenter -replace "'", "''")', '$($hostInfo.Version -replace "'", "''")', '$($hostInfo.Build -replace "'", "''")', '$($hostInfo.ConnectionState -replace "'", "''")', $isConnected)
"@
    
    $currentBatch += $hostValues
    
    # Cuando llegamos a 100, insertamos el lote
    if ($currentBatch.Count -ge $batchSize) {
        $bulkInsert = @"
INSERT INTO hosts (execution_id, hostname, datacenter, cluster, vcenter, esxi_version, esxi_build, connection_state, is_connected)
VALUES
$($currentBatch -join ",`n");
"@
        
        Invoke-SQLite -Query $bulkInsert
        $hostsInserted += $currentBatch.Count
        Write-Host "  $hostsInserted hosts insertados..." -ForegroundColor Gray
        $currentBatch = @()
    }
}

# Insertar el último lote si queda algo
if ($currentBatch.Count -gt 0) {
    $bulkInsert = @"
INSERT INTO hosts (execution_id, hostname, datacenter, cluster, vcenter, esxi_version, esxi_build, connection_state, is_connected)
VALUES
$($currentBatch -join ",`n");
"@
    
    Invoke-SQLite -Query $bulkInsert
    $hostsInserted += $currentBatch.Count
}

Write-Host "✓ $hostsInserted hosts insertados" -ForegroundColor Green

# Insertar distribución de versiones
Write-Host "Insertando distribución de versiones..." -ForegroundColor Cyan

$connectedHostsOnly = $allHosts | Where-Object { $_.IsConnected }
$versionGroups = $connectedHostsOnly | Group-Object @{Expression={$_.Version + " - Build " + $_.Build}}

foreach ($versionGroup in $versionGroups) {
    $versionParts = $versionGroup.Name -split " - Build "
    $version = $versionParts[0]
    $build = $versionParts[1]
    $count = $versionGroup.Count
    $percentage = [math]::Round(($count / $connectedHostsOnly.Count) * 100, 2)
    
    $versionSQL = @"
INSERT INTO version_distribution (
    execution_id,
    esxi_version,
    esxi_build,
    version_full,
    host_count,
    percentage
) VALUES (
    $executionId,
    '$version',
    '$build',
    '$($versionGroup.Name -replace "'", "''")',
    $count,
    $percentage
);
"@
    
    Invoke-SQLite -Query $versionSQL
}

Write-Host "✓ $($versionGroups.Count) versiones registradas" -ForegroundColor Green

# Insertar estadísticas por datacenter
Write-Host "Insertando estadísticas por datacenter..." -ForegroundColor Cyan

foreach ($dc in $datacenters) {
    $dcHosts = $allHosts | Where-Object { $_.Datacenter -eq $dc }
    $dcTotal = $dcHosts.Count
    $dcConnected = ($dcHosts | Where-Object { $_.IsConnected }).Count
    $dcDisconnected = $dcTotal - $dcConnected
    $dcAvailability = if ($dcTotal -gt 0) {
        [math]::Round(($dcConnected / $dcTotal) * 100, 2)
    } else {
        0
    }
    
    $dcSQL = @"
INSERT INTO datacenter_stats (
    execution_id,
    datacenter_name,
    total_hosts,
    connected_hosts,
    disconnected_hosts,
    availability_percent
) VALUES (
    $executionId,
    '$($dc -replace "'", "''")',
    $dcTotal,
    $dcConnected,
    $dcDisconnected,
    $dcAvailability
);
"@
    
    Invoke-SQLite -Query $dcSQL
}

Write-Host "✓ $datacenterCount datacenters registrados" -ForegroundColor Green

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ DATOS GUARDADOS CORRECTAMENTE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Ejecución ID: $executionId" -ForegroundColor White
Write-Host "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Duración total: $($totalDuration.ToString('mm\:ss'))" -ForegroundColor White
Write-Host ""
Write-Host "Base de datos: $DatabasePath" -ForegroundColor Cyan
$dbSize = [math]::Round((Get-Item $DatabasePath).Length / 1KB, 2)
Write-Host "Tamaño: $dbSize KB" -ForegroundColor Cyan
Write-Host ""

# Mostrar registros totales
Write-Host "Registros en base de datos:" -ForegroundColor White
$execCount = Invoke-SQLite -Query "SELECT COUNT(*) FROM executions;" -ReturnResult
$hostCount = Invoke-SQLite -Query "SELECT COUNT(*) FROM hosts;" -ReturnResult
Write-Host "  Ejecuciones: $execCount" -ForegroundColor Gray
Write-Host "  Hosts (histórico): $hostCount" -ForegroundColor Gray
Write-Host ""

Write-Host "Próximos pasos:" -ForegroundColor Cyan
Write-Host "  • Ejecuta este script regularmente (ej: tarea programada)" -ForegroundColor White
Write-Host "  • Visualiza los datos: .\Start-DashboardServer.ps1" -ForegroundColor White
Write-Host ""