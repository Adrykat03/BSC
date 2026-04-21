import { useContext, useEffect, useMemo, useState } from 'react';
import { Pencil } from 'lucide-react';
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

function formatPeriodo(inicio, fin) {
  const fmt = (iso) => {
    const d = new Date(iso);
    return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`;
  };
  if (inicio && fin) return `${fmt(inicio)} - ${fmt(fin)}`;
  if (inicio) return fmt(inicio);
  if (fin) return fmt(fin);
  return '—';
}

function parseDestinatarios(raw) {
  if (!raw) return [];
  return raw
    .split(/[|;,]/)
    .map((d) => d.trim().toLowerCase())
    .filter(Boolean);
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
   Table columns definition
   ======================================== */
const baseColumns = [
  { key: 'fechaCreacion', header: 'Fecha', render: (row) => formatDate(row.fechaCreacion) },
  { key: 'estado', header: 'Estado', render: (row) => <StatusBadge status={row.estado} /> },
  { key: 'prioridad', header: 'Prioridad', render: (row) => <PriorityBadge priority={row.prioridad} /> },
  { key: 'categoria', header: 'Categoría', render: (row) => row.categoria ?? '—' },
  { key: 'origen', header: 'Origen' },
  { key: 'asunto', header: 'Asunto' },
  { key: 'descripcion', header: 'Descripción', render: (row) => truncate(row.descripcion, 80) },
  { key: 'destinatarios', header: 'Notificados', render: (row) => parseDestinatarios(row.destinatarios).join(', ') },
  { key: 'fechaModificacion', header: 'Fecha Resolución', render: (row) => formatDate(row.fechaModificacion) },
  { key: 'usuarioResolucion', header: 'Usuario Resolución', render: (row) => row.usuarioResolucion ?? '—' },
  { key: 'notasResolucion', header: 'Notas Resolución', render: (row) => truncate(row.notasResolucion, 60) },
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
    setEditEstado(row.estado === 'R' ? 'R' : 'P');
    setEditNotas(row.notasResolucion || '');
  };

  const closeEdit = () => {
    if (saving) return;
    setEditing(null);
  };

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

  const columns = [
    ...baseColumns,
    {
      key: '__actions',
      header: 'Acciones',
      render: (row) => (
        <button
          type="button"
          className="payroll-action-btn"
          onClick={() => openEdit(row)}
          title="Editar resolución"
          aria-label="Editar resolución"
        >
          <Pencil size={16} />
        </button>
      ),
    },
  ];

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
              <div className="table-responsive">
                <table className="table">
                  <thead>
                    <tr>
                      {columns.map((col) => (
                        <th key={col.key}>{col.header}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {data.length === 0 ? (
                      <tr>
                        <td colSpan={columns.length} className="text-center p-6 text-secondary">
                          No hay notificaciones
                        </td>
                      </tr>
                    ) : (
                      data.map((row) => (
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
