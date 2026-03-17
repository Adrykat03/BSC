import { useState, useEffect } from 'react';
import { X } from 'lucide-react';

const RoleModal = ({ isOpen, onClose, onSubmit, role, loading }) => {
  const [formData, setFormData] = useState({ name: '', description: '' });
  const [errors, setErrors] = useState({});

  useEffect(() => {
    const handleEsc = (e) => { if (e.key === 'Escape') onClose(); };
    if (isOpen) document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [isOpen, onClose]);

  const isEditing = Boolean(role);

  useEffect(() => {
    if (role) {
      setFormData({ name: role.name || '', description: role.description || '' });
    } else {
      setFormData({ name: '', description: '' });
    }
    setErrors({});
  }, [role, isOpen]);

  const validate = () => {
    const newErrors = {};
    if (!formData.name.trim()) {
      newErrors.name = 'El nombre es requerido';
    }
    if (!formData.description.trim()) {
      newErrors.description = 'La descripcion es requerida';
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;
    onSubmit(formData);
  };

  if (!isOpen) return null;

  return (
    <>
      <div
        className={`modal-backdrop ${isOpen ? 'modal-backdrop--open' : ''}`}
      />
      <div className={`modal ${isOpen ? 'modal--open' : ''}`}>
        <div className="modal__header">
          <h3 className="modal__title">
            {isEditing ? 'Editar Rol' : 'Crear Rol'}
          </h3>
          <button className="modal__close" onClick={onClose} type="button">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal__body">
            <div className="form-group mb-4">
              <label className="form-label form-label--required">Nombre</label>
              <input
                type="text"
                name="name"
                className={`form-control ${errors.name ? 'form-input--error' : ''}`}
                value={formData.name}
                onChange={handleChange}
                placeholder="Nombre del rol"
              />
              {errors.name && (
                <span className="form-helper form-helper--error">{errors.name}</span>
              )}
            </div>

            <div className="form-group">
              <label className="form-label form-label--required">Descripcion</label>
              <textarea
                name="description"
                className={`form-control form-textarea ${errors.description ? 'form-input--error' : ''}`}
                value={formData.description}
                onChange={handleChange}
                placeholder="Descripcion del rol"
                rows={3}
              />
              {errors.description && (
                <span className="form-helper form-helper--error">{errors.description}</span>
              )}
            </div>
          </div>

          <div className="modal__footer">
            <button
              type="button"
              className="btn btn--secondary"
              onClick={onClose}
              disabled={loading}
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="btn btn--primary"
              disabled={loading}
            >
              {loading ? 'Guardando...' : isEditing ? 'Actualizar' : 'Crear'}
            </button>
          </div>
        </form>
      </div>
    </>
  );
};

export default RoleModal;
