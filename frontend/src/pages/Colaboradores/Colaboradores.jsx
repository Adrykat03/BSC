import { useState, useEffect, useCallback } from 'react';
import { Plus, Pencil, Trash2, Users } from 'lucide-react';
import { colaboradorService } from '../../services/colaboradorService';
import Modal from '../../components/common/Modal';
import ConfirmDialog from '../../components/common/ConfirmDialog';

const INITIAL_FORM = {
  nombreCompleto: '',
  cedula: '',
  area: '',
  correo: '',
  password: '',
};

const Colaboradores = () => {
  const [colaboradores, setColaboradores] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);
  const [confirmDelete, setConfirmDelete] = useState(null);
  const [form, setForm] = useState(INITIAL_FORM);
  const [formErrors, setFormErrors] = useState([]);
  const [submitting, setSubmitting] = useState(false);

  const fetchColaboradores = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await colaboradorService.getAll();
      setColaboradores(response.data || []);
    } catch (err) {
      setError(err.message || 'Error al cargar colaboradores');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchColaboradores();
  }, [fetchColaboradores]);

  const resetForm = () => {
    setForm(INITIAL_FORM);
    setFormErrors([]);
    setEditing(null);
  };

  const openCreateModal = () => {
    resetForm();
    setModalOpen(true);
  };

  const openEditModal = (colaborador) => {
    setEditing(colaborador);
    setForm({
      nombreCompleto: colaborador.nombreCompleto || '',
      cedula: colaborador.cedula || '',
      area: colaborador.area || '',
      correo: colaborador.correo || '',
      password: '',
    });
    setFormErrors([]);
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    resetForm();
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  };

  const validate = () => {
    const errors = [];
    if (!form.nombreCompleto.trim()) errors.push('El nombre completo es obligatorio.');
    if (!form.cedula.trim()) {
      errors.push('La cédula es obligatoria.');
    } else if (!/^\d{10}$/.test(form.cedula)) {
      errors.push('La cédula debe tener exactamente 10 dígitos.');
    }
    if (!form.area.trim()) errors.push('El área es obligatoria.');
    if (!form.correo.trim()) {
      errors.push('El correo es obligatorio.');
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.correo)) {
      errors.push('El correo no tiene un formato válido.');
    }
    if (!editing && !form.password.trim()) {
      errors.push('La contraseña es obligatoria.');
    } else if (!editing && form.password.trim().length < 8) {
      errors.push('La contraseña debe tener al menos 8 caracteres.');
    }
    return errors;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const errors = validate();
    if (errors.length > 0) {
      setFormErrors(errors);
      return;
    }

    try {
      setSubmitting(true);
      setFormErrors([]);

      if (editing) {
        const { password, ...updateData } = form;
        await colaboradorService.update(editing.id, updateData);
      } else {
        await colaboradorService.create(form);
      }

      closeModal();
      await fetchColaboradores();
    } catch (err) {
      const backendErrors = err.errors && err.errors.length > 0
        ? err.errors
        : [err.message || 'Error al guardar colaborador'];
      setFormErrors(backendErrors);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!confirmDelete) return;
    try {
      await colaboradorService.delete(confirmDelete.id);
      setConfirmDelete(null);
      await fetchColaboradores();
    } catch (err) {
      setError(err.message || 'Error al eliminar colaborador');
      setConfirmDelete(null);
    }
  };

  const modalFooter = (
    <div className="d-flex justify-end gap-2">
      <button
        className="btn btn--secondary"
        onClick={closeModal}
        type="button"
        disabled={submitting}
      >
        Cancelar
      </button>
      <button
        className="btn btn--primary"
        onClick={handleSubmit}
        type="button"
        disabled={submitting}
      >
        {submitting ? 'Guardando...' : 'Guardar'}
      </button>
    </div>
  );

  return (
    <div>
      <div className="page-header d-flex justify-between items-center mb-4">
        <div>
          <h1 className="page-header__title">Colaboradores</h1>
          <p className="page-header__subtitle">Gestión de colaboradores del sistema</p>
        </div>
        <button className="btn btn--primary" onClick={openCreateModal}>
          <Plus size={18} />
          Nuevo Colaborador
        </button>
      </div>

      {error && (
        <div className="alert alert--error mb-4">
          {error}
        </div>
      )}

      {loading ? (
        <div className="card">
          <div className="card__body text-center p-4">
            Cargando...
          </div>
        </div>
      ) : colaboradores.length === 0 ? (
        <div className="card">
          <div className="card__body text-center p-4">
            <Users size={48} className="mb-4 text-disabled" />
            <p>No hay colaboradores registrados.</p>
            <button className="btn btn--primary mt-4" onClick={openCreateModal}>
              <Plus size={18} />
              Crear primer colaborador
            </button>
          </div>
        </div>
      ) : (
        <div className="card">
          <div className="card__body">
            <table className="table">
              <thead>
                <tr>
                  <th>Nombre Completo</th>
                  <th>Cédula</th>
                  <th>Área</th>
                  <th>Correo</th>
                  <th>Acciones</th>
                </tr>
              </thead>
              <tbody>
                {colaboradores.map((col) => (
                  <tr key={col.id}>
                    <td>{col.nombreCompleto}</td>
                    <td>{col.cedula}</td>
                    <td>{col.area}</td>
                    <td>{col.correo}</td>
                    <td className="table__actions">
                      <button
                        className="btn btn--ghost btn--sm"
                        onClick={() => openEditModal(col)}
                        title="Editar"
                      >
                        <Pencil size={16} />
                      </button>
                      <button
                        className="btn btn--ghost btn--sm"
                        onClick={() => setConfirmDelete(col)}
                        title="Eliminar"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <Modal
        isOpen={modalOpen}
        onClose={closeModal}
        title={editing ? 'Editar Colaborador' : 'Nuevo Colaborador'}
        footer={modalFooter}
      >
        <form onSubmit={handleSubmit}>
          {formErrors.length > 0 && (
            <div className="alert alert--error mb-4">
              <ul>
                {formErrors.map((err, i) => (
                  <li key={i}>{err}</li>
                ))}
              </ul>
            </div>
          )}

          <div className="form-group">
            <label className="form-label" htmlFor="nombreCompleto">
              Nombre Completo
            </label>
            <input
              className="form-input"
              type="text"
              id="nombreCompleto"
              name="nombreCompleto"
              value={form.nombreCompleto}
              onChange={handleChange}
              placeholder="Ingrese el nombre completo"
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="cedula">
              Cédula
            </label>
            <input
              className="form-input"
              type="text"
              id="cedula"
              name="cedula"
              value={form.cedula}
              onChange={handleChange}
              placeholder="Ingrese la cédula"
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="area">
              Área
            </label>
            <input
              className="form-input"
              type="text"
              id="area"
              name="area"
              value={form.area}
              onChange={handleChange}
              placeholder="Ingrese el área"
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="correo">
              Correo
            </label>
            <input
              className="form-input"
              type="email"
              id="correo"
              name="correo"
              value={form.correo}
              onChange={handleChange}
              placeholder="Ingrese el correo electrónico"
            />
          </div>

          {!editing && (
            <div className="form-group">
              <label className="form-label" htmlFor="password">
                Contraseña
              </label>
              <input
                className="form-input"
                type="password"
                id="password"
                name="password"
                value={form.password}
                onChange={handleChange}
                placeholder="Ingrese la contraseña"
              />
            </div>
          )}
        </form>
      </Modal>

      <ConfirmDialog
        isOpen={!!confirmDelete}
        onClose={() => setConfirmDelete(null)}
        onConfirm={handleDelete}
        title="Eliminar Colaborador"
        message={`¿Está seguro de eliminar a ${confirmDelete?.nombreCompleto}?`}
        confirmText="Eliminar"
        cancelText="Cancelar"
      />
    </div>
  );
};

export default Colaboradores;
