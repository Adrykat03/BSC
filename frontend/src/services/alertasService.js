import { apiClient } from './api';

const ENDPOINT = '/alertas';

export const alertasService = {
  /**
   * Cambia el estado de una alerta a través del backend BSC (NO DAB).
   * El backend persiste el cambio en DAB y registra una entrada en el historial.
   *
   * NOTA: el backend extrae el usuario (email + rol) del JWT — NO se envían en el body.
   *
   * @param {number|string} id - idNotificacion de la alerta.
   * @param {{
   *   nuevoEstado: 'A' | 'P' | 'R' | 'C' | 'E',
   *   comentario?: string,
   * }} payload
   * @returns {Promise<{ success: boolean, historialPersistido: boolean }>}
   */
  async cambiarEstado(id, { nuevoEstado, comentario }) {
    const response = await apiClient.post(`${ENDPOINT}/${id}/cambiar-estado`, {
      nuevoEstado,
      comentario: comentario ?? '',
    });
    return response?.data ?? null;
  },

  /**
   * Obtiene el historial cronológico de cambios de estado de una alerta.
   *
   * @param {number|string} id - idNotificacion de la alerta.
   * @returns {Promise<{ items: Array<{
   *   id: string,
   *   idNotificacion: number,
   *   estadoAnterior: string,
   *   estadoNuevo: string,
   *   comentario: string,
   *   usuarioEmail: string,
   *   usuarioRol: string,
   *   fecha: string,
   * }> }>}
   */
  async getHistorial(id) {
    const response = await apiClient.get(`${ENDPOINT}/${id}/historial`);
    return response?.data ?? { items: [] };
  },
};

export default alertasService;
