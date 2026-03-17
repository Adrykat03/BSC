import { apiClient } from './api';

const ENDPOINT = '/roles';

export const rolesService = {
  async getAll(page = 1, pageSize = 10) {
    const response = await apiClient.get(`${ENDPOINT}?page=${page}&pageSize=${pageSize}`);
    return response.data ?? { items: [], totalCount: 0, page: 1, pageSize: 10, totalPages: 0 };
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
