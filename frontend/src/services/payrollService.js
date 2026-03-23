const PAYROLL_API_BASE = 'http://localhost:8080/api';

export const payrollService = {
  async getNotificaciones() {
    const response = await fetch(`${PAYROLL_API_BASE}/notificaciones`);
    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }
    return response.json();
  },
};
