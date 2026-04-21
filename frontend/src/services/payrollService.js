const DAB_API_BASE = '/dab';

export const payrollService = {
  async getNotificaciones() {
    const response = await fetch(
      `${DAB_API_BASE}/NotificacionesConsolidadas?$orderby=fechaCreacion desc&$first=100`
    );
    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    return (data.value || []).map((row) => ({
      ...row,
      prioridad: row.Prioridad ?? row.prioridad ?? null,
      categoria: row.Categoria ?? row.categoria ?? null,
    }));
  },

  async updateResolucion(idNotificacion, { estado, notasResolucion, usuarioResolucion, fechaModificacion }) {
    const response = await fetch(
      `${DAB_API_BASE}/NotificacionesConsolidadas/idNotificacion/${idNotificacion}`,
      {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ estado, notasResolucion, usuarioResolucion, fechaModificacion }),
      }
    );
    if (!response.ok) {
      const errText = await response.text().catch(() => '');
      throw new Error(`Error ${response.status}: ${errText || response.statusText}`);
    }
    return response.json().catch(() => null);
  },
};
