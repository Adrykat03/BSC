import { useState, useEffect, useCallback } from 'react';
import { Plus, Pencil, Trash2, Users, ChevronLeft, ChevronRight } from 'lucide-react';
import Swal from 'sweetalert2';
import toast, { Toaster } from 'react-hot-toast';
import { colaboradorService } from '../../services/colaboradorService';
import ColaboradorModal from './ColaboradorModal';

const PAGE_SIZE = 10;

const Colaboradores = () => {
  const [allColaboradores, setAllColaboradores] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedColaborador, setSelectedColaborador] = useState(null);
  const [page, setPage] = useState(1);

  const totalCount = allColaboradores.length;
  const totalPages = Math.ceil(totalCount / PAGE_SIZE);

  const colaboradores = allColaboradores.slice(
    (page - 1) * PAGE_SIZE,
    page * PAGE_SIZE
  );

  const loadColaboradores = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await colaboradorService.getAll();
      setAllColaboradores(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadColaboradores();
  }, [loadColaboradores]);

  const goToPage = (newPage) => {
    if (newPage >= 1 && newPage <= totalPages) {
      setPage(newPage);
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
    setSelectedColaborador(null);
    setModalOpen(true);
  };

  const openEditModal = (colaborador) => {
    setSelectedColaborador(colaborador);
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedColaborador(null);
  };

  const handleSubmit = async (formData) => {
    const isEditing = Boolean(selectedColaborador);

    if (isEditing) {
      const result = await Swal.fire({
        title: 'Confirmar actualizacion',
        text: `Se actualizara el colaborador "${selectedColaborador.nombreCompleto}". ¿Desea continuar?`,
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
        await colaboradorService.update(selectedColaborador.id, formData);
        toast.success('Colaborador actualizado exitosamente');
      } else {
        await colaboradorService.create(formData);
        toast.success('Colaborador creado exitosamente');
      }
      closeModal();
      await loadColaboradores();
      if (!isEditing) {
        setPage(1);
      }
    } catch (err) {
      toast.error(`Error al ${isEditing ? 'actualizar' : 'crear'} el colaborador: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (colaborador) => {
    const result = await Swal.fire({
      title: 'Eliminar colaborador',
      text: `¿Esta seguro de eliminar al colaborador "${colaborador.nombreCompleto}"? Esta accion no se puede deshacer.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, eliminar',
      cancelButtonText: 'Cancelar',
    });

    if (!result.isConfirmed) return;

    try {
      await colaboradorService.delete(colaborador.id);
      toast.success('Colaborador eliminado exitosamente');
      await loadColaboradores();
      // Adjust page if the current page becomes empty after deletion
      const newTotal = allColaboradores.length - 1;
      const newTotalPages = Math.ceil(newTotal / PAGE_SIZE);
      if (page > newTotalPages && newTotalPages > 0) {
        setPage(newTotalPages);
      }
    } catch (err) {
      toast.error(`Error al eliminar el colaborador: ${err.message}`);
    }
  };

  if (loading && allColaboradores.length === 0) {
    return <div className="text-center p-6">Cargando...</div>;
  }

  if (error) {
    return (
      <div>
        <div className="alert alert--error mb-4">
          <div className="alert__content">
            <div className="alert__title">Error de conexion</div>
            <div className="alert__message">
              No se pudieron cargar los colaboradores: {error}
            </div>
          </div>
        </div>
        <button className="btn btn--primary" onClick={() => loadColaboradores()}>
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
          <h1 className="page-header__title">Colaboradores</h1>
          <p className="page-header__subtitle">Gestion de colaboradores del sistema</p>
        </div>
        <button className="btn btn--primary" onClick={openCreateModal}>
          <Plus size={18} />
          Nuevo Colaborador
        </button>
      </div>

      <div className="card">
        <div className="card__body">
          {colaboradores.length === 0 && !loading ? (
            <div className="empty-state">
              <Users size={48} className="empty-state__icon" />
              <h3 className="empty-state__title">No hay colaboradores</h3>
              <p className="empty-state__description">
                Aun no se han creado colaboradores. Crea el primero haciendo clic en "Nuevo Colaborador".
              </p>
            </div>
          ) : (
            <>
              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Nombre Completo</th>
                      <th>Cedula</th>
                      <th>Area</th>
                      <th>Correo</th>
                      <th>Rol</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {colaboradores.map((col) => (
                      <tr key={col.id}>
                        <td className="font-semibold">{col.nombreCompleto}</td>
                        <td className="text-secondary">{col.cedula}</td>
                        <td className="text-secondary">{col.area}</td>
                        <td className="text-secondary">{col.correo}</td>
                        <td>
                          {col.rolNames && col.rolNames.length > 0 ? (
                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                              {col.rolNames.map((rolName, idx) => (
                                <span key={idx} className="badge badge--active">
                                  {rolName}
                                </span>
                              ))}
                            </div>
                          ) : (
                            <span className="text-secondary">{col.rolName || '—'}</span>
                          )}
                        </td>
                        <td>
                          <div className="table__actions">
                            <button
                              className="btn btn--icon btn--sm btn--ghost"
                              onClick={() => openEditModal(col)}
                              data-tooltip="Editar"
                            >
                              <Pencil size={16} />
                            </button>
                            <button
                              className="btn btn--icon btn--sm btn--ghost text-error"
                              onClick={() => handleDelete(col)}
                              data-tooltip="Eliminar"
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
                    Mostrando {startItem}-{endItem} de {totalCount} colaboradores
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

      <ColaboradorModal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSubmit}
        colaborador={selectedColaborador}
        loading={saving}
      />
    </div>
  );
};

export default Colaboradores;
