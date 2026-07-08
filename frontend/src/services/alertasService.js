import { apiClient } from './api';

const ENDPOINT = '/alertas';
const API_BASE = '/api';
const TOKEN_KEY = 'fp_token';

function authHeader() {
  const token = sessionStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function parseFileName(response, fallback = 'adjunto') {
  const disposition = response.headers.get('Content-Disposition');
  if (disposition) {
    const match = disposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
    if (match && match[1]) return match[1].replace(/['"]/g, '');
  }
  return fallback;
}

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

  // ── Adjuntos de resolución (archivo en disco + metadata en Mongo) ──────────

  /** Lista los adjuntos de resolución de una alerta. */
  async getAdjuntos(id) {
    const response = await apiClient.get(`${ENDPOINT}/${id}/adjuntos`);
    return Array.isArray(response?.data) ? response.data : [];
  },

  /** Sube uno o varios archivos como adjuntos de resolución (multipart). */
  async uploadAdjuntos(id, files) {
    const formData = new FormData();
    const list = Array.isArray(files) ? files : [files];
    list.filter(Boolean).forEach((f) => formData.append('files', f));
    const response = await fetch(`${API_BASE}${ENDPOINT}/${id}/adjuntos`, {
      method: 'POST',
      headers: authHeader(),
      body: formData,
    });
    if (!response.ok) {
      const txt = await response.text().catch(() => '');
      throw new Error(txt || `HTTP ${response.status}`);
    }
    const json = await response.json();
    return Array.isArray(json?.data) ? json.data : [];
  },

  /** Descarga (blob) un adjunto para previsualizar. */
  async previewAdjunto(id, adjuntoId) {
    const response = await fetch(`${API_BASE}${ENDPOINT}/${id}/adjuntos/${adjuntoId}`, {
      headers: authHeader(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const fileName = parseFileName(response);
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    return { url, fileName, mimeType: blob.type };
  },

  /** Descarga un adjunto al disco del usuario. */
  async downloadAdjunto(id, adjuntoId) {
    const response = await fetch(`${API_BASE}${ENDPOINT}/${id}/adjuntos/${adjuntoId}`, {
      headers: authHeader(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const fileName = parseFileName(response);
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  },

  /** Elimina un adjunto de resolución. */
  async removeAdjunto(id, adjuntoId) {
    const response = await fetch(`${API_BASE}${ENDPOINT}/${id}/adjuntos/${adjuntoId}`, {
      method: 'DELETE',
      headers: authHeader(),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return true;
  },
};

export default alertasService;
