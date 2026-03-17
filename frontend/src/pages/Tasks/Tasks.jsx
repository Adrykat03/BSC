import { useState, useEffect, useCallback, useContext } from 'react';
import {
  Plus, Pencil, Trash2, ClipboardList, ChevronLeft, ChevronRight,
  Eye, Search, History,
} from 'lucide-react';
import Swal from 'sweetalert2';
import toast, { Toaster } from 'react-hot-toast';
import { tasksService } from '../../services/tasksService';
import { colaboradorService } from '../../services/colaboradorService';
import SessionContext from '../../context/SessionContext';
import TaskModal from './TaskModal';

const PAGE_SIZE = 20;

const STATUS_BADGE_MAP = {
  'Creada': 'badge badge--inactive',
  'Asignada': 'badge badge--draft',
  'Completa - Por Validar': 'badge badge--editing',
  'Reasignada': 'badge badge--blocked',
  'Completa - Validada': 'badge badge--active',
  'Completa': 'badge badge--published',
  'Cancelada': 'badge badge--error',
};

const getBadgeClass = (status) => STATUS_BADGE_MAP[status] || 'badge badge--inactive';

/** Returns valid next statuses based on current status and role */
const getStatusTransitions = (currentStatus, role) => {
  if (role === 'Gerente') {
    if (currentStatus === 'Completa - Validada') return ['Completa', 'Reasignada'];
  }
  if (role === 'Lider') {
    if (currentStatus === 'Completa - Por Validar') return ['Completa - Validada', 'Reasignada'];
  }
  if (role === 'Colaborador') {
    if (currentStatus === 'Asignada') return ['Completa - Por Validar'];
    if (currentStatus === 'Reasignada') return ['Completa - Por Validar'];
  }
  return [];
};

const Tasks = () => {
  const { user } = useContext(SessionContext);
  const role = user?.role || '';
  const email = user?.email || '';

  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [totalCount, setTotalCount] = useState(0);

  // Assign modal state
  const [assignModalOpen, setAssignModalOpen] = useState(false);
  const [assignTask, setAssignTask] = useState(null);
  const [colaboradores, setColaboradores] = useState([]);
  const [selectedColaborador, setSelectedColaborador] = useState('');
  const [loadingColaboradores, setLoadingColaboradores] = useState(false);

  // Evidence upload modal
  const [evidenceModalOpen, setEvidenceModalOpen] = useState(false);
  const [evidenceTask, setEvidenceTask] = useState(null);
  const [evidenceFile, setEvidenceFile] = useState(null);

  // Detail view modal (Colaborador)
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [detailTask, setDetailTask] = useState(null);

  // Row selection (visual only)
  const [selectedRowId, setSelectedRowId] = useState(null);

  // History modal
  const [historyModalOpen, setHistoryModalOpen] = useState(false);
  const [historyTask, setHistoryTask] = useState(null);

  // Filters
  const [searchText, setSearchText] = useState('');
  const [filterStatus, setFilterStatus] = useState(''); // '' = todas
  const [filterDate, setFilterDate] = useState(''); // '' = todas, 'hoy', 'ayer', 'semana'

  // Close inline modals with Escape
  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        if (historyModalOpen) { setHistoryModalOpen(false); setHistoryTask(null); }
      }
    };
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [historyModalOpen]);

  const isGerente = role === 'Gerente';
  const isLider = role === 'Lider';
  const isColaborador = role === 'Colaborador';

  const loadTasks = useCallback(async (currentPage = 1) => {
    try {
      setLoading(true);
      setError(null);
      const data = await tasksService.getAll(currentPage, PAGE_SIZE, email, role);
      setTasks(data.items ?? []);
      setTotalPages(data.totalPages);
      setTotalCount(data.totalCount);
      setPage(data.page);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [email, role]);

  useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  const goToPage = (newPage) => {
    if (newPage >= 1 && newPage <= totalPages) {
      loadTasks(newPage);
    }
  };

  const getPageNumbers = () => {
    const pages = [];
    const maxVisible = 5;
    let start = Math.max(1, page - Math.floor(maxVisible / 2));
    let end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) {
      start = Math.max(1, end - maxVisible + 1);
    }
    for (let i = start; i <= end; i++) pages.push(i);
    return pages;
  };

  // ---- Create / Edit (Gerente creates, Lider edits) ----
  const openCreateModal = () => {
    setSelectedTask(null);
    setModalOpen(true);
  };

  const openEditModal = (task) => {
    setSelectedTask(task);
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedTask(null);
  };

  const handleSubmit = async (formData) => {
    const isEditing = Boolean(selectedTask);

    if (isEditing) {
      const result = await Swal.fire({
        title: 'Confirmar actualizacion',
        text: `Se actualizara la tarea "${selectedTask.title}". ¿Desea continuar?`,
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#E31837',
        cancelButtonColor: '#6B7280',
        confirmButtonText: 'Si, actualizar',
        cancelButtonText: 'Cancelar',
      });
      if (!result.isConfirmed) return;
    }

    try {
      setSaving(true);
      if (isEditing) {
        formData.append('updatedByEmail', email);
        await tasksService.update(selectedTask.id, formData);
        toast.success('Tarea actualizada exitosamente');
      } else {
        formData.append('createdByEmail', email);
        await tasksService.create(formData);
        toast.success('Tarea creada exitosamente');
      }
      closeModal();
      await loadTasks(isEditing ? page : 1);
    } catch (err) {
      toast.error(`Error al ${isEditing ? 'actualizar' : 'crear'} la tarea: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  // ---- Delete or Cancel (Gerente only) ----
  const handleDelete = async (task) => {
    const isCreada = task.status === 'Creada';
    const title = isCreada ? 'Eliminar tarea' : 'Cancelar tarea';
    const text = isCreada
      ? `¿Esta seguro de eliminar la tarea "${task.title}"? Esta accion no se puede deshacer.`
      : `¿Esta seguro de cancelar la tarea "${task.title}"? Pasara a estado Cancelada.`;
    const confirmText = isCreada ? 'Si, eliminar' : 'Si, cancelar';

    const result = await Swal.fire({
      title,
      text,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#6B7280',
      confirmButtonText: confirmText,
      cancelButtonText: 'Volver',
    });
    if (!result.isConfirmed) return;

    try {
      if (isCreada) {
        await tasksService.delete(task.id);
        toast.success('Tarea eliminada exitosamente');
      } else {
        await tasksService.changeStatus(task.id, {
          newStatus: 'Cancelada',
          changedByEmail: email,
          changedByRole: role,
          comment: 'Tarea cancelada por el Gerente',
        });
        toast.success('Tarea cancelada exitosamente');
      }
      const newPage = tasks.length === 1 && page > 1 ? page - 1 : page;
      await loadTasks(newPage);
    } catch (err) {
      toast.error(`Error: ${err.message}`);
    }
  };

  // ---- Change Status ----
  const handleChangeStatus = async (task, newStatus) => {
    const result = await Swal.fire({
      title: 'Cambiar estado',
      text: `¿Cambiar estado de "${task.title}" a "${newStatus}"?`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#E31837',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, cambiar',
      cancelButtonText: 'Cancelar',
    });
    if (!result.isConfirmed) return;

    try {
      await tasksService.changeStatus(task.id, {
        newStatus,
        changedByEmail: email,
        changedByRole: role,
        comment: '',
      });
      toast.success(`Estado cambiado a "${newStatus}"`);
      await loadTasks(page);
    } catch (err) {
      toast.error(`Error al cambiar estado: ${err.message}`);
    }
  };

  // ---- Assign ----
  const openAssignModal = async (task) => {
    setAssignTask(task);
    setSelectedColaborador('');
    setAssignModalOpen(true);
    try {
      setLoadingColaboradores(true);
      const data = await colaboradorService.getAll();
      // Gerente assigns to Lider first, then Lider to Colaborador
      let targetRole = '';
      if (isGerente) {
        targetRole = task.assignedLeaderName ? 'Colaborador' : 'Lider';
      } else if (isLider) {
        targetRole = 'Colaborador';
      }
      const filtered = targetRole
        ? data.filter((c) => {
            const names = c.rolNames || (c.rolName ? [c.rolName] : []);
            return names.includes(targetRole);
          })
        : data;
      setColaboradores(filtered);
    } catch (err) {
      toast.error(`Error al cargar colaboradores: ${err.message}`);
      setColaboradores([]);
    } finally {
      setLoadingColaboradores(false);
    }
  };

  const handleAssign = async () => {
    if (!selectedColaborador || !assignTask) return;
    try {
      await tasksService.assignTask(assignTask.id, {
        assigneeId: selectedColaborador,
        assignerEmail: email,
        assignerRole: role,
      });
      toast.success('Tarea asignada exitosamente');
      setAssignModalOpen(false);
      setAssignTask(null);
      await loadTasks(page);
    } catch (err) {
      toast.error(`Error al asignar tarea: ${err.message}`);
    }
  };

  // ---- Evidence Upload (Colaborador) ----
  const openEvidenceModal = (task) => {
    setEvidenceTask(task);
    setEvidenceFile(null);
    setEvidenceModalOpen(true);
  };

  const handleUploadEvidence = async () => {
    if (!evidenceFile || !evidenceTask) return;
    try {
      await tasksService.uploadEvidence(evidenceTask.id, evidenceFile, email);
      toast.success('Evidencia subida exitosamente');
      setEvidenceModalOpen(false);
      setEvidenceTask(null);
      setEvidenceFile(null);
      await loadTasks(page);
    } catch (err) {
      toast.error(`Error al subir evidencia: ${err.message}`);
    }
  };

  // Downloads are now handled inside the TaskModal via tasksService.downloadFile

  const formatTime = (hours) => {
    if (hours === null || hours === undefined || hours === '') return '-';
    return `${hours}h`;
  };

  /**
   * Urgency based on dueDate and estimatedTime.
   * - timeToDeadline: ms until dueDate
   * - estimatedMs: estimatedTime in ms
   * - level: 'normal' (timeToDeadline > 2x estimated), 'warning' (1x-2x estimated), 'danger' (<= estimated)
   */
  const getUrgency = (task) => {
    if (!task.dueDate) return { level: 'normal', dueDate: null };
    if (['Completa', 'Completa - Validada'].includes(task.status)) return { level: 'normal', dueDate: task.dueDate };
    const deadline = new Date(task.dueDate).getTime();
    const now = Date.now();
    const timeToDeadline = deadline - now;
    const estimatedMs = (task.estimatedTime || 0) * 60 * 60 * 1000;
    let level = 'normal';
    if (estimatedMs > 0) {
      if (timeToDeadline <= estimatedMs) level = 'danger';
      else if (timeToDeadline <= estimatedMs * 2) level = 'warning';
    } else {
      // No estimated time — just check if overdue
      if (timeToDeadline <= 0) level = 'danger';
    }
    return { level, dueDate: task.dueDate };
  };

  const getRowBgColor = (level) => {
    if (level === 'danger') return 'rgba(239,68,68,0.08)';
    if (level === 'warning') return 'rgba(245,158,11,0.08)';
    return undefined;
  };

  const formatDueDate = (dueDate) => {
    if (!dueDate) return '-';
    const d = new Date(dueDate);
    return d.toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' }) +
      ' ' + d.toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' });
  };

  // ---- Render ----

  if (loading && tasks.length === 0) {
    return <div className="text-center p-6">Cargando...</div>;
  }

  if (error) {
    return (
      <div>
        <div className="alert alert--error mb-4">
          <div className="alert__content">
            <div className="alert__title">Error de conexion</div>
            <div className="alert__message">
              No se pudieron cargar las tareas: {error}
            </div>
          </div>
        </div>
        <button className="btn btn--primary" onClick={() => loadTasks(page)}>
          Reintentar
        </button>
      </div>
    );
  }

  // ---- Filter logic (client-side on loaded data) ----
  const VISIBLE_STATUSES = (() => {
    if (isGerente) return ['Creada', 'Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada', 'Completa', 'Cancelada'];
    if (isLider) return ['Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada'];
    if (isColaborador) return ['Asignada', 'Completa - Por Validar', 'Reasignada'];
    return [];
  })();
  const DATE_OPTIONS = [
    { value: '', label: 'Todas' },
    { value: 'hoy', label: 'Hoy' },
    { value: 'ayer', label: 'Ayer' },
    { value: 'semana', label: 'Esta semana' },
  ];

  const matchesDate = (task) => {
    if (!filterDate) return true;
    const created = new Date(task.createdAt);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1);
    const weekStart = new Date(today); weekStart.setDate(weekStart.getDate() - today.getDay());
    if (filterDate === 'hoy') return created >= today;
    if (filterDate === 'ayer') return created >= yesterday && created < today;
    if (filterDate === 'semana') return created >= weekStart;
    return true;
  };

  const filteredTasks = tasks.filter((task) => {
    if (filterStatus && task.status !== filterStatus) return false;
    if (!matchesDate(task)) return false;
    if (searchText.trim()) {
      const q = searchText.toLowerCase();
      const matchTitle = (task.title || '').toLowerCase().includes(q);
      const matchAssigned = (task.assignedToName || '').toLowerCase().includes(q);
      const matchLeader = (task.assignedLeaderName || '').toLowerCase().includes(q);
      const matchDesc = (task.description || '').toLowerCase().includes(q);
      if (!matchTitle && !matchAssigned && !matchLeader && !matchDesc) return false;
    }
    return true;
  });

  const startItem = (page - 1) * PAGE_SIZE + 1;
  const endItem = Math.min(page * PAGE_SIZE, totalCount);

  return (
    <div>
      <Toaster position="top-right" />

      <div className="page-header">
        <div>
          <h1 className="page-header__title">Tareas</h1>
          <p className="page-header__subtitle">
            Gestion de tareas del sistema — Rol: {role}
          </p>
        </div>
        {isGerente && (
          <button className="btn btn--primary" onClick={openCreateModal}>
            <Plus size={18} />
            Nueva Tarea
          </button>
        )}
      </div>

      {/* ── Toolbar: Search + Filters in one row ── */}
      <div style={{ marginBottom: '16px', display: 'flex', gap: '12px', alignItems: 'center' }}>
        <div className="header__search" style={{ flex: 1 }}>
          <input
            type="text"
            className="header__search-input"
            placeholder="Buscar.."
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
            style={{ width: '100%' }}
          />
          <Search size={18} className="header__search-icon" />
        </div>

        <select
          className="form-control form-select"
          value={filterStatus}
          onChange={(e) => { setFilterStatus(e.target.value); setSearchText(''); }}
          style={{ width: '220px', height: '36px', padding: '0 32px 0 12px', fontSize: '13px' }}
        >
          <option value="">Estado: Todas</option>
          {VISIBLE_STATUSES.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>

        <select
          className="form-control form-select"
          value={filterDate}
          onChange={(e) => setFilterDate(e.target.value)}
          style={{ width: '180px', height: '36px', padding: '0 32px 0 12px', fontSize: '13px' }}
        >
          {DATE_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>Fecha: {opt.label}</option>
          ))}
        </select>
      </div>

      <div className="card">
        <div className="card__body">
          {filteredTasks.length === 0 && !loading ? (
            <div className="empty-state">
              <ClipboardList size={48} className="empty-state__icon" />
              <h3 className="empty-state__title">No hay tareas</h3>
              <p className="empty-state__description">
                {isGerente
                  ? 'Aun no se han creado tareas. Crea la primera haciendo clic en "Nueva Tarea".'
                  : 'No tienes tareas asignadas por el momento.'}
              </p>
            </div>
          ) : (
            <>
              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Titulo</th>
                      {(isGerente || isLider) && <th>Asignado a</th>}
                      <th>Lider</th>
                      <th>Estado</th>
                      <th>Entrega</th>
                      <th data-tooltip="Tiempo estimado (horas)">&#128339;</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[...filteredTasks]
                      .map((t) => ({ ...t, _urgency: getUrgency(t) }))
                      .sort((a, b) => {
                        const aDate = a.dueDate ? new Date(a.dueDate).getTime() : Infinity;
                        const bDate = b.dueDate ? new Date(b.dueDate).getTime() : Infinity;
                        return aDate - bDate;
                      })
                      .map((task) => {
                      const transitions = getStatusTransitions(task.status, role);
                      const isSelected = selectedRowId === task.id;
                      const urgencyBg = getRowBgColor(task._urgency.level);
                      return (
                        <tr
                          key={task.id}
                          onClick={() => setSelectedRowId(isSelected ? null : task.id)}
                          style={{
                            cursor: 'pointer',
                            backgroundColor: urgencyBg,
                            outline: isSelected ? '3px solid #166534' : 'none',
                            outlineOffset: '-3px',
                            transition: 'outline 150ms',
                          }}
                        >
                          <td className="font-semibold">{task.title}</td>
                          {(isGerente || isLider) && (
                            <td className="text-secondary">
                              {task.assignedToName || 'Sin asignar'}
                            </td>
                          )}
                          <td className="text-secondary">
                            {task.assignedLeaderName || '-'}
                          </td>
                          <td>
                            <span className={getBadgeClass(task.status)}>
                              {task.status}
                            </span>
                          </td>
                          <td className="text-secondary" style={{ fontSize: '12px', whiteSpace: 'nowrap' }}>
                            {formatDueDate(task.dueDate)}
                          </td>
                          <td>{formatTime(task.estimatedTime)}</td>
                          <td>
                            <div className="table__actions">
                              {/* Edit button — Gerente (full) or Lider (limited) */}
                              {(isGerente || isLider) && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={(e) => { e.stopPropagation(); openEditModal(task); }}
                                  data-tooltip="Editar"
                                >
                                  <Pencil size={16} />
                                </button>
                              )}

                              {/* View detail — Colaborador */}
                              {isColaborador && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={(e) => { e.stopPropagation(); setDetailTask(task); setDetailModalOpen(true); }}
                                  data-tooltip="Ver detalle"
                                >
                                  <Eye size={16} />
                                </button>
                              )}

                              {/* History */}
                              <button
                                className="btn btn--icon btn--sm btn--ghost"
                                onClick={(e) => { e.stopPropagation(); setHistoryTask(task); setHistoryModalOpen(true); }}
                                data-tooltip="Historial"
                              >
                                <History size={16} />
                              </button>

                              {/* Delete — Gerente only */}
                              {isGerente && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost text-error"
                                  onClick={(e) => { e.stopPropagation(); handleDelete(task); }}
                                  data-tooltip="Eliminar"
                                >
                                  <Trash2 size={16} />
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              {totalPages > 0 && (
                <div className="pagination">
                  <div className="pagination__info">
                    Mostrando {startItem}-{endItem} de {totalCount} tareas
                  </div>
                  <div className="pagination__pages">
                    <button
                      className="pagination__btn"
                      onClick={() => goToPage(page - 1)}
                      disabled={page <= 1}
                    >
                      <ChevronLeft size={16} />
                    </button>
                    {getPageNumbers().map((p) => (
                      <button
                        key={p}
                        className={`pagination__btn${p === page ? ' pagination__btn--active' : ''}`}
                        onClick={() => goToPage(p)}
                      >
                        {p}
                      </button>
                    ))}
                    <button
                      className="pagination__btn"
                      onClick={() => goToPage(page + 1)}
                      disabled={page >= totalPages}
                    >
                      <ChevronRight size={16} />
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {/* Create / Edit / Detail modal */}
      <TaskModal
        isOpen={modalOpen || detailModalOpen}
        onClose={() => { closeModal(); setDetailModalOpen(false); setDetailTask(null); }}
        onSubmit={handleSubmit}
        onUploadEvidence={async (taskId, file, text) => {
          try {
            await tasksService.uploadEvidence(taskId, file, email, text);
            toast.success('Evidencia guardada exitosamente');
            setDetailModalOpen(false);
            setDetailTask(null);
            setModalOpen(false);
            await loadTasks(page);
          } catch (err) {
            toast.error(`Error al guardar evidencia: ${err.message}`);
          }
        }}
        onChangeStatus={async (t, newStatus) => {
          await handleChangeStatus(t, newStatus);
          setDetailModalOpen(false);
          setDetailTask(null);
          setModalOpen(false);
        }}
        onAssign={async (t, assigneeId) => {
          try {
            await tasksService.assignTask(t.id, {
              assigneeId,
              assignerEmail: email,
              assignerRole: role,
            });
            toast.success('Tarea asignada exitosamente');
            await loadTasks(page);
          } catch (err) {
            toast.error(`Error al asignar: ${err.message}`);
          }
        }}
        task={detailModalOpen ? detailTask : selectedTask}
        loading={saving}
        userRole={role}
        userEmail={email}
      />


      {/* ── History modal ── */}
      {historyModalOpen && historyTask && (
        <>
          <div className="modal-backdrop modal-backdrop--open" />
          <div className="modal modal--open" style={{ maxWidth: '650px' }}>
            <div className="modal__header">
              <h3 className="modal__title">Historial — {historyTask.title}</h3>
              <button
                className="modal__close"
                onClick={() => { setHistoryModalOpen(false); setHistoryTask(null); }}
                type="button"
              >
                &times;
              </button>
            </div>
            <div className="modal__body" style={{ overflowY: 'auto', maxHeight: '60vh' }}>
              {/* Current state */}
              <div style={{ marginBottom: '16px', padding: '12px', backgroundColor: 'rgba(34,197,94,0.08)', borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-success)' }}>
                <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Estado actual</span>
                <div style={{ marginTop: '4px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span className={getBadgeClass(historyTask.status)}>{historyTask.status}</span>
                  {historyTask.assignedLeaderName && <span style={{ fontSize: '13px' }}>Lider: <strong>{historyTask.assignedLeaderName}</strong></span>}
                  {historyTask.assignedToName && <span style={{ fontSize: '13px' }}>Colaborador: <strong>{historyTask.assignedToName}</strong></span>}
                </div>
              </div>

              {/* Timeline */}
              {historyTask.statusHistory && historyTask.statusHistory.length > 0 ? (
                <div>
                  <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: '12px' }}>Historial de cambios</span>
                  {[...historyTask.statusHistory].reverse().map((entry, idx) => {
                    const isLast = idx === 0;
                    const date = new Date(entry.changedAt);
                    const dateStr = date.toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' });
                    const timeStr = date.toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' });
                    return (
                      <div
                        key={idx}
                        style={{
                          display: 'flex',
                          gap: '12px',
                          padding: '10px 0',
                          borderBottom: '1px solid var(--color-border-light)',
                          opacity: isLast ? 1 : 0.7,
                        }}
                      >
                        {/* Timeline dot */}
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '20px', flexShrink: 0 }}>
                          <div style={{
                            width: '10px', height: '10px', borderRadius: '50%',
                            backgroundColor: isLast ? 'var(--color-success)' : 'var(--color-border-main)',
                            marginTop: '4px',
                          }} />
                          {idx < historyTask.statusHistory.length - 1 && (
                            <div style={{ width: '2px', flex: 1, backgroundColor: 'var(--color-border-light)', marginTop: '4px' }} />
                          )}
                        </div>
                        {/* Content */}
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '2px' }}>
                            <span className={getBadgeClass(entry.fromStatus)} style={{ fontSize: '10px' }}>{entry.fromStatus}</span>
                            <span style={{ fontSize: '12px', color: '#6B7280' }}>→</span>
                            <span className={getBadgeClass(entry.toStatus)} style={{ fontSize: '10px' }}>{entry.toStatus}</span>
                          </div>
                          <div style={{ fontSize: '12px', color: '#6B7280' }}>
                            <strong>{entry.changedByName}</strong> — {dateStr} {timeStr}
                          </div>
                          {entry.comment && (
                            <div style={{ fontSize: '12px', color: '#9CA3AF', fontStyle: 'italic', marginTop: '2px' }}>
                              {entry.comment}
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div style={{ textAlign: 'center', color: '#9CA3AF', padding: '24px 0' }}>
                  No hay cambios de estado registrados
                </div>
              )}

              {/* Creation info */}
              <div style={{ marginTop: '16px', padding: '10px 0', borderTop: '1px solid var(--color-border-light)', fontSize: '12px', color: '#6B7280' }}>
                Creada: {new Date(historyTask.createdAt).toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' })} {new Date(historyTask.createdAt).toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' })}
              </div>
            </div>
            <div className="modal__footer">
              <button className="btn btn--secondary" onClick={() => { setHistoryModalOpen(false); setHistoryTask(null); }}>
                Cerrar
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default Tasks;
