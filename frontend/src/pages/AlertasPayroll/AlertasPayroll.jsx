import { useContext, useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Calendar,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  Download,
  Eye,
  Search,
  X,
  ZoomIn,
  ZoomOut,
} from 'lucide-react';
import Swal from 'sweetalert2';
import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';
import * as XLSX from '@e965/xlsx';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  ArcElement,
  Tooltip as ChartTooltip,
  Legend as ChartLegend,
  Title as ChartTitle,
} from 'chart.js';
import { Bar, Doughnut } from 'react-chartjs-2';
import SessionContext from '../../context/SessionContext';
import { payrollService } from '../../services/payrollService';
import './AlertasPayroll.css';

ChartJS.register(CategoryScale, LinearScale, BarElement, ArcElement, ChartTooltip, ChartLegend, ChartTitle);

const ESTADO_LABELS = {
  A: 'Activa',
  P: 'En Proceso',
  R: 'Resuelta',
  C: 'Cerrada',
  E: 'Error',
};

const PRIORIDAD_LABELS = {
  critica: 'Crítica',
  alta: 'Alta',
  media: 'Media',
  baja: 'Baja',
};

const COLORS = {
  A: '#22c55e',
  P: '#a855f7',
  R: '#3b82f6',
  C: '#eab308',
  E: '#ef4444',
};

const ORIGIN_COLORS = [
  '#3b82f6', '#22c55e', '#eab308', '#ef4444', '#a855f7',
  '#06b6d4', '#f97316', '#ec4899',
];

const DESC_KEYS = ['con_novedad', 'sin_novedad', 'reporteria', 'error_proceso'];

const DESC_LABELS = {
  con_novedad: 'Con novedad',
  sin_novedad: 'Sin novedad',
  reporteria: 'Reportería',
  error_proceso: 'Error Proceso',
};

const DESC_COLORS = {
  con_novedad: '#ef4444',
  sin_novedad: '#22c55e',
  reporteria: '#3b82f6',
  error_proceso: '#eab308',
};

function classifyDescripcion(desc) {
  if (!desc) return null;
  const k = String(desc).trim().toLowerCase();
  if (k === 'con novedad') return 'con_novedad';
  if (k === 'sin novedad') return 'sin_novedad';
  if (k === 'reporteria' || k === 'reportería') return 'reporteria';
  if (k === 'error proceso') return 'error_proceso';
  return null;
}

function isCriticalRow(row) {
  if (!row) return false;
  if (String(row.prioridad || '').trim().toLowerCase() !== 'alta') return false;
  if (!['A', 'P', 'E'].includes(row.estado)) return false;
  const desc = classifyDescripcion(row.descripcion);
  return desc === 'con_novedad' || desc === 'error_proceso';
}

const pad2 = (n) => String(n).padStart(2, '0');

function isoDay(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function isoMonth(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}`;
}

function isoWeek(d) {
  const target = new Date(d.valueOf());
  const dayNr = (d.getDay() + 6) % 7;
  target.setDate(target.getDate() - dayNr + 3);
  const firstThursday = target.valueOf();
  target.setMonth(0, 1);
  if (target.getDay() !== 4) {
    target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7));
  }
  const week = 1 + Math.ceil((firstThursday - target) / 604800000);
  return `${target.getFullYear()}-W${pad2(week)}`;
}

function bucketOf(iso, mode) {
  if (!iso) return null;
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  if (mode === 'mes') return isoMonth(d);
  if (mode === 'semana') return isoWeek(d);
  return isoDay(d);
}

function formatDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}/${d.getFullYear()} ` +
    `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function nowLocalIso() {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}` +
    `T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

function truncate(text, max) {
  if (!text) return '—';
  return text.length > max ? text.slice(0, max) + '...' : text;
}

function parseDestinatarios(raw) {
  if (!raw) return [];
  return raw
    .split(/[|;,]/)
    .map((d) => d.trim().toLowerCase())
    .filter(Boolean);
}

function buildPreviewDocument(html) {
  if (!html) return '';
  const looksComplete = /<html[\s>]/i.test(html);
  if (looksComplete) return html;
  return `<!DOCTYPE html><html><head><meta charset="utf-8">` +
    `<style>body{font-family:Arial,Helvetica,sans-serif;margin:16px;color:#111;font-size:14px;line-height:1.5;}` +
    `table{border-collapse:collapse;}img{max-width:100%;height:auto;}</style>` +
    `</head><body>${html}</body></html>`;
}

function getFilterText(col, row) {
  if (typeof col.filterValue === 'function') return String(col.filterValue(row) ?? '');
  const v = row[col.key];
  return v == null ? '' : String(v);
}

function getSortValue(col, row) {
  if (typeof col.sortValue === 'function') return col.sortValue(row);
  return row[col.key];
}

function compareValues(a, b, type) {
  const aEmpty = a == null || a === '';
  const bEmpty = b == null || b === '';
  if (aEmpty && bEmpty) return 0;
  if (aEmpty) return 1;
  if (bEmpty) return -1;

  if (type === 'number') {
    return (Number(a) || 0) - (Number(b) || 0);
  }
  if (type === 'date') {
    const ta = new Date(a).getTime();
    const tb = new Date(b).getTime();
    return (isNaN(ta) ? 0 : ta) - (isNaN(tb) ? 0 : tb);
  }
  return String(a).localeCompare(String(b), 'es', {
    sensitivity: 'base',
    numeric: true,
  });
}

/* ========================================
   Status Badge
   ======================================== */
const StatusBadge = ({ status }) => {
  const classMap = {
    A: 'payroll-badge--activa',
    P: 'payroll-badge--en-proceso',
    R: 'payroll-badge--resuelta',
    C: 'payroll-badge--cerrada',
    E: 'payroll-badge--error',
  };
  return (
    <span className={`payroll-badge ${classMap[status] || ''}`}>
      {ESTADO_LABELS[status] || status}
    </span>
  );
};

/* ========================================
   Priority Badge
   ======================================== */
const normalizePriority = (priority) =>
  priority ? String(priority).trim().toLowerCase() : '';

const PriorityBadge = ({ priority }) => {
  if (!priority) {
    return <span className="payroll-badge payroll-badge--sin-asignar">Sin asignar</span>;
  }
  const key = normalizePriority(priority);
  const classMap = {
    critica: 'payroll-badge--critica',
    alta: 'payroll-badge--alta',
    media: 'payroll-badge--media',
    baja: 'payroll-badge--baja',
  };
  return (
    <span className={`payroll-badge ${classMap[key] || ''}`}>
      {PRIORIDAD_LABELS[key] || priority}
    </span>
  );
};

/* ========================================
   Description Badge
   ======================================== */
const DESCRIPCION_CLASS = {
  'con novedad': 'payroll-badge--desc-con-novedad',
  'sin novedad': 'payroll-badge--desc-sin-novedad',
  'reporteria': 'payroll-badge--desc-reporteria',
  'reportería': 'payroll-badge--desc-reporteria',
  'error proceso': 'payroll-badge--desc-error',
};

const DescriptionBadge = ({ descripcion }) => {
  if (!descripcion) return <span>—</span>;
  const key = descripcion.trim().toLowerCase();
  const cls = DESCRIPCION_CLASS[key];
  if (!cls) return <span>{truncate(descripcion, 80)}</span>;
  return <span className={`payroll-badge ${cls}`}>{descripcion.trim()}</span>;
};

/* ========================================
   Donut Chart (SVG)
   ======================================== */
const DonutChart = ({ segments, centerLabel = 'Total', showPercent = false }) => {
  const total = segments.reduce((sum, s) => sum + s.value, 0);
  const radius = 60;
  const circumference = 2 * Math.PI * radius;

  let offset = 0;
  const arcs = segments.map((seg) => {
    const pct = total > 0 ? seg.value / total : 0;
    const dash = pct * circumference;
    const gap = circumference - dash;
    const currentOffset = offset;
    offset += dash;
    return { ...seg, dash, gap, offset: currentOffset };
  });

  return (
    <div className="payroll-donut">
      <div className="payroll-donut__svg-wrap">
        <svg viewBox="0 0 160 160" width="160" height="160">
          {arcs.map((arc) => (
            <circle
              key={arc.label}
              cx="80"
              cy="80"
              r={radius}
              fill="none"
              stroke={arc.color}
              strokeWidth="30"
              strokeDasharray={`${arc.dash} ${arc.gap}`}
              strokeDashoffset={-arc.offset}
            />
          ))}
          {total === 0 && (
            <circle cx="80" cy="80" r={radius} fill="none" stroke="var(--color-border-main)" strokeWidth="30" />
          )}
        </svg>
        <div className="payroll-donut__center">
          <span className="payroll-donut__center-value">{total}</span>
          <span className="payroll-donut__center-text">{centerLabel}</span>
        </div>
      </div>
      <div className="payroll-donut__legend">
        {segments.map((seg) => {
          const pct = total > 0 ? Math.round((seg.value / total) * 1000) / 10 : 0;
          return (
            <div key={seg.label} className="payroll-donut__legend-item">
              <span className="payroll-donut__legend-dot" style={{ background: seg.color }} />
              <span>{seg.label}</span>
              <span className="payroll-donut__legend-value">
                {seg.value}
                {showPercent && total > 0 && (
                  <span className="payroll-donut__legend-pct"> · {pct}%</span>
                )}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

/* ========================================
   Horizontal Bar Chart
   ======================================== */
const HorizontalBar = ({ items, maxItems = 8 }) => {
  const sorted = [...items].sort((a, b) => b.value - a.value).slice(0, maxItems);
  const max = sorted[0]?.value || 1;

  return (
    <div className="payroll-hbar">
      {sorted.map((item) => (
        <div key={item.label} className="payroll-hbar__row">
          <span className="payroll-hbar__label" title={item.label}>{item.label}</span>
          <div className="payroll-hbar__bar-col">
            <div
              className="payroll-hbar__bar"
              style={{
                width: `${(item.value / max) * 100}%`,
                background: item.color,
              }}
            />
          </div>
          <span className="payroll-hbar__value">{item.value}</span>
        </div>
      ))}
    </div>
  );
};

/* ========================================
   Sort indicator
   ======================================== */
const SortIndicator = ({ dir }) => {
  if (dir === 'asc') return <ArrowUp size={14} aria-hidden="true" />;
  if (dir === 'desc') return <ArrowDown size={14} aria-hidden="true" />;
  return <ArrowUpDown size={14} aria-hidden="true" className="payroll-sort-icon--neutral" />;
};

/* ========================================
   Preview Modal (iframe + zoom)
   ======================================== */
const PREVIEW_BASE_W = 800;
const PREVIEW_BASE_H = 1100;
const ZOOM_MIN = 25;
const ZOOM_MAX = 300;
const ZOOM_STEP = 25;

const AlertaModal = ({ row, usuarioSesion, saving, onClose, onSave }) => {
  const [zoom, setZoom] = useState(100);
  const [editEstado, setEditEstado] = useState(
    ['P', 'R', 'E'].includes(row?.estado) ? row.estado : 'P',
  );
  const [editNotas, setEditNotas] = useState(row?.notasResolucion || '');
  const [adjuntoBusy, setAdjuntoBusy] = useState(false);
  const [previewMode, setPreviewMode] = useState('correo');
  const [adjuntoState, setAdjuntoState] = useState({
    status: 'idle', url: null, mime: null, ext: null, error: null,
  });
  const scrollRef = useRef(null);
  const closeBtnRef = useRef(null);

  const tieneAdjunto = !!row?.rutaAdjunto;
  const nombreAdjunto = row?.nombreAdjunto || row?.rutaAdjunto?.split('/').pop() || '';

  const loadAdjunto = async () => {
    if (!tieneAdjunto) return;
    setAdjuntoState({ status: 'loading', url: null, mime: null, ext: null, error: null });
    try {
      const result = await payrollService.previewAdjunto({
        rutaAdjunto: row.rutaAdjunto,
        nombreAdjunto: row.nombreAdjunto,
      });
      if (!result.previewable) {
        setAdjuntoState({ status: 'unsupported', url: null, mime: null, ext: result.ext, error: null });
        return;
      }
      setAdjuntoState({ status: 'ready', url: result.url, mime: result.mime, ext: result.ext, error: null });
    } catch (err) {
      setAdjuntoState({
        status: 'error', url: null, mime: null, ext: null,
        error: err.message || 'Error al obtener el adjunto.',
      });
    }
  };

  const handlePreviewAdjunto = async () => {
    if (!tieneAdjunto || adjuntoBusy || saving) return;
    setPreviewMode('adjunto');
    if (adjuntoState.status === 'idle') {
      setAdjuntoBusy(true);
      try { await loadAdjunto(); } finally { setAdjuntoBusy(false); }
    }
  };

  const handleDescargarAdjunto = async () => {
    if (!tieneAdjunto || adjuntoBusy) return;
    try {
      setAdjuntoBusy(true);
      await payrollService.descargarAdjunto({
        rutaAdjunto: row.rutaAdjunto,
        nombreAdjunto: row.nombreAdjunto,
      });
    } catch (err) {
      Swal.fire({
        title: 'No se pudo descargar',
        text: err.message || 'Ocurrió un error al descargar el adjunto.',
        icon: 'error',
      });
    } finally {
      setAdjuntoBusy(false);
    }
  };

  useEffect(() => {
    setZoom(100);
    setEditEstado(['P', 'R', 'E'].includes(row?.estado) ? row.estado : 'P');
    setEditNotas(row?.notasResolucion || '');
    setPreviewMode('correo');
    setAdjuntoState((prev) => {
      if (prev.url) URL.revokeObjectURL(prev.url);
      return { status: 'idle', url: null, mime: null, ext: null, error: null };
    });
  }, [row?.idNotificacion, row?.estado, row?.notasResolucion]);

  useEffect(() => () => {
    if (adjuntoState.url) URL.revokeObjectURL(adjuntoState.url);
  }, [adjuntoState.url]);

  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape' && !saving) onClose(); };
    window.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    closeBtnRef.current?.focus();
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose, saving]);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    const onWheel = (e) => {
      if (!e.ctrlKey) return;
      e.preventDefault();
      setZoom((z) => {
        const next = z + (e.deltaY > 0 ? -ZOOM_STEP : ZOOM_STEP);
        return Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, next));
      });
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, []);

  const scale = zoom / 100;
  const doc = buildPreviewDocument(row?.descripcionHtml);
  const baseTitle = row?.asunto || `Alerta #${row?.idNotificacion ?? ''}`;
  const fechaTitle = row?.fechaCreacion ? formatDate(row.fechaCreacion) : null;
  const title = fechaTitle ? `${baseTitle} — ${fechaTitle}` : baseTitle;

  const handleSubmit = () => {
    if (saving) return;
    onSave({ estado: editEstado, notas: editNotas });
  };

  return (
    <div
      className="preview-modal__overlay"
      role="presentation"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget && !saving) onClose();
      }}
    >
      <div className="preview-modal preview-modal--with-side" role="dialog" aria-modal="true" aria-label={title}>
        <div className="preview-modal__header">
          <span className="preview-modal__title" title={title}>{title}</span>

          {previewMode === 'correo' && (
            <div className="preview-modal__zoom" role="group" aria-label="Controles de zoom">
              <button
                type="button"
                className="preview-modal__zoom-btn"
                onClick={() => setZoom((z) => Math.max(ZOOM_MIN, z - ZOOM_STEP))}
                disabled={zoom <= ZOOM_MIN}
                aria-label="Alejar"
                title="Alejar (Ctrl + rueda)"
              >
                <ZoomOut size={16} />
              </button>
              <button
                type="button"
                className="preview-modal__zoom-pct"
                onClick={() => setZoom(100)}
                aria-label={`Zoom ${zoom}%. Clic para restablecer al 100%`}
                title="Restablecer al 100%"
              >
                {zoom}%
              </button>
              <button
                type="button"
                className="preview-modal__zoom-btn"
                onClick={() => setZoom((z) => Math.min(ZOOM_MAX, z + ZOOM_STEP))}
                disabled={zoom >= ZOOM_MAX}
                aria-label="Acercar"
                title="Acercar (Ctrl + rueda)"
              >
                <ZoomIn size={16} />
              </button>
            </div>
          )}

          <button
            ref={closeBtnRef}
            type="button"
            className="preview-modal__close"
            onClick={onClose}
            disabled={saving}
            aria-label="Cerrar"
            title="Cerrar (Esc)"
          >
            <X size={20} />
          </button>
        </div>

        <div className="preview-modal__body">
          <div className="preview-modal__main">
            <div className="preview-modal__tabs" role="tablist" aria-label="Vistas">
              <button
                type="button"
                role="tab"
                aria-selected={previewMode === 'correo'}
                className={`preview-modal__tab ${previewMode === 'correo' ? 'is-active' : ''}`}
                onClick={() => setPreviewMode('correo')}
              >
                Correo
              </button>
              {tieneAdjunto && (
                <button
                  type="button"
                  role="tab"
                  aria-selected={previewMode === 'adjunto'}
                  className={`preview-modal__tab ${previewMode === 'adjunto' ? 'is-active' : ''}`}
                  onClick={handlePreviewAdjunto}
                  title={nombreAdjunto}
                >
                  Adjunto: {nombreAdjunto}
                </button>
              )}
            </div>

            {previewMode === 'correo' ? (
              <div ref={scrollRef} className="preview-modal__scroll">
                {doc ? (
                  <div
                    className="preview-modal__stage"
                    style={{ width: PREVIEW_BASE_W * scale, height: PREVIEW_BASE_H * scale }}
                  >
                    <iframe
                      title="Previsualización del correo"
                      className="preview-modal__iframe"
                      sandbox=""
                      srcDoc={doc}
                      style={{
                        width: PREVIEW_BASE_W,
                        height: PREVIEW_BASE_H,
                        transform: `scale(${scale})`,
                        transformOrigin: 'top left',
                      }}
                    />
                  </div>
                ) : (
                  <div className="preview-modal__empty">Sin previsualización disponible</div>
                )}
              </div>
            ) : (
              <div className="preview-modal__attachment-view">
                {adjuntoState.status === 'loading' && (
                  <div className="preview-modal__empty">Cargando adjunto…</div>
                )}
                {adjuntoState.status === 'ready' && (
                  <iframe
                    key={adjuntoState.url}
                    title={`Adjunto: ${nombreAdjunto}`}
                    className="preview-modal__attachment-iframe"
                    src={adjuntoState.url}
                  />
                )}
                {adjuntoState.status === 'unsupported' && (
                  <div className="preview-modal__empty preview-modal__empty--column">
                    <div>
                      Los archivos <strong>.{adjuntoState.ext || 'tipo desconocido'}</strong> no se pueden previsualizar en el navegador.
                    </div>
                    <button
                      type="button"
                      className="btn btn--primary btn--sm"
                      onClick={handleDescargarAdjunto}
                      disabled={adjuntoBusy}
                    >
                      <Download size={14} aria-hidden="true" /> Descargar adjunto
                    </button>
                  </div>
                )}
                {adjuntoState.status === 'error' && (
                  <div className="preview-modal__empty preview-modal__empty--column">
                    <div>No se pudo cargar el adjunto.</div>
                    <small>{adjuntoState.error}</small>
                    <button
                      type="button"
                      className="btn btn--secondary btn--sm"
                      onClick={loadAdjunto}
                    >
                      Reintentar
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>

          <aside className="preview-modal__side" aria-label="Resolución de la alerta">
            <div className="preview-modal__side-section">
              <h3 className="preview-modal__side-title preview-modal__side-title--main">Resolución</h3>
              <div className="preview-modal__side-meta">
                <div><strong>Estado actual:</strong> {ESTADO_LABELS[row?.estado] || row?.estado || '—'}</div>
                <div><strong>Prioridad:</strong> {PRIORIDAD_LABELS[normalizePriority(row?.prioridad)] || row?.prioridad || '—'}</div>
                <div><strong>Categoría:</strong> {row?.categoria || '—'}</div>
              </div>
            </div>

            <div className="preview-modal__side-section">
              <h3 className="preview-modal__side-title">Adjunto</h3>
              {tieneAdjunto ? (
                <div className="preview-modal__attachment-row">
                  <span className="preview-modal__attachment-name" title={nombreAdjunto}>
                    {nombreAdjunto}
                  </span>
                  <div className="preview-modal__attachment-icons">
                    <button
                      type="button"
                      className="btn btn--icon btn--sm btn--ghost"
                      onClick={handlePreviewAdjunto}
                      disabled={adjuntoBusy || saving}
                      data-tooltip="Previsualizar adjunto"
                      aria-label="Previsualizar adjunto"
                    >
                      <Eye size={16} />
                    </button>
                    <button
                      type="button"
                      className="btn btn--icon btn--sm btn--ghost"
                      onClick={handleDescargarAdjunto}
                      disabled={adjuntoBusy || saving}
                      data-tooltip="Descargar adjunto"
                      aria-label="Descargar adjunto"
                    >
                      <Download size={16} />
                    </button>
                  </div>
                </div>
              ) : (
                <div className="preview-modal__attachment-empty">Sin adjunto</div>
              )}
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="alerta-modal-estado">Cambiar estado</label>
              <select
                id="alerta-modal-estado"
                className="form-control"
                value={editEstado}
                onChange={(e) => setEditEstado(e.target.value)}
                disabled={saving}
              >
                <option value="P">En Proceso</option>
                <option value="R">Resuelto</option>
                <option value="E">Error</option>
              </select>
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="alerta-modal-notas">Notas de resolución</label>
              <textarea
                id="alerta-modal-notas"
                className="form-control preview-modal__notas"
                rows={12}
                maxLength={500}
                value={editNotas}
                onChange={(e) => setEditNotas(e.target.value.slice(0, 500))}
                placeholder="Ingrese observaciones sobre la resolución..."
                disabled={saving}
              />
              <small
                className={`preview-modal__chars ${
                  editNotas.length >= 500
                    ? 'preview-modal__chars--full'
                    : editNotas.length >= 450
                      ? 'preview-modal__chars--near'
                      : ''
                }`}
                aria-live="polite"
              >
                {editNotas.length} / 500 caracteres
              </small>
            </div>

            <div className="form-group">
              <label className="form-label">Usuario resolución</label>
              <input
                type="text"
                className="form-control"
                value={usuarioSesion}
                readOnly
              />
              <small className="payroll-edit-hint">
                Se asigna automáticamente al guardar.
              </small>
            </div>

            <div className="preview-modal__side-actions">
              <button
                type="button"
                className="btn btn--secondary"
                onClick={onClose}
                disabled={saving}
              >
                Cancelar
              </button>
              <button
                type="button"
                className="btn btn--primary"
                onClick={handleSubmit}
                disabled={saving}
              >
                {saving ? 'Guardando...' : 'Guardar cambios'}
              </button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
};

/* ========================================
   Table columns definition
   ======================================== */
const baseColumns = [
  {
    key: 'fechaCreacion',
    header: 'Fecha',
    type: 'date',
    filterValue: (row) => formatDate(row.fechaCreacion),
    render: (row) => formatDate(row.fechaCreacion),
  },
  {
    key: 'estado',
    header: 'Estado',
    type: 'text',
    filterValue: (row) => ESTADO_LABELS[row.estado] || row.estado || '',
    sortValue: (row) => ESTADO_LABELS[row.estado] || row.estado || '',
    render: (row) => <StatusBadge status={row.estado} />,
  },
  {
    key: 'prioridad',
    header: 'Prioridad',
    type: 'text',
    filterValue: (row) => PRIORIDAD_LABELS[normalizePriority(row.prioridad)] || row.prioridad || '',
    sortValue: (row) => PRIORIDAD_LABELS[normalizePriority(row.prioridad)] || row.prioridad || '',
    render: (row) => <PriorityBadge priority={row.prioridad} />,
  },
  {
    key: 'categoria',
    header: 'Categoría',
    type: 'text',
    render: (row) => row.categoria ?? '—',
  },
  { key: 'asunto', header: 'Asunto', type: 'text' },
  {
    key: 'descripcion',
    header: 'Descripción',
    type: 'text',
    filterValue: (row) => row.descripcion || '',
    render: (row) => <DescriptionBadge descripcion={row.descripcion} />,
  },
  {
    key: 'destinatarios',
    header: 'Notificados',
    type: 'text',
    filterValue: (row) => parseDestinatarios(row.destinatarios).join(', '),
    render: (row) => parseDestinatarios(row.destinatarios).join(', '),
  },
  { key: 'origen', header: 'Origen', type: 'text' },
  {
    key: 'fechaModificacion',
    header: 'Fecha Resolución',
    type: 'date',
    filterValue: (row) => (row.fechaModificacion ? formatDate(row.fechaModificacion) : ''),
    render: (row) => formatDate(row.fechaModificacion),
  },
  {
    key: 'usuarioResolucion',
    header: 'Usuario Resolución',
    type: 'text',
    render: (row) => row.usuarioResolucion ?? '—',
  },
  {
    key: 'notasResolucion',
    header: 'Notas Resolución',
    type: 'text',
    filterValue: (row) => row.notasResolucion || '',
    render: (row) => truncate(row.notasResolucion, 60),
  },
];

/* ========================================
   XLSX Export
   ======================================== */
function downloadAlertasXlsx(alertas, fileName) {
  if (!alertas.length) {
    Swal.fire({
      title: 'Sin resultados',
      text: 'No hay alertas que coincidan con la selección.',
      icon: 'info',
      timer: 1800,
      showConfirmButton: false,
    });
    return;
  }
  const rows = alertas.map((a) => ({
    'ID': a.idNotificacion ?? '',
    'Fecha Creación': formatDate(a.fechaCreacion),
    'Estado': ESTADO_LABELS[a.estado] || a.estado || '',
    'Prioridad': PRIORIDAD_LABELS[normalizePriority(a.prioridad)] || a.prioridad || '',
    'Categoría': a.categoria || '',
    'Asunto': a.asunto || '',
    'Descripción': a.descripcion || '',
    'Notificados': parseDestinatarios(a.destinatarios).join(', '),
    'Origen': a.origen || '',
    'Fecha Resolución': a.fechaModificacion ? formatDate(a.fechaModificacion) : '',
    'Usuario Resolución': a.usuarioResolucion || '',
    'Notas Resolución': a.notasResolucion || '',
  }));
  const ws = XLSX.utils.json_to_sheet(rows);
  const colWidths = Object.keys(rows[0]).map((key) => {
    const maxLen = Math.max(key.length, ...rows.map((r) => String(r[key] || '').length));
    return { wch: Math.min(maxLen + 2, 60) };
  });
  ws['!cols'] = colWidths;
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Alertas');
  XLSX.writeFile(wb, fileName);
}

/* ========================================
   Description Pie (doughnut con total al centro y % al costado)
   ======================================== */
const descPieCenterPlugin = {
  id: 'descPieCenter',
  afterDraw(chart) {
    const cfg = chart.options.plugins?.descPieCenter;
    if (!cfg) return;
    const { ctx, chartArea } = chart;
    if (!chartArea) return;
    const cx = (chartArea.left + chartArea.right) / 2;
    const cy = (chartArea.top + chartArea.bottom) / 2;
    const count = Number(cfg.count ?? 0);
    const labelText = count === 1 ? 'alerta' : 'alertas';
    ctx.save();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = '700 26px Inter, system-ui, -apple-system, sans-serif';
    ctx.fillStyle = '#111827';
    ctx.fillText(String(count), cx, cy - 8);
    ctx.font = '500 11px Inter, system-ui, -apple-system, sans-serif';
    ctx.fillStyle = '#6B7280';
    ctx.fillText(labelText, cx, cy + 14);
    ctx.restore();
  },
};

const DescriptionPie = ({ label, count, pct, color }) => {
  const safePct = Math.max(0, Math.min(100, Number(pct) || 0));
  const data = {
    datasets: [{
      data: [safePct, 100 - safePct],
      backgroundColor: [color, '#E5E7EB'],
      borderWidth: 0,
      cutout: '72%',
    }],
  };
  const options = {
    responsive: true,
    maintainAspectRatio: true,
    animation: { duration: 0 },
    plugins: {
      legend: { display: false },
      tooltip: { enabled: false },
      descPieCenter: { count },
    },
  };
  return (
    <div className="payroll-dash-pie" style={{ borderTopColor: color }}>
      <div className="payroll-dash-pie__label">{label}</div>
      <div className="payroll-dash-pie__row">
        <div className="payroll-dash-pie__chart">
          <Doughnut data={data} options={options} plugins={[descPieCenterPlugin]} />
        </div>
        <div className="payroll-dash-pie__pct-side">
          <span className="payroll-dash-pie__pct-value" style={{ color }}>
            {safePct}%
          </span>
          <span className="payroll-dash-pie__pct-text">del total</span>
        </div>
      </div>
    </div>
  );
};

/* ========================================
   Alertas Dashboard (Time-series)
   ======================================== */
const AlertasDashboard = ({ data }) => {
  const [filterPrioridad, setFilterPrioridad] = useState('');
  const [filterCategoria, setFilterCategoria] = useState('');
  const [filterEstado, setFilterEstado] = useState('');
  const [filterDateFrom, setFilterDateFrom] = useState(null);
  const [filterDateTo, setFilterDateTo] = useState(null);
  const [groupMode, setGroupMode] = useState('dia');
  const datePickerDashRef = useRef(null);

  const prioridadOptions = useMemo(() => {
    const set = new Set();
    data.forEach((a) => {
      const p = normalizePriority(a.prioridad);
      if (p) set.add(p);
    });
    return Array.from(set).sort();
  }, [data]);

  const categoriaOptions = useMemo(() => {
    const set = new Set();
    data.forEach((a) => { if (a.categoria) set.add(a.categoria); });
    return Array.from(set).sort();
  }, [data]);

  const estadoOptions = useMemo(() => {
    const set = new Set();
    data.forEach((a) => { if (a.estado) set.add(a.estado); });
    return Array.from(set).sort();
  }, [data]);

  const filteredData = useMemo(() => {
    const fromTs = filterDateFrom ? new Date(filterDateFrom).setHours(0, 0, 0, 0) : null;
    const toTs = filterDateTo ? new Date(filterDateTo).setHours(23, 59, 59, 999) : null;
    return data.filter((a) => {
      if (filterPrioridad && normalizePriority(a.prioridad) !== filterPrioridad) return false;
      if (filterCategoria && a.categoria !== filterCategoria) return false;
      if (filterEstado && a.estado !== filterEstado) return false;
      if (fromTs !== null || toTs !== null) {
        if (!a.fechaCreacion) return false;
        const t = new Date(a.fechaCreacion).getTime();
        if (isNaN(t)) return false;
        if (fromTs !== null && t < fromTs) return false;
        if (toTs !== null && t > toTs) return false;
      }
      return true;
    });
  }, [data, filterPrioridad, filterCategoria, filterEstado, filterDateFrom, filterDateTo]);

  const kpis = useMemo(() => {
    const counts = { con_novedad: 0, sin_novedad: 0, reporteria: 0, error_proceso: 0 };
    let classified = 0;
    filteredData.forEach((a) => {
      const k = classifyDescripcion(a.descripcion);
      if (k) {
        counts[k] += 1;
        classified += 1;
      }
    });
    const pct = (n) => classified > 0 ? Math.round((n / classified) * 1000) / 10 : 0;
    return {
      total: classified,
      filtered: filteredData.length,
      unclassified: filteredData.length - classified,
      con_novedad: { count: counts.con_novedad, pct: pct(counts.con_novedad) },
      sin_novedad: { count: counts.sin_novedad, pct: pct(counts.sin_novedad) },
      reporteria: { count: counts.reporteria, pct: pct(counts.reporteria) },
      error_proceso: { count: counts.error_proceso, pct: pct(counts.error_proceso) },
    };
  }, [filteredData]);

  const chartData = useMemo(() => {
    const buckets = new Map();
    filteredData.forEach((a) => {
      const k = classifyDescripcion(a.descripcion);
      if (!k) return;
      const bk = bucketOf(a.fechaCreacion, groupMode);
      if (!bk) return;
      if (!buckets.has(bk)) {
        buckets.set(bk, { con_novedad: 0, sin_novedad: 0, reporteria: 0, error_proceso: 0 });
      }
      buckets.get(bk)[k] += 1;
    });
    const labels = Array.from(buckets.keys()).sort();
    const datasets = DESC_KEYS.map((k) => ({
      label: DESC_LABELS[k],
      data: labels.map((lbl) => buckets.get(lbl)[k]),
      backgroundColor: DESC_COLORS[k],
      borderRadius: 4,
      maxBarThickness: 40,
      stack: 'alertas',
      _descKey: k,
    }));
    return { labels, datasets };
  }, [filteredData, groupMode]);

  const handleBarClick = (event, elements) => {
    if (!elements || elements.length === 0) return;
    const el = elements[0];
    const ds = chartData.datasets[el.datasetIndex];
    const descKey = ds?._descKey;
    const bucketKey = chartData.labels[el.index];
    if (!descKey || !bucketKey) return;

    const matched = filteredData.filter((a) => (
      classifyDescripcion(a.descripcion) === descKey &&
      bucketOf(a.fechaCreacion, groupMode) === bucketKey
    ));

    const safeBucket = bucketKey.replace(/[^\w-]/g, '_');
    const safeDesc = DESC_LABELS[descKey].replace(/\s+/g, '');
    downloadAlertasXlsx(matched, `Alertas_${safeDesc}_${safeBucket}.xlsx`);
  };

  const groupTitle = groupMode === 'mes' ? 'Mes' : groupMode === 'semana' ? 'Semana' : 'Día';

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    onClick: handleBarClick,
    onHover: (e, els) => {
      if (e?.native?.target) e.native.target.style.cursor = els.length ? 'pointer' : 'default';
    },
    interaction: { mode: 'nearest', intersect: true },
    plugins: {
      legend: { position: 'bottom' },
      tooltip: {
        callbacks: {
          afterBody: () => 'Click en la barra para descargar XLSX',
        },
      },
    },
    scales: {
      x: { stacked: true, title: { display: true, text: groupTitle } },
      y: {
        stacked: true,
        beginAtZero: true,
        ticks: { precision: 0 },
        title: { display: true, text: 'Alertas' },
      },
    },
  };

  const clearDashFilters = () => {
    setFilterPrioridad('');
    setFilterCategoria('');
    setFilterEstado('');
    setFilterDateFrom(null);
    setFilterDateTo(null);
  };

  const hasDashFilters = !!filterPrioridad || !!filterCategoria || !!filterEstado
    || !!filterDateFrom || !!filterDateTo;

  return (
    <div className="payroll-dashboard-tab">
      <div className="card mb-4">
        <div className="card__body">
          <div className="payroll-dash-filters">
            <div className="payroll-dash-filter">
              <label className="form-label" htmlFor="dash-prioridad">Prioridad</label>
              <select
                id="dash-prioridad"
                className="form-control"
                value={filterPrioridad}
                onChange={(e) => setFilterPrioridad(e.target.value)}
              >
                <option value="">Todas</option>
                {prioridadOptions.map((p) => (
                  <option key={p} value={p}>{PRIORIDAD_LABELS[p] || p}</option>
                ))}
              </select>
            </div>
            <div className="payroll-dash-filter">
              <label className="form-label" htmlFor="dash-categoria">Categoría</label>
              <select
                id="dash-categoria"
                className="form-control"
                value={filterCategoria}
                onChange={(e) => setFilterCategoria(e.target.value)}
              >
                <option value="">Todas</option>
                {categoriaOptions.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>
            <div className="payroll-dash-filter">
              <label className="form-label" htmlFor="dash-estado">Estado</label>
              <select
                id="dash-estado"
                className="form-control"
                value={filterEstado}
                onChange={(e) => setFilterEstado(e.target.value)}
              >
                <option value="">Todos</option>
                {estadoOptions.map((s) => (
                  <option key={s} value={s}>{ESTADO_LABELS[s] || s}</option>
                ))}
              </select>
            </div>
            <div className="payroll-dash-filter">
              <label className="form-label">Agrupar por</label>
              <div className="payroll-dash-segmented" role="group" aria-label="Agrupación temporal">
                {[
                  { k: 'dia', l: 'Día' },
                  { k: 'semana', l: 'Semana' },
                  { k: 'mes', l: 'Mes' },
                ].map(({ k, l }) => (
                  <button
                    key={k}
                    type="button"
                    className={`payroll-dash-segmented__btn ${groupMode === k ? 'is-active' : ''}`}
                    onClick={() => setGroupMode(k)}
                    aria-pressed={groupMode === k}
                  >
                    {l}
                  </button>
                ))}
              </div>
            </div>
            <div className="payroll-dash-filter">
              <label className="form-label">Fecha</label>
              <div className="payroll-toolbar__date payroll-dash-filter__date">
                <button
                  type="button"
                  className="btn btn--secondary payroll-toolbar__date-btn payroll-dash-filter__date-btn"
                  onClick={() => datePickerDashRef.current?.setOpen(true)}
                  aria-label="Filtrar por fecha de creación"
                >
                  <Calendar size={16} aria-hidden="true" />
                  <span>
                    {filterDateFrom && filterDateTo
                      ? `${filterDateFrom.toLocaleDateString('es-ES')} – ${filterDateTo.toLocaleDateString('es-ES')}`
                      : filterDateFrom
                        ? `${filterDateFrom.toLocaleDateString('es-ES')} –`
                        : 'Fecha'}
                  </span>
                  {(filterDateFrom || filterDateTo) && (
                    <span
                      role="button"
                      tabIndex={0}
                      className="payroll-toolbar__date-clear"
                      aria-label="Quitar filtro de fecha"
                      onClick={(e) => {
                        e.stopPropagation();
                        setFilterDateFrom(null);
                        setFilterDateTo(null);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          e.stopPropagation();
                          setFilterDateFrom(null);
                          setFilterDateTo(null);
                        }
                      }}
                    >
                      <X size={14} />
                    </span>
                  )}
                </button>
                <div className="payroll-toolbar__date-picker">
                  <DatePicker
                    ref={datePickerDashRef}
                    selectsRange
                    startDate={filterDateFrom}
                    endDate={filterDateTo}
                    onChange={(dates) => {
                      const [start, end] = dates || [null, null];
                      setFilterDateFrom(start);
                      setFilterDateTo(end);
                    }}
                    dateFormat="dd/MM/yyyy"
                    isClearable={false}
                    portalId="datepicker-portal"
                    popperPlacement="bottom-start"
                    customInput={<span style={{ display: 'none' }} />}
                  />
                </div>
              </div>
            </div>
            <div className="payroll-dash-filter payroll-dash-filter--actions">
              <button
                type="button"
                className="btn btn--secondary"
                onClick={clearDashFilters}
                disabled={!hasDashFilters}
              >
                Limpiar filtros
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="payroll-dash-summary">
        <span>
          <strong>{kpis.filtered}</strong> alertas filtradas
        </span>
        <span>
          <strong>{kpis.total}</strong> clasificadas
        </span>
        {kpis.unclassified > 0 && (
          <span className="payroll-dash-summary__warn">
            {kpis.unclassified} sin clasificar
          </span>
        )}
      </div>

      <div className="payroll-dash-pies">
        {DESC_KEYS.map((k) => (
          <DescriptionPie
            key={k}
            label={DESC_LABELS[k]}
            count={kpis[k].count}
            pct={kpis[k].pct}
            color={DESC_COLORS[k]}
          />
        ))}
      </div>

      <div className="card">
        <div className="card__header payroll-dash-chart-header">
          <h2 className="card__title">Alertas vs Tiempo</h2>
          <span className="payroll-dash-hint">
            Click en una barra para descargar el detalle en XLSX
          </span>
        </div>
        <div className="card__body">
          {chartData.labels.length === 0 ? (
            <div className="text-center p-6 text-secondary">
              No hay alertas que coincidan con los filtros.
            </div>
          ) : (
            <div className="payroll-dash-chart">
              <Bar data={chartData} options={options} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

/* ========================================
   Main Dashboard Component
   ======================================== */
const AlertasPayroll = () => {
  const { user } = useContext(SessionContext);
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [editingRow, setEditingRow] = useState(null);
  const [saving, setSaving] = useState(false);

  const [sort, setSort] = useState({ key: null, dir: null });
  const [globalFilter, setGlobalFilter] = useState('');
  const [columnFilters, setColumnFilters] = useState({});

  const [activeTab, setActiveTab] = useState('dashboard');
  const [catDescFilter, setCatDescFilter] = useState(() => new Set(DESC_KEYS));

  const [filterDateFrom, setFilterDateFrom] = useState(null);
  const [filterDateTo, setFilterDateTo] = useState(null);
  const datePickerRef = useRef(null);

  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);

  const loadData = () => {
    setLoading(true);
    payrollService.getNotificaciones()
      .then(setData)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadData();
  }, []);

  const usuarioSesion = user?.email || user?.name || user?.id || '';

  const openAlerta = (row) => setEditingRow(row);

  const closeAlerta = () => {
    if (saving) return;
    setEditingRow(null);
  };

  const handleSave = async ({ estado, notas }) => {
    if (!editingRow) return;
    const result = await Swal.fire({
      title: '¿Guardar cambios?',
      text: `Se actualizará la alerta #${editingRow.idNotificacion} con estado "${ESTADO_LABELS[estado]}".`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: 'Sí, guardar',
      cancelButtonText: 'Cancelar',
      confirmButtonColor: '#2563eb',
    });
    if (!result.isConfirmed) return;

    try {
      setSaving(true);
      await payrollService.updateResolucion(editingRow.idNotificacion, {
        estado,
        notasResolucion: notas,
        usuarioResolucion: usuarioSesion,
        fechaModificacion: nowLocalIso(),
      });
      await Swal.fire({
        title: 'Guardado',
        text: 'Los cambios se guardaron correctamente.',
        icon: 'success',
        timer: 1800,
        showConfirmButton: false,
      });
      setEditingRow(null);
      loadData();
    } catch (err) {
      Swal.fire({
        title: 'Error',
        text: err.message || 'No se pudieron guardar los cambios.',
        icon: 'error',
      });
    } finally {
      setSaving(false);
    }
  };

  const columns = useMemo(() => [
    {
      key: '__actions',
      header: 'Acciones',
      sortable: false,
      filterable: false,
      render: (row) => (
        <div className="table__actions">
          <button
            type="button"
            className="btn btn--icon btn--sm btn--ghost"
            onClick={(e) => { e.stopPropagation(); openAlerta(row); }}
            data-tooltip="Ver y resolver alerta"
            aria-label={`Ver y resolver alerta ${row.asunto || row.idNotificacion}`}
          >
            <Eye size={16} />
          </button>
        </div>
      ),
    },
    ...baseColumns,
  ], []);

  const toggleSort = (key) => {
    setSort((s) => {
      if (s.key !== key) return { key, dir: 'asc' };
      if (s.dir === 'asc') return { key, dir: 'desc' };
      return { key: null, dir: null };
    });
  };

  const clearFilters = () => {
    setGlobalFilter('');
    setColumnFilters({});
    setFilterDateFrom(null);
    setFilterDateTo(null);
  };

  const hasFilters = globalFilter.trim() !== ''
    || Object.values(columnFilters).some((v) => v && v.trim() !== '')
    || !!filterDateFrom || !!filterDateTo;

  const dateFilteredData = useMemo(() => {
    if (!filterDateFrom && !filterDateTo) return data;
    const fromTs = filterDateFrom ? new Date(filterDateFrom).setHours(0, 0, 0, 0) : null;
    const toTs = filterDateTo ? new Date(filterDateTo).setHours(23, 59, 59, 999) : null;
    return data.filter((row) => {
      if (!row.fechaCreacion) return false;
      const t = new Date(row.fechaCreacion).getTime();
      if (isNaN(t)) return false;
      if (fromTs !== null && t < fromTs) return false;
      if (toTs !== null && t > toTs) return false;
      return true;
    });
  }, [data, filterDateFrom, filterDateTo]);

  const filteredSorted = useMemo(() => {
    let rows = dateFilteredData;

    const g = globalFilter.trim().toLowerCase();
    if (g) {
      rows = rows.filter((row) =>
        columns.some(
          (col) => col.filterable !== false && getFilterText(col, row).toLowerCase().includes(g),
        ),
      );
    }

    const activeColFilters = Object.entries(columnFilters)
      .filter(([, v]) => v && v.trim() !== '');
    if (activeColFilters.length) {
      rows = rows.filter((row) =>
        activeColFilters.every(([key, val]) => {
          const col = columns.find((c) => c.key === key);
          if (!col) return true;
          return getFilterText(col, row).toLowerCase().includes(val.trim().toLowerCase());
        }),
      );
    }

    if (sort.key && sort.dir) {
      const col = columns.find((c) => c.key === sort.key);
      if (col) {
        rows = [...rows].sort((a, b) => {
          const cmp = compareValues(getSortValue(col, a), getSortValue(col, b), col.type);
          return sort.dir === 'asc' ? cmp : -cmp;
        });
      }
    }

    return rows;
  }, [dateFilteredData, globalFilter, columnFilters, sort, columns]);

  const totalPages = Math.max(1, Math.ceil(filteredSorted.length / pageSize));
  const safePage = Math.min(currentPage, totalPages);

  const paginatedRows = useMemo(() => {
    const start = (safePage - 1) * pageSize;
    return filteredSorted.slice(start, start + pageSize);
  }, [filteredSorted, safePage, pageSize]);

  useEffect(() => {
    setCurrentPage(1);
  }, [globalFilter, columnFilters, filterDateFrom, filterDateTo, pageSize]);

  const handleDownloadTabla = () => {
    const stamp = new Date().toISOString().slice(0, 10);
    downloadAlertasXlsx(filteredSorted, `Alertas_${stamp}.xlsx`);
  };

  const stats = useMemo(() => ({
    total: dateFilteredData.length,
    activas: dateFilteredData.filter((n) => n.estado === 'A').length,
    enProceso: dateFilteredData.filter((n) => n.estado === 'P').length,
    resueltas: dateFilteredData.filter((n) => n.estado === 'R').length,
    cerradas: dateFilteredData.filter((n) => n.estado === 'C').length,
    error: dateFilteredData.filter((n) => n.estado === 'E').length,
  }), [dateFilteredData]);

  const categoriaItems = useMemo(() => {
    const map = new Map();
    dateFilteredData.forEach((n) => {
      const descKey = classifyDescripcion(n.descripcion);
      if (!descKey || !catDescFilter.has(descKey)) return;
      const cat = n.categoria || 'Sin categoría';
      map.set(cat, (map.get(cat) || 0) + 1);
    });
    return Array.from(map, ([label, value], i) => ({
      label,
      value,
      color: ORIGIN_COLORS[i % ORIGIN_COLORS.length],
    })).sort((a, b) => b.value - a.value);
  }, [dateFilteredData, catDescFilter]);

  const toggleCatDesc = (key) => {
    setCatDescFilter((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key); else next.add(key);
      return next;
    });
  };

  const donutSegments = [
    { label: 'Activas', value: stats.activas, color: COLORS.A },
    { label: 'En Proceso', value: stats.enProceso, color: COLORS.P },
    { label: 'Resueltas', value: stats.resueltas, color: COLORS.R },
    { label: 'Cerradas', value: stats.cerradas, color: COLORS.C },
    { label: 'Error', value: stats.error, color: COLORS.E },
  ];

  const pendientesSegments = useMemo(() => {
    const pendKeys = ['con_novedad', 'reporteria', 'error_proceso'];
    const counts = { con_novedad: 0, reporteria: 0, error_proceso: 0 };
    dateFilteredData.forEach((n) => {
      if (!['A', 'P', 'E'].includes(n.estado)) return;
      const k = classifyDescripcion(n.descripcion);
      if (!k || !pendKeys.includes(k)) return;
      counts[k] += 1;
    });
    return pendKeys.map((k) => ({
      label: DESC_LABELS[k],
      value: counts[k],
      color: DESC_COLORS[k],
    }));
  }, [dateFilteredData]);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-header__title">Alertas Payroll</h1>
          <p className="page-header__subtitle">Dashboard de notificaciones y alertas del sistema de nómina</p>
        </div>
      </div>

      {error && (
        <div className="alert alert--error mb-4">
          <div className="alert__content">
            <div className="alert__title">Error al cargar datos</div>
            <div className="alert__message">{error}</div>
          </div>
        </div>
      )}

      {loading ? (
        <div className="text-center p-6">Cargando notificaciones...</div>
      ) : (
        <>
          <div className="payroll-tabs" role="tablist" aria-label="Vistas de Alertas Payroll">
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'dashboard'}
              className={`payroll-tab ${activeTab === 'dashboard' ? 'is-active' : ''}`}
              onClick={() => setActiveTab('dashboard')}
            >
              Dashboard
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'listado'}
              className={`payroll-tab ${activeTab === 'listado' ? 'is-active' : ''}`}
              onClick={() => setActiveTab('listado')}
            >
              Listado
            </button>
          </div>

          {activeTab === 'dashboard' && (
            <AlertasDashboard data={data} />
          )}

          {activeTab === 'listado' && (
        <>
          {/* KPI Cards */}
          <div className="payroll-kpi-row">
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Total Alertas</span>
              <span className="payroll-kpi-card__value">{stats.total}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Activas</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.A }}>{stats.activas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">En Proceso</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.P }}>{stats.enProceso}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Resueltas</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.R }}>{stats.resueltas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Cerradas</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.C }}>{stats.cerradas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Error</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.E }}>{stats.error}</span>
            </div>
          </div>

          {/* Charts */}
          <div className="payroll-charts-row">
            <div className="card">
              <div className="card__header">
                <h2 className="card__title">Pendientes por Resolver</h2>
              </div>
              <div className="card__body">
                <DonutChart
                  segments={pendientesSegments}
                  centerLabel="Pendientes"
                  showPercent
                />
              </div>
            </div>
            <div className="card">
              <div className="card__header">
                <h2 className="card__title">Distribución por Estado</h2>
              </div>
              <div className="card__body">
                <DonutChart segments={donutSegments} />
              </div>
            </div>
            <div className="card">
              <div className="card__header">
                <h2 className="card__title">Alertas por Categoría</h2>
              </div>
              <div className="card__body">
                <div className="payroll-cat-filters" role="group" aria-label="Filtrar por descripción">
                  {DESC_KEYS.map((k) => {
                    const active = catDescFilter.has(k);
                    return (
                      <button
                        key={k}
                        type="button"
                        className={`payroll-cat-chip ${active ? 'is-active' : ''}`}
                        onClick={() => toggleCatDesc(k)}
                        aria-pressed={active}
                        style={active ? {
                          backgroundColor: DESC_COLORS[k],
                          borderColor: DESC_COLORS[k],
                          color: '#ffffff',
                        } : { borderColor: DESC_COLORS[k], color: DESC_COLORS[k] }}
                      >
                        {DESC_LABELS[k]}
                      </button>
                    );
                  })}
                  {(() => {
                    const allActive = catDescFilter.size === DESC_KEYS.length;
                    return (
                      <button
                        type="button"
                        className="payroll-cat-chip payroll-cat-chip--reset"
                        onClick={() => setCatDescFilter(allActive ? new Set() : new Set(DESC_KEYS))}
                        aria-label={allActive ? 'Limpiar todos los filtros' : 'Seleccionar todos los filtros'}
                      >
                        {allActive ? 'Limpiar' : 'Todas'}
                      </button>
                    );
                  })()}
                </div>
                {categoriaItems.length === 0 ? (
                  <div className="text-center p-6 text-secondary">
                    Sin coincidencias para los filtros seleccionados.
                  </div>
                ) : (
                  <HorizontalBar items={categoriaItems} />
                )}
              </div>
            </div>
          </div>

          {/* Alertas Table */}
          <div className="card">
            <div className="card__header">
              <h2 className="card__title">Alertas</h2>
            </div>
            <div className="card__body">
              <div className="payroll-toolbar">
                <div className="payroll-toolbar__search">
                  <Search size={16} aria-hidden="true" className="payroll-toolbar__search-icon" />
                  <input
                    type="text"
                    className="payroll-toolbar__search-input"
                    placeholder="Buscar en todas las columnas..."
                    value={globalFilter}
                    onChange={(e) => setGlobalFilter(e.target.value)}
                    aria-label="Búsqueda global"
                  />
                </div>

                <div className="payroll-toolbar__date">
                  <button
                    type="button"
                    className="btn btn--secondary btn--sm payroll-toolbar__date-btn"
                    onClick={() => datePickerRef.current?.setOpen(true)}
                    data-tooltip="Filtrar por fecha de creación"
                    aria-label="Filtrar por fecha de creación"
                  >
                    <Calendar size={16} aria-hidden="true" />
                    <span>
                      {filterDateFrom && filterDateTo
                        ? `${filterDateFrom.toLocaleDateString('es-ES')} – ${filterDateTo.toLocaleDateString('es-ES')}`
                        : filterDateFrom
                          ? `${filterDateFrom.toLocaleDateString('es-ES')} –`
                          : 'Fecha'}
                    </span>
                    {(filterDateFrom || filterDateTo) && (
                      <span
                        role="button"
                        tabIndex={0}
                        className="payroll-toolbar__date-clear"
                        aria-label="Quitar filtro de fecha"
                        onClick={(e) => {
                          e.stopPropagation();
                          setFilterDateFrom(null);
                          setFilterDateTo(null);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            e.stopPropagation();
                            setFilterDateFrom(null);
                            setFilterDateTo(null);
                          }
                        }}
                      >
                        <X size={14} />
                      </span>
                    )}
                  </button>
                  <div className="payroll-toolbar__date-picker">
                    <DatePicker
                      ref={datePickerRef}
                      selectsRange
                      startDate={filterDateFrom}
                      endDate={filterDateTo}
                      onChange={(dates) => {
                        const [start, end] = dates || [null, null];
                        setFilterDateFrom(start);
                        setFilterDateTo(end);
                      }}
                      dateFormat="dd/MM/yyyy"
                      isClearable={false}
                      portalId="datepicker-portal"
                      popperPlacement="bottom-start"
                      customInput={<span style={{ display: 'none' }} />}
                    />
                  </div>
                </div>

                <button
                  type="button"
                  className="btn btn--primary btn--sm"
                  onClick={handleDownloadTabla}
                  disabled={filteredSorted.length === 0}
                  data-tooltip={hasFilters ? 'Descargar resultados filtrados' : 'Descargar todas las alertas'}
                >
                  <Download size={16} aria-hidden="true" /> Descargar
                </button>

                <button
                  type="button"
                  className="btn btn--secondary btn--sm payroll-toolbar__clear"
                  onClick={clearFilters}
                  disabled={!hasFilters}
                >
                  Limpiar filtros
                </button>

                <span className="payroll-toolbar__count" aria-live="polite">
                  {filteredSorted.length} de {data.length}
                </span>
              </div>

              <div className="table-container payroll-sticky-table">
                <table className="table">
                  <thead>
                    <tr className="payroll-header-row">
                      {columns.map((col) => {
                        const sortable = col.sortable !== false;
                        const isSorted = sortable && sort.key === col.key;
                        const ariaSort = sortable
                          ? (isSorted ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none')
                          : undefined;
                        return (
                          <th
                            key={col.key}
                            aria-sort={ariaSort}
                            className={sortable ? 'payroll-th payroll-th--sortable' : 'payroll-th'}
                          >
                            {sortable ? (
                              <button
                                type="button"
                                className="payroll-th__sort-btn"
                                onClick={() => toggleSort(col.key)}
                                aria-label={`Ordenar por ${col.header}`}
                              >
                                <span>{col.header}</span>
                                <SortIndicator dir={isSorted ? sort.dir : null} />
                              </button>
                            ) : (
                              <span>{col.header}</span>
                            )}
                          </th>
                        );
                      })}
                    </tr>
                    <tr className="payroll-filters-row">
                      {columns.map((col) => {
                        const filterable = col.filterable !== false;
                        return (
                          <th key={col.key} className="payroll-th-filter">
                            {filterable ? (
                              <input
                                type="text"
                                className="payroll-filter-input"
                                placeholder="Filtrar..."
                                value={columnFilters[col.key] || ''}
                                onChange={(e) =>
                                  setColumnFilters((f) => ({ ...f, [col.key]: e.target.value }))
                                }
                                aria-label={`Filtrar columna ${col.header}`}
                              />
                            ) : null}
                          </th>
                        );
                      })}
                    </tr>
                  </thead>
                  <tbody>
                    {filteredSorted.length === 0 ? (
                      <tr>
                        <td colSpan={columns.length} className="text-center p-6 text-secondary">
                          {data.length === 0
                            ? 'No hay alertas'
                            : 'Sin coincidencias con los filtros actuales'}
                        </td>
                      </tr>
                    ) : (
                      paginatedRows.map((row) => (
                        <tr
                          key={row.idNotificacion}
                          className={isCriticalRow(row) ? 'payroll-row--critical' : ''}
                        >
                          {columns.map((col) => (
                            <td key={col.key}>
                              {col.render
                                ? col.render(row)
                                : String(row[col.key] ?? '')}
                            </td>
                          ))}
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>

              <div className="payroll-pagination">
                <div className="payroll-pagination__size">
                  <label htmlFor="payroll-page-size">Filas por página:</label>
                  <select
                    id="payroll-page-size"
                    className="form-control"
                    value={pageSize}
                    onChange={(e) => setPageSize(Number(e.target.value))}
                  >
                    {[10, 20, 50, 100, 200].map((n) => (
                      <option key={n} value={n}>{n}</option>
                    ))}
                  </select>
                </div>
                <div className="payroll-pagination__info">
                  {filteredSorted.length === 0
                    ? '0 resultados'
                    : `${(safePage - 1) * pageSize + 1}–${(safePage - 1) * pageSize + paginatedRows.length} de ${filteredSorted.length}`}
                </div>
                <div className="payroll-pagination__nav" role="group" aria-label="Paginación">
                  <button
                    type="button"
                    className="btn btn--icon btn--sm btn--ghost"
                    onClick={() => setCurrentPage(1)}
                    disabled={safePage <= 1}
                    aria-label="Primera página"
                  >
                    <ChevronsLeft size={16} />
                  </button>
                  <button
                    type="button"
                    className="btn btn--icon btn--sm btn--ghost"
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    disabled={safePage <= 1}
                    aria-label="Página anterior"
                  >
                    <ChevronLeft size={16} />
                  </button>
                  <span className="payroll-pagination__page">
                    Página {safePage} de {totalPages}
                  </span>
                  <button
                    type="button"
                    className="btn btn--icon btn--sm btn--ghost"
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    disabled={safePage >= totalPages}
                    aria-label="Página siguiente"
                  >
                    <ChevronRight size={16} />
                  </button>
                  <button
                    type="button"
                    className="btn btn--icon btn--sm btn--ghost"
                    onClick={() => setCurrentPage(totalPages)}
                    disabled={safePage >= totalPages}
                    aria-label="Última página"
                  >
                    <ChevronsRight size={16} />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </>
          )}
        </>
      )}

      {editingRow && (
        <AlertaModal
          row={editingRow}
          usuarioSesion={usuarioSesion}
          saving={saving}
          onClose={closeAlerta}
          onSave={handleSave}
        />
      )}
    </div>
  );
};

export default AlertasPayroll;
