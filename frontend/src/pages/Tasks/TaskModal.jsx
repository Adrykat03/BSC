import { useState, useEffect } from 'react';
import { X, Upload, FileText } from 'lucide-react';

const ALLOWED_TYPES = [
  'application/pdf',
  'image/jpeg',
  'image/png',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
];

const ALLOWED_EXTENSIONS = '.pdf,.jpg,.jpeg,.png,.doc,.docx,.xls,.xlsx';
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

const TaskModal = ({ isOpen, onClose, onSubmit, task, loading, userRole = 'Gerente' }) => {
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    estimatedTime: '',
    insumos: '',
  });
  const [insumoFile, setInsumoFile] = useState(null);
  const [errors, setErrors] = useState({});

  const isEditing = Boolean(task);
  const isGerente = userRole === 'Gerente';
  const isLider = userRole === 'Lider';

  useEffect(() => {
    if (task) {
      setFormData({
        title: task.title || '',
        description: task.description || '',
        estimatedTime: task.estimatedTime ?? '',
        insumos: task.insumos || '',
      });
    } else {
      setFormData({
        title: '',
        description: '',
        estimatedTime: '',
        insumos: '',
      });
    }
    setInsumoFile(null);
    setErrors({});
  }, [task, isOpen]);

  const validate = () => {
    const newErrors = {};
    if (!formData.title.trim()) {
      newErrors.title = 'El titulo es requerido';
    }
    if (!formData.description.trim()) {
      newErrors.description = 'La descripcion es requerida';
    }
    if (insumoFile) {
      if (!ALLOWED_TYPES.includes(insumoFile.type)) {
        newErrors.insumoFile = 'Tipo de archivo no permitido. Use: PDF, JPG, PNG, DOC, DOCX, XLS, XLSX';
      }
      if (insumoFile.size > MAX_FILE_SIZE) {
        newErrors.insumoFile = 'El archivo no debe superar los 10MB';
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

  const handleFileChange = (e) => {
    const file = e.target.files[0] || null;
    setInsumoFile(file);
    if (errors.insumoFile) {
      setErrors((prev) => ({ ...prev, insumoFile: '' }));
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;

    const data = new FormData();
    data.append('title', formData.title.trim());
    data.append('description', formData.description.trim());
    if (formData.estimatedTime !== '' && formData.estimatedTime !== null) {
      data.append('estimatedTime', formData.estimatedTime);
    }
    if (formData.insumos.trim()) {
      data.append('insumos', formData.insumos.trim());
    }
    if (insumoFile) {
      data.append('insumoFile', insumoFile);
    }

    onSubmit(data);
  };

  if (!isOpen) return null;

  // Lider can only edit title, description, insumos
  const canEditTitle = isGerente || isLider;
  const canEditDescription = isGerente || isLider;
  const canEditEstimatedTime = isGerente;
  const canEditInsumos = isGerente || isLider;

  return (
    <>
      <div
        className={`modal-backdrop ${isOpen ? 'modal-backdrop--open' : ''}`}
      />
      <div className={`modal ${isOpen ? 'modal--open' : ''}`}>
        <div className="modal__header">
          <h3 className="modal__title">
            {isEditing ? 'Editar Tarea' : 'Crear Tarea'}
          </h3>
          <button className="modal__close" onClick={onClose} type="button">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal__body">
            <div className="form-group mb-4">
              <label className="form-label form-label--required">Titulo</label>
              <input
                type="text"
                name="title"
                className={`form-control ${errors.title ? 'form-input--error' : ''}`}
                value={formData.title}
                onChange={handleChange}
                placeholder="Titulo de la tarea"
                disabled={!canEditTitle}
              />
              {errors.title && (
                <span className="form-helper form-helper--error">{errors.title}</span>
              )}
            </div>

            <div className="form-group mb-4">
              <label className="form-label form-label--required">Descripcion</label>
              <textarea
                name="description"
                className={`form-control form-textarea ${errors.description ? 'form-input--error' : ''}`}
                value={formData.description}
                onChange={handleChange}
                placeholder="Descripcion de la tarea"
                rows={3}
                disabled={!canEditDescription}
              />
              {errors.description && (
                <span className="form-helper form-helper--error">{errors.description}</span>
              )}
            </div>

            {canEditEstimatedTime && (
              <div className="form-group mb-4">
                <label className="form-label">Tiempo estimado (horas)</label>
                <input
                  type="number"
                  name="estimatedTime"
                  className="form-control"
                  value={formData.estimatedTime}
                  onChange={handleChange}
                  placeholder="Ej: 8"
                  min="0"
                  step="0.5"
                />
              </div>
            )}

            {canEditInsumos && (
              <>
                <div className="form-group mb-4">
                  <label className="form-label">Insumos (texto)</label>
                  <textarea
                    name="insumos"
                    className="form-control form-textarea"
                    value={formData.insumos}
                    onChange={handleChange}
                    placeholder="Descripcion de insumos necesarios"
                    rows={2}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Archivo de insumo</label>
                  <div style={{ paddingTop: '24px' }}>
                    <label className="upload-zone" style={{ padding: 'var(--spacing-4)', cursor: 'pointer' }}>
                      <input
                        type="file"
                        accept={ALLOWED_EXTENSIONS}
                        onChange={handleFileChange}
                        style={{ display: 'none' }}
                      />
                      <Upload size={24} className="upload-zone__icon" style={{ marginBottom: '0' }} />
                      <span className="upload-zone__text">
                        {insumoFile
                          ? insumoFile.name
                          : 'Clic para seleccionar archivo'}
                      </span>
                      <span className="upload-zone__hint">PDF, JPG, PNG, DOC, DOCX, XLS, XLSX (max 10MB)</span>
                    </label>
                    {isEditing && task?.insumoFileName && !insumoFile && (
                      <div className="d-flex items-center gap-2 mt-2">
                        <FileText size={16} style={{ color: 'var(--color-text-secondary)' }} />
                        <span className="text-sm text-secondary">
                          Archivo actual: {task.insumoFileName}
                        </span>
                      </div>
                    )}
                    {errors.insumoFile && (
                      <span className="form-helper form-helper--error">{errors.insumoFile}</span>
                    )}
                  </div>
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

export default TaskModal;
