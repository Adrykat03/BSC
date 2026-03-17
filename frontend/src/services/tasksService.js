import { apiClient } from './api';

const API_BASE_URL = '/api';
const ENDPOINT = '/tasks';
const TOKEN_KEY = 'fp_token';

function getAuthHeader() {
  const token = sessionStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export const tasksService = {
  async getAll(page = 1, pageSize = 20) {
    const url = `${ENDPOINT}?page=${page}&pageSize=${pageSize}`;
    const response = await apiClient.get(url);
    return response.data ?? { items: [], totalCount: 0, page: 1, pageSize: 20, totalPages: 0 };
  },

  async getById(id) {
    const response = await apiClient.get(`${ENDPOINT}/${id}`);
    return response.data;
  },

  async create(formData) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}`, {
      method: 'POST',
      headers: getAuthHeader(),
      body: formData,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },

  async update(id, formData) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${id}`, {
      method: 'PUT',
      headers: getAuthHeader(),
      body: formData,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },

  async delete(id) {
    return apiClient.delete(`${ENDPOINT}/${id}`);
  },

  async changeStatus(taskId, { newStatus, comment }) {
    const response = await apiClient.put(`${ENDPOINT}/${taskId}/status`, {
      newStatus,
      comment,
    });
    return response;
  },

  async assignTask(taskId, { assigneeId }) {
    const response = await apiClient.put(`${ENDPOINT}/${taskId}/assign`, {
      assigneeId,
    });
    return response;
  },

  async uploadEvidence(taskId, files, evidenceText) {
    const formData = new FormData();
    if (files) {
      const fileList = Array.isArray(files) ? files : [files];
      fileList.forEach((f) => formData.append('EvidenceFiles', f));
    }
    if (evidenceText) formData.append('evidenceText', evidenceText);
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${taskId}/evidence`, {
      method: 'POST',
      headers: getAuthHeader(),
      body: formData,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },

  async downloadFile(taskId, fileId) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${taskId}/files/${fileId}`, {
      headers: getAuthHeader(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const disposition = response.headers.get('Content-Disposition');
    let filename = 'archivo';
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

  async removeFile(taskId, fileId, fileType) {
    const params = new URLSearchParams({ fileType });
    const response = await fetch(
      `${API_BASE_URL}${ENDPOINT}/${taskId}/files/${fileId}?${params.toString()}`,
      {
        method: 'DELETE',
        headers: getAuthHeader(),
      }
    );
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response;
  },
};
