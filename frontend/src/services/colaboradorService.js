import { apiClient } from './api';

const ENDPOINT = '/colaboradores';

export const colaboradorService = {
  getAll: () => apiClient.get(ENDPOINT),
  getById: (id) => apiClient.get(`${ENDPOINT}/${id}`),
  create: (data) => apiClient.post(ENDPOINT, data),
  update: (id, data) => apiClient.put(`${ENDPOINT}/${id}`, data),
  delete: (id) => apiClient.delete(`${ENDPOINT}/${id}`),
};
