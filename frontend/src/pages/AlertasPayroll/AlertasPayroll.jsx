import { useContext, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import {
  AlertTriangle,
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Calendar,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  Clock,
  Layers,
  Download,
  Eye,
  FileText,
  Filter,
  Loader2,
  Paperclip,
  RefreshCw,
  Search,
  Trash2,
  Upload,
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
import { alertasService } from '../../services/alertasService';
import Modal from '../../components/common/Modal';
import './AlertasPayroll.css';

ChartJS.register(CategoryScale, LinearScale, BarElement, ArcElement, ChartTooltip, ChartLegend, ChartTitle);

// Roles que pueden ver la pestaña Dashboard. Comparación case-insensitive + trim.
const PRIVILEGED_ROLES = ['Administrador', 'Gerente', 'Soporte Alertas'];

function isPrivilegedUser(user) {
  if (!user) return false;
  const allowed = new Set(PRIVILEGED_ROLES.map((r) => r.trim().toLowerCase()));
  const candidates = [];
  if (user.role) candidates.push(user.role);
  if (Array.isArray(user.roles)) candidates.push(...user.roles);
  return candidates.some(
    (r) => typeof r === 'string' && allowed.has(r.trim().toLowerCase())
  );
}

const ESTADO_LABELS = {
  A: 'Activa',
  P: 'En Proceso',
  R: 'Resuelta',
  C: 'Cerrada',
  E: 'Error',
};

// Estados que se consideran "finalizados" (van a la sub-pestaña Finalizadas).
const ESTADOS_FINALIZADOS = ['R', 'C'];

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

// Alertas que deben mostrarse SIEMPRE primero en el listado:
// prioridad Alta + "Con novedad" + Activas (estado A).
function isTopPriorityRow(row) {
  if (!row) return false;
  if (String(row.prioridad || '').trim().toLowerCase() !== 'alta') return false;
  if (row.estado !== 'A') return false;
  return classifyDescripcion(row.descripcion) === 'con_novedad';
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

// Repara un bug común en los correos de Nómina: un <style ...> sin su </style>
// antes de </head> (o de <body>). El navegador se traga todo el resto del
// documento como CSS y la vista queda EN BLANCO. Insertamos el </style> faltante.
// Solo actúa sobre <style> realmente sin cerrar (los ya cerrados no se tocan).
function repairUnclosedStyle(html) {
  return html.replace(
    /(<style\b[^>]*>)((?:(?!<\/style>)[\s\S])*?)(<\/head>|<body[\s>])/gi,
    (_m, open, inner, next) => `${open}${inner}</style>${next}`,
  );
}

function buildPreviewDocument(html) {
  if (!html) return '';
  const repaired = repairUnclosedStyle(html);
  const looksComplete = /<html[\s>]/i.test(repaired);
  if (looksComplete) return repaired;
  return `<!DOCTYPE html><html><head><meta charset="utf-8">` +
    `<style>body{font-family:Arial,Helvetica,sans-serif;margin:16px;color:#111;font-size:14px;line-height:1.5;}` +
    `table{border-collapse:collapse;}img{max-width:100%;height:auto;}</style>` +
    `</head><body>${repaired}</body></html>`;
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
const DonutChart = ({ segments, centerLabel = 'Total', showPercent = false, showLegend = true }) => {
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
        <svg viewBox="0 0 160 160" style={{ width: '100%', height: '100%' }}>
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
      {showLegend && (
      <div className="payroll-donut__legend">
        {segments.map((seg) => {
          const pct = total > 0 ? Math.round((seg.value / total) * 1000) / 10 : 0;
          return (
            <div key={seg.label} className="payroll-donut__legend-item">
              <span className="payroll-donut__legend-dot" style={{ background: seg.color }} />
              <span className="payroll-donut__legend-label">{seg.label}</span>
              <span className="payroll-donut__legend-value">{seg.value}</span>
              {showPercent && total > 0
                ? <span className="payroll-donut__legend-pct">{pct}%</span>
                : <span />}
            </div>
          );
        })}
      </div>
      )}
    </div>
  );
};

/* ========================================
   Horizontal Bar Chart (apilado por descripción)
   --------------------------------------------------------------
   Cada fila es una categoría; la barra se divide en segmentos
   coloreados según el tipo de descripción (con novedad, sin
   novedad, reportería, error proceso). El ancho total de la barra
   es proporcional al total de la categoría con más alertas.
   ======================================== */
const HorizontalBar = ({ items, maxItems = 8 }) => {
  const sorted = [...items].sort((a, b) => b.total - a.total).slice(0, maxItems);
  const max = sorted[0]?.total || 1;

  return (
    <div className="payroll-hbar">
      {sorted.map((item) => (
        <div key={item.label} className="payroll-hbar__row">
          <span className="payroll-hbar__label" title={item.label}>{item.label}</span>
          <div className="payroll-hbar__bar-col">
            <div
              className="payroll-hbar__stack"
              style={{ width: `${(item.total / max) * 100}%` }}
            >
              {item.segments.map((seg) => (
                <div
                  key={seg.key}
                  className="payroll-hbar__seg"
                  style={{
                    width: `${(seg.value / item.total) * 100}%`,
                    background: seg.color,
                  }}
                  title={`${seg.label}: ${seg.value}`}
                  data-tooltip={`${seg.label}: ${seg.value}`}
                />
              ))}
            </div>
          </div>
          <span className="payroll-hbar__value">{item.total}</span>
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
   Menú de filtro por columna (estilo Excel)
   --------------------------------------------------------------
   Embudo en el encabezado → panel con orden A→Z / Z→A, buscador
   y lista de valores únicos con casillas (incluye "Seleccionar
   todo"). Aplica al pulsar "Aceptar"; "Limpiar" quita el filtro
   de esa columna.
   ======================================== */
const labelForValue = (v) => (v === '' || v == null ? '(Vacías)' : String(v));

const FILTER_MENU_WIDTH = 248;

const ColumnFilterMenu = ({ col, anchorRect, options, selected, sortDir, onApply, onSort, onClose }) => {
  const ref = useRef(null);
  const [search, setSearch] = useState('');
  const [checked, setChecked] = useState(() => new Set(selected ?? options));

  useEffect(() => {
    const handleOutside = (e) => {
      // Ignorar clics en el propio botón de embudo (él gestiona el toggle)
      if (e.target.closest && e.target.closest('.payroll-th__filter-btn')) return;
      if (ref.current && !ref.current.contains(e.target)) onClose();
    };
    const handleEsc = (e) => {
      if (e.key === 'Escape') onClose();
    };
    // Cerrar al hacer scroll FUERA del menú (p. ej. la tabla), ya que el menú
    // usa coordenadas fijas calculadas al abrir. El scroll interno de la lista
    // de valores no debe cerrarlo.
    const handleScroll = (e) => {
      if (ref.current && ref.current.contains(e.target)) return;
      onClose();
    };
    document.addEventListener('mousedown', handleOutside);
    document.addEventListener('keydown', handleEsc);
    window.addEventListener('scroll', handleScroll, true);
    window.addEventListener('resize', onClose);
    return () => {
      document.removeEventListener('mousedown', handleOutside);
      document.removeEventListener('keydown', handleEsc);
      window.removeEventListener('scroll', handleScroll, true);
      window.removeEventListener('resize', onClose);
    };
  }, [onClose]);

  // ── Posicionamiento (portal con position:fixed) ──────────────────────────
  // Se calcula el espacio disponible debajo/encima del botón. Si abajo no
  // cabe, el menú se abre hacia arriba. Además se limita la altura (maxHeight)
  // para que la lista tenga scroll y el footer (Limpiar/Aceptar) SIEMPRE se vea.
  const margin = 8;
  let left = anchorRect ? anchorRect.right - FILTER_MENU_WIDTH : margin;
  left = Math.max(margin, Math.min(left, window.innerWidth - margin - FILTER_MENU_WIDTH));

  const spaceBelow = anchorRect ? window.innerHeight - anchorRect.bottom - margin : window.innerHeight;
  const spaceAbove = anchorRect ? anchorRect.top - margin : window.innerHeight;
  const openUp = !!anchorRect && spaceBelow < 280 && spaceAbove > spaceBelow;
  const maxHeight = Math.max(200, openUp ? spaceAbove : spaceBelow);
  const positionStyle = openUp
    ? { bottom: window.innerHeight - anchorRect.top + 6, left }
    : { top: anchorRect ? anchorRect.bottom + 6 : margin, left };

  const term = search.trim().toLowerCase();
  const visibleOptions = term
    ? options.filter((o) => labelForValue(o).toLowerCase().includes(term))
    : options;
  const allVisibleChecked = visibleOptions.length > 0
    && visibleOptions.every((o) => checked.has(o));
  const allSelected = options.length > 0 && options.every((o) => checked.has(o));

  const toggle = (val) => {
    setChecked((prev) => {
      // Si estaban TODOS seleccionados (estado por defecto) y el usuario empieza
      // a elegir entre resultados de búsqueda, arrancamos selección limpia para
      // poder filtrar SOLO por lo elegido (si no, "todo seleccionado" = sin filtro).
      if (term && options.length > 0 && options.every((o) => prev.has(o))) {
        return new Set([val]);
      }
      const next = new Set(prev);
      if (next.has(val)) next.delete(val); else next.add(val);
      return next;
    });
  };

  const toggleAllVisible = () => {
    setChecked((prev) => {
      // Con búsqueda activa, "(Seleccionar todo)" significa "solo los resultados":
      // aísla la selección a lo visible (o la limpia si ya está exactamente así).
      if (term) {
        const exactlyVisible = prev.size === visibleOptions.length
          && visibleOptions.every((o) => prev.has(o));
        return exactlyVisible ? new Set() : new Set(visibleOptions);
      }
      const next = new Set(prev);
      if (allVisibleChecked) visibleOptions.forEach((o) => next.delete(o));
      else visibleOptions.forEach((o) => next.add(o));
      return next;
    });
  };

  const apply = () => {
    // Con búsqueda activa y todo aún marcado (no se tocó la selección), "Aceptar"
    // filtra por los resultados de la búsqueda. Así no hay que deseleccionar y
    // volver a seleccionar para filtrar por lo que se buscó. Si el usuario ya
    // marcó/desmarcó casillas, se respeta su selección (comportamiento normal).
    if (term && allSelected) {
      onApply(col.key, visibleOptions.length ? Array.from(visibleOptions) : null);
    } else {
      onApply(col.key, allSelected ? null : Array.from(checked));
    }
    onClose();
  };

  const clear = () => {
    onApply(col.key, null);
    onClose();
  };

  return createPortal(
    <div
      className="payroll-filter-menu"
      ref={ref}
      role="dialog"
      aria-label={`Filtrar ${col.header}`}
      style={{ ...positionStyle, width: FILTER_MENU_WIDTH, maxHeight }}
    >
      <div className="payroll-filter-menu__sort">
        <button
          type="button"
          className={`payroll-filter-menu__sort-btn${sortDir === 'asc' ? ' is-active' : ''}`}
          onClick={() => onSort(col.key, 'asc')}
        >
          <ArrowUp size={14} aria-hidden="true" /> Ordenar A → Z
        </button>
        <button
          type="button"
          className={`payroll-filter-menu__sort-btn${sortDir === 'desc' ? ' is-active' : ''}`}
          onClick={() => onSort(col.key, 'desc')}
        >
          <ArrowDown size={14} aria-hidden="true" /> Ordenar Z → A
        </button>
      </div>

      <div className="payroll-filter-menu__search">
        <Search size={14} aria-hidden="true" />
        <input
          type="text"
          autoFocus
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Buscar..."
          aria-label="Buscar valores"
        />
      </div>

      <label className="payroll-filter-menu__item payroll-filter-menu__item--all">
        <input
          type="checkbox"
          checked={allVisibleChecked}
          onChange={toggleAllVisible}
        />
        <span>(Seleccionar todo)</span>
      </label>

      <div className="payroll-filter-menu__list">
        {visibleOptions.length === 0 ? (
          <div className="payroll-filter-menu__empty">Sin valores</div>
        ) : (
          visibleOptions.map((opt) => (
            <label key={opt} className="payroll-filter-menu__item">
              <input
                type="checkbox"
                checked={checked.has(opt)}
                onChange={() => toggle(opt)}
              />
              <span title={labelForValue(opt)}>{labelForValue(opt)}</span>
            </label>
          ))
        )}
      </div>

      <div className="payroll-filter-menu__actions">
        <button type="button" className="btn btn--sm btn--ghost" onClick={clear}>
          Limpiar
        </button>
        <button type="button" className="btn btn--sm btn--primary" onClick={apply}>
          Aceptar
        </button>
      </div>
    </div>,
    document.body,
  );
};

/* ========================================
   Historial Popup (acceso directo desde grilla)
   --------------------------------------------------------------
   Modal pequeño, centrado, que muestra SOLO el historial de una
   alerta. Reutiliza el componente Modal genérico del design
   system (.modal/.modal__*) y las clases payroll-historial__*
   ya existentes para el render de cada entrada — no se duplican
   estilos ni lógica visual.
   ======================================== */
const HistorialPopup = ({
  open,
  idNotificacion,
  items,
  loading,
  error,
  onClose,
  onReload,
}) => {
  const title = (
    <span className="payroll-historial-popup__title">
      <Clock size={16} aria-hidden="true" />
      <span>Historial de cambios</span>
      {idNotificacion != null && (
        <span className="payroll-historial-popup__id">#{idNotificacion}</span>
      )}
    </span>
  );

  return (
    <Modal isOpen={open} onClose={onClose} title={title}>
      <div className="payroll-historial-popup__body">
        {loading ? (
          <div
            className="payroll-historial__loading"
            role="status"
            aria-live="polite"
          >
            <Loader2
              size={16}
              aria-hidden="true"
              className="payroll-historial__spinner"
            />
            <span>Cargando historial…</span>
          </div>
        ) : error ? (
          <div className="payroll-historial__error" role="alert">
            <span>No se pudo cargar el historial.</span>
            <button
              type="button"
              className="btn btn--secondary btn--sm"
              onClick={onReload}
            >
              Reintentar
            </button>
          </div>
        ) : !items || items.length === 0 ? (
          <div className="payroll-historial__empty">
            Sin historial de cambios todavía.
          </div>
        ) : (
          <ul className="payroll-historial__list payroll-historial__list--popup">
            {items.map((entry, idx) => {
              const sinCambio = entry.estadoAnterior === entry.estadoNuevo;
              const fecha = entry.fecha ? new Date(entry.fecha) : null;
              const fechaTxt = fecha && !isNaN(fecha.getTime())
                ? `${pad2(fecha.getDate())}/${pad2(fecha.getMonth() + 1)}/${fecha.getFullYear()} ` +
                  `${pad2(fecha.getHours())}:${pad2(fecha.getMinutes())}`
                : '—';
              return (
                <li
                  key={entry.id || `${entry.fecha}-${idx}`}
                  className={`payroll-historial__item${idx === 0 ? ' payroll-historial__item--latest' : ''}`}
                >
                  <div className="payroll-historial__dot" aria-hidden="true" />
                  <div className="payroll-historial__content">
                    <div className="payroll-historial__change">
                      {sinCambio ? (
                        <span className="payroll-historial__no-change">
                          Editado (sin cambio de estado)
                        </span>
                      ) : (
                        <>
                          <StatusBadge status={entry.estadoAnterior} />
                          <span className="payroll-historial__arrow">→</span>
                          <StatusBadge status={entry.estadoNuevo} />
                        </>
                      )}
                    </div>
                    <div className="payroll-historial__meta">
                      <strong>{entry.usuarioEmail || '—'}</strong>
                      {entry.usuarioRol ? ` (${entry.usuarioRol})` : ''}
                      {' · '}
                      <span>{fechaTxt}</span>
                    </div>
                    {entry.comentario && (
                      <div className="payroll-historial__comment">
                        {entry.comentario}
                      </div>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </Modal>
  );
};

/* ========================================
   Preview Modal (iframe + zoom)
   ======================================== */
const PREVIEW_BASE_W = 800;
const PREVIEW_BASE_H = 1100;
const ZOOM_MIN = 25;
const ZOOM_MAX = 300;
const ZOOM_STEP = 25;

// ¿El adjunto se puede previsualizar en el navegador (imagen o PDF)?
function isImageOrPdf(mime, name) {
  const m = (mime || '').toLowerCase();
  if (m.startsWith('image/') || m === 'application/pdf') return true;
  const ext = (name || '').toLowerCase().split('.').pop();
  return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg', 'pdf'].includes(ext);
}

const AlertaModal = ({
  row,
  usuarioSesion,
  saving,
  onClose,
  onSave,
  historial,
  historialLoading,
  historialError,
  onReloadHistorial,
  historialDelayedWarning,
  onDismissHistorialWarning,
}) => {
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
  const previewIframeRef = useRef(null);
  // Tamaño de la "página" del correo. Arranca en el base y se ajusta al tamaño
  // real del contenido tras cargar el iframe: así los reportes largos no se
  // recortan (alto) y las tablas anchas no generan scroll interno (ancho). De
  // este modo solo queda UN scroll: el del visor (.preview-modal__scroll).
  const [contentHeight, setContentHeight] = useState(PREVIEW_BASE_H);
  const [contentWidth, setContentWidth] = useState(PREVIEW_BASE_W);

  // Mide el tamaño real del contenido del iframe y ajusta la página. Requiere
  // allow-same-origin en el sandbox (el correo no ejecuta scripts, es seguro).
  const measurePreviewSize = () => {
    try {
      const doc = previewIframeRef.current?.contentDocument;
      if (!doc) return;
      const h = Math.max(
        doc.documentElement?.scrollHeight || 0,
        doc.body?.scrollHeight || 0,
      );
      const w = Math.max(
        doc.documentElement?.scrollWidth || 0,
        doc.body?.scrollWidth || 0,
      );
      if (h > 0) setContentHeight(Math.min(Math.max(h + 8, 300), 50000));
      // El ancho nunca baja del base (800), solo crece si el contenido es más ancho.
      if (w > 0) setContentWidth(Math.min(Math.max(w + 4, PREVIEW_BASE_W), 20000));
    } catch {
      // Sin acceso (cross-origin): se mantiene el tamaño por defecto.
    }
  };

  // Adjuntos de resolución (los sube quien resuelve; distintos del adjunto origen de la alerta).
  const [existingAdjuntos, setExistingAdjuntos] = useState([]);
  const [newAdjuntoFiles, setNewAdjuntoFiles] = useState([]);
  const [adjuntosBusy, setAdjuntosBusy] = useState(false);
  const [adjuntoPreview, setAdjuntoPreview] = useState(null); // { url, fileName, mimeType }
  const [adjuntoZoom, setAdjuntoZoom] = useState(100);
  const adjuntoInputRef = useRef(null);
  const totalAdjuntos = existingAdjuntos.length + newAdjuntoFiles.length;

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
    setContentHeight(PREVIEW_BASE_H);
    setContentWidth(PREVIEW_BASE_W);
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

  // Cargar adjuntos de resolución al abrir/cambiar de alerta.
  useEffect(() => {
    if (!row?.idNotificacion) return undefined;
    let cancelled = false;
    setNewAdjuntoFiles([]);
    alertasService.getAdjuntos(row.idNotificacion)
      .then((list) => { if (!cancelled) setExistingAdjuntos(list); })
      .catch(() => { if (!cancelled) setExistingAdjuntos([]); });
    return () => { cancelled = true; };
  }, [row?.idNotificacion]);

  // Pegar imagen (Ctrl+V) → se agrega como adjunto de resolución.
  useEffect(() => {
    const onPaste = (e) => {
      const cd = e.clipboardData;
      if (!cd) return;
      const raw = cd.files.length
        ? Array.from(cd.files)
        : Array.from(cd.items || []).filter((it) => it.kind === 'file').map((it) => it.getAsFile()).filter(Boolean);
      const imgs = raw
        .filter((f) => f && f.type.startsWith('image/'))
        .map((f) => {
          const ext = f.type.split('/')[1] || 'png';
          const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
          return new File([f], `imagen-${ts}.${ext}`, { type: f.type });
        });
      if (imgs.length > 0) {
        e.preventDefault();
        setNewAdjuntoFiles((prev) => [...prev, ...imgs]);
      }
    };
    document.addEventListener('paste', onPaste);
    return () => document.removeEventListener('paste', onPaste);
  }, []);

  const handleAdjuntoSelect = (e) => {
    const selected = Array.from(e.target.files || []);
    if (selected.length > 0) setNewAdjuntoFiles((prev) => [...prev, ...selected]);
    e.target.value = '';
  };

  const handleRemoveNewAdjunto = (idx) => {
    setNewAdjuntoFiles((prev) => prev.filter((_, i) => i !== idx));
  };

  const handleDownloadResolucionAdjunto = async (adjuntoId) => {
    try {
      await alertasService.downloadAdjunto(row.idNotificacion, adjuntoId);
    } catch (err) {
      Swal.fire({ title: 'No se pudo descargar', text: err.message || 'Error al descargar.', icon: 'error' });
    }
  };

  const handleRemoveExistingAdjunto = async (adjuntoId) => {
    const confirm = await Swal.fire({
      title: 'Eliminar adjunto',
      text: '¿Eliminar este adjunto de la resolución?',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#E31837',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Sí, eliminar',
      cancelButtonText: 'Cancelar',
    });
    if (!confirm.isConfirmed) return;
    try {
      setAdjuntosBusy(true);
      await alertasService.removeAdjunto(row.idNotificacion, adjuntoId);
      setExistingAdjuntos((prev) => prev.filter((a) => a.id !== adjuntoId));
    } catch (err) {
      Swal.fire({ title: 'No se pudo eliminar', text: err.message || 'Error.', icon: 'error' });
    } finally {
      setAdjuntosBusy(false);
    }
  };

  const handlePreviewExistingAdjunto = async (a) => {
    try {
      setAdjuntosBusy(true);
      const { url, fileName, mimeType } = await alertasService.previewAdjunto(row.idNotificacion, a.id);
      setAdjuntoZoom(100);
      setAdjuntoPreview({ url, fileName, mimeType: mimeType || a.contentType });
    } catch (err) {
      Swal.fire({ title: 'No se pudo previsualizar', text: err.message || 'Error.', icon: 'error' });
    } finally {
      setAdjuntosBusy(false);
    }
  };

  const handlePreviewNewAdjunto = (f) => {
    setAdjuntoZoom(100);
    setAdjuntoPreview({ url: URL.createObjectURL(f), fileName: f.name, mimeType: f.type });
  };

  const closeAdjuntoPreview = () => {
    setAdjuntoPreview((prev) => {
      if (prev?.url) URL.revokeObjectURL(prev.url);
      return null;
    });
  };

  const handleSubmit = async () => {
    if (saving || adjuntosBusy) return;

    // Regla: el estado "Error" (E) exige al menos un adjunto de resolución.
    if (editEstado === 'E' && totalAdjuntos === 0) {
      Swal.fire({
        title: 'Adjunto requerido',
        text: 'Para marcar la alerta como "Error" debe adjuntar al menos un archivo.',
        icon: 'warning',
        confirmButtonColor: '#E31837',
      });
      return;
    }

    // Subir los archivos nuevos antes de guardar el cambio de estado.
    if (newAdjuntoFiles.length > 0) {
      try {
        setAdjuntosBusy(true);
        const subidos = await alertasService.uploadAdjuntos(row.idNotificacion, newAdjuntoFiles);
        setExistingAdjuntos((prev) => [...prev, ...subidos]);
        setNewAdjuntoFiles([]);
      } catch (err) {
        setAdjuntosBusy(false);
        Swal.fire({ title: 'Error al subir adjuntos', text: err.message || 'No se pudieron subir los archivos.', icon: 'error' });
        return;
      }
      setAdjuntosBusy(false);
    }

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
                    style={{ width: contentWidth * scale, height: contentHeight * scale }}
                  >
                    <iframe
                      ref={previewIframeRef}
                      title="Previsualización del correo"
                      className="preview-modal__iframe"
                      sandbox="allow-same-origin allow-popups allow-popups-to-escape-sandbox allow-top-navigation-by-user-activation"
                      srcDoc={doc}
                      scrolling="no"
                      onLoad={measurePreviewSize}
                      style={{
                        width: contentWidth,
                        height: contentHeight,
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
            {historialDelayedWarning && (
              <div className="alert alert--warning payroll-historial__banner" role="status">
                <AlertTriangle size={18} className="alert__icon" aria-hidden="true" />
                <div className="alert__content">
                  <div className="alert__title">Cambio guardado</div>
                  <div className="alert__message">
                    El cambio se guardó, pero el historial puede demorar en aparecer.
                  </div>
                </div>
                {onDismissHistorialWarning && (
                  <button
                    type="button"
                    className="btn btn--icon btn--sm btn--ghost"
                    onClick={onDismissHistorialWarning}
                    aria-label="Cerrar aviso"
                    title="Cerrar"
                  >
                    <X size={14} />
                  </button>
                )}
              </div>
            )}

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
                placeholder="Ingrese observaciones sobre la resolución... o realiza Ctrl+V para pegar una imagen"
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

            <div className="preview-modal__side-section">
              <h3 className="preview-modal__side-title">
                <Paperclip size={14} aria-hidden="true" /> Adjuntos de resolución
                {editEstado === 'E' && <span className="payroll-adjunto-req"> *</span>}
              </h3>

              <button
                type="button"
                className="payroll-adjunto-drop"
                onClick={() => adjuntoInputRef.current?.click()}
                disabled={saving || adjuntosBusy}
              >
                <Upload size={16} aria-hidden="true" />
                <span>Adjuntar archivo o pegar imagen (Ctrl+V)</span>
              </button>
              <input
                ref={adjuntoInputRef}
                type="file"
                multiple
                onChange={handleAdjuntoSelect}
                style={{ display: 'none' }}
              />

              {editEstado === 'E' && totalAdjuntos === 0 && (
                <small className="payroll-adjunto-req-hint">
                  Obligatorio para marcar la alerta como "Error".
                </small>
              )}

              {(existingAdjuntos.length > 0 || newAdjuntoFiles.length > 0) && (
                <ul className="payroll-adjunto-list">
                  {existingAdjuntos.map((a) => (
                    <li key={a.id} className="payroll-adjunto-item">
                      <FileText size={14} aria-hidden="true" className="payroll-adjunto-icon" />
                      <span className="payroll-adjunto-name" title={a.fileName}>{a.fileName}</span>
                      {isImageOrPdf(a.contentType, a.fileName) && (
                        <button
                          type="button"
                          className="btn btn--icon btn--sm btn--ghost"
                          data-tooltip="Previsualizar"
                          aria-label="Previsualizar adjunto"
                          onClick={() => handlePreviewExistingAdjunto(a)}
                          disabled={adjuntosBusy}
                        >
                          <Eye size={14} />
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn btn--icon btn--sm btn--ghost"
                        data-tooltip="Descargar"
                        aria-label="Descargar adjunto"
                        onClick={() => handleDownloadResolucionAdjunto(a.id)}
                        disabled={adjuntosBusy}
                      >
                        <Download size={14} />
                      </button>
                      <button
                        type="button"
                        className="btn btn--icon btn--sm btn--ghost"
                        data-tooltip="Eliminar"
                        aria-label="Eliminar adjunto"
                        onClick={() => handleRemoveExistingAdjunto(a.id)}
                        disabled={adjuntosBusy || saving}
                      >
                        <Trash2 size={14} />
                      </button>
                    </li>
                  ))}
                  {newAdjuntoFiles.map((f, idx) => (
                    <li key={`new-${idx}-${f.name}`} className="payroll-adjunto-item payroll-adjunto-item--new">
                      <FileText size={14} aria-hidden="true" className="payroll-adjunto-icon" />
                      <span className="payroll-adjunto-name" title={f.name}>{f.name}</span>
                      <span className="payroll-adjunto-badge">nuevo</span>
                      {isImageOrPdf(f.type, f.name) && (
                        <button
                          type="button"
                          className="btn btn--icon btn--sm btn--ghost"
                          data-tooltip="Previsualizar"
                          aria-label="Previsualizar adjunto"
                          onClick={() => handlePreviewNewAdjunto(f)}
                          disabled={adjuntosBusy}
                        >
                          <Eye size={14} />
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn btn--icon btn--sm btn--ghost"
                        data-tooltip="Quitar"
                        aria-label="Quitar adjunto"
                        onClick={() => handleRemoveNewAdjunto(idx)}
                        disabled={adjuntosBusy || saving}
                      >
                        <X size={14} />
                      </button>
                    </li>
                  ))}
                </ul>
              )}
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

            <div className="preview-modal__side-section payroll-historial">
              <h3 className="preview-modal__side-title payroll-historial__title">
                <Clock size={14} aria-hidden="true" /> Historial de cambios
              </h3>
              {historialLoading ? (
                <div
                  className="payroll-historial__loading"
                  role="status"
                  aria-live="polite"
                >
                  <Loader2
                    size={16}
                    aria-hidden="true"
                    className="payroll-historial__spinner"
                  />
                  <span>Cargando historial…</span>
                </div>
              ) : historialError ? (
                <div className="payroll-historial__error" role="alert">
                  <span>No se pudo cargar el historial.</span>
                  <button
                    type="button"
                    className="btn btn--secondary btn--sm"
                    onClick={onReloadHistorial}
                  >
                    Reintentar
                  </button>
                </div>
              ) : !historial || historial.length === 0 ? (
                <div className="payroll-historial__empty">
                  Sin historial de cambios todavía.
                </div>
              ) : (
                <ul className="payroll-historial__list">
                  {historial.map((entry, idx) => {
                    const sinCambio = entry.estadoAnterior === entry.estadoNuevo;
                    const fecha = entry.fecha ? new Date(entry.fecha) : null;
                    const fechaTxt = fecha && !isNaN(fecha.getTime())
                      ? `${pad2(fecha.getDate())}/${pad2(fecha.getMonth() + 1)}/${fecha.getFullYear()} ` +
                        `${pad2(fecha.getHours())}:${pad2(fecha.getMinutes())}`
                      : '—';
                    return (
                      <li
                        key={entry.id || `${entry.fecha}-${idx}`}
                        className={`payroll-historial__item${idx === 0 ? ' payroll-historial__item--latest' : ''}`}
                      >
                        <div className="payroll-historial__dot" aria-hidden="true" />
                        <div className="payroll-historial__content">
                          <div className="payroll-historial__change">
                            {sinCambio ? (
                              <span className="payroll-historial__no-change">
                                Editado (sin cambio de estado)
                              </span>
                            ) : (
                              <>
                                <StatusBadge status={entry.estadoAnterior} />
                                <span className="payroll-historial__arrow">→</span>
                                <StatusBadge status={entry.estadoNuevo} />
                              </>
                            )}
                          </div>
                          <div className="payroll-historial__meta">
                            <strong>{entry.usuarioEmail || '—'}</strong>
                            {entry.usuarioRol ? ` (${entry.usuarioRol})` : ''}
                            {' · '}
                            <span>{fechaTxt}</span>
                          </div>
                          {entry.comentario && (
                            <div className="payroll-historial__comment">
                              {entry.comentario}
                            </div>
                          )}
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )}
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

        {saving && (
          <div className="payroll-saving-overlay" role="status" aria-live="polite">
            <Loader2 size={28} className="payroll-historial__spinner" aria-hidden="true" />
            <span>Guardando cambios…</span>
          </div>
        )}
      </div>

      {adjuntoPreview && createPortal(
        <div
          className="preview-modal__overlay"
          style={{ zIndex: 3000 }}
          role="presentation"
          onMouseDown={(e) => { if (e.target === e.currentTarget) closeAdjuntoPreview(); }}
        >
          <div className="payroll-adjunto-lightbox" role="dialog" aria-modal="true" aria-label={adjuntoPreview.fileName}>
            <div className="payroll-adjunto-lightbox__header">
              <span className="payroll-adjunto-lightbox__title" title={adjuntoPreview.fileName}>
                {adjuntoPreview.fileName}
              </span>
              {(adjuntoPreview.mimeType || '').startsWith('image/') && (
                <div className="preview-modal__zoom" role="group" aria-label="Controles de zoom">
                  <button
                    type="button"
                    className="preview-modal__zoom-btn"
                    onClick={() => setAdjuntoZoom((z) => Math.max(25, z - 25))}
                    disabled={adjuntoZoom <= 25}
                    aria-label="Alejar"
                  >
                    <ZoomOut size={16} />
                  </button>
                  <button
                    type="button"
                    className="preview-modal__zoom-pct"
                    onClick={() => setAdjuntoZoom(100)}
                    title="Restablecer al 100%"
                  >
                    {adjuntoZoom}%
                  </button>
                  <button
                    type="button"
                    className="preview-modal__zoom-btn"
                    onClick={() => setAdjuntoZoom((z) => Math.min(400, z + 25))}
                    disabled={adjuntoZoom >= 400}
                    aria-label="Acercar"
                  >
                    <ZoomIn size={16} />
                  </button>
                </div>
              )}
              <button
                type="button"
                className="preview-modal__close"
                onClick={closeAdjuntoPreview}
                aria-label="Cerrar"
                title="Cerrar"
              >
                <X size={20} />
              </button>
            </div>
            <div className="payroll-adjunto-lightbox__body">
              {(adjuntoPreview.mimeType || '').startsWith('image/') ? (
                <div
                  className="payroll-adjunto-lightbox__imgwrap"
                  style={{ width: `${adjuntoZoom}%`, margin: adjuntoZoom <= 100 ? '0 auto' : '0' }}
                >
                  <img
                    src={adjuntoPreview.url}
                    alt={adjuntoPreview.fileName}
                    className="payroll-adjunto-lightbox__img"
                  />
                </div>
              ) : (adjuntoPreview.mimeType === 'application/pdf' || /\.pdf$/i.test(adjuntoPreview.fileName)) ? (
                <iframe
                  title={adjuntoPreview.fileName}
                  src={adjuntoPreview.url}
                  className="payroll-adjunto-lightbox__iframe"
                />
              ) : (
                <div className="preview-modal__empty">
                  No se puede previsualizar este tipo de archivo.
                </div>
              )}
            </div>
          </div>
        </div>,
        document.body,
      )}
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
  { key: 'origen', header: 'Origen', type: 'text' },
];

/* ========================================
   XLSX Export
   ======================================== */
async function downloadAlertasXlsx(alertas, fileName) {
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

  const { default: ExcelJS } = await import('exceljs');
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Alertas');

  const headers = [
    'ID', 'Fecha Creación', 'Estado', 'Prioridad', 'Categoría',
    'Asunto', 'Descripción', 'Notificados', 'Origen',
    'Fecha Resolución', 'Usuario Resolución', 'Notas Resolución',
  ];

  // ── Anchos de columna ──────────────────────────────────────────────────────
  const colWidths = [6, 18, 12, 12, 18, 40, 18, 35, 18, 18, 25, 40];
  ws.columns = headers.map((h, i) => ({ header: h, key: h, width: colWidths[i] }));

  // ── Estilo del encabezado ──────────────────────────────────────────────────
  const headerRow = ws.getRow(1);
  headerRow.height = 22;
  headerRow.eachCell((cell) => {
    cell.font   = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11, name: 'Calibri' };
    cell.fill   = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };
    cell.border = {
      top: { style: 'thin', color: { argb: 'FFC0C0C0' } },
      bottom: { style: 'thin', color: { argb: 'FFC0C0C0' } },
      left: { style: 'thin', color: { argb: 'FFC0C0C0' } },
      right: { style: 'thin', color: { argb: 'FFC0C0C0' } },
    };
    cell.alignment = { horizontal: 'center', vertical: 'middle' };
  });

  // ── Filas de datos ─────────────────────────────────────────────────────────
  alertas.forEach((a, idx) => {
    const rowData = [
      a.idNotificacion ?? '',
      formatDate(a.fechaCreacion),
      ESTADO_LABELS[a.estado] || a.estado || '',
      PRIORIDAD_LABELS[normalizePriority(a.prioridad)] || a.prioridad || '',
      a.categoria || '',
      a.asunto || '',
      a.descripcion || '',
      parseDestinatarios(a.destinatarios).join(', '),
      a.origen || '',
      a.fechaModificacion ? formatDate(a.fechaModificacion) : '',
      a.usuarioResolucion || '',
      a.notasResolucion || '',
    ];
    const row = ws.addRow(rowData);
    row.height = 18;
    const bgArgb = idx % 2 === 0 ? 'FFEBF3FB' : 'FFFFFFFF';
    row.eachCell({ includeEmpty: true }, (cell, colNumber) => {
      cell.font   = { size: 10, name: 'Calibri', color: { argb: 'FF000000' } };
      cell.fill   = { type: 'pattern', pattern: 'solid', fgColor: { argb: bgArgb } };
      cell.border = {
        top: { style: 'thin', color: { argb: 'FFE0E0E0' } },
        bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } },
        left: { style: 'thin', color: { argb: 'FFE0E0E0' } },
        right: { style: 'thin', color: { argb: 'FFE0E0E0' } },
      };
      cell.alignment = { horizontal: colNumber === 1 ? 'center' : 'left', vertical: 'middle' };
    });
  });

  // ── Congelar fila de encabezado ────────────────────────────────────────────
  ws.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

  // ── Descargar ──────────────────────────────────────────────────────────────
  const buffer = await wb.xlsx.writeBuffer();
  const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = fileName;
  a.click();
  URL.revokeObjectURL(url);
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
          // Total primero (antes de la línea del segmento y del hint de clic).
          beforeBody: (tooltipItems) => {
            const item = tooltipItems[0];
            const descKey = item ? chartData.datasets[item.datasetIndex]?._descKey : null;
            // Total de alertas del día/semana/mes (todas las descripciones,
            // no solo la seleccionada) — solo para reportería, con novedad
            // y sin novedad; error proceso no cuenta como alerta "llegada".
            if (!item || !['con_novedad', 'sin_novedad', 'reporteria'].includes(descKey)) return [];
            const idx = item.dataIndex;
            const total = chartData.datasets.reduce(
              (sum, ds) => sum + (Number(ds.data[idx]) || 0), 0,
            );
            return [`Total del ${groupTitle.toLowerCase()}: ${total} alertas`];
          },
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
  const isPrivileged = useMemo(() => isPrivilegedUser(user), [user]);
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  const [editingRow, setEditingRow] = useState(null);
  const [saving, setSaving] = useState(false);
  const [historial, setHistorial] = useState([]);
  const [historialLoading, setHistorialLoading] = useState(false);
  const [historialError, setHistorialError] = useState(null);
  // Banner amarillo dentro del modal cuando DAB OK pero Mongo falla
  // (response.historialPersistido === false). Es informativo, no bloquea.
  const [historialDelayedWarning, setHistorialDelayedWarning] = useState(false);

  // Popup de historial accesible desde la columna Acciones (no es el
  // modal grande de la alerta; sólo muestra el historial).
  const [historialPopup, setHistorialPopup] = useState({
    open: false,
    idNotificacion: null,
    items: [],
    loading: false,
    error: null,
  });

  const [sort, setSort] = useState({ key: null, dir: null });
  const [globalFilter, setGlobalFilter] = useState('');
  // columnFilters: { [key]: string[] } — valores seleccionados; sin entrada = sin filtro
  const [columnFilters, setColumnFilters] = useState({});
  // openFilter: null o { key, rect } — columna con menú abierto y posición del botón
  const [openFilter, setOpenFilter] = useState(null);

  const [activeTab, setActiveTab] = useState(() => (isPrivilegedUser(user) ? 'dashboard' : 'listado'));
  // Sub-pestaña de la tabla del Listado: 'pendientes' (A/P/E) | 'finalizadas' (R/C)
  const [tableTab, setTableTab] = useState('pendientes');
  // Modo de la tabla del Listado: 'lista' (plana paginada) | 'agrupado' (por categoría).
  // Por defecto arranca agrupado; el usuario puede cambiar a lista.
  const [viewMode, setViewMode] = useState('agrupado');
  // Categorías expandidas en modo agrupado (arrancan todas contraídas).
  const [expandedGroups, setExpandedGroups] = useState(() => new Set());
  const [catDescFilter, setCatDescFilter] = useState(() => new Set(DESC_KEYS));

  // "Pegado" horizontal del título de categoría (modo Agrupado) hecho a mano
  // con JS: `position: sticky; left` NO se aplica de forma confiable en un
  // elemento dentro de un <td colSpan> (verificado en Chromium — se probó
  // sticky en el <td> y en un hijo directo, ninguno "pega" horizontalmente,
  // aunque el sticky vertical del mismo <td> sí funciona). Se compensa
  // trasladando el botón con `transform: translateX(scrollLeft)` cada vez
  // que se hace scroll horizontal, con rAF para no saturar de renders.
  const [groupHeaderShift, setGroupHeaderShift] = useState(0);
  const groupHeaderShiftRaf = useRef(null);
  const handleTableScroll = (e) => {
    const scrollLeft = e.currentTarget.scrollLeft;
    if (groupHeaderShiftRaf.current) cancelAnimationFrame(groupHeaderShiftRaf.current);
    groupHeaderShiftRaf.current = requestAnimationFrame(() => setGroupHeaderShift(scrollLeft));
  };

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

  // Refresco "silencioso": misma llamada que loadData, pero NO dispara el
  // gate de `loading` que reemplaza toda la pantalla por "Cargando...".
  // Lo usan el botón Actualizar, el auto-refresh periódico y el refresco al
  // volver a la pestaña — así no se pierde el scroll, los grupos expandidos
  // ni los filtros cada vez que se refresca.
  const refreshData = () => {
    setRefreshing(true);
    return payrollService.getNotificaciones()
      .then(setData)
      .catch((err) => setError(err.message))
      .finally(() => setRefreshing(false));
  };

  useEffect(() => {
    loadData();
  }, []);

  // Auto-refresh cada 60s + al volver a la pestaña (visibilitychange).
  // Se pausa mientras hay una alerta abierta en el modal de resolución para
  // no pisarle a alguien las notas que está escribiendo a media edición.
  useEffect(() => {
    if (editingRow) return undefined;

    const interval = setInterval(refreshData, 60000);

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') refreshData();
    };
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      clearInterval(interval);
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, [editingRow]);

  // Si el usuario no es privilegiado, nunca debe quedar en la pestaña Dashboard
  // (p. ej. tras cambiar de rol con switchRole).
  useEffect(() => {
    if (!isPrivileged && activeTab === 'dashboard') {
      setActiveTab('listado');
    }
  }, [isPrivileged, activeTab]);

  const usuarioSesion = user?.email || user?.name || user?.id || '';
  // usuarioRol ya no se envia al backend (lo extrae del JWT) — se mantenia solo para
  // el body antiguo de cambiarEstado.

  const loadHistorial = async (idNotificacion) => {
    if (!idNotificacion) return;
    setHistorialLoading(true);
    setHistorialError(null);
    try {
      const response = await alertasService.getHistorial(idNotificacion);
      const items = Array.isArray(response?.items) ? response.items : [];
      // Orden DESC por fecha (más reciente arriba)
      items.sort((a, b) => {
        const ta = a?.fecha ? new Date(a.fecha).getTime() : 0;
        const tb = b?.fecha ? new Date(b.fecha).getTime() : 0;
        return tb - ta;
      });
      setHistorial(items);
    } catch (err) {
      setHistorialError(err.message || 'Error al cargar historial');
      setHistorial([]);
    } finally {
      setHistorialLoading(false);
    }
  };

  const openAlerta = (row) => {
    setEditingRow(row);
    setHistorial([]);
    setHistorialError(null);
    setHistorialDelayedWarning(false);
    loadHistorial(row?.idNotificacion);
  };

  // Carga el historial dentro del estado del popup (independiente del
  // historial del modal grande para que ambos puedan abrirse sin
  // pisarse entre sí).
  const loadHistorialPopup = async (idNotificacion) => {
    if (!idNotificacion) return;
    setHistorialPopup((prev) => ({
      ...prev,
      loading: true,
      error: null,
    }));
    try {
      const response = await alertasService.getHistorial(idNotificacion);
      const items = Array.isArray(response?.items) ? response.items : [];
      items.sort((a, b) => {
        const ta = a?.fecha ? new Date(a.fecha).getTime() : 0;
        const tb = b?.fecha ? new Date(b.fecha).getTime() : 0;
        return tb - ta;
      });
      setHistorialPopup((prev) => ({
        ...prev,
        items,
        loading: false,
        error: null,
      }));
    } catch (err) {
      setHistorialPopup((prev) => ({
        ...prev,
        items: [],
        loading: false,
        error: err.message || 'Error al cargar historial',
      }));
    }
  };

  const openHistorialPopup = (row) => {
    const id = row?.idNotificacion;
    if (!id) return;
    setHistorialPopup({
      open: true,
      idNotificacion: id,
      items: [],
      loading: true,
      error: null,
    });
    loadHistorialPopup(id);
  };

  const closeHistorialPopup = () => {
    setHistorialPopup({
      open: false,
      idNotificacion: null,
      items: [],
      loading: false,
      error: null,
    });
  };

  const closeAlerta = () => {
    if (saving) return;
    setEditingRow(null);
    setHistorial([]);
    setHistorialError(null);
    setHistorialDelayedWarning(false);
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
      setHistorialDelayedWarning(false);

      // El backend toma usuarioEmail/usuarioRol del JWT — no se envian en el body.
      // Enviamos las notas como `comentario` para que queden registradas en el historial.
      const response = await alertasService.cambiarEstado(editingRow.idNotificacion, {
        nuevoEstado: estado,
        comentario: notas?.trim() || '',
      });

      const idActual = editingRow.idNotificacion;

      if (response && response.historialPersistido === false) {
        // DAB OK pero Mongo falló: NO bloqueamos al usuario, mostramos
        // banner dentro del modal y refrescamos lista + historial.
        setHistorialDelayedWarning(true);
        refreshData();
        if (idActual) loadHistorial(idActual);
      } else {
        // Actualizar esa fila en la tabla al instante con los valores que el
        // backend confirma que ya quedaron guardados (evita esperar un
        // refetch completo de TODAS las alertas, que era la parte mas lenta
        // — hasta 3-4s — porque el cache de 15s se invalida con cada cambio).
        // El auto-refresh (60s / cambio de pestaña) sigue sincronizando en
        // segundo plano el resto de campos (fechaModificacion, etc.) y
        // cualquier cambio de otros usuarios.
        setData((prev) => prev.map((row) => (
          row.idNotificacion === idActual
            ? {
                ...row,
                estado: response.estado,
                notasResolucion: response.notasResolucion,
                usuarioResolucion: response.usuarioResolucion,
              }
            : row
        )));
        await Swal.fire({
          title: 'Guardado',
          text: 'Los cambios se guardaron correctamente.',
          icon: 'success',
          timer: 900,
          showConfirmButton: false,
        });
        setEditingRow(null);
        setHistorial([]);
        setHistorialDelayedWarning(false);
        if (idActual) loadHistorial(idActual);
        refreshData();
      }
    } catch (err) {
      // 5xx (DAB caído / SQL no disponible) — mensaje claro y accionable.
      // 4xx — usar el mensaje del backend si vino, o uno genérico.
      const status = err?.status;
      const isServerError = typeof status === 'number' && status >= 500;
      const title = isServerError ? 'No se pudo actualizar el estado' : 'Error';
      const text = isServerError
        ? 'No se pudo actualizar el estado en SQL. Reintenta más tarde.'
        : err.message || 'No se pudieron guardar los cambios.';

      Swal.fire({
        title,
        text,
        icon: 'error',
        confirmButtonText: 'Entendido',
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
          <button
            type="button"
            className="btn btn--icon btn--sm btn--ghost"
            onClick={(e) => { e.stopPropagation(); openHistorialPopup(row); }}
            data-tooltip="Ver historial de cambios"
            aria-label={`Ver historial de la alerta ${row.asunto || row.idNotificacion}`}
          >
            <Clock size={16} />
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

  // Aplica/quita el filtro de una columna (vals null o vacío = sin filtro)
  const applyColumnFilter = (key, vals) => {
    setColumnFilters((f) => {
      const next = { ...f };
      if (!vals || !vals.length) delete next[key];
      else next[key] = vals;
      return next;
    });
  };

  const applyColumnSort = (key, dir) => setSort({ key, dir });

  // Valores únicos disponibles para una columna, respetando los demás
  // filtros activos (búsqueda global, fechas y otras columnas) — como Excel.
  const getColumnOptions = (colKey) => {
    const col = columns.find((c) => c.key === colKey);
    if (!col) return [];
    let rows = dateFilteredData;
    const g = globalFilter.trim().toLowerCase();
    if (g) {
      rows = rows.filter((row) =>
        columns.some(
          (c) => c.filterable !== false && getFilterText(c, row).toLowerCase().includes(g),
        ),
      );
    }
    const others = Object.entries(columnFilters).filter(
      ([k, v]) => k !== colKey && Array.isArray(v) && v.length,
    );
    if (others.length) {
      rows = rows.filter((row) =>
        others.every(([k, vals]) => {
          const c = columns.find((x) => x.key === k);
          if (!c) return true;
          return vals.includes(getFilterText(c, row));
        }),
      );
    }
    const set = new Set();
    rows.forEach((row) => set.add(getFilterText(col, row)));
    return Array.from(set).sort((a, b) =>
      labelForValue(a).localeCompare(labelForValue(b), 'es', { sensitivity: 'base', numeric: true }),
    );
  };

  const hasFilters = globalFilter.trim() !== ''
    || Object.values(columnFilters).some((v) => Array.isArray(v) && v.length > 0)
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

    // Sub-pestaña de la tabla: 'finalizadas' = Resueltas (R) + Cerradas (C);
    // 'pendientes' = el resto (Activa/En Proceso/Error); 'todas' = sin filtro
    // de estado (abiertas y cerradas, todos los estados).
    if (tableTab !== 'todas') {
      rows = rows.filter((row) => {
        const finalizada = ESTADOS_FINALIZADOS.includes(row.estado);
        return tableTab === 'finalizadas' ? finalizada : !finalizada;
      });
    }

    const g = globalFilter.trim().toLowerCase();
    if (g) {
      rows = rows.filter((row) =>
        columns.some(
          (col) => col.filterable !== false && getFilterText(col, row).toLowerCase().includes(g),
        ),
      );
    }

    const activeColFilters = Object.entries(columnFilters)
      .filter(([, v]) => Array.isArray(v) && v.length > 0);
    if (activeColFilters.length) {
      rows = rows.filter((row) =>
        activeColFilters.every(([key, vals]) => {
          const col = columns.find((c) => c.key === key);
          if (!col) return true;
          return vals.includes(getFilterText(col, row));
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

    // Pin al tope: las alertas Alta + Con novedad + Activas siempre primero,
    // PERO solo en el orden por defecto. Si el usuario ordenó por una columna,
    // se respeta ese orden para TODAS las filas (sin partir en dos grupos).
    if (!sort.key || !sort.dir) {
      rows = [...rows].sort((a, b) => {
        const ap = isTopPriorityRow(a) ? 0 : 1;
        const bp = isTopPriorityRow(b) ? 0 : 1;
        return ap - bp;
      });
    }

    return rows;
  }, [dateFilteredData, globalFilter, columnFilters, sort, columns, tableTab]);

  const totalPages = Math.max(1, Math.ceil(filteredSorted.length / pageSize));
  const safePage = Math.min(currentPage, totalPages);

  const paginatedRows = useMemo(() => {
    const start = (safePage - 1) * pageSize;
    return filteredSorted.slice(start, start + pageSize);
  }, [filteredSorted, safePage, pageSize]);

  // Agrupación por categoría (modo 'agrupado'). Respeta TODOS los filtros previos
  // (parte de filteredSorted) y conserva el orden de fila dentro de cada grupo.
  // Los grupos se ordenan por cantidad de alertas (desc).
  const groupedData = useMemo(() => {
    const map = new Map();
    filteredSorted.forEach((row) => {
      const cat = row.categoria || 'Sin categoría';
      if (!map.has(cat)) map.set(cat, []);
      map.get(cat).push(row);
    });
    return Array.from(map.entries())
      .map(([categoria, rows]) => ({ categoria, rows }))
      .sort((a, b) => b.rows.length - a.rows.length);
  }, [filteredSorted]);

  const toggleGroup = (categoria) => {
    setExpandedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(categoria)) next.delete(categoria);
      else next.add(categoria);
      return next;
    });
  };

  const expandAllGroups = () => setExpandedGroups(new Set(groupedData.map((g) => g.categoria)));
  const collapseAllGroups = () => setExpandedGroups(new Set());
  const allGroupsExpanded = groupedData.length > 0 && expandedGroups.size === groupedData.length;

  useEffect(() => {
    setCurrentPage(1);
  }, [globalFilter, columnFilters, filterDateFrom, filterDateTo, pageSize, tableTab]);

  const handleDownloadTabla = async () => {
    const stamp = new Date().toISOString().slice(0, 10);
    try {
      await downloadAlertasXlsx(filteredSorted, `Alertas_${stamp}.xlsx`);
    } catch (err) {
      Swal.fire({
        title: 'No se pudo generar el Excel',
        text: err?.message
          || 'Error al descargar. Recarga la página (Ctrl+Shift+R) e intenta de nuevo.',
        icon: 'error',
      });
    }
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
    // Por cada categoría se acumula el conteo por tipo de descripción
    // (con novedad / sin novedad / reportería / error proceso) para pintar
    // barras apiladas con el color de cada descripción.
    const map = new Map();
    dateFilteredData.forEach((n) => {
      const descKey = classifyDescripcion(n.descripcion);
      if (!descKey || !catDescFilter.has(descKey)) return;
      const cat = n.categoria || 'Sin categoría';
      if (!map.has(cat)) {
        map.set(cat, { con_novedad: 0, sin_novedad: 0, reporteria: 0, error_proceso: 0 });
      }
      map.get(cat)[descKey] += 1;
    });
    return Array.from(map, ([label, counts]) => {
      const segments = DESC_KEYS
        .filter((k) => catDescFilter.has(k) && counts[k] > 0)
        .map((k) => ({ key: k, label: DESC_LABELS[k], value: counts[k], color: DESC_COLORS[k] }));
      const total = segments.reduce((s, seg) => s + seg.value, 0);
      return { label, total, segments };
    })
      .filter((item) => item.total > 0)
      .sort((a, b) => b.total - a.total);
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
    // Por cada prioridad (pendientes A/P/E): total + desglose por descripción
    // (con novedad / reportería / error proceso) para mostrarlo en la leyenda.
    const mk = () => ({ total: 0, con_novedad: 0, reporteria: 0, error_proceso: 0 });
    const byPrio = { alta: mk(), media: mk(), baja: mk() };
    dateFilteredData.forEach((n) => {
      if (!['A', 'P', 'E'].includes(n.estado)) return;
      const p = String(n.prioridad || '').trim().toLowerCase();
      const key = p === 'alta' ? 'alta' : p === 'baja' ? 'baja' : 'media';
      byPrio[key].total += 1;
      const dk = classifyDescripcion(n.descripcion);
      if (dk && byPrio[key][dk] !== undefined) byPrio[key][dk] += 1;
    });
    const mkSeg = (label, key, color) => ({
      label,
      value: byPrio[key].total,
      color,
      descCounts: {
        con_novedad: byPrio[key].con_novedad,
        reporteria: byPrio[key].reporteria,
        error_proceso: byPrio[key].error_proceso,
      },
    });
    return [
      mkSeg('Alta', 'alta', '#ef4444'),
      mkSeg('Media', 'media', '#eab308'),
      mkSeg('Baja', 'baja', '#22c55e'),
    ];
  }, [dateFilteredData]);

  const pendientesTotal = pendientesSegments.reduce((s, x) => s + x.value, 0);

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
            {isPrivileged && (
              <button
                type="button"
                role="tab"
                aria-selected={activeTab === 'dashboard'}
                className={`payroll-tab ${activeTab === 'dashboard' ? 'is-active' : ''}`}
                onClick={() => setActiveTab('dashboard')}
              >
                Dashboard
              </button>
            )}
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

          {isPrivileged && activeTab === 'dashboard' && (
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
              <span className="payroll-kpi-card__value payroll-kpi-card__value--activa">{stats.activas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">En Proceso</span>
              <span className="payroll-kpi-card__value payroll-kpi-card__value--en-proceso">{stats.enProceso}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Resueltas</span>
              <span className="payroll-kpi-card__value payroll-kpi-card__value--resuelta">{stats.resueltas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Cerradas</span>
              <span className="payroll-kpi-card__value payroll-kpi-card__value--cerrada">{stats.cerradas}</span>
            </div>
            <div className="payroll-kpi-card">
              <span className="payroll-kpi-card__label">Error</span>
              <span className="payroll-kpi-card__value payroll-kpi-card__value--error">{stats.error}</span>
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
                  showLegend={false}
                />
                <div className="payroll-pend-lines">
                  {pendientesSegments.map((seg) => (
                    <div key={seg.label} className="payroll-pend-line">
                      <span className="payroll-pend-line__prio">
                        <span className="payroll-pend-line__dot" style={{ background: seg.color }} />
                        {seg.label} <span className="payroll-pend-line__val">{seg.value}</span>
                        {pendientesTotal > 0 && (
                          <span className="payroll-pend-line__pct">
                            ({Math.round((seg.value / pendientesTotal) * 1000) / 10}%)
                          </span>
                        )}
                      </span>
                      <span className="payroll-pend-line__divider" aria-hidden="true" />
                      {['con_novedad', 'reporteria', 'error_proceso'].map((k) => (
                        <span key={k} className="payroll-pend-line__cell">
                          <span style={{ color: DESC_COLORS[k] }}>{DESC_LABELS[k]}</span>{' '}
                          <span className="payroll-pend-line__val">{seg.descCounts[k]}</span>
                        </span>
                      ))}
                    </div>
                  ))}
                </div>
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
              <h2 className="card__title">
                Alertas
                <span className="payroll-title-count" aria-live="polite">
                  {filteredSorted.length} de {data.length}
                </span>
              </h2>
            </div>
            <div className="card__body">
              <div className="payroll-subtabs" role="tablist" aria-label="Estado de las alertas">
                <button
                  type="button"
                  role="tab"
                  aria-selected={tableTab === 'pendientes'}
                  className={`payroll-subtab ${tableTab === 'pendientes' ? 'is-active' : ''}`}
                  onClick={() => setTableTab('pendientes')}
                >
                  Pendientes
                  <span className="payroll-subtab__count">
                    {stats.activas + stats.enProceso + stats.error}
                  </span>
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={tableTab === 'finalizadas'}
                  className={`payroll-subtab ${tableTab === 'finalizadas' ? 'is-active' : ''}`}
                  onClick={() => setTableTab('finalizadas')}
                >
                  Finalizadas
                  <span className="payroll-subtab__count">
                    {stats.resueltas + stats.cerradas}
                  </span>
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={tableTab === 'todas'}
                  className={`payroll-subtab ${tableTab === 'todas' ? 'is-active' : ''}`}
                  onClick={() => setTableTab('todas')}
                >
                  Total
                  <span className="payroll-subtab__count">
                    {stats.total}
                  </span>
                </button>
              </div>

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
                  className="btn btn--secondary btn--sm"
                  onClick={refreshData}
                  disabled={refreshing}
                  data-tooltip="Actualizar datos"
                  aria-label="Actualizar datos"
                >
                  <RefreshCw
                    size={16}
                    aria-hidden="true"
                    className={refreshing ? 'payroll-historial__spinner' : ''}
                  /> Actualizar
                </button>

                <button
                  type="button"
                  className="btn btn--secondary btn--sm payroll-toolbar__clear"
                  onClick={clearFilters}
                  disabled={!hasFilters}
                >
                  Limpiar filtros
                </button>

                <div className="payroll-viewmode" role="group" aria-label="Modo de vista">
                  <button
                    type="button"
                    className={`payroll-viewmode__btn${viewMode === 'lista' ? ' is-active' : ''}`}
                    onClick={() => setViewMode('lista')}
                    aria-pressed={viewMode === 'lista'}
                    data-tooltip="Vista de lista"
                  >
                    Lista
                  </button>
                  <button
                    type="button"
                    className={`payroll-viewmode__btn${viewMode === 'agrupado' ? ' is-active' : ''}`}
                    onClick={() => setViewMode('agrupado')}
                    aria-pressed={viewMode === 'agrupado'}
                    data-tooltip="Agrupar por categoría"
                  >
                    <Layers size={14} aria-hidden="true" /> Agrupado
                  </button>
                </div>

                {viewMode === 'agrupado' && (
                  <button
                    type="button"
                    className="btn btn--secondary btn--sm"
                    onClick={allGroupsExpanded ? collapseAllGroups : expandAllGroups}
                    disabled={groupedData.length === 0}
                  >
                    {allGroupsExpanded ? 'Contraer todo' : 'Expandir todo'}
                  </button>
                )}
              </div>

              <div className="table-container payroll-sticky-table" onScroll={handleTableScroll}>
                <table className="table">
                  <thead>
                    <tr className="payroll-header-row">
                      {columns.map((col) => {
                        const sortable = col.sortable !== false;
                        const filterable = col.filterable !== false;
                        const isSorted = sortable && sort.key === col.key;
                        const ariaSort = sortable
                          ? (isSorted ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none')
                          : undefined;
                        const colFilterActive = Array.isArray(columnFilters[col.key])
                          && columnFilters[col.key].length > 0;
                        return (
                          <th
                            key={col.key}
                            data-col={col.key}
                            aria-sort={ariaSort}
                            className={sortable ? 'payroll-th payroll-th--sortable' : 'payroll-th'}
                          >
                            <div className="payroll-th__inner">
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
                                <span className="payroll-th__label">{col.header}</span>
                              )}
                              {filterable && (
                                <button
                                  type="button"
                                  className={`payroll-th__filter-btn${colFilterActive ? ' is-active' : ''}`}
                                  onClick={(e) => {
                                    const rect = e.currentTarget.getBoundingClientRect();
                                    setOpenFilter((cur) =>
                                      cur && cur.key === col.key ? null : { key: col.key, rect });
                                  }}
                                  aria-label={`Filtrar ${col.header}`}
                                  aria-expanded={openFilter?.key === col.key}
                                  data-tooltip={colFilterActive ? 'Filtro activo' : 'Filtrar'}
                                >
                                  <Filter size={13} aria-hidden="true" />
                                </button>
                              )}
                              {filterable && openFilter?.key === col.key && (
                                <ColumnFilterMenu
                                  col={col}
                                  anchorRect={openFilter.rect}
                                  options={getColumnOptions(col.key)}
                                  selected={columnFilters[col.key] ?? null}
                                  sortDir={isSorted ? sort.dir : null}
                                  onApply={applyColumnFilter}
                                  onSort={applyColumnSort}
                                  onClose={() => setOpenFilter(null)}
                                />
                              )}
                            </div>
                          </th>
                        );
                      })}
                    </tr>
                  </thead>
                  {filteredSorted.length === 0 ? (
                    <tbody>
                      <tr>
                        <td colSpan={columns.length} className="text-center p-6 text-secondary">
                          {data.length === 0
                            ? 'No hay alertas'
                            : 'Sin coincidencias con los filtros actuales'}
                        </td>
                      </tr>
                    </tbody>
                  ) : viewMode === 'agrupado' ? (
                    groupedData.map((group) => {
                      const isExpanded = expandedGroups.has(group.categoria);
                      return (
                        <tbody key={group.categoria} className="payroll-group">
                          <tr className="payroll-group__header">
                            <td colSpan={columns.length}>
                              <button
                                type="button"
                                className="payroll-group__toggle"
                                onClick={() => toggleGroup(group.categoria)}
                                aria-expanded={isExpanded}
                              >
                                {/* Solo este span angosto se desplaza (transform) para simular
                                    el "pegado" horizontal; el <button> de afuera NO se transforma
                                    (queda del ancho real de la fila) para no inflar el scrollWidth
                                    del contenedor — si se transformaba el botón completo (100% del
                                    colSpan), el área de scroll crecía sin límite al desplazarse. */}
                                <span
                                  className="payroll-group__toggle-inner"
                                  style={groupHeaderShift ? { transform: `translateX(${groupHeaderShift}px)` } : undefined}
                                >
                                  {isExpanded
                                    ? <ChevronDown size={16} aria-hidden="true" />
                                    : <ChevronRight size={16} aria-hidden="true" />}
                                  <span className="payroll-group__name">{group.categoria}</span>
                                  <span className="payroll-group__count">{group.rows.length}</span>
                                </span>
                              </button>
                            </td>
                          </tr>
                          {isExpanded && group.rows.map((row) => (
                            <tr
                              key={row.idNotificacion}
                              className={isCriticalRow(row) ? 'payroll-row--critical' : ''}
                            >
                              {columns.map((col) => (
                                <td key={col.key} data-col={col.key}>
                                  {col.render
                                    ? col.render(row)
                                    : String(row[col.key] ?? '')}
                                </td>
                              ))}
                            </tr>
                          ))}
                        </tbody>
                      );
                    })
                  ) : (
                    <tbody>
                      {paginatedRows.map((row) => (
                        <tr
                          key={row.idNotificacion}
                          className={isCriticalRow(row) ? 'payroll-row--critical' : ''}
                        >
                          {columns.map((col) => (
                            <td key={col.key} data-col={col.key}>
                              {col.render
                                ? col.render(row)
                                : String(row[col.key] ?? '')}
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  )}
                </table>
              </div>

              {viewMode === 'lista' && (
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
              )}
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
          historial={historial}
          historialLoading={historialLoading}
          historialError={historialError}
          onReloadHistorial={() => loadHistorial(editingRow?.idNotificacion)}
          historialDelayedWarning={historialDelayedWarning}
          onDismissHistorialWarning={() => setHistorialDelayedWarning(false)}
        />
      )}

      <HistorialPopup
        open={historialPopup.open}
        idNotificacion={historialPopup.idNotificacion}
        items={historialPopup.items}
        loading={historialPopup.loading}
        error={historialPopup.error}
        onClose={closeHistorialPopup}
        onReload={() => loadHistorialPopup(historialPopup.idNotificacion)}
      />
    </div>
  );
};

export default AlertasPayroll;
