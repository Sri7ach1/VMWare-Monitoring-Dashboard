# Esquema de Base de Datos

La base de datos SQLite almacena todo el histórico de monitorización de la infraestructura VMware.

## Tablas Principales

### 1. executions

Almacena información de cada ejecución del script de recopilación.

**Estructura:**

```sql
CREATE TABLE executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_date DATETIME DEFAULT CURRENT_TIMESTAMP,
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
```

**Campos:**

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER | ID único de ejecución (autoincremental) |
| execution_date | DATETIME | Fecha y hora de ejecución |
| total_hosts | INTEGER | Total de hosts detectados |
| connected_hosts | INTEGER | Hosts conectados |
| disconnected_hosts | INTEGER | Hosts desconectados |
| availability_percent | REAL | Porcentaje de disponibilidad |
| vcenters_processed | INTEGER | vCenters procesados exitosamente |
| vcenters_total | INTEGER | Total de vCenters configurados |
| clusters_processed | INTEGER | Total de clusters procesados |
| datacenters_count | INTEGER | Número de datacenters únicos |
| processing_time_seconds | INTEGER | Tiempo de recopilación de datos |
| total_time_seconds | INTEGER | Tiempo total de ejecución |
| alert_sent | BOOLEAN | Si se envió alerta (0/1) |
| alert_type | TEXT | Tipo de alerta enviada |
| notes | TEXT | Notas adicionales |
| created_at | DATETIME | Timestamp de creación del registro |

**Índices:**
```sql
CREATE INDEX idx_execution_date ON executions(execution_date);
```

**Ejemplo de consulta:**
```sql
-- Últimas 10 ejecuciones
SELECT * FROM executions 
ORDER BY execution_date DESC 
LIMIT 10;

-- Disponibilidad promedio de los últimos 7 días
SELECT 
    DATE(execution_date) as date,
    AVG(availability_percent) as avg_availability
FROM executions
WHERE execution_date >= datetime('now', '-7 days')
GROUP BY DATE(execution_date);
```

---

### 2. hosts

Histórico completo de todos los hosts detectados en cada ejecución.

**Estructura:**

```sql
CREATE TABLE hosts (
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);
```

**Campos:**

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER | ID único del registro |
| execution_id | INTEGER | Referencia a executions.id |
| hostname | TEXT | Nombre completo del host (FQDN) |
| datacenter | TEXT | Datacenter al que pertenece |
| cluster | TEXT | Cluster al que pertenece |
| vcenter | TEXT | vCenter que lo gestiona |
| esxi_version | TEXT | Versión de ESXi |
| esxi_build | TEXT | Build de ESXi |
| connection_state | TEXT | Estado de conexión (Connected, NotResponding, etc.) |
| is_connected | BOOLEAN | 1 si está conectado, 0 si no |
| created_at | DATETIME | Timestamp de creación |

**Índices:**
```sql
CREATE INDEX idx_hosts_execution ON hosts(execution_id);
CREATE INDEX idx_hosts_hostname ON hosts(hostname);
CREATE INDEX idx_hosts_datacenter ON hosts(datacenter);
CREATE INDEX idx_hosts_connected ON hosts(is_connected);
CREATE INDEX idx_hosts_version ON hosts(esxi_version, esxi_build);
```

**Ejemplo de consulta:**
```sql
-- Todos los hosts desconectados en la última ejecución
SELECT h.* 
FROM hosts h
JOIN executions e ON h.execution_id = e.id
WHERE h.is_connected = 0
  AND e.id = (SELECT MAX(id) FROM executions);

-- Histórico de un host específico
SELECT 
    e.execution_date,
    h.connection_state,
    h.esxi_version,
    h.esxi_build
FROM hosts h
JOIN executions e ON h.execution_id = e.id
WHERE h.hostname = 'esxi-prod-001.domain.com'
ORDER BY e.execution_date DESC;
```

---

### 3. version_distribution

Distribución de versiones ESXi por ejecución.

**Estructura:**

```sql
CREATE TABLE version_distribution (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    esxi_version TEXT NOT NULL,
    esxi_build TEXT NOT NULL,
    version_full TEXT NOT NULL,
    host_count INTEGER NOT NULL,
    percentage REAL NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);
```

**Campos:**

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER | ID único |
| execution_id | INTEGER | Referencia a executions.id |
| esxi_version | TEXT | Versión de ESXi (ej: 8.0.3) |
| esxi_build | TEXT | Build de ESXi (ej: 24784735) |
| version_full | TEXT | Versión completa (ej: 8.0.3 - Build 24784735) |
| host_count | INTEGER | Número de hosts con esta versión |
| percentage | REAL | Porcentaje del total |
| created_at | DATETIME | Timestamp |

**Índices:**
```sql
CREATE INDEX idx_version_execution ON version_distribution(execution_id);
```

**Ejemplo de consulta:**
```sql
-- Distribución actual de versiones
SELECT 
    version_full,
    host_count,
    percentage
FROM version_distribution
WHERE execution_id = (SELECT MAX(id) FROM executions)
ORDER BY host_count DESC;
```

---

### 4. datacenter_stats

Estadísticas agregadas por datacenter.

**Estructura:**

```sql
CREATE TABLE datacenter_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    datacenter_name TEXT NOT NULL,
    total_hosts INTEGER NOT NULL,
    connected_hosts INTEGER NOT NULL,
    disconnected_hosts INTEGER NOT NULL,
    availability_percent REAL NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);
```

**Campos:**

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | INTEGER | ID único |
| execution_id | INTEGER | Referencia a executions.id |
| datacenter_name | TEXT | Nombre del datacenter |
| total_hosts | INTEGER | Total de hosts en el datacenter |
| connected_hosts | INTEGER | Hosts conectados |
| disconnected_hosts | INTEGER | Hosts desconectados |
| availability_percent | REAL | Porcentaje de disponibilidad |
| created_at | DATETIME | Timestamp |

**Índices:**
```sql
CREATE INDEX idx_datacenter_execution ON datacenter_stats(execution_id);
CREATE INDEX idx_datacenter_name ON datacenter_stats(datacenter_name);
```

**Ejemplo de consulta:**
```sql
-- Estadísticas actuales por datacenter
SELECT 
    datacenter_name,
    total_hosts,
    availability_percent
FROM datacenter_stats
WHERE execution_id = (SELECT MAX(id) FROM executions)
ORDER BY total_hosts DESC;

-- Comparar disponibilidad entre datacenters (último mes)
SELECT 
    ds.datacenter_name,
    AVG(ds.availability_percent) as avg_availability,
    MIN(ds.availability_percent) as min_availability,
    MAX(ds.availability_percent) as max_availability
FROM datacenter_stats ds
JOIN executions e ON ds.execution_id = e.id
WHERE e.execution_date >= datetime('now', '-30 days')
GROUP BY ds.datacenter_name
ORDER BY avg_availability DESC;
```

---

## Vistas

### v_recent_executions

Vista simplificada de las últimas 30 ejecuciones.

```sql
CREATE VIEW v_recent_executions AS
SELECT 
    id,
    execution_date,
    total_hosts,
    connected_hosts,
    disconnected_hosts,
    availability_percent,
    vcenters_processed,
    alert_sent
FROM executions
ORDER BY execution_date DESC
LIMIT 30;
```

---

### v_availability_trend

Tendencia de disponibilidad diaria.

```sql
CREATE VIEW v_availability_trend AS
SELECT 
    DATE(execution_date) as date,
    COUNT(*) as total_executions,
    AVG(availability_percent) as avg_availability,
    SUM(disconnected_hosts) as total_disconnected
FROM executions
GROUP BY DATE(execution_date)
ORDER BY date DESC;
```

---

## Relaciones

```
executions (1) -----> (N) hosts
executions (1) -----> (N) version_distribution
executions (1) -----> (N) datacenter_stats
```

Todas las relaciones usan `ON DELETE CASCADE`, lo que significa que al eliminar una ejecución, se eliminan automáticamente todos sus registros relacionados.

---

## Consultas Útiles

### Tamaño de la base de datos

```sql
-- Obtener tamaño aproximado
SELECT 
    (SELECT COUNT(*) FROM executions) as total_executions,
    (SELECT COUNT(*) FROM hosts) as total_host_records,
    (SELECT COUNT(*) FROM version_distribution) as total_version_records,
    (SELECT COUNT(*) FROM datacenter_stats) as total_datacenter_records;
```

### Limpiar datos antiguos

```sql
-- Eliminar ejecuciones mayores a 90 días (y todos sus datos relacionados)
DELETE FROM executions 
WHERE execution_date < datetime('now', '-90 days');

-- Hacer VACUUM para compactar la BD
VACUUM;
```

### Hosts que cambiaron de estado

```sql
-- Hosts que pasaron de conectado a desconectado
SELECT 
    h1.hostname,
    h1.datacenter,
    e1.execution_date as when_disconnected,
    h1.connection_state
FROM hosts h1
JOIN executions e1 ON h1.execution_id = e1.id
WHERE h1.is_connected = 0
  AND h1.hostname IN (
      SELECT h2.hostname 
      FROM hosts h2
      JOIN executions e2 ON h2.execution_id = e2.id
      WHERE h2.is_connected = 1
        AND e2.execution_date < e1.execution_date
        AND e2.id = (
            SELECT MAX(e3.id) 
            FROM executions e3 
            WHERE e3.execution_date < e1.execution_date
        )
  )
ORDER BY e1.execution_date DESC;
```

### Top 10 hosts con más desconexiones

```sql
SELECT 
    hostname,
    COUNT(*) as times_disconnected,
    MAX(e.execution_date) as last_disconnection
FROM hosts h
JOIN executions e ON h.execution_id = e.id
WHERE is_connected = 0
GROUP BY hostname
ORDER BY times_disconnected DESC
LIMIT 10;
```

---

## Mantenimiento

### Backup

```powershell
# Backup simple
Copy-Item .\data\vmware_monitoring.db .\data\vmware_monitoring_backup_$(Get-Date -Format 'yyyyMMdd').db

# Backup con SQLite
.\sqlite3.exe .\data\vmware_monitoring.db ".backup '.\data\backup.db'"
```

### Optimización

```sql
-- Reconstruir índices
REINDEX;

-- Analizar estadísticas
ANALYZE;

-- Compactar base de datos
VACUUM;
```

### Monitorización del crecimiento

```powershell
# Ver tamaño de la BD
$size = (Get-Item .\data\vmware_monitoring.db).Length / 1MB
Write-Host "Tamaño BD: $([math]::Round($size, 2)) MB"

# Estimar crecimiento
.\sqlite3.exe .\data\vmware_monitoring.db "
SELECT 
    (SELECT COUNT(*) FROM hosts) as total_hosts,
    (SELECT COUNT(*) FROM hosts) / (SELECT COUNT(*) FROM executions) as hosts_per_execution,
    ((SELECT COUNT(*) FROM hosts) / (SELECT COUNT(*) FROM executions) * 365 * 2) as estimated_annual_records
;"
```

---

## Migración y Exportación

### Exportar a CSV

```powershell
# Exportar hosts desconectados
.\sqlite3.exe .\data\vmware_monitoring.db ".mode csv" ".headers on" ".output disconnected.csv" "SELECT * FROM hosts WHERE is_connected = 0;" ".output stdout"
```

### Exportar a JSON

```powershell
# Exportar última ejecución
.\sqlite3.exe .\data\vmware_monitoring.db ".mode json" "SELECT * FROM executions ORDER BY execution_date DESC LIMIT 1;"
```

---

¿Necesitas más información sobre el esquema? Consulta el código fuente en `Initialize-MonitoringDatabase.ps1`.
