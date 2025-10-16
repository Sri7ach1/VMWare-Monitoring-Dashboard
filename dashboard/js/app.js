// Main Application - Coordina carga de datos y actualización de UI
const App = {
    currentDateRange: 7,
    currentDatacenter: 'all',
    
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
                disconnectedHosts,
                recentExecutions,
                datacenters
            ] = await Promise.all([
                API.getLatestSummary(),
                API.getAvailabilityTrend(this.currentDateRange),
                API.getVersionDistribution(),
                API.getDatacenterStats(),
                API.getDisconnectedHosts(),
                API.getRecentExecutions(10),
                API.getDatacenters()
            ]);
            
            console.log('Datos recibidos:', {
                summary,
                availabilityTrend: availabilityTrend?.length,
                versions: versions?.length,
                datacenterStats: datacenterStats?.length,
                disconnectedHosts: disconnectedHosts?.length,
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
            this.updateTables(disconnectedHosts, recentExecutions);
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
        if (!data) return;
        
        document.getElementById('totalHosts').textContent = data.total_hosts || '-';
        document.getElementById('availability').textContent = 
            data.availability_percent ? `${data.availability_percent}%` : '-';
        document.getElementById('disconnectedHosts').textContent = data.disconnected_hosts || '0';
        document.getElementById('vcentersCount').textContent = 
            `${data.vcenters_processed}/${data.vcenters_total}`;
        document.getElementById('datacentersCount').textContent = data.datacenters_count || '-';
        document.getElementById('clustersCount').textContent = data.clusters_processed || '-';
        
        // Cambiar color del KPI de disponibilidad según porcentaje
        const availabilityCard = document.getElementById('availability').closest('.kpi-card');
        availabilityCard.className = 'kpi-card';
        if (data.availability_percent >= 95) {
            availabilityCard.classList.add('kpi-success');
        } else if (data.availability_percent >= 90) {
            availabilityCard.classList.add('kpi-warning');
        } else {
            availabilityCard.classList.add('kpi-danger');
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
    
    // Actualizar tablas
    updateTables(disconnectedHosts, recentExecutions) {
        // Tabla de hosts desconectados
        const disconnectedSection = document.getElementById('disconnectedSection');
        const disconnectedTable = document.getElementById('disconnectedTable').querySelector('tbody');
        
        if (disconnectedHosts && disconnectedHosts.length > 0) {
            disconnectedSection.style.display = 'block';
            disconnectedTable.innerHTML = disconnectedHosts.map(host => `
                <tr>
                    <td>${host.hostname}</td>
                    <td>${host.datacenter}</td>
                    <td>${host.cluster}</td>
                    <td>${host.vcenter}</td>
                    <td><span class="status-badge status-disconnected">${host.connection_state}</span></td>
                    <td>${host.esxi_version} (${host.esxi_build})</td>
                </tr>
            `).join('');
        } else {
            disconnectedSection.style.display = 'none';
        }
        
        // Tabla de últimas ejecuciones
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
        const currentValue = select.value;
        
        // Mantener "Todos"
        select.innerHTML = '<option value="all">Todos</option>';
        
        if (datacenters && datacenters.length > 0) {
            datacenters.forEach(dc => {
                const option = document.createElement('option');
                option.value = dc;
                option.textContent = dc;
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
