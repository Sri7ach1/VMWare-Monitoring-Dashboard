// Main Application - Coordina carga de datos y actualización de UI
const App = {
    currentDateRange: 7,
    currentDatacenter: 'all',
    currentDisconnectedPeriod: '7',
    
    // Inicializar aplicación
    async init() {
        console.log('Inicializando dashboard...');
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Cargar datos iniciales
        await this.loadAllData();
        
        // Auto-refresh cada 5 minutos
        setInterval(() => this.loadAllData(), 300000);
    },
    
    // Configurar event listeners
    setupEventListeners() {
        // Botón de refresh
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.loadAllData();
        });
        
        // Filtro de rango de fechas
        document.getElementById('dateRange').addEventListener('change', (e) => {
            this.currentDateRange = e.target.value;
            this.loadAllData();
        });
        
        // Filtro de datacenter
        document.getElementById('datacenterFilter').addEventListener('change', (e) => {
            this.currentDatacenter = e.target.value;
            this.loadAllData();
        });
        
        // Filtro de histórico de desconexiones
        document.getElementById('disconnectedHistoryFilter').addEventListener('change', (e) => {
            this.currentDisconnectedPeriod = e.target.value;
            this.loadDisconnectedHistory();
        });
        
        // Botón de exportar
        document.getElementById('exportBtn').addEventListener('click', () => {
            this.exportData();
        });
    },
    
    // Cargar todos los datos
    async loadAllData() {
        this.showLoading(true);
        
        try {
            console.log('Cargando datos del dashboard...');
            
            // Cargar datos en paralelo
            const [
                summary,
                availabilityTrend,
                versions,
                datacenterStats,
                disconnectedNow,
                disconnectedHistory,
                recentExecutions,
                datacenters
            ] = await Promise.all([
                API.getLatestSummary(),
                API.getAvailabilityTrend(this.currentDateRange),
                API.getVersionDistribution(),
                API.getDatacenterStats(),
                API.getDisconnectedHosts(),
                API.getDisconnectedHistory(this.currentDisconnectedPeriod),
                API.getRecentExecutions(10),
                API.getDatacenters()
            ]);
            
            console.log('Datos recibidos:', {
                summary,
                availabilityTrend: availabilityTrend?.length,
                versions: versions?.length,
                datacenterStats: datacenterStats?.length,
                disconnectedNow: disconnectedNow?.length,
                disconnectedHistory: disconnectedHistory?.length,
                recentExecutions: recentExecutions?.length,
                datacenters: datacenters?.length
            });
            
            // Verificar que al menos tengamos el resumen
            if (!summary) {
                throw new Error('No se pudo obtener el resumen de la última ejecución');
            }
            
            // Actualizar UI
            this.updateKPIs(summary);
            this.updateCharts(availabilityTrend, versions, datacenterStats, recentExecutions);
            this.updateDisconnectedTables(disconnectedNow, disconnectedHistory);
            this.updateExecutionsTable(recentExecutions);
            this.updateDatacenterFilter(datacenters);
            this.updateLastUpdate();
            
            console.log('Dashboard actualizado correctamente');
            
        } catch (error) {
            console.error('Error cargando datos:', error);
            this.showError('Error al cargar los datos del servidor: ' + error.message);
        } finally {
            this.showLoading(false);
        }
    },
    
    // Actualizar KPIs
    updateKPIs(data) {
        if (!data) {
            console.error('updateKPIs: No data received');
            return;
        }
        
        console.log('updateKPIs - Raw data:', data);
        console.log('vcenters_processed:', data.vcenters_processed, 'type:', typeof data.vcenters_processed);
        console.log('vcenters_total:', data.vcenters_total, 'type:', typeof data.vcenters_total);
        
        document.getElementById('totalHosts').textContent = data.total_hosts || '0';
        document.getElementById('availability').textContent = 
            data.availability_percent ? `${data.availability_percent}%` : '0%';
        document.getElementById('disconnectedHosts').textContent = data.disconnected_hosts || '0';
        
        const vcentersProcessed = data.vcenters_processed || 0;
        const vcentersTotal = data.vcenters_total || 0;
        document.getElementById('vcentersCount').textContent = `${vcentersProcessed}/${vcentersTotal}`;
        console.log('Setting vcentersCount to:', `${vcentersProcessed}/${vcentersTotal}`);
        
        document.getElementById('datacentersCount').textContent = data.datacenters_count || '0';
        document.getElementById('clustersCount').textContent = data.clusters_processed || '0';
        
        // Cambiar color del KPI de disponibilidad según porcentaje
        const availabilityCard = document.getElementById('availability').closest('.kpi-card');
        if (availabilityCard) {
            availabilityCard.className = 'kpi-card';
            const availPct = parseFloat(data.availability_percent) || 0;
            if (availPct >= 95) {
                availabilityCard.classList.add('kpi-success');
            } else if (availPct >= 90) {
                availabilityCard.classList.add('kpi-warning');
            } else {
                availabilityCard.classList.add('kpi-danger');
            }
        }
    },
    
    // Actualizar gráficos
    updateCharts(availabilityData, versionsData, datacenterData, executionsData) {
        // Verificar si Chart.js está disponible
        if (typeof Chart === 'undefined') {
            console.warn('Chart.js no disponible - Los gráficos no se mostrarán');
            // Ocultar contenedores de gráficos
            document.querySelectorAll('.chart-container').forEach(container => {
                container.style.display = 'none';
            });
            return;
        }
        
        if (availabilityData && availabilityData.length > 0) {
            Charts.createAvailabilityChart(availabilityData.reverse());
        }
        
        if (versionsData && versionsData.length > 0) {
            Charts.createVersionsChart(versionsData);
        }
        
        if (datacenterData && datacenterData.length > 0) {
            Charts.createDatacenterChart(datacenterData);
        }
        
        if (executionsData && executionsData.length > 0) {
            Charts.createExecutionsChart(executionsData.reverse().slice(0, 10));
        }
    },
    
    // Actualizar tablas de hosts desconectados
    updateDisconnectedTables(disconnectedNow, disconnectedHistory) {
        // Tabla de hosts desconectados AHORA (última ejecución)
        const disconnectedNowSection = document.getElementById('disconnectedNowSection');
        const disconnectedNowTableElement = document.getElementById('disconnectedNowTable');
        const disconnectedNowCount = document.getElementById('disconnectedNowCount');
        
        if (!disconnectedNowSection || !disconnectedNowTableElement || !disconnectedNowCount) {
            console.error('Elementos de tabla "disconnected now" no encontrados');
            return;
        }
        
        const disconnectedNowTable = disconnectedNowTableElement.querySelector('tbody');
        if (!disconnectedNowTable) {
            console.error('tbody de disconnectedNowTable no encontrado');
            return;
        }
        
        if (disconnectedNow && disconnectedNow.length > 0) {
            disconnectedNowSection.style.display = 'block';
            disconnectedNowCount.textContent = disconnectedNow.length;
            
            disconnectedNowTable.innerHTML = disconnectedNow.map(host => {
                const detectedDate = new Date(host.detected_at);
                const dateStr = detectedDate.toLocaleString('es-ES', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });
                
                return `
                <tr>
                    <td>${host.hostname}</td>
                    <td>${host.datacenter}</td>
                    <td>${host.cluster}</td>
                    <td>${host.vcenter}</td>
                    <td><span class="status-badge status-disconnected">${host.connection_state}</span></td>
                    <td>${host.esxi_version} (${host.esxi_build})</td>
                    <td>${dateStr}</td>
                </tr>
            `;
            }).join('');
        } else {
            disconnectedNowSection.style.display = 'none';
        }
        
        // Tabla de histórico de desconexiones
        const disconnectedHistoryTableElement = document.getElementById('disconnectedHistoryTable');
        if (!disconnectedHistoryTableElement) {
            console.error('Elemento disconnectedHistoryTable no encontrado');
            return;
        }
        
        const disconnectedHistoryTable = disconnectedHistoryTableElement.querySelector('tbody');
        if (!disconnectedHistoryTable) {
            console.error('tbody de disconnectedHistoryTable no encontrado');
            return;
        }
        
        if (disconnectedHistory && disconnectedHistory.length > 0) {
            disconnectedHistoryTable.innerHTML = disconnectedHistory.map(host => {
                const detectedDate = new Date(host.detected_at);
                const dateStr = detectedDate.toLocaleString('es-ES', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });
                
                return `
                <tr>
                    <td>${host.hostname}</td>
                    <td>${host.datacenter}</td>
                    <td>${host.cluster}</td>
                    <td>${host.vcenter}</td>
                    <td><span class="status-badge status-disconnected">${host.connection_state}</span></td>
                    <td>${host.esxi_version} (${host.esxi_build})</td>
                    <td>${dateStr}</td>
                </tr>
            `;
            }).join('');
        } else {
            disconnectedHistoryTable.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 20px;">No hay hosts desconectados en el período seleccionado</td></tr>';
        }
    },
    
    // Actualizar tabla de ejecuciones
    updateExecutionsTable(recentExecutions) {
        const executionsTable = document.getElementById('executionsTable').querySelector('tbody');
        
        if (recentExecutions && recentExecutions.length > 0) {
            executionsTable.innerHTML = recentExecutions.map(exec => {
                const date = new Date(exec.execution_date);
                const dateStr = date.toLocaleString('es-ES', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });
                
                const availClass = exec.availability_percent >= 95 ? 'success' : 
                                  exec.availability_percent >= 90 ? 'warning' : 'danger';
                
                const alertBadge = exec.disconnected_hosts > 0 ? 
                    '<span class="status-badge status-disconnected">Alerta</span>' : 
                    '<span class="status-badge status-connected">OK</span>';
                
                return `
                    <tr>
                        <td>${dateStr}</td>
                        <td>${exec.total_hosts}</td>
                        <td>${exec.connected_hosts}</td>
                        <td>${exec.disconnected_hosts}</td>
                        <td><span class="status-badge status-${availClass}">${exec.availability_percent}%</span></td>
                        <td>${exec.vcenters_processed}</td>
                        <td>${alertBadge}</td>
                    </tr>
                `;
            }).join('');
        }
    },
    
    // Actualizar filtro de datacenters
    updateDatacenterFilter(datacenters) {
        const select = document.getElementById('datacenterFilter');
        if (!select) return;
        
        const currentValue = select.value;
        
        // Mantener "Todos"
        select.innerHTML = '<option value="all">Todos</option>';
        
        if (datacenters && Array.isArray(datacenters) && datacenters.length > 0) {
            datacenters.forEach(dc => {
                // Asegurarse de que dc es un string
                const dcName = typeof dc === 'string' ? dc : (dc.datacenter_name || dc.toString());
                const option = document.createElement('option');
                option.value = dcName;
                option.textContent = dcName;
                select.appendChild(option);
            });
        }
        
        // Restaurar selección si existe
        if (currentValue && Array.from(select.options).some(o => o.value === currentValue)) {
            select.value = currentValue;
        }
    },
    
    // Actualizar timestamp de última actualización
    updateLastUpdate() {
        const now = new Date();
        const timeStr = now.toLocaleString('es-ES', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
        document.getElementById('lastUpdate').textContent = timeStr;
    },
    
    // Cargar solo histórico de desconexiones (cuando cambia el filtro)
    async loadDisconnectedHistory() {
        try {
            const disconnectedHistory = await API.getDisconnectedHistory(this.currentDisconnectedPeriod);
            
            const disconnectedHistoryTable = document.getElementById('disconnectedHistoryTable').querySelector('tbody');
            
            if (disconnectedHistory && disconnectedHistory.length > 0) {
                disconnectedHistoryTable.innerHTML = disconnectedHistory.map(host => {
                    const detectedDate = new Date(host.detected_at);
                    const dateStr = detectedDate.toLocaleString('es-ES', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                    
                    return `
                    <tr>
                        <td>${host.hostname}</td>
                        <td>${host.datacenter}</td>
                        <td>${host.cluster}</td>
                        <td>${host.vcenter}</td>
                        <td><span class="status-badge status-disconnected">${host.connection_state}</span></td>
                        <td>${host.esxi_version} (${host.esxi_build})</td>
                        <td>${dateStr}</td>
                    </tr>
                `;
                }).join('');
            } else {
                disconnectedHistoryTable.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 20px;">No hay hosts desconectados en el período seleccionado</td></tr>';
            }
        } catch (error) {
            console.error('Error cargando histórico:', error);
        }
    },
    
    // Mostrar/ocultar overlay de carga
    showLoading(show) {
        const overlay = document.getElementById('loadingOverlay');
        if (show) {
            overlay.classList.add('active');
        } else {
            overlay.classList.remove('active');
        }
    },
    
    // Mostrar error
    showError(message) {
        alert(message); // Podrías usar una notificación más elegante
    },
    
    // Exportar datos (placeholder)
    exportData() {
        alert('Funcionalidad de exportación en desarrollo');
        // Aquí podrías implementar exportación a CSV, Excel, etc.
    }
};

// Inicializar cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    App.init();
});