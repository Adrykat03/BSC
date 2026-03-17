import { useState, useEffect, useCallback } from 'react';
import { Plus, Pencil, Trash2, Shield, ChevronLeft, ChevronRight } from 'lucide-react';
import Swal from 'sweetalert2';
import toast, { Toaster } from 'react-hot-toast';
import { rolesService } from '../../services/rolesService';
import RoleModal from './RoleModal';

const PAGE_SIZE = 10;

const Roles = () => {
  const [roles, setRoles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedRole, setSelectedRole] = useState(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [totalCount, setTotalCount] = useState(0);

  const loadRoles = useCallback(async (currentPage = 1) => {
    try {
      setLoading(true);
      setError(null);
      const data = await rolesService.getAll(currentPage, PAGE_SIZE);
      setRoles(data.items ?? []);
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
    loadRoles();
  }, [loadRoles]);

  const goToPage = (newPage) => {
    if (newPage >= 1 && newPage <= totalPages) {
      loadRoles(newPage);
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
    setSelectedRole(null);
    setModalOpen(true);
  };

  const openEditModal = (role) => {
    setSelectedRole(role);
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedRole(null);
  };

  const handleSubmit = async (formData) => {
    const isEditing = Boolean(selectedRole);

    if (isEditing) {
      const result = await Swal.fire({
        title: 'Confirmar actualizacion',
        text: `Se actualizara el rol "${selectedRole.name}". ¿Desea continuar?`,
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
        await rolesService.update(selectedRole.id, formData);
        toast.success('Rol actualizado exitosamente');
      } else {
        await rolesService.create(formData);
        toast.success('Rol creado exitosamente');
      }
      closeModal();
      await loadRoles(isEditing ? page : 1);
    } catch (err) {
      toast.error(`Error al ${isEditing ? 'actualizar' : 'crear'} el rol: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (role) => {
    const result = await Swal.fire({
      title: 'Eliminar rol',
      text: `¿Esta seguro de eliminar el rol "${role.name}"? Esta accion no se puede deshacer.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, eliminar',
      cancelButtonText: 'Cancelar',
    });

    if (!result.isConfirmed) return;

    try {
      await rolesService.delete(role.id);
      toast.success('Rol eliminado exitosamente');
      const newPage = roles.length === 1 && page > 1 ? page - 1 : page;
      await loadRoles(newPage);
    } catch (err) {
      toast.error(`Error al eliminar el rol: ${err.message}`);
    }
  };

  if (loading && roles.length === 0) {
    return <div className="text-center p-6">Cargando...</div>;
  }

  if (error) {
    return (
      <div>
        <div className="alert alert--error mb-4">
          <div className="alert__content">
            <div className="alert__title">Error de conexion</div>
            <div className="alert__message">
              No se pudieron cargar los roles: {error}
            </div>
          </div>
        </div>
        <button className="btn btn--primary" onClick={() => loadRoles(page)}>
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
          <h1 className="page-header__title">Roles</h1>
          <p className="page-header__subtitle">Gestion de roles del sistema</p>
        </div>
        <button className="btn btn--primary" onClick={openCreateModal}>
          <Plus size={18} />
          Nuevo Rol
        </button>
      </div>

      <div className="card">
        <div className="card__body">
          {roles.length === 0 && !loading ? (
            <div className="empty-state">
              <Shield size={48} className="empty-state__icon" />
              <h3 className="empty-state__title">No hay roles</h3>
              <p className="empty-state__description">
                Aun no se han creado roles. Crea el primero haciendo clic en "Nuevo Rol".
              </p>
            </div>
          ) : (
            <>
              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Nombre</th>
                      <th>Descripcion</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {roles.map((role) => (
                      <tr key={role.id}>
                        <td className="font-semibold">{role.name}</td>
                        <td className="text-secondary">{role.description}</td>
                        <td>
                          <div className="table__actions">
                            <button
                              className="btn btn--icon btn--sm btn--ghost"
                              onClick={() => openEditModal(role)}
                              title="Editar"
                            >
                              <Pencil size={16} />
                            </button>
                            <button
                              className="btn btn--icon btn--sm btn--ghost text-error"
                              onClick={() => handleDelete(role)}
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
                    Mostrando {startItem}-{endItem} de {totalCount} roles
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

      <RoleModal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSubmit}
        role={selectedRole}
        loading={saving}
      />
    </div>
  );
};

export default Roles;
