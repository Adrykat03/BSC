import { useState, useEffect } from 'react';
import { X, Check } from 'lucide-react';
import { rolesService } from '../../services/rolesService';

const passwordRules = [
  { label: 'Minimo 8 caracteres', test: (v) => v.length >= 8 },
  { label: 'Al menos una mayuscula', test: (v) => /[A-Z]/.test(v) },
  { label: 'Al menos una minuscula', test: (v) => /[a-z]/.test(v) },
  { label: 'Al menos un numero', test: (v) => /[0-9]/.test(v) },
  { label: 'Al menos un caracter especial (@$!%*?&#)', test: (v) => /[@$!%*?&#]/.test(v) },
];

const ColaboradorModal = ({ isOpen, onClose, onSubmit, colaborador, loading }) => {
  const [formData, setFormData] = useState({
    nombreCompleto: '',
    cedula: '',
    area: '',
    correo: '',
    password: '',
    rolId: '',
  });
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errors, setErrors] = useState({});
  const [roles, setRoles] = useState([]);
  const [loadingRoles, setLoadingRoles] = useState(false);

  const isEditing = Boolean(colaborador);

  useEffect(() => {
    if (isOpen) {
      setLoadingRoles(true);
      rolesService.getAll(1, 100)
        .then((data) => {
          setRoles(data.items || []);
        })
        .catch(() => {
          setRoles([]);
        })
        .finally(() => {
          setLoadingRoles(false);
        });
    }
  }, [isOpen]);

  useEffect(() => {
    if (colaborador) {
      setFormData({
        nombreCompleto: colaborador.nombreCompleto || '',
        cedula: colaborador.cedula || '',
        area: colaborador.area || '',
        correo: colaborador.correo || '',
        password: '',
        rolId: colaborador.rolId || '',
      });
    } else {
      setFormData({
        nombreCompleto: '',
        cedula: '',
        area: '',
        correo: '',
        password: '',
        rolId: '',
      });
    }
    setConfirmPassword('');
    setErrors({});
  }, [colaborador, isOpen]);

  const allPasswordRulesMet = passwordRules.every((rule) => rule.test(formData.password));

  const validate = () => {
    const newErrors = {};
    if (!formData.nombreCompleto.trim()) {
      newErrors.nombreCompleto = 'El nombre completo es requerido';
    }
    if (!formData.cedula.trim()) {
      newErrors.cedula = 'La cedula es requerida';
    } else if (!/^\d{10}$/.test(formData.cedula)) {
      newErrors.cedula = 'La cedula debe tener exactamente 10 digitos';
    }
    if (!formData.area.trim()) {
      newErrors.area = 'El area es requerida';
    }
    if (!formData.correo.trim()) {
      newErrors.correo = 'El correo es requerido';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.correo)) {
      newErrors.correo = 'El correo no tiene un formato valido';
    }
    if (!formData.rolId) {
      newErrors.rolId = 'El rol es requerido';
    }
    if (!isEditing) {
      if (!formData.password.trim()) {
        newErrors.password = 'La contrasena es requerida';
      } else if (!allPasswordRulesMet) {
        newErrors.password = 'La contrasena no cumple todos los requisitos';
      }
      if (formData.password !== confirmPassword) {
        newErrors.confirmPassword = 'Las contrasenas no coinciden';
      }
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

  const handleConfirmPasswordChange = (e) => {
    setConfirmPassword(e.target.value);
    if (errors.confirmPassword) {
      setErrors((prev) => ({ ...prev, confirmPassword: '' }));
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;
    if (isEditing) {
      const { password, ...updateData } = formData;
      onSubmit(updateData);
    } else {
      onSubmit(formData);
    }
  };

  if (!isOpen) return null;

  return (
    <>
      <div
        className={`modal-backdrop ${isOpen ? 'modal-backdrop--open' : ''}`}
        onClick={onClose}
      />
      <div className={`modal ${isOpen ? 'modal--open' : ''}`}>
        <div className="modal__header">
          <h3 className="modal__title">
            {isEditing ? 'Editar Colaborador' : 'Crear Colaborador'}
          </h3>
          <button className="modal__close" onClick={onClose} type="button">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal__body">
            <div className="form-group mb-4">
              <label className="form-label form-label--required">Nombre Completo</label>
              <input
                type="text"
                name="nombreCompleto"
                className={`form-control ${errors.nombreCompleto ? 'form-input--error' : ''}`}
                value={formData.nombreCompleto}
                onChange={handleChange}
                placeholder="Nombre completo del colaborador"
              />
              {errors.nombreCompleto && (
                <span className="form-helper form-helper--error">{errors.nombreCompleto}</span>
              )}
            </div>

            <div className="form-group mb-4">
              <label className="form-label form-label--required">Cedula</label>
              <input
                type="text"
                name="cedula"
                className={`form-control ${errors.cedula ? 'form-input--error' : ''}`}
                value={formData.cedula}
                onChange={handleChange}
                placeholder="Cedula de 10 digitos"
              />
              {errors.cedula && (
                <span className="form-helper form-helper--error">{errors.cedula}</span>
              )}
            </div>

            <div className="form-group mb-4">
              <label className="form-label form-label--required">Area</label>
              <input
                type="text"
                name="area"
                className={`form-control ${errors.area ? 'form-input--error' : ''}`}
                value={formData.area}
                onChange={handleChange}
                placeholder="Area del colaborador"
              />
              {errors.area && (
                <span className="form-helper form-helper--error">{errors.area}</span>
              )}
            </div>

            <div className="form-group mb-4">
              <label className="form-label form-label--required">Correo</label>
              <input
                type="email"
                name="correo"
                className={`form-control ${errors.correo ? 'form-input--error' : ''}`}
                value={formData.correo}
                onChange={handleChange}
                placeholder="Correo electronico"
              />
              {errors.correo && (
                <span className="form-helper form-helper--error">{errors.correo}</span>
              )}
            </div>

            <div className="form-group mb-4">
              <label className="form-label form-label--required">Rol</label>
              <select
                name="rolId"
                className={`form-control form-select ${errors.rolId ? 'form-input--error' : ''}`}
                value={formData.rolId}
                onChange={handleChange}
                disabled={loadingRoles}
              >
                <option value="">{loadingRoles ? 'Cargando roles...' : 'Seleccione un rol'}</option>
                {roles.map((role) => (
                  <option key={role.id} value={role.id}>
                    {role.name}
                  </option>
                ))}
              </select>
              {errors.rolId && (
                <span className="form-helper form-helper--error">{errors.rolId}</span>
              )}
            </div>

            {!isEditing && (
              <>
                <div className="form-group mb-4">
                  <label className="form-label form-label--required">Contrasena</label>
                  <input
                    type="password"
                    name="password"
                    className={`form-control ${errors.password ? 'form-input--error' : ''}`}
                    value={formData.password}
                    onChange={handleChange}
                    placeholder="Minimo 8 caracteres"
                  />
                  {errors.password && (
                    <span className="form-helper form-helper--error">{errors.password}</span>
                  )}

                  <ul style={{ listStyle: 'none', padding: 0, margin: '8px 0 0 0' }}>
                    {passwordRules.map((rule, idx) => {
                      const passed = rule.test(formData.password);
                      return (
                        <li
                          key={idx}
                          className={passed ? 'text-success' : 'text-error'}
                          style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', marginBottom: '2px' }}
                        >
                          {passed ? <Check size={14} /> : <X size={14} />}
                          {rule.label}
                        </li>
                      );
                    })}
                  </ul>
                </div>

                <div className="form-group">
                  <label className="form-label form-label--required">Confirmar Contrasena</label>
                  <input
                    type="password"
                    name="confirmPassword"
                    className={`form-control ${errors.confirmPassword || (confirmPassword && formData.password !== confirmPassword) ? 'form-input--error' : ''}`}
                    value={confirmPassword}
                    onChange={handleConfirmPasswordChange}
                    placeholder="Repita la contrasena"
                  />
                  {errors.confirmPassword && (
                    <span className="form-helper form-helper--error">{errors.confirmPassword}</span>
                  )}
                  {confirmPassword && !errors.confirmPassword && (
                    <span
                      className={`form-helper ${formData.password === confirmPassword ? 'text-success' : 'form-helper--error'}`}
                      style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', marginTop: '4px' }}
                    >
                      {formData.password === confirmPassword ? (
                        <><Check size={14} /> Las contrasenas coinciden</>
                      ) : (
                        <><X size={14} /> Las contrasenas no coinciden</>
                      )}
                    </span>
                  )}
                </div>
              </>
            )}
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

export default ColaboradorModal;
