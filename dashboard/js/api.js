// API Module - Maneja todas las peticiones a la base de datos
const API = {
    baseUrl: 'http://localhost:8080/api',
    
    // Obtener resumen de última ejecución
    async getLatestSummary() {
        try {
            const response = await fetch(`${this.baseUrl}/latest`);
            if (!response.ok) {
                console.error('API error:', response.status, response.statusText);
                return null;
            }
            const data = await response.json();
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
    
    // Obtener hosts desconectados
    async getDisconnectedHosts() {
        try {
            const response = await fetch(`${this.baseUrl}/disconnected-hosts`);
            return await response.json();
        } catch (error) {
            console.error('Error fetching disconnected hosts:', error);
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
