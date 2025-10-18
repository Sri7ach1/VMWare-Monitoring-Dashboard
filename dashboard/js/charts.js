// Charts Module - Configuración y creación de gráficos con Chart.js

// Verificar que Chart.js está cargado
if (typeof Chart === 'undefined') {
    console.error('Chart.js no está cargado. Verifica la conexión a internet.');
}

const Charts = {
    availabilityChart: null,
    versionsChart: null,
    datacenterChart: null,
    executionsChart: null,
    
    // Crear gráfico de tendencia de disponibilidad
    createAvailabilityChart(data) {
        if (typeof Chart === 'undefined') {
            console.error('Chart.js no disponible');
            return;
        }
        
        const ctx = document.getElementById('availabilityChart');
        
        if (this.availabilityChart) {
            this.availabilityChart.destroy();
        }
        
        this.availabilityChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.map(d => d.date),
                datasets: [{
                    label: 'Disponibilidad (%)',
                    data: data.map(d => d.avg_availability),
                    borderColor: '#10b981',
                    backgroundColor: 'rgba(16, 185, 129, 0.1)',
                    tension: 0.4,
                    fill: true,
                    pointRadius: 4,
                    pointHoverRadius: 6
                }, {
                    label: 'Hosts Desconectados',
                    data: data.map(d => d.total_disconnected),
                    borderColor: '#ef4444',
                    backgroundColor: 'rgba(239, 68, 68, 0.1)',
                    tension: 0.4,
                    fill: true,
                    yAxisID: 'y1',
                    pointRadius: 4,
                    pointHoverRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                interaction: {
                    mode: 'index',
                    intersect: false,
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        padding: 12,
                        titleFont: { size: 14 },
                        bodyFont: { size: 13 }
                    }
                },
                scales: {
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        min: 0,
                        max: 100,
                        title: {
                            display: true,
                            text: 'Disponibilidad (%)'
                        }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        min: 0,
                        title: {
                            display: true,
                            text: 'Hosts Desconectados'
                        },
                        grid: {
                            drawOnChartArea: false,
                        }
                    }
                }
            }
        });
    },
    
    // Crear gráfico de distribución de versiones
    createVersionsChart(data) {
        if (typeof Chart === 'undefined') {
            console.error('Chart.js no disponible');
            return;
        }
        
        const ctx = document.getElementById('versionsChart');
        
        if (this.versionsChart) {
            this.versionsChart.destroy();
        }
        
        // Tomar solo top 5
        const top5 = data.slice(0, 5);
        
        this.versionsChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: top5.map(d => d.version_full),
                datasets: [{
                    data: top5.map(d => d.host_count),
                    backgroundColor: [
                        '#3b82f6',
                        '#10b981',
                        '#f59e0b',
                        '#ef4444',
                        '#8b5cf6'
                    ],
                    borderWidth: 2,
                    borderColor: '#fff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        display: true,
                        position: 'right',
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        padding: 12,
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.parsed || 0;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                return `${label}: ${value} hosts (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
    },
    
    // Crear gráfico de hosts por datacenter
    createDatacenterChart(data) {
        if (typeof Chart === 'undefined') {
            console.error('Chart.js no disponible');
            return;
        }
        
        const ctx = document.getElementById('datacenterChart');
        
        if (this.datacenterChart) {
            this.datacenterChart.destroy();
        }
        
        // Ordenar por total de hosts
        const sorted = data.sort((a, b) => b.total_hosts - a.total_hosts);
        
        this.datacenterChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: sorted.map(d => d.datacenter_name),
                datasets: [{
                    label: 'Hosts Conectados',
                    data: sorted.map(d => d.connected_hosts),
                    backgroundColor: '#10b981',
                }, {
                    label: 'Hosts Desconectados',
                    data: sorted.map(d => d.disconnected_hosts),
                    backgroundColor: '#ef4444',
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                indexAxis: 'y',
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        padding: 12,
                    }
                },
                scales: {
                    x: {
                        stacked: true,
                        title: {
                            display: true,
                            text: 'Número de Hosts'
                        }
                    },
                    y: {
                        stacked: true,
                    }
                }
            }
        });
    },
    
    // Crear gráfico de histórico de ejecuciones
    createExecutionsChart(data) {
        if (typeof Chart === 'undefined') {
            console.error('Chart.js no disponible');
            return;
        }
        
        const ctx = document.getElementById('executionsChart');
        
        if (this.executionsChart) {
            this.executionsChart.destroy();
        }
        
        this.executionsChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: data.map(d => {
                    const date = new Date(d.execution_date);
                    return date.toLocaleString('es-ES', { 
                        month: 'short', 
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                }),
                datasets: [{
                    label: 'Total Hosts',
                    data: data.map(d => d.total_hosts),
                    backgroundColor: '#3b82f6',
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        display: false,
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        padding: 12,
                        callbacks: {
                            label: function(context) {
                                return `Total: ${context.parsed.y} hosts`;
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Número de Hosts'
                        }
                    }
                }
            }
        });
    }
};