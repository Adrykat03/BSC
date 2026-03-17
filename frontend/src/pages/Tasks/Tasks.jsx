import { useState, useEffect, useCallback, useContext } from 'react';
import {
  Plus, Pencil, Trash2, ClipboardList, ChevronLeft, ChevronRight,
  Download, Upload, UserPlus, RefreshCw, FileText,
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
        await tasksService.update(selectedTask.id, formData);
        toast.success('Tarea actualizada exitosamente');
      } else {
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

  // ---- Delete (Gerente only) ----
  const handleDelete = async (task) => {
    const result = await Swal.fire({
      title: 'Eliminar tarea',
      text: `¿Esta seguro de eliminar la tarea "${task.title}"? Esta accion no se puede deshacer.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, eliminar',
      cancelButtonText: 'Cancelar',
    });
    if (!result.isConfirmed) return;

    try {
      await tasksService.delete(task.id);
      toast.success('Tarea eliminada exitosamente');
      const newPage = tasks.length === 1 && page > 1 ? page - 1 : page;
      await loadTasks(newPage);
    } catch (err) {
      toast.error(`Error al eliminar la tarea: ${err.message}`);
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
        targetRole = task.leaderName ? 'Colaborador' : 'Lider';
      } else if (isLider) {
        targetRole = 'Colaborador';
      }
      const filtered = targetRole
        ? data.filter((c) => c.rolName === targetRole)
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

  // ---- Downloads ----
  const handleDownloadEvidence = async (task) => {
    try {
      await tasksService.downloadEvidence(task.id);
    } catch (err) {
      toast.error(`Error al descargar evidencia: ${err.message}`);
    }
  };

  const handleDownloadInsumo = async (task) => {
    try {
      await tasksService.downloadInsumo(task.id);
    } catch (err) {
      toast.error(`Error al descargar insumo: ${err.message}`);
    }
  };

  const formatTime = (hours) => {
    if (hours === null || hours === undefined || hours === '') return '-';
    return `${hours}h`;
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

      <div className="card">
        <div className="card__body">
          {tasks.length === 0 && !loading ? (
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
                      <th>Asignado a</th>
                      <th>Lider</th>
                      <th>Estado</th>
                      <th>Tiempo estimado</th>
                      <th>Evidencia</th>
                      <th>Insumos</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tasks.map((task) => {
                      const transitions = getStatusTransitions(task.status, role);
                      return (
                        <tr key={task.id}>
                          <td className="font-semibold">{task.title}</td>
                          <td className="text-secondary">
                            {task.assignedTo || 'Sin asignar'}
                          </td>
                          <td className="text-secondary">
                            {task.leaderName || '-'}
                          </td>
                          <td>
                            <span className={getBadgeClass(task.status)}>
                              {task.status}
                            </span>
                          </td>
                          <td>{formatTime(task.estimatedTime)}</td>
                          <td>
                            {task.evidenceFileName ? (
                              <button
                                className="btn btn--icon btn--sm btn--ghost"
                                onClick={() => handleDownloadEvidence(task)}
                                title={`Descargar ${task.evidenceFileName}`}
                              >
                                <Download size={16} />
                              </button>
                            ) : (
                              <span className="text-secondary">-</span>
                            )}
                          </td>
                          <td>
                            {task.insumoFileName ? (
                              <button
                                className="btn btn--icon btn--sm btn--ghost"
                                onClick={() => handleDownloadInsumo(task)}
                                title={`Descargar ${task.insumoFileName}`}
                              >
                                <Download size={16} />
                              </button>
                            ) : (
                              <span className="text-secondary">-</span>
                            )}
                          </td>
                          <td>
                            <div className="table__actions">
                              {/* Assign button — Gerente and Lider */}
                              {(isGerente || isLider) && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={() => openAssignModal(task)}
                                  title="Asignar"
                                >
                                  <UserPlus size={16} />
                                </button>
                              )}

                              {/* Edit button — Gerente (full) or Lider (limited) */}
                              {(isGerente || isLider) && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={() => openEditModal(task)}
                                  title="Editar"
                                >
                                  <Pencil size={16} />
                                </button>
                              )}

                              {/* Upload evidence — Colaborador */}
                              {isColaborador && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={() => openEvidenceModal(task)}
                                  title="Subir evidencia"
                                >
                                  <Upload size={16} />
                                </button>
                              )}

                              {/* Status transitions */}
                              {transitions.map((newStatus) => (
                                <button
                                  key={newStatus}
                                  className="btn btn--sm btn--outline-primary"
                                  onClick={() => handleChangeStatus(task, newStatus)}
                                  title={`Cambiar a ${newStatus}`}
                                >
                                  <RefreshCw size={14} />
                                  {newStatus.length > 16
                                    ? newStatus.substring(0, 16) + '...'
                                    : newStatus}
                                </button>
                              ))}

                              {/* Delete — Gerente only */}
                              {isGerente && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost text-error"
                                  onClick={() => handleDelete(task)}
                                  title="Eliminar"
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

      {/* Create / Edit modal — Gerente creates, Lider edits */}
      <TaskModal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSubmit}
        task={selectedTask}
        loading={saving}
        userRole={role}
      />

      {/* Assign modal */}
      {assignModalOpen && (
        <>
          <div
            className="modal-backdrop modal-backdrop--open"
            onClick={() => setAssignModalOpen(false)}
          />
          <div className="modal modal--open">
            <div className="modal__header">
              <h3 className="modal__title">Asignar tarea</h3>
              <button
                className="modal__close"
                onClick={() => setAssignModalOpen(false)}
                type="button"
              >
                &times;
              </button>
            </div>
            <div className="modal__body">
              <p className="text-sm mb-4">
                Tarea: <strong>{assignTask?.title}</strong>
              </p>
              {loadingColaboradores ? (
                <div className="text-center p-6">Cargando colaboradores...</div>
              ) : colaboradores.length === 0 ? (
                <div className="alert alert--warning">
                  <div className="alert__content">
                    <div className="alert__message">
                      No hay colaboradores disponibles con el rol requerido.
                    </div>
                  </div>
                </div>
              ) : (
                <div className="form-group mb-4">
                  <label className="form-label">Colaborador</label>
                  <select
                    className="form-control form-select"
                    value={selectedColaborador}
                    onChange={(e) => setSelectedColaborador(e.target.value)}
                  >
                    <option value="">Seleccione...</option>
                    {colaboradores.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.nombreCompleto} — {c.rolName}
                      </option>
                    ))}
                  </select>
                </div>
              )}
            </div>
            <div className="modal__footer">
              <button
                className="btn btn--secondary"
                onClick={() => setAssignModalOpen(false)}
              >
                Cancelar
              </button>
              <button
                className="btn btn--primary"
                disabled={!selectedColaborador}
                onClick={handleAssign}
              >
                <UserPlus size={16} />
                Asignar
              </button>
            </div>
          </div>
        </>
      )}

      {/* Evidence upload modal — Colaborador */}
      {evidenceModalOpen && (
        <>
          <div
            className="modal-backdrop modal-backdrop--open"
            onClick={() => setEvidenceModalOpen(false)}
          />
          <div className="modal modal--open">
            <div className="modal__header">
              <h3 className="modal__title">Subir evidencia</h3>
              <button
                className="modal__close"
                onClick={() => setEvidenceModalOpen(false)}
                type="button"
              >
                &times;
              </button>
            </div>
            <div className="modal__body">
              <p className="text-sm mb-4">
                Tarea: <strong>{evidenceTask?.title}</strong>
              </p>
              <div className="form-group">
                <div style={{ paddingTop: '24px' }}>
                  <label
                    className="upload-zone"
                    style={{ padding: 'var(--spacing-4)', cursor: 'pointer' }}
                  >
                    <input
                      type="file"
                      accept=".pdf,.jpg,.jpeg,.png,.doc,.docx,.xls,.xlsx"
                      onChange={(e) => setEvidenceFile(e.target.files[0] || null)}
                      style={{ display: 'none' }}
                    />
                    <Upload
                      size={24}
                      className="upload-zone__icon"
                      style={{ marginBottom: '0' }}
                    />
                    <span className="upload-zone__text">
                      {evidenceFile
                        ? evidenceFile.name
                        : 'Clic para seleccionar archivo'}
                    </span>
                    <span className="upload-zone__hint">
                      PDF, JPG, PNG, DOC, DOCX, XLS, XLSX (max 10MB)
                    </span>
                  </label>
                </div>
              </div>
            </div>
            <div className="modal__footer">
              <button
                className="btn btn--secondary"
                onClick={() => setEvidenceModalOpen(false)}
              >
                Cancelar
              </button>
              <button
                className="btn btn--primary"
                disabled={!evidenceFile}
                onClick={handleUploadEvidence}
              >
                <Upload size={16} />
                Subir
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default Tasks;
