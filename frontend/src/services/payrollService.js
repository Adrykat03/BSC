const DAB_API_BASE = '/dab';
const BSC_API_BASE = '/api';
const TOKEN_KEY = 'fp_token';

function authHeader() {
  const token = sessionStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function triggerBrowserDownload(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = fileName || 'adjunto';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

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

  async descargarAdjunto({ rutaAdjunto, nombreAdjunto }) {
    if (!rutaAdjunto) {
      throw new Error('La alerta no tiene adjunto.');
    }
    const params = new URLSearchParams({ ruta: rutaAdjunto });
    if (nombreAdjunto) params.append('nombre', nombreAdjunto);

    const response = await fetch(`${BSC_API_BASE}/alertas-payroll/adjunto?${params.toString()}`, {
      headers: authHeader(),
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => '');
      throw new Error(`Error ${response.status}: ${errText || response.statusText}`);
    }

    const blob = await response.blob();
    const fileName =
      nombreAdjunto ||
      rutaAdjunto.split('/').pop() ||
      'adjunto';
    triggerBrowserDownload(blob, fileName);
  },
};
