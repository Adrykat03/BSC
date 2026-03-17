const API_BASE_URL = '/api';
const TOKEN_KEY = 'fp_token';

function getAuthHeaders(includeContentType = true) {
  const headers = {};
  if (includeContentType) {
    headers['Content-Type'] = 'application/json';
  }
  const token = sessionStorage.getItem(TOKEN_KEY);
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
}

async function handleResponse(response) {
  if (response.status === 401) {
    sessionStorage.removeItem(TOKEN_KEY);
    window.location.href = '/login';
    throw new Error('Sesión expirada');
  }

  if (response.status === 403) {
    const error = new Error('No tiene permisos para realizar esta acción.');
    error.status = 403;
    throw error;
  }

  const text = await response.text();
  const data = text ? JSON.parse(text) : {};

  if (!response.ok) {
    const error = new Error(data.message || `HTTP ${response.status}`);
    error.errors = data.errors || [];
    error.status = response.status;
    throw error;
  }
  return data;
}

export const apiClient = {
  async get(endpoint) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      headers: getAuthHeaders(false),
    });
    return handleResponse(response);
  },

  async post(endpoint, data) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: getAuthHeaders(),
      body: JSON.stringify(data),
    });
    return handleResponse(response);
  },

  async put(endpoint, data) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify(data),
    });
    return handleResponse(response);
  },

  async delete(endpoint) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'DELETE',
      headers: getAuthHeaders(false),
    });
    return handleResponse(response);
  },
};
