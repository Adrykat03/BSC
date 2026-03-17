import { apiClient } from './api';

const ENDPOINT = '/colaboradores';

export const colaboradorService = {
  async getAll() {
    const response = await apiClient.get(ENDPOINT);
    return response.data ?? [];
  },

  async getById(id) {
    const response = await apiClient.get(`${ENDPOINT}/${id}`);
    return response.data;
  },

  async create(data) {
    const response = await apiClient.post(ENDPOINT, data);
    return response.data;
  },

  async update(id, data) {
    const response = await apiClient.put(`${ENDPOINT}/${id}`, data);
    return response.data;
  },

  async delete(id) {
    return apiClient.delete(`${ENDPOINT}/${id}`);
  },
};
