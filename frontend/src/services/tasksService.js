import { apiClient } from './api';

const API_BASE_URL = '/api';
const ENDPOINT = '/tasks';
const TOKEN_KEY = 'fp_token';

function getAuthHeader() {
  const token = sessionStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export const tasksService = {
  async getMonthlyStars() {
    const response = await apiClient.get(`${ENDPOINT}/monthly-stars`);
    return response.data;
  },

  async hasBscDashboard() {
    const response = await apiClient.get(`${ENDPOINT}/has-bsc-dashboard`);
    return response;
  },

  async getBscMonthlyStars() {
    const response = await apiClient.get(`${ENDPOINT}/bsc-monthly-stars`);
    return response.data;
  },

  async getAll(page = 1, pageSize = 20, search = '', status = '', dateFrom = '', dateTo = '', sortDueDate = '', extra = {}) {
    let url = `${ENDPOINT}?page=${page}&pageSize=${pageSize}`;
    if (search && search.trim()) {
      url += `&search=${encodeURIComponent(search.trim())}`;
    }
    if (status) {
      url += `&status=${encodeURIComponent(status)}`;
    }
    if (dateFrom) {
      url += `&dateFrom=${encodeURIComponent(dateFrom)}`;
    }
    if (dateTo) {
      url += `&dateTo=${encodeURIComponent(dateTo)}`;
    }
    if (sortDueDate) {
      url += `&sortDueDate=${encodeURIComponent(sortDueDate)}`;
    }
    if (extra && typeof extra === 'object') {
      const { titleFilter, assignedToFilter, leaderFilter, sortBy, sortDir } = extra;
      if (titleFilter && titleFilter.trim()) url += `&titleFilter=${encodeURIComponent(titleFilter.trim())}`;
      if (assignedToFilter && assignedToFilter.trim()) url += `&assignedToFilter=${encodeURIComponent(assignedToFilter.trim())}`;
      if (leaderFilter && leaderFilter.trim()) url += `&leaderFilter=${encodeURIComponent(leaderFilter.trim())}`;
      if (sortBy) url += `&sortBy=${encodeURIComponent(sortBy)}`;
      if (sortDir) url += `&sortDir=${encodeURIComponent(sortDir)}`;
    }
    const response = await apiClient.get(url);
    return response.data ?? { items: [], totalCount: 0, page: 1, pageSize: 20, totalPages: 0 };
  },

  async getById(id) {
    const response = await apiClient.get(`${ENDPOINT}/${id}`);
    return response.data;
  },

  // Lista de asignables (colaboradores y lideres) para el selector de tareas.
  // Protegido por el modulo "tareas" (no requiere el modulo "colaboradores").
  async getAssignees() {
    const response = await apiClient.get(`${ENDPOINT}/assignees`);
    return response.data ?? [];
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

  async overrideRating(taskId, { newRating, reason }) {
    const response = await apiClient.put(`${ENDPOINT}/${taskId}/rating-override`, {
      newRating,
      reason,
    });
    return response;
  },

  async getDistinctValues(field) {
    const response = await apiClient.get(`${ENDPOINT}/distinct-values?field=${encodeURIComponent(field)}`);
    return Array.isArray(response.data) ? response.data : [];
  },

  async assignTask(taskId, { assigneeId }) {
    const response = await apiClient.put(`${ENDPOINT}/${taskId}/assign`, {
      assigneeId,
    });
    return response;
  },

  async uploadEvidence(taskId, files, evidenceText, observations) {
    const formData = new FormData();
    if (files) {
      const fileList = Array.isArray(files) ? files : [files];
      fileList.forEach((f) => formData.append('EvidenceFiles', f));
    }
    if (evidenceText) formData.append('evidenceText', evidenceText);
    if (observations != null) formData.append('observations', observations);
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${taskId}/evidence`, {
      method: 'POST',
      headers: getAuthHeader(),
      body: formData,
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },

  async previewFile(taskId, fileId) {
    const response = await fetch(`${API_BASE_URL}${ENDPOINT}/${taskId}/files/${fileId}`, {
      headers: getAuthHeader(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const disposition = response.headers.get('Content-Disposition');
    let fileName = 'archivo';
    if (disposition) {
      const match = disposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
      if (match && match[1]) fileName = match[1].replace(/['"]/g, '');
    }
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    return { url, fileName, mimeType: blob.type };
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

  async exportByCollaborator(collaboratorName, status, from, to, { historicStatus, lateTasks } = {}) {
    const params = new URLSearchParams({ collaboratorName });
    if (historicStatus) params.append('historicStatus', historicStatus);
    else if (status) params.append('status', status);
    if (from) params.append('from', from);
    if (to) params.append('to', to);
    if (lateTasks) params.append('lateTasks', 'true');
    const response = await apiClient.get(`${ENDPOINT}/export?${params.toString()}`);
    return response.data ?? [];
  },

  async bulkDelete(ids) {
    const response = await apiClient.post(`${ENDPOINT}/bulk-delete`, { ids });
    return response;
  },

  async bulkCreate(tasks) {
    const response = await apiClient.post(`${ENDPOINT}/bulk`, { tasks });
    return response.data;
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
