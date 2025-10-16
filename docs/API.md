# API REST - Documentación

El servidor dashboard expone una API REST que puedes usar para consultas personalizadas o integraciones con otros sistemas.

## Base URL

```
http://localhost:8080/api
```

## Endpoints Disponibles

### 1. Última Ejecución

Obtiene el resumen de la última ejecución del script de recopilación.

**Endpoint:** `/api/latest`  
**Método:** `GET`  
**Respuesta:**

```json
{
  "id": 1,
  "execution_date": "2025-10-16 16:08:25",
  "total_hosts": 2184,
  "connected_hosts": 2181,
  "disconnected_hosts": 3,
  "availability_percent": 99.86,
  "vcenters_processed": 18,
  "vcenters_total": 18,
  "clusters_processed": 1092,
  "datacenters_count": 18,
  "processing_time_seconds": 91,
  "total_time_seconds": 107,
  "alert_sent": 0,
  "alert_type": null
}
```

**Ejemplo PowerShell:**
```powershell
$result = Invoke-RestMethod -Uri "http://localhost:8080/api/latest"
Write-Host "Disponibilidad: $($result.availability_percent)%"
```

---

### 2. Tendencia de Disponibilidad

Obtiene el histórico de disponibilidad por día.

**Endpoint:** `/api/availability-trend`  
**Método:** `GET`  
**Parámetros:**
- `days` (opcional): Número de días a consultar (default: 7)

**Respuesta:**

```json
[
  {
    "date": "2025-10-16",
    "total_executions": 6,
    "avg_availability": 99.86,
    "total_disconnected": 3
  },
  {
    "date": "2025-10-15",
    "total_executions": 6,
    "avg_availability": 100.0,
    "total_disconnected": 0
  }
]
```

**Ejemplo:**
```powershell
$trend = Invoke-RestMethod -Uri "http://localhost:8080/api/availability-trend?days=30"
$trend | Format-Table
```

---

### 3. Distribución de Versiones ESXi

Obtiene la distribución de versiones ESXi en la infraestructura.

**Endpoint:** `/api/version-distribution`  
**Método:** `GET`  
**Respuesta:**

```json
[
  {
    "execution_id": 1,
    "esxi_version": "8.0.3",
    "esxi_build": "24784735",
    "version_full": "8.0.3 - Build 24784735",
    "host_count": 1500,
    "percentage": 68.72
  },
  {
    "execution_id": 1,
    "esxi_version": "8.0.3",
    "esxi_build": "24674464",
    "version_full": "8.0.3 - Build 24674464",
    "host_count": 650,
    "percentage": 29.76
  }
]
```

---

### 4. Estadísticas por Datacenter

Obtiene estadísticas agregadas por datacenter.

**Endpoint:** `/api/datacenter-stats`  
**Método:** `GET`  
**Respuesta:**

```json
[
  {
    "execution_id": 1,
    "datacenter_name": "DC-Madrid",
    "total_hosts": 500,
    "connected_hosts": 499,
    "disconnected_hosts": 1,
    "availability_percent": 99.8
  },
  {
    "execution_id": 1,
    "datacenter_name": "DC-Barcelona",
    "total_hosts": 400,
    "connected_hosts": 400,
    "disconnected_hosts": 0,
    "availability_percent": 100.0
  }
]
```

---

### 5. Hosts Desconectados (Última Ejecución)

Lista de hosts desconectados en la última ejecución.

**Endpoint:** `/api/disconnected-hosts`  
**Método:** `GET`  
**Respuesta:**

```json
[
  {
    "hostname": "esxi-prod-001.domain.com",
    "datacenter": "DC-Madrid",
    "cluster": "Cluster-Produccion",
    "vcenter": "vcenter01.domain.com",
    "connection_state": "NotResponding",
    "esxi_version": "8.0.3",
    "esxi_build": "24784735",
    "detected_at": "2025-10-16 16:08:25"
  }
]
```

---

### 6. Histórico de Hosts Desconectados

Lista de hosts desconectados con filtro temporal.

**Endpoint:** `/api/disconnected-history`  
**Método:** `GET`  
**Parámetros:**
- `period`: Período a consultar
  - `latest`: Solo última ejecución
  - `7`: Últimos 7 días (default)
  - `30`: Últimos 30 días
  - `all`: Todo el histórico

**Ejemplo:**
```
/api/disconnected-history?period=30
```

**Respuesta:**

```json
[
  {
    "hostname": "esxi-prod-001.domain.com",
    "datacenter": "DC-Madrid",
    "cluster": "Cluster-Produccion",
    "vcenter": "vcenter01.domain.com",
    "connection_state": "NotResponding",
    "esxi_version": "8.0.3",
    "esxi_build": "24784735",
    "detected_at": "2025-10-16 16:08:25"
  },
  {
    "hostname": "esxi-dev-050.domain.com",
    "datacenter": "DC-Barcelona",
    "cluster": "Cluster-Desarrollo",
    "vcenter": "vcenter02.domain.com",
    "connection_state": "Disconnected",
    "esxi_version": "8.0.2",
    "esxi_build": "22380479",
    "detected_at": "2025-10-15 08:15:00"
  }
]
```

---

### 7. Últimas Ejecuciones

Lista de las últimas ejecuciones del script.

**Endpoint:** `/api/recent-executions`  
**Método:** `GET`  
**Parámetros:**
- `limit` (opcional): Número de resultados (default: 10)

**Respuesta:**

```json
[
  {
    "execution_date": "2025-10-16 16:08:25",
    "total_hosts": 2184,
    "connected_hosts": 2181,
    "disconnected_hosts": 3,
    "availability_percent": 99.86,
    "vcenters_processed": 18
  }
]
```

---

### 8. Lista de Datacenters

Obtiene lista de todos los datacenters monitorizados.

**Endpoint:** `/api/datacenters`  
**Método:** `GET`  
**Respuesta:**

```json
[
  "DC-Madrid",
  "DC-Barcelona",
  "DC-Valencia",
  "DC-Sevilla"
]
```

---

## Ejemplos de Uso

### PowerShell

```powershell
# Obtener última ejecución
$latest = Invoke-RestMethod "http://localhost:8080/api/latest"
Write-Host "Disponibilidad: $($latest.availability_percent)%"

# Obtener hosts desconectados
$disconnected = Invoke-RestMethod "http://localhost:8080/api/disconnected-hosts"
$disconnected | ForEach-Object {
    Write-Host "⚠ $($_.hostname) está desconectado desde $($_.detected_at)"
}

# Obtener tendencia de 30 días
$trend = Invoke-RestMethod "http://localhost:8080/api/availability-trend?days=30"
$trend | Select-Object date, avg_availability | Format-Table
```

### cURL

```bash
# Última ejecución
curl http://localhost:8080/api/latest

# Hosts desconectados
curl http://localhost:8080/api/disconnected-hosts

# Histórico de desconexiones (7 días)
curl "http://localhost:8080/api/disconnected-history?period=7"
```

### Python

```python
import requests
import json

# Base URL
base_url = "http://localhost:8080/api"

# Obtener última ejecución
response = requests.get(f"{base_url}/latest")
data = response.json()
print(f"Disponibilidad: {data['availability_percent']}%")

# Obtener hosts desconectados
response = requests.get(f"{base_url}/disconnected-hosts")
hosts = response.json()
for host in hosts:
    print(f"⚠ {host['hostname']} - {host['connection_state']}")
```

---

## Códigos de Respuesta HTTP

| Código | Descripción |
|--------|-------------|
| 200 | OK - Solicitud exitosa |
| 404 | Not Found - Endpoint no existe |
| 500 | Internal Server Error - Error en el servidor |

---

## Headers

Todas las respuestas incluyen:

```
Content-Type: application/json; charset=utf-8
Access-Control-Allow-Origin: *
```

---

## Limitaciones

- No hay autenticación implementada (solo red interna)
- Límite de resultados en algunos endpoints
- No hay paginación (se devuelven todos los resultados)

---

## Integración con Otros Sistemas

### Ejemplo: Enviar alerta a Slack

```powershell
$latest = Invoke-RestMethod "http://localhost:8080/api/latest"

if ($latest.availability_percent -lt 95) {
    $slackMessage = @{
        text = "⚠ Alerta VMware: Disponibilidad baja: $($latest.availability_percent)%"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" `
        -Method Post -Body $slackMessage -ContentType "application/json"
}
```

### Ejemplo: Monitorización con Prometheus

Puedes crear un exporter que consulte la API:

```python
# prometheus_exporter.py
from prometheus_client import start_http_server, Gauge
import requests
import time

# Métricas
availability = Gauge('vmware_availability_percent', 'VMware availability percentage')
disconnected_hosts = Gauge('vmware_disconnected_hosts', 'Number of disconnected hosts')

def collect_metrics():
    response = requests.get('http://localhost:8080/api/latest')
    data = response.json()
    
    availability.set(data['availability_percent'])
    disconnected_hosts.set(data['disconnected_hosts'])

if __name__ == '__main__':
    start_http_server(9090)
    while True:
        collect_metrics()
        time.sleep(60)
```

---

## Desarrollo

Para añadir nuevos endpoints, edita `Start-DashboardServer.ps1` y añade tu lógica en la sección de endpoints.

Ejemplo de nuevo endpoint:

```powershell
elseif ($url -eq "/api/mi-nuevo-endpoint") {
    $jsonData = Invoke-SQLiteQuery @"
SELECT * FROM mi_tabla WHERE condicion = 1;
"@
}
```

---

¿Necesitas un endpoint específico que no existe? Contacta con el equipo de desarrollo o modifica el código fuente.
