import { apiClient } from './api';

const API_BASE_URL = '/api';
const ENDPOINT = '/tasks';

export const tasksService = {
  async getAll(page = 1, pageSize = 20) {
    const response = await apiClient.get(`${ENDPOINT}?page=${page}&pageSize=${pageSize}`);
    return response.data ?? { items: [], totalCount: 0, page: 1, pageSize: 20, totalPages: 0 };
  },

  async getById(id) {
    const response = await apiClient.get(`${ENDPOINT}/${id}`);
    return response.data;
  },

  async create(formData) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}`, {
      method: 'POST',
      body: formData,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },

  async update(id, formData) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${id}`, {
      method: 'PUT',
      body: formData,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },

  async delete(id) {
    return apiClient.delete(`${ENDPOINT}/${id}`);
  },

  async downloadEvidence(id) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${id}/evidence`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const disposition = response.headers.get('Content-Disposition');
    let filename = 'evidencia';
    if (disposition) {
      const match = disposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
      if (match && match[1]) {
        filename = match[1].replace(/['"]/g, '');
      }
    }
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  },
};
