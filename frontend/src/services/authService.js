import { apiClient } from './api';

const authService = {
  async login(email, password) {
    // Login bypasses apiClient to avoid 401 interceptor redirecting to /login
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await response.json();
    if (!response.ok) {
      const error = new Error(data.message || 'Error al iniciar sesión');
      error.status = response.status;
      error.errors = data.errors || [];
      throw error;
    }
    return data.data;
  },

  async switchRole(role) {
    const response = await apiClient.post('/auth/switch-role', { role });
    return response.data;
  },
};

export default authService;
