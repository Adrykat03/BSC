import { useState, useEffect, useCallback } from 'react';
import { Plus, Pencil, Trash2, ClipboardList, ChevronLeft, ChevronRight, Download } from 'lucide-react';
import Swal from 'sweetalert2';
import toast, { Toaster } from 'react-hot-toast';
import { tasksService } from '../../services/tasksService';
import TaskModal from './TaskModal';

const PAGE_SIZE = 20;

const STATUS_BADGE_MAP = {
  'Creada': 'badge badge--draft',
  'En Progreso': 'badge badge--editing',
  'Completada': 'badge badge--published',
  'Cancelada': 'badge badge--inactive',
};

const getBadgeClass = (status) => {
  return STATUS_BADGE_MAP[status] || 'badge badge--draft';
};

const Tasks = () => {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [totalCount, setTotalCount] = useState(0);

  const loadTasks = useCallback(async (currentPage = 1) => {
    try {
      setLoading(true);
      setError(null);
      const data = await tasksService.getAll(currentPage, PAGE_SIZE);
      setTasks(data.items ?? []);
      setTotalPages(data.totalPages);
      setTotalCount(data.totalCount);
      setPage(data.page);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

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
    for (let i = start; i <= end; i++) {
      pages.push(i);
    }
    return pages;
  };

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

  const handleDownloadEvidence = async (task) => {
    try {
      await tasksService.downloadEvidence(task.id);
    } catch (err) {
      toast.error(`Error al descargar evidencia: ${err.message}`);
    }
  };

  const formatTime = (hours) => {
    if (hours === null || hours === undefined || hours === '') return '-';
    return `${hours}h`;
  };

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
          <p className="page-header__subtitle">Gestion de tareas del sistema</p>
        </div>
        <button className="btn btn--primary" onClick={openCreateModal}>
          <Plus size={18} />
          Nueva Tarea
        </button>
      </div>

      <div className="card">
        <div className="card__body">
          {tasks.length === 0 && !loading ? (
            <div className="empty-state">
              <ClipboardList size={48} className="empty-state__icon" />
              <h3 className="empty-state__title">No hay tareas</h3>
              <p className="empty-state__description">
                Aun no se han creado tareas. Crea la primera haciendo clic en "Nueva Tarea".
              </p>
            </div>
          ) : (
            <>
              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Titulo</th>
                      <th>Persona asignada</th>
                      <th>Estado</th>
                      <th>Tiempo estimado</th>
                      <th>Tiempo real</th>
                      <th>Evidencia</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tasks.map((task) => (
                      <tr key={task.id}>
                        <td className="font-semibold">{task.title}</td>
                        <td className="text-secondary">
                          {task.assignedTo || 'Sin asignar'}
                        </td>
                        <td>
                          <span className={getBadgeClass(task.status)}>
                            {task.status}
                          </span>
                        </td>
                        <td>{formatTime(task.estimatedTime)}</td>
                        <td>{formatTime(task.actualTime)}</td>
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
                          <div className="table__actions">
                            <button
                              className="btn btn--icon btn--sm btn--ghost"
                              onClick={() => openEditModal(task)}
                              title="Editar"
                            >
                              <Pencil size={16} />
                            </button>
                            <button
                              className="btn btn--icon btn--sm btn--ghost text-error"
                              onClick={() => handleDelete(task)}
                              title="Eliminar"
                            >
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
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

      <TaskModal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSubmit}
        task={selectedTask}
        loading={saving}
      />
    </div>
  );
};

export default Tasks;
