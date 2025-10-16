# Script para instalar System.Data.SQLite automáticamente
# Descarga la versión adecuada según tu sistema

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Instalador de System.Data.SQLite" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Detectar arquitectura
$is64bit = [Environment]::Is64BitProcess
$arch = if ($is64bit) { "x64" } else { "x86" }

Write-Host "Sistema detectado: $arch" -ForegroundColor Green
Write-Host ""

# Directorio de instalación (mismo donde está el script)
$installDir = $PSScriptRoot
$sqliteDir = Join-Path $installDir "sqlite"

Write-Host "Directorio de instalación: $installDir" -ForegroundColor Cyan
Write-Host ""

# URLs de descarga actualizadas
$sqliteToolsUrl = "https://www.sqlite.org/2024/sqlite-tools-win-x64-3460100.zip"
$sqliteDllUrl = "https://www.sqlite.org/2024/sqlite-dll-win-x64-3460100.zip"

Write-Host "Descargando SQLite Tools..." -ForegroundColor Cyan
Write-Host "URL: $sqliteToolsUrl" -ForegroundColor Gray

$toolsZip = Join-Path $env:TEMP "sqlite_tools.zip"
$dllZip = Join-Path $env:TEMP "sqlite_dll.zip"

try {
    # Descargar herramientas (sqlite3.exe)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $sqliteToolsUrl -OutFile $toolsZip -UseBasicParsing
    Write-Host "✓ SQLite Tools descargado" -ForegroundColor Green
    
    # Descargar DLL
    Write-Host "Descargando SQLite DLL..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $sqliteDllUrl -OutFile $dllZip -UseBasicParsing
    Write-Host "✓ SQLite DLL descargado" -ForegroundColor Green
    
    # Extraer herramientas
    Write-Host ""
    Write-Host "Extrayendo sqlite3.exe..." -ForegroundColor Cyan
    
    $toolsDir = Join-Path $env:TEMP "sqlite_tools_temp"
    if (Test-Path $toolsDir) {
        Remove-Item $toolsDir -Recurse -Force
    }
    Expand-Archive -Path $toolsZip -DestinationPath $toolsDir -Force
    
    # Buscar sqlite3.exe recursivamente
    $sqlite3exe = Get-ChildItem -Path $toolsDir -Filter "sqlite3.exe" -Recurse | Select-Object -First 1
    if ($sqlite3exe) {
        Copy-Item $sqlite3exe.FullName $installDir -Force
        Write-Host "✓ sqlite3.exe instalado" -ForegroundColor Green
    } else {
        Write-Host "⚠ sqlite3.exe no encontrado en el zip" -ForegroundColor Yellow
    }
    
    # Extraer DLL
    Write-Host "Extrayendo sqlite3.dll..." -ForegroundColor Cyan
    
    $dllDir = Join-Path $env:TEMP "sqlite_dll_temp"
    if (Test-Path $dllDir) {
        Remove-Item $dllDir -Recurse -Force
    }
    Expand-Archive -Path $dllZip -DestinationPath $dllDir -Force
    
    # Buscar sqlite3.dll recursivamente
    $sqlite3dll = Get-ChildItem -Path $dllDir -Filter "sqlite3.dll" -Recurse | Select-Object -First 1
    if ($sqlite3dll) {
        Copy-Item $sqlite3dll.FullName $installDir -Force
        Write-Host "✓ sqlite3.dll instalado" -ForegroundColor Green
    }
    
    # Limpiar temporales
    Remove-Item $toolsZip -Force -ErrorAction SilentlyContinue
    Remove-Item $dllZip -Force -ErrorAction SilentlyContinue
    Remove-Item $toolsDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $dllDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "✅ SQLite instalado correctamente" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Archivos instalados en:" -ForegroundColor White
    Write-Host "  $installDir" -ForegroundColor Cyan
    Write-Host ""
    
    # Listar archivos instalados
    $installedFiles = @("sqlite3.exe", "sqlite3.dll")
    foreach ($file in $installedFiles) {
        $filePath = Join-Path $installDir $file
        if (Test-Path $filePath) {
            $size = [math]::Round((Get-Item $filePath).Length / 1MB, 2)
            Write-Host "  ✓ $file ($size MB)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "Prueba de instalación:" -ForegroundColor Cyan
    
    # Probar sqlite3.exe
    $sqlite3Path = Join-Path $installDir "sqlite3.exe"
    if (Test-Path $sqlite3Path) {
        try {
            $version = & $sqlite3Path --version 2>&1
            if ($version) {
                Write-Host "✓ sqlite3.exe funciona correctamente" -ForegroundColor Green
                Write-Host "  Versión: $($version.Split()[0])" -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "⚠ sqlite3.exe instalado pero no se pudo verificar" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ sqlite3.exe no encontrado" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Próximos pasos:" -ForegroundColor Cyan
    Write-Host "  1. Ejecuta: .\Initialize-MonitoringDatabase.ps1" -ForegroundColor White
    Write-Host "  2. Ejecuta: .\check_esxi_with_history.ps1" -ForegroundColor White
    Write-Host "  3. Visualiza: .\Start-DashboardServer.ps1" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "✗ Error durante la instalación: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instalación manual:" -ForegroundColor Yellow
    Write-Host "  1. Visita: https://www.sqlite.org/download.html" -ForegroundColor White
    Write-Host "  2. Descarga: sqlite-tools-win-x64-*.zip" -ForegroundColor White
    Write-Host "  3. Extrae sqlite3.exe a: $installDir" -ForegroundColor White
    Write-Host ""
    exit 1
}
