# Script de Diagnóstico - Prueba BD y API

$DatabasePath = ".\data\vmware_monitoring.db"
$sqlite3Path = ".\sqlite3.exe"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Diagnóstico de Dashboard VMware" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar Base de Datos
Write-Host "1. Verificando base de datos..." -ForegroundColor Cyan
if (Test-Path $DatabasePath) {
    Write-Host "   ✓ Base de datos encontrada" -ForegroundColor Green
    $dbSize = [math]::Round((Get-Item $DatabasePath).Length / 1KB, 2)
    Write-Host "   Tamaño: $dbSize KB" -ForegroundColor Gray
} else {
    Write-Host "   ✗ Base de datos NO encontrada" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 2. Verificar SQLite
Write-Host "2. Verificando sqlite3.exe..." -ForegroundColor Cyan
if (Test-Path $sqlite3Path) {
    Write-Host "   ✓ sqlite3.exe encontrado" -ForegroundColor Green
} else {
    Write-Host "   ✗ sqlite3.exe NO encontrado" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 3. Verificar datos en BD
Write-Host "3. Verificando datos..." -ForegroundColor Cyan

$execCount = & $sqlite3Path $DatabasePath "SELECT COUNT(*) FROM executions;" 2>&1
Write-Host "   Ejecuciones registradas: $execCount" -ForegroundColor Gray

$hostCount = & $sqlite3Path $DatabasePath "SELECT COUNT(*) FROM hosts;" 2>&1
Write-Host "   Hosts en histórico: $hostCount" -ForegroundColor Gray

if ([int]$execCount -eq 0) {
    Write-Host "   ⚠ No hay datos. Ejecuta: .\Collect-VMwareData.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 4. Probar query JSON
Write-Host "4. Probando formato JSON..." -ForegroundColor Cyan

$tempFile = Join-Path $env:TEMP "test_query.sql"
".mode json`nSELECT * FROM executions LIMIT 1;" | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

$jsonResult = & $sqlite3Path $DatabasePath ".read $tempFile" 2>&1
Remove-Item $tempFile -Force

if ($jsonResult) {
    Write-Host "   ✓ JSON generado correctamente" -ForegroundColor Green
    Write-Host "   Primeros 200 caracteres:" -ForegroundColor Gray
    Write-Host "   $($jsonResult.ToString().Substring(0, [Math]::Min(200, $jsonResult.Length)))..." -ForegroundColor Gray
} else {
    Write-Host "   ✗ No se pudo generar JSON" -ForegroundColor Red
}

Write-Host ""

# 5. Probar API (si el servidor está corriendo)
Write-Host "5. Probando API (si el servidor está activo)..." -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/api/latest" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "   ✓ API respondiendo correctamente" -ForegroundColor Green
    Write-Host "   Status: $($response.StatusCode)" -ForegroundColor Gray
    Write-Host "   Content-Type: $($response.Headers['Content-Type'])" -ForegroundColor Gray
    Write-Host "   Tamaño respuesta: $($response.Content.Length) bytes" -ForegroundColor Gray
}
catch {
    if ($_.Exception.Message -match "No se puede conectar") {
        Write-Host "   ⊘ Servidor no está corriendo" -ForegroundColor Yellow
        Write-Host "   Inicia con: .\Start-DashboardServer.ps1" -ForegroundColor White
    } else {
        Write-Host "   ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Diagnóstico completado" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ([int]$execCount -gt 0) {
    Write-Host "✓ Todo parece estar bien" -ForegroundColor Green
    Write-Host ""
    Write-Host "Si el dashboard muestra error:" -ForegroundColor Yellow
    Write-Host "  1. Abre la consola del navegador (F12)" -ForegroundColor White
    Write-Host "  2. Ve a la pestaña 'Console'" -ForegroundColor White
    Write-Host "  3. Ve a la pestaña 'Network'" -ForegroundColor White
    Write-Host "  4. Recarga la página (F5)" -ForegroundColor White
    Write-Host "  5. Busca peticiones en rojo y compárteme el error" -ForegroundColor White
}
Write-Host ""
