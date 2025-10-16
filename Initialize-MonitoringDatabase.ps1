# Script para inicializar la base de datos de monitoreo VMware
# Crea el esquema SQLite para almacenar histórico de análisis

param(
    [string]$DatabasePath = ".\data\vmware_monitoring.db"
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Inicializando Base de Datos de Monitoreo VMware" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Crear directorio si no existe
$dataDir = Split-Path $DatabasePath -Parent
if (-not (Test-Path $dataDir)) {
    New-Item -Path $dataDir -ItemType Directory -Force | Out-Null
    Write-Host "✓ Directorio creado: $dataDir" -ForegroundColor Green
}

Write-Host "Verificando SQLite..." -ForegroundColor Cyan

# Buscar sqlite3.exe primero (más confiable)
$sqlite3Path = $null
$searchPaths = @(
    ".\sqlite3.exe",
    "$PSScriptRoot\sqlite3.exe",
    (Get-Command sqlite3.exe -ErrorAction SilentlyContinue)
)

foreach ($path in $searchPaths) {
    if ($path -and (Test-Path $path -ErrorAction SilentlyContinue)) {
        $sqlite3Path = $path
        break
    }
}

$useSqliteExe = $false
$useDotNet = $false

if ($sqlite3Path) {
    Write-Host "✓ Usando sqlite3.exe: $sqlite3Path" -ForegroundColor Green
    $useSqliteExe = $true
} else {
    Write-Host "⚠ sqlite3.exe no encontrado, intentando .NET..." -ForegroundColor Yellow
    # Intentar cargar SQLite via .NET
    try {
        Add-Type -AssemblyName System.Data.SQLite -ErrorAction Stop
        Write-Host "✓ System.Data.SQLite cargado" -ForegroundColor Green
        $useDotNet = $true
    }
    catch {
        Write-Host "✗ SQLite no disponible" -ForegroundColor Red
        Write-Host ""
        Write-Host "Por favor, ejecuta primero: .\Install-SQLite.ps1" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Creando esquema de base de datos..." -ForegroundColor Cyan
Write-Host "Ubicación: $DatabasePath" -ForegroundColor White
Write-Host ""

# Esquema SQL completo
$schemaSQL = @"
-- Tabla principal: Ejecuciones del script
CREATE TABLE IF NOT EXISTS executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_date DATETIME NOT NULL,
    total_hosts INTEGER NOT NULL,
    connected_hosts INTEGER NOT NULL,
    disconnected_hosts INTEGER NOT NULL,
    availability_percent REAL NOT NULL,
    vcenters_processed INTEGER NOT NULL,
    vcenters_total INTEGER NOT NULL,
    clusters_processed INTEGER NOT NULL,
    datacenters_count INTEGER NOT NULL,
    processing_time_seconds INTEGER,
    total_time_seconds INTEGER,
    alert_sent BOOLEAN DEFAULT 0,
    alert_type TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_executions_date ON executions(execution_date);

-- Tabla: Información detallada de cada host
CREATE TABLE IF NOT EXISTS hosts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    hostname TEXT NOT NULL,
    datacenter TEXT NOT NULL,
    cluster TEXT NOT NULL,
    vcenter TEXT NOT NULL,
    esxi_version TEXT NOT NULL,
    esxi_build TEXT NOT NULL,
    connection_state TEXT NOT NULL,
    is_connected BOOLEAN NOT NULL,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_hosts_execution ON hosts(execution_id);
CREATE INDEX IF NOT EXISTS idx_hosts_hostname ON hosts(hostname);
CREATE INDEX IF NOT EXISTS idx_hosts_datacenter ON hosts(datacenter);

-- Tabla: Distribución de versiones
CREATE TABLE IF NOT EXISTS version_distribution (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    esxi_version TEXT NOT NULL,
    esxi_build TEXT NOT NULL,
    version_full TEXT NOT NULL,
    host_count INTEGER NOT NULL,
    percentage REAL NOT NULL,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_versions_execution ON version_distribution(execution_id);

-- Tabla: Estadísticas por datacenter
CREATE TABLE IF NOT EXISTS datacenter_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    datacenter_name TEXT NOT NULL,
    total_hosts INTEGER NOT NULL,
    connected_hosts INTEGER NOT NULL,
    disconnected_hosts INTEGER NOT NULL,
    availability_percent REAL NOT NULL,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_datacenter_execution ON datacenter_stats(execution_id);

-- Vista: Últimas ejecuciones
CREATE VIEW IF NOT EXISTS v_recent_executions AS
SELECT 
    id,
    datetime(execution_date) as execution_date,
    total_hosts,
    connected_hosts,
    disconnected_hosts,
    ROUND(availability_percent, 2) as availability_percent,
    vcenters_processed,
    datacenters_count,
    alert_type
FROM executions
ORDER BY execution_date DESC
LIMIT 30;

-- Vista: Tendencia de disponibilidad
CREATE VIEW IF NOT EXISTS v_availability_trend AS
SELECT 
    DATE(execution_date) as date,
    ROUND(AVG(availability_percent), 2) as avg_availability,
    SUM(disconnected_hosts) as total_disconnected,
    COUNT(*) as execution_count
FROM executions
GROUP BY DATE(execution_date)
ORDER BY date DESC;
"@

if ($useSqliteExe) {
    # Usar sqlite3.exe
    $sqlFile = Join-Path $env:TEMP "schema.sql"
    $schemaSQL | Out-File -FilePath $sqlFile -Encoding UTF8
    
    Write-Host "Creando esquema con sqlite3.exe..." -ForegroundColor Cyan
    
    try {
        # Ejecutar con sqlite3.exe
        $output = & $sqlite3Path $DatabasePath ".read $sqlFile" 2>&1
        
        if ($LASTEXITCODE -eq 0 -or $output -eq $null) {
            Write-Host "✓ Esquema creado exitosamente" -ForegroundColor Green
        } else {
            Write-Host "⚠ Advertencia: $output" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    finally {
        Remove-Item $sqlFile -ErrorAction SilentlyContinue
    }
} elseif ($useDotNet) {
    # Usar .NET SQLite
    Write-Host "Creando esquema con .NET SQLite..." -ForegroundColor Cyan
    
    try {
        $connectionString = "Data Source=$DatabasePath;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()
        
        $commands = $schemaSQL -split ";"
        $successCount = 0
        
        foreach ($cmdText in $commands) {
            $cmdText = $cmdText.Trim()
            if ($cmdText.Length -gt 10) {
                try {
                    $command = $connection.CreateCommand()
                    $command.CommandText = $cmdText
                    $command.ExecuteNonQuery() | Out-Null
                    $successCount++
                }
                catch {
                    # Ignorar errores de "already exists"
                }
            }
        }
        
        $connection.Close()
        Write-Host "✓ Esquema creado ($successCount comandos)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✗ No hay método disponible para crear la base de datos" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Base de datos inicializada correctamente" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Ubicación: $DatabasePath" -ForegroundColor White
Write-Host "Tamaño: $([math]::Round((Get-Item $DatabasePath).Length / 1KB, 2)) KB" -ForegroundColor White
Write-Host ""
