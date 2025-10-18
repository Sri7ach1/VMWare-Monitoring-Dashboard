// API Module - Maneja todas las peticiones a la base de datos
const API = {
    // Detectar puerto automáticamente
    baseUrl: `http://${window.location.hostname}:${window.location.port}/api`,
    
    // Obtener resumen de última ejecución
    async getLatestSummary() {
        try {
            const response = await fetch(`${this.baseUrl}/latest`);
            if (!response.ok) {
                console.error('API error:', response.status, response.statusText);
                return null;
            }
            let data = await response.json();
            
            // Si es un array, tomar el primer elemento
            if (Array.isArray(data) && data.length > 0) {
                data = data[0];
            }
            
            console.log('Latest summary:', data);
            return data;
        } catch (error) {
            console.error('Error fetching latest summary:', error);
            return null;
        }
    },
    
    // Obtener tendencia de disponibilidad
    async getAvailabilityTrend(days = 7) {
        try {
            const response = await fetch(`${this.baseUrl}/availability-trend?days=${days}`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching availability trend:', error);
            return null;
        }
    },
    
    // Obtener distribución de versiones
    async getVersionDistribution() {
        try {
            const response = await fetch(`${this.baseUrl}/version-distribution`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching version distribution:', error);
            return null;
        }
    },
    
    // Obtener estadísticas por datacenter
    async getDatacenterStats() {
        try {
            const response = await fetch(`${this.baseUrl}/datacenter-stats`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching datacenter stats:', error);
            return null;
        }
    },
    
    // Obtener hosts desconectados (última ejecución)
    async getDisconnectedHosts() {
        try {
            const response = await fetch(`${this.baseUrl}/disconnected-hosts`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching disconnected hosts:', error);
            return null;
        }
    },
    
    // Obtener histórico de hosts desconectados
    async getDisconnectedHistory(period = '7') {
        try {
            const response = await fetch(`${this.baseUrl}/disconnected-history?period=${period}`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching disconnected history:', error);
            return null;
        }
    },
    
    // Obtener últimas ejecuciones
    async getRecentExecutions(limit = 10) {
        try {
            const response = await fetch(`${this.baseUrl}/recent-executions?limit=${limit}`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching recent executions:', error);
            return null;
        }
    },
    
    // Obtener lista de datacenters
    async getDatacenters() {
        try {
            const response = await fetch(`${this.baseUrl}/datacenters`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching datacenters:', error);
            return [];
        }
    }
};