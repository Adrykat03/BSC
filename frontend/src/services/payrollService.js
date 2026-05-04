import * as XLSX from '@e965/xlsx';

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

const MIME_BY_EXT = {
  pdf: 'application/pdf',
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  gif: 'image/gif',
  webp: 'image/webp',
  svg: 'image/svg+xml',
  bmp: 'image/bmp',
  txt: 'text/plain',
  csv: 'text/csv',
  json: 'application/json',
  xml: 'application/xml',
  html: 'text/html',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  xls: 'application/vnd.ms-excel',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  doc: 'application/msword',
  zip: 'application/zip',
};

const PREVIEWABLE_EXTS = new Set([
  'pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'txt', 'json', 'xml', 'html',
]);

const SHEETJS_EXTS = new Set(['xlsx', 'xls', 'xlsm', 'ods', 'csv', 'tsv']);

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function buildSpreadsheetPreviewBlob({ blob, fileName }) {
  const buffer = await blob.arrayBuffer();
  const wb = XLSX.read(buffer, { type: 'array' });
  const sheets = wb.SheetNames.map((name) => ({
    name,
    html: XLSX.utils.sheet_to_html(wb.Sheets[name], { editable: false }),
  }));

  const tabs = sheets.length > 1
    ? `<nav class="tabs" role="tablist">${sheets
        .map((s, i) => `<button type="button" role="tab" data-i="${i}" class="${i === 0 ? 'active' : ''}">${escapeHtml(s.name)}</button>`)
        .join('')}</nav>`
    : '';
  const sections = sheets
    .map((s, i) => `<section class="sheet" data-i="${i}"${i === 0 ? '' : ' hidden'}>${s.html}</section>`)
    .join('');

  const html = `<!DOCTYPE html><html lang="es"><head><meta charset="utf-8"><title>${escapeHtml(fileName)}</title>
<style>
  *,*::before,*::after { box-sizing: border-box; }
  body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 16px; background: #f3f4f6; color: #111; }
  h1 { font-size: 14px; margin: 0 0 12px; color: #374151; word-break: break-all; }
  .tabs { display: flex; gap: 4px; margin-bottom: 12px; border-bottom: 1px solid #d1d5db; flex-wrap: wrap; }
  .tabs button { background: transparent; border: 0; padding: 8px 14px; cursor: pointer; border-bottom: 2px solid transparent; font-size: 13px; color: #6b7280; }
  .tabs button:hover { color: #111; }
  .tabs button.active { color: #2563eb; border-bottom-color: #2563eb; font-weight: 600; }
  .sheet { background: #fff; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); padding: 12px; overflow: auto; }
  .sheet[hidden] { display: none; }
  table { border-collapse: collapse; font-size: 12px; }
  td, th { border: 1px solid #d1d5db; padding: 4px 8px; vertical-align: top; white-space: nowrap; }
  thead td, thead th, tr:first-child td { background: #f9fafb; font-weight: 600; }
</style></head>
<body>
  <h1>${escapeHtml(fileName)}</h1>
  ${tabs}
  ${sections}
  <script>
    document.querySelectorAll('.tabs button').forEach((btn) => {
      btn.addEventListener('click', () => {
        const i = +btn.dataset.i;
        document.querySelectorAll('.tabs button').forEach((b) => b.classList.toggle('active', b === btn));
        document.querySelectorAll('.sheet').forEach((s) => s.toggleAttribute('hidden', +s.dataset.i !== i));
      });
    });
  </script>
</body></html>`;

  return new Blob([html], { type: 'text/html;charset=utf-8' });
}

function getExt(fileName) {
  const m = String(fileName || '').toLowerCase().match(/\.([a-z0-9]+)$/);
  return m ? m[1] : '';
}

async function fetchAdjuntoBlob({ rutaAdjunto, nombreAdjunto }) {
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

  const fileName = nombreAdjunto || rutaAdjunto.split('/').pop() || 'adjunto';
  const ext = getExt(fileName);
  const mime = MIME_BY_EXT[ext] || 'application/octet-stream';
  const rawBlob = await response.blob();
  const blob = new Blob([rawBlob], { type: mime });
  return { blob, fileName, ext, mime };
}

export const payrollService = {
  async getNotificaciones() {
    const all = [];
    let url = `${DAB_API_BASE}/NotificacionesConsolidadas?$orderby=fechaCreacion desc&$first=100`;
    let safety = 100;
    while (url && safety > 0) {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Error ${response.status}: ${response.statusText}`);
      }
      const data = await response.json();
      if (Array.isArray(data.value)) all.push(...data.value);
      const next = data.nextLink || data['@odata.nextLink'] || null;
      if (!next) {
        url = null;
      } else if (/^https?:\/\//i.test(next)) {
        const u = new URL(next);
        url = `${DAB_API_BASE}${u.pathname.replace(/^.*?(\/NotificacionesConsolidadas)/, '$1')}${u.search}`;
      } else {
        url = next.startsWith('/') ? next : `${DAB_API_BASE}/${next}`;
      }
      safety -= 1;
    }
    return all.map((row) => ({
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
    const { blob, fileName } = await fetchAdjuntoBlob({ rutaAdjunto, nombreAdjunto });
    triggerBrowserDownload(blob, fileName);
  },

  async previewAdjunto({ rutaAdjunto, nombreAdjunto }) {
    const { blob, fileName, ext, mime } = await fetchAdjuntoBlob({ rutaAdjunto, nombreAdjunto });
    if (SHEETJS_EXTS.has(ext)) {
      const htmlBlob = await buildSpreadsheetPreviewBlob({ blob, fileName });
      const url = URL.createObjectURL(htmlBlob);
      return { previewable: true, url, fileName, ext, mime: 'text/html' };
    }
    if (PREVIEWABLE_EXTS.has(ext)) {
      const url = URL.createObjectURL(blob);
      return { previewable: true, url, fileName, ext, mime };
    }
    return { previewable: false, fileName, ext, mime };
  },
};
