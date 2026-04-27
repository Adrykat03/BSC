import { useContext, useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Eye,
  Pencil,
  Search,
  X,
  ZoomIn,
  ZoomOut,
} from 'lucide-react';
import Swal from 'sweetalert2';
import Modal from '../../components/common/Modal';
import SessionContext from '../../context/SessionContext';
import { payrollService } from '../../services/payrollService';
import './AlertasPayroll.css';

const ESTADO_LABELS = {
  A: 'Activa',
  P: 'En Proceso',
  R: 'Resuelta',
  C: 'Cerrada',
  E: 'Error envío',
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

const pad2 = (n) => String(n).padStart(2, '0');

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
    C: 'payroll-badge--caducada',
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
const PriorityBadge = ({ priority }) => {
  if (!priority) {
    return <span className="payroll-badge payroll-badge--sin-asignar">Sin asignar</span>;
  }
  const classMap = {
    critica: 'payroll-badge--critica',
    alta: 'payroll-badge--alta',
    media: 'payroll-badge--media',
    baja: 'payroll-badge--baja',
  };
  return (
    <span className={`payroll-badge ${classMap[priority] || ''}`}>
      {PRIORIDAD_LABELS[priority] || priority}
    </span>
  );
};

/* ========================================
   Donut Chart (SVG)
   ======================================== */
const DonutChart = ({ segments, centerLabel = 'Total' }) => {
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
        {segments.map((seg) => (
          <div key={seg.label} className="payroll-donut__legend-item">
            <span className="payroll-donut__legend-dot" style={{ background: seg.color }} />
            <span>{seg.label}</span>
            <span className="payroll-donut__legend-value">{seg.value}</span>
          </div>
        ))}
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

const PreviewModal = ({ row, onClose }) => {
  const [zoom, setZoom] = useState(100);
  const scrollRef = useRef(null);
  const closeBtnRef = useRef(null);

  useEffect(() => {
    setZoom(100);
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    closeBtnRef.current?.focus();
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);

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

  return (
    <div
      className="preview-modal__overlay"
      role="presentation"
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="preview-modal" role="dialog" aria-modal="true" aria-label={title}>
        <div className="preview-modal__header">
          <span className="preview-modal__title" title={title}>{title}</span>

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

          <button
            ref={closeBtnRef}
            type="button"
            className="preview-modal__close"
            onClick={onClose}
            aria-label="Cerrar previsualización"
            title="Cerrar (Esc)"
          >
            <X size={20} />
          </button>
        </div>

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
    filterValue: (row) => PRIORIDAD_LABELS[row.prioridad] || row.prioridad || '',
    sortValue: (row) => PRIORIDAD_LABELS[row.prioridad] || row.prioridad || '',
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
    render: (row) => truncate(row.descripcion, 80),
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
   Main Dashboard Component
   ======================================== */
const AlertasPayroll = () => {
  const { user } = useContext(SessionContext);
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [editing, setEditing] = useState(null);
  const [editEstado, setEditEstado] = useState('P');
  const [editNotas, setEditNotas] = useState('');
  const [saving, setSaving] = useState(false);

  const [previewing, setPreviewing] = useState(null);

  const [sort, setSort] = useState({ key: null, dir: null });
  const [globalFilter, setGlobalFilter] = useState('');
  const [columnFilters, setColumnFilters] = useState({});

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

  const openEdit = (row) => {
    setEditing(row);
    setEditEstado(['P', 'R', 'E'].includes(row.estado) ? row.estado : 'P');
    setEditNotas(row.notasResolucion || '');
  };

  const closeEdit = () => {
    if (saving) return;
    setEditing(null);
  };

  const openPreview = (row) => setPreviewing(row);
  const closePreview = () => setPreviewing(null);

  const handleSave = async () => {
    const result = await Swal.fire({
      title: '¿Guardar cambios?',
      text: `Se actualizará la alerta #${editing.idNotificacion} con estado "${ESTADO_LABELS[editEstado]}".`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: 'Sí, guardar',
      cancelButtonText: 'Cancelar',
      confirmButtonColor: '#2563eb',
    });
    if (!result.isConfirmed) return;

    try {
      setSaving(true);
      await payrollService.updateResolucion(editing.idNotificacion, {
        estado: editEstado,
        notasResolucion: editNotas,
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
      setEditing(null);
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
            onClick={(e) => { e.stopPropagation(); openPreview(row); }}
            data-tooltip="Ver previsualización"
            aria-label={`Ver previsualización de ${row.asunto || `alerta ${row.idNotificacion}`}`}
          >
            <Eye size={16} />
          </button>
          <button
            type="button"
            className="btn btn--icon btn--sm btn--ghost"
            onClick={(e) => { e.stopPropagation(); openEdit(row); }}
            data-tooltip="Editar resolución"
            aria-label="Editar resolución"
          >
            <Pencil size={16} />
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
  };

  const hasFilters = globalFilter.trim() !== ''
    || Object.values(columnFilters).some((v) => v && v.trim() !== '');

  const filteredSorted = useMemo(() => {
    let rows = data;

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
  }, [data, globalFilter, columnFilters, sort, columns]);

  const stats = useMemo(() => ({
    total: data.length,
    activas: data.filter((n) => n.estado === 'A').length,
    enProceso: data.filter((n) => n.estado === 'P').length,
    resueltas: data.filter((n) => n.estado === 'R').length,
    caducadas: data.filter((n) => n.estado === 'C').length,
    error: data.filter((n) => n.estado === 'E').length,
  }), [data]);

  const origenItems = useMemo(() => {
    const map = new Map();
    data.forEach((n) => map.set(n.origen, (map.get(n.origen) || 0) + 1));
    return Array.from(map, ([label, value], i) => ({
      label,
      value,
      color: ORIGIN_COLORS[i % ORIGIN_COLORS.length],
    }));
  }, [data]);

  const donutSegments = [
    { label: 'Activas', value: stats.activas, color: COLORS.A },
    { label: 'En Proceso', value: stats.enProceso, color: COLORS.P },
    { label: 'Resueltas', value: stats.resueltas, color: COLORS.R },
    { label: 'Caducadas', value: stats.caducadas, color: COLORS.C },
    { label: 'Error', value: stats.error, color: COLORS.E },
  ];

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
              <span className="payroll-kpi-card__label">Caducadas</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.C }}>{stats.caducadas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Error Envío</span>
              <span className="payroll-kpi-card__value" style={{ color: COLORS.E }}>{stats.error}</span>
            </div>
          </div>

          {/* Charts */}
          <div className="payroll-charts-row">
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
                <h2 className="card__title">Alertas por Origen</h2>
              </div>
              <div className="card__body">
                <HorizontalBar items={origenItems} />
              </div>
            </div>
          </div>

          {/* Recent Notifications Table */}
          <div className="card">
            <div className="card__header">
              <h2 className="card__title">Notificaciones Recientes</h2>
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
                <button
                  type="button"
                  className="btn btn--secondary payroll-toolbar__clear"
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
                            ? 'No hay notificaciones'
                            : 'Sin coincidencias con los filtros actuales'}
                        </td>
                      </tr>
                    ) : (
                      filteredSorted.map((row) => (
                        <tr key={row.idNotificacion}>
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
            </div>
          </div>
        </>
      )}

      {previewing && (
        <PreviewModal row={previewing} onClose={closePreview} />
      )}

      <Modal
        isOpen={!!editing}
        onClose={closeEdit}
        title={editing ? editing.asunto || `Alerta #${editing.idNotificacion}` : ''}
        footer={
          <>
            <button
              type="button"
              className="btn btn--secondary"
              onClick={closeEdit}
              disabled={saving}
            >
              Cancelar
            </button>
            <button
              type="button"
              className="btn btn--primary"
              onClick={handleSave}
              disabled={saving}
            >
              {saving ? 'Guardando...' : 'Guardar cambios'}
            </button>
          </>
        }
      >
        {editing && (
          <div className="payroll-edit-form">
            <div className="form-group">
              <label className="form-label" htmlFor="payroll-edit-estado">Estado</label>
              <select
                id="payroll-edit-estado"
                className="form-control"
                value={editEstado}
                onChange={(e) => setEditEstado(e.target.value)}
                disabled={saving}
              >
                <option value="P">En Proceso</option>
                <option value="R">Resuelto</option>
                <option value="E">Error envío</option>
              </select>
            </div>
            <div className="form-group">
              <label className="form-label" htmlFor="payroll-edit-notas">Notas Resolución</label>
              <textarea
                id="payroll-edit-notas"
                className="form-control"
                rows={4}
                value={editNotas}
                onChange={(e) => setEditNotas(e.target.value)}
                placeholder="Ingrese observaciones sobre la resolución..."
                disabled={saving}
              />
            </div>
            <div className="form-group">
              <label className="form-label">Usuario Resolución</label>
              <input
                type="text"
                className="form-control"
                value={usuarioSesion}
                readOnly
              />
              <small className="payroll-edit-hint">
                Se asigna automáticamente al usuario de la sesión al guardar.
              </small>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

export default AlertasPayroll;
