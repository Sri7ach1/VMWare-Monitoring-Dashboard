# Servidor Web para Dashboard VMware
# Sirve el dashboard HTML y proporciona API REST para consultar SQLite

param(
    [int]$Port = 8080,
    [string]$DatabasePath = ".\data\vmware_monitoring.db"
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "VMware Dashboard Server" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verificar base de datos
if (-not (Test-Path $DatabasePath)) {
    Write-Host "✗ Base de datos no encontrada: $DatabasePath" -ForegroundColor Red
    Write-Host "  Ejecuta primero: .\Collect-VMwareData.ps1" -ForegroundColor Yellow
    exit 1
}

# Verificar sqlite3.exe
$sqlite3Path = $null
$searchPaths = @(".\sqlite3.exe", "$PSScriptRoot\sqlite3.exe")
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $sqlite3Path = $path
        break
    }
}

if (-not $sqlite3Path) {
    Write-Host "✗ sqlite3.exe no encontrado" -ForegroundColor Red
    exit 1
}

# Verificar directorio dashboard
$dashboardPath = Join-Path $PSScriptRoot "dashboard"
if (-not (Test-Path $dashboardPath)) {
    Write-Host "✗ Directorio dashboard no encontrado: $dashboardPath" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Base de datos: $DatabasePath" -ForegroundColor Green
Write-Host "✓ Dashboard: $dashboardPath" -ForegroundColor Green
Write-Host "✓ Puerto: $Port" -ForegroundColor Green
Write-Host ""

# Función para ejecutar queries SQL
function Invoke-SQLiteQuery {
    param([string]$Query)
    
    try {
        $tempFile = Join-Path $env:TEMP "query_$(Get-Random).sql"
        ".mode json`n$Query" | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
        
        $result = & $sqlite3Path $DatabasePath ".read $tempFile" 2>&1
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        # Verificar si hay error
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ⚠ SQLite error: $result" -ForegroundColor Yellow
            return "[]"
        }
        
        if ($result) {
            # Si el resultado es un array, unirlo
            if ($result -is [Array]) {
                $jsonStr = $result -join "`n"
            } else {
                $jsonStr = $result
            }
            
            # Verificar que sea JSON válido
            if ($jsonStr.Trim().StartsWith('[') -or $jsonStr.Trim().StartsWith('{')) {
                return $jsonStr
            }
        }
        
        # Si no hay resultado o no es JSON, devolver array vacío
        return "[]"
    }
    catch {
        Write-Host "  ✗ Error SQL: $($_.Exception.Message)" -ForegroundColor Red
        return "[]"
    }
}

# Función para determinar Content-Type
function Get-ContentType {
    param([string]$Extension)
    
    $types = @{
        '.html' = 'text/html; charset=utf-8'
        '.css'  = 'text/css; charset=utf-8'
        '.js'   = 'application/javascript; charset=utf-8'
        '.json' = 'application/json; charset=utf-8'
        '.png'  = 'image/png'
        '.jpg'  = 'image/jpeg'
        '.svg'  = 'image/svg+xml'
        '.ico'  = 'image/x-icon'
    }
    
    return $types[$Extension] ?? 'text/plain'
}

# Crear HTTP Listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Servidor iniciado" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Dashboard: http://localhost:$Port" -ForegroundColor Cyan
Write-Host "📊 API: http://localhost:$Port/api/*" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona Ctrl+C para detener el servidor" -ForegroundColor Yellow
Write-Host ""
Write-Host "Logs de solicitudes:" -ForegroundColor Gray
Write-Host ""

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        $method = $request.HttpMethod
        $url = $request.Url.LocalPath
        
        Write-Host "[$timestamp] $method $url" -ForegroundColor Gray
        
        try {
            # API Endpoints
            if ($url -like "/api/*") {
                $response.ContentType = "application/json; charset=utf-8"
                $response.Headers.Add("Access-Control-Allow-Origin", "*")
                
                $jsonData = ""
                
                # Procesar cada endpoint
                if ($url -eq "/api/latest") {
                    Write-Host "  → Consultando última ejecución..." -ForegroundColor Cyan
                    $result = Invoke-SQLiteQuery "SELECT * FROM executions ORDER BY execution_date DESC LIMIT 1;"
                    Write-Host "  ← Resultado SQL: $($result.Length) bytes" -ForegroundColor Gray
                    
                    # Convertir de JSON array a objeto único
                    try {
                        $parsed = $result | ConvertFrom-Json
                        Write-Host "  → Tipo de dato: $($parsed.GetType().Name)" -ForegroundColor Gray
                        
                        if ($parsed -is [Array] -and $parsed.Count -gt 0) {
                            Write-Host "  → Convirtiendo array[0] a objeto" -ForegroundColor Gray
                            $jsonData = ($parsed[0] | ConvertTo-Json -Compress -Depth 10)
                        } elseif ($parsed -is [PSCustomObject]) {
                            Write-Host "  → Ya es un objeto" -ForegroundColor Gray
                            $jsonData = ($parsed | ConvertTo-Json -Compress -Depth 10)
                        } else {
                            Write-Host "  → Usando resultado original" -ForegroundColor Gray
                            $jsonData = $result
                        }
                        
                        Write-Host "  ← Resultado final: $($jsonData.Substring(0, [Math]::Min(100, $jsonData.Length)))..." -ForegroundColor Gray
                    } catch {
                        Write-Host "  ⚠ Error en conversión: $($_.Exception.Message)" -ForegroundColor Yellow
                        $jsonData = $result
                    }
                }
                elseif ($url -like "/api/availability-trend*") {
                    $days = 7
                    if ($request.QueryString["days"]) {
                        $days = [int]$request.QueryString["days"]
                    }
                    $jsonData = Invoke-SQLiteQuery "SELECT * FROM v_availability_trend LIMIT $days;"
                }
                elseif ($url -eq "/api/version-distribution") {
                    $jsonData = Invoke-SQLiteQuery @"
SELECT vd.* FROM version_distribution vd
JOIN executions e ON vd.execution_id = e.id
ORDER BY e.execution_date DESC, vd.host_count DESC
LIMIT 10;
"@
                }
                elseif ($url -eq "/api/datacenter-stats") {
                    $jsonData = Invoke-SQLiteQuery @"
SELECT ds.* FROM datacenter_stats ds
JOIN executions e ON ds.execution_id = e.id
ORDER BY e.execution_date DESC
LIMIT 50;
"@
                }
                elseif ($url -eq "/api/disconnected-hosts") {
                    # Hosts desconectados de la última ejecución solamente
                    $jsonData = Invoke-SQLiteQuery @"
SELECT 
    h.hostname,
    h.datacenter,
    h.cluster,
    h.vcenter,
    h.connection_state,
    h.esxi_version,
    h.esxi_build,
    e.execution_date as detected_at
FROM hosts h
JOIN executions e ON h.execution_id = e.id
WHERE h.is_connected = 0
  AND e.id = (SELECT MAX(id) FROM executions)
ORDER BY h.hostname;
"@
                }
                elseif ($url -like "/api/disconnected-history*") {
                    # Histórico de hosts desconectados con filtro de tiempo
                    $period = "7"
                    if ($request.QueryString["period"]) {
                        $period = $request.QueryString["period"]
                    }
                    
                    $whereClause = if ($period -eq "latest") {
                        "AND e.id = (SELECT MAX(id) FROM executions)"
                    } elseif ($period -eq "all") {
                        ""
                    } else {
                        "AND e.execution_date >= datetime('now', '-$period days')"
                    }
                    
                    $jsonData = Invoke-SQLiteQuery @"
SELECT 
    h.hostname,
    h.datacenter,
    h.cluster,
    h.vcenter,
    h.connection_state,
    h.esxi_version,
    h.esxi_build,
    e.execution_date as detected_at
FROM hosts h
JOIN executions e ON h.execution_id = e.id
WHERE h.is_connected = 0
  $whereClause
ORDER BY e.execution_date DESC, h.hostname;
"@
                }
                elseif ($url -like "/api/recent-executions*") {
                    $limit = 10
                    if ($request.QueryString["limit"]) {
                        $limit = [int]$request.QueryString["limit"]
                    }
                    $jsonData = Invoke-SQLiteQuery "SELECT * FROM v_recent_executions LIMIT $limit;"
                }
                elseif ($url -eq "/api/datacenters") {
                    # Devolver array simple de strings, no objetos
                    $query = @"
SELECT DISTINCT datacenter_name 
FROM datacenter_stats 
ORDER BY datacenter_name;
"@
                    $result = Invoke-SQLiteQuery $query
                    
                    try {
                        # Convertir objetos a array de strings
                        $parsed = $result | ConvertFrom-Json
                        if ($parsed) {
                            $dcNames = $parsed | ForEach-Object { $_.datacenter_name }
                            $jsonData = ($dcNames | ConvertTo-Json -Compress)
                        } else {
                            $jsonData = "[]"
                        }
                    } catch {
                        $jsonData = "[]"
                    }
                }
                else {
                    $jsonData = '{"error": "Endpoint not found"}'
                    Write-Host "  ✗ Endpoint no encontrado: $url" -ForegroundColor Red
                }
                
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            # Archivos estáticos
            else {
                $filePath = if ($url -eq "/" -or $url -eq "") {
                    Join-Path $dashboardPath "index.html"
                } else {
                    Join-Path $dashboardPath $url.TrimStart('/')
                }
                
                if (Test-Path $filePath -PathType Leaf) {
                    $extension = [System.IO.Path]::GetExtension($filePath)
                    $response.ContentType = Get-ContentType $extension
                    
                    $content = [System.IO.File]::ReadAllBytes($filePath)
                    $response.ContentLength64 = $content.Length
                    $response.OutputStream.Write($content, 0, $content.Length)
                } else {
                    $response.StatusCode = 404
                    $html = "<h1>404 - Not Found</h1><p>$url</p>"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
        }
        catch {
            Write-Host "  Error: $_" -ForegroundColor Red
            $response.StatusCode = 500
        }
        finally {
            $response.OutputStream.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host ""
    Write-Host "Servidor detenido" -ForegroundColor Yellow
}
