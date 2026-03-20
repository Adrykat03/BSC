import { useState, useEffect, useRef, useCallback } from 'react';
import { X, Upload, FileText, Download, Trash2 } from 'lucide-react';
import Swal from 'sweetalert2';
import toast from 'react-hot-toast';
import { tasksService } from '../../services/tasksService';
import { colaboradorService } from '../../services/colaboradorService';
import './TaskModal.css';

const MAX_FILE_SIZE = 20 * 1024 * 1024; // 20MB

/* ────────────────────────────────────────────
   Label helper
   ──────────────────────────────────────────── */
const Label = ({ children, required }) => (
  <span
    style={{
      fontSize: '10px',
      fontWeight: 'bold',
      color: '#6B7280',
      textTransform: 'uppercase',
      letterSpacing: '0.05em',
      display: 'block',
      marginBottom: '8px',
    }}
  >
    {children}
    {required && <span style={{ color: 'var(--color-error)' }}> *</span>}
  </span>
);

/* ────────────────────────────────────────────
   FileDropZone — reusable drag & drop area
   Supports multiple files
   ──────────────────────────────────────────── */
const FileDropZone = ({
  files,
  existingFiles,
  onChange,
  onRemoveNew,
  onRemoveExisting,
  onDownload,
  label,
  error,
}) => {
  const inputRef = useRef(null);
  const [dragging, setDragging] = useState(false);

  const validateFile = (f) => {
    if (f.size > MAX_FILE_SIZE) {
      return 'El archivo no debe superar los 20MB';
    }
    return null;
  };

  const processFiles = useCallback(
    (fileList) => {
      const validFiles = [];
      let firstError = null;
      for (const f of fileList) {
        const err = validateFile(f);
        if (err) {
          if (!firstError) firstError = err;
        } else {
          validFiles.push(f);
        }
      }
      if (validFiles.length > 0) {
        onChange(validFiles, firstError);
      } else if (firstError) {
        onChange([], firstError);
      }
    },
    [onChange],
  );

  const handleDrop = useCallback(
    (e) => {
      e.preventDefault();
      setDragging(false);
      const droppedFiles = Array.from(e.dataTransfer.files);
      if (droppedFiles.length === 0) return;
      processFiles(droppedFiles);
    },
    [processFiles],
  );

  const handleDragOver = (e) => {
    e.preventDefault();
    setDragging(true);
  };
  const handleDragLeave = (e) => {
    e.preventDefault();
    setDragging(false);
  };

  const handleClick = () => inputRef.current?.click();

  const handleInputChange = (e) => {
    const selected = Array.from(e.target.files);
    if (selected.length === 0) return;
    processFiles(selected);
    // reset so the same files can be re-selected
    e.target.value = '';
  };

  const hasFiles = files.length > 0 || (existingFiles && existingFiles.length > 0);

  return (
    <div>
      <Label>{label}</Label>

      {/* Drop zone — always visible so user can keep adding */}
      <div
        role="button"
        tabIndex={0}
        onClick={handleClick}
        onKeyDown={(e) => e.key === 'Enter' && handleClick()}
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '6px',
          padding: hasFiles ? 'var(--spacing-3)' : 'var(--spacing-5)',
          border: `2px dashed ${dragging ? 'var(--color-primary)' : 'var(--color-border-main)'}`,
          borderRadius: 'var(--radius-lg)',
          backgroundColor: dragging ? 'rgba(227,24,55,0.04)' : 'var(--color-bg-main)',
          cursor: 'pointer',
          transition: 'border-color 150ms, background-color 150ms',
        }}
      >
        <Upload size={hasFiles ? 20 : 28} style={{ color: dragging ? 'var(--color-primary)' : 'var(--color-text-secondary)' }} />
        <span style={{ fontSize: '13px', color: 'var(--color-text-secondary)', textAlign: 'center' }}>
          {hasFiles ? 'Agregar mas archivos' : 'Arrastra archivos aqui o haz clic para seleccionar'}
        </span>
        {!hasFiles && (
          <span style={{ fontSize: '11px', color: 'var(--color-text-disabled)' }}>
            Cualquier tipo de archivo (max 20MB)
          </span>
        )}
      </div>

      <input
        ref={inputRef}
        type="file"
        multiple
        onChange={handleInputChange}
        style={{ display: 'none' }}
      />

      {/* File list */}
      {hasFiles && (
        <div
          style={{
            marginTop: '8px',
            border: '1px solid var(--color-border-main)',
            borderRadius: 'var(--radius-lg)',
            overflow: 'hidden',
          }}
        >
          {/* Existing files (from server) */}
          {existingFiles && existingFiles.map((ef) => (
            <div
              key={ef.id}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '6px 12px',
                borderBottom: '1px solid var(--color-border-light)',
                fontSize: '13px',
              }}
            >
              <FileText size={16} style={{ color: 'var(--color-text-secondary)', flexShrink: 0 }} />
              <span style={{ flex: 1, wordBreak: 'break-all' }}>
                {ef.fileName}{' '}
                <span style={{ color: 'var(--color-text-disabled)', fontSize: '11px' }}>(guardado)</span>
              </span>
              {onDownload && (
                <button
                  type="button"
                  data-tooltip="Descargar"
                  onClick={() => onDownload(ef.id)}
                  style={{
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    padding: '2px',
                    color: 'var(--color-text-secondary)',
                    flexShrink: 0,
                  }}
                >
                  <Download size={14} />
                </button>
              )}
              {onRemoveExisting && (
                <button
                  type="button"
                  data-tooltip="Eliminar"
                  onClick={() => onRemoveExisting(ef.id)}
                  style={{
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    padding: '2px',
                    color: 'var(--color-text-secondary)',
                    flexShrink: 0,
                  }}
                >
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          ))}

          {/* New files (not yet saved) */}
          {files.map((f, idx) => (
            <div
              key={`new-${idx}-${f.name}`}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '6px 12px',
                borderBottom: '1px solid var(--color-border-light)',
                fontSize: '13px',
              }}
            >
              <FileText size={16} style={{ color: 'var(--color-text-secondary)', flexShrink: 0 }} />
              <span style={{ flex: 1, wordBreak: 'break-all' }}>{f.name}</span>
              <button
                type="button"
                data-tooltip="Eliminar"
                onClick={() => onRemoveNew(idx)}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  padding: '2px',
                  color: 'var(--color-text-secondary)',
                  flexShrink: 0,
                }}
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
        </div>
      )}

      {error && (
        <span className="form-helper form-helper--error">{error}</span>
      )}
    </div>
  );
};

/* ────────────────────────────────────────────
   ReadOnlyFileList — for read-only file access
   ──────────────────────────────────────────── */
const ReadOnlyFileList = ({ files, onDownload, label }) => (
  <div>
    <Label>{label}</Label>
    {files && files.length > 0 ? (
      <div
        style={{
          border: '1px solid var(--color-border-main)',
          borderRadius: 'var(--radius-lg)',
          overflow: 'hidden',
        }}
      >
        {files.map((ef) => (
          <div
            key={ef.id}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              padding: '6px 12px',
              borderBottom: '1px solid var(--color-border-light)',
              fontSize: '13px',
            }}
          >
            <FileText size={16} style={{ color: 'var(--color-text-secondary)', flexShrink: 0 }} />
            <span style={{ flex: 1, wordBreak: 'break-all' }}>{ef.fileName}</span>
            <button
              type="button"
              data-tooltip="Descargar"
              className="btn btn--sm btn--ghost"
              onClick={() => onDownload(ef.id)}
              style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '2px 6px' }}
            >
              <Download size={14} />
            </button>
          </div>
        ))}
      </div>
    ) : (
      <span style={{ fontSize: '13px', color: 'var(--color-text-disabled)' }}>Sin archivos</span>
    )}
  </div>
);

/* ════════════════════════════════════════════
   TaskModal — Main component
   ════════════════════════════════════════════ */
const TaskModal = ({
  isOpen,
  onClose,
  onSubmit,
  onSaveOnly,
  onUploadEvidence,
  onChangeStatus,
  onAssign,
  task,
  loading,
  userRole = 'Gerente',
  userEmail = '',
}) => {
  useEffect(() => {
    const handleEsc = (e) => { if (e.key === 'Escape') onClose(); };
    if (isOpen) document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [isOpen, onClose]);

  const [assigneeList, setAssigneeList] = useState([]);
  const [selectedAssignee, setSelectedAssignee] = useState('');
  const [loadingAssignees, setLoadingAssignees] = useState(false);

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    estimatedTime: '',
    dueDate: '',
    insumos: '',
    evidenceText: '',
    observations: '',
  });
  const [insumoFiles, setInsumoFiles] = useState([]);
  const [evidenceFiles, setEvidenceFiles] = useState([]);
  const [existingInsumoFiles, setExistingInsumoFiles] = useState([]);
  const [existingEvidenceFiles, setExistingEvidenceFiles] = useState([]);
  const [errors, setErrors] = useState({});

  const isEditing = Boolean(task);
  const isGerente = userRole === 'Gerente';
  const isLider = userRole === 'Lider';
  const isColaborador = userRole === 'Colaborador';

  /* ── Determine modal title ── */
  const modalTitle = isColaborador
    ? 'Detalle Tarea'
    : isEditing
      ? 'Editar Tarea'
      : 'Crear Tarea';

  /* ── Determine which role to assign ── */
  const getAssignTarget = () => {
    if (isGerente) return task?.assignedLeaderName ? 'Colaborador' : 'Lider';
    if (isLider) return 'Colaborador';
    return '';
  };

  const getCurrentAssigneeId = () => {
    const target = getAssignTarget();
    if (target === 'Lider') return task?.assignedLeaderId || '';
    return task?.assignedToId || '';
  };

  /* ── Load assignees for Gerente/Lider ── */
  useEffect(() => {
    if (!isOpen || isColaborador) return;
    setLoadingAssignees(true);
    const targetRole = getAssignTarget();
    colaboradorService.getAll()
      .then((data) => {
        const filtered = targetRole
          ? data.filter((c) => {
              const names = c.rolNames || (c.rolName ? [c.rolName] : []);
              return names.includes(targetRole);
            })
          : data;
        setAssigneeList(filtered);
        setSelectedAssignee(getCurrentAssigneeId());
      })
      .catch(() => setAssigneeList([]))
      .finally(() => setLoadingAssignees(false));
  }, [isOpen, task, isColaborador, isGerente, isLider]);

  /* ── Reset form when modal opens ── */
  useEffect(() => {
    if (task) {
      // Format dueDate for datetime-local input
      let dueDateStr = '';
      if (task.dueDate) {
        const d = new Date(task.dueDate);
        dueDateStr = d.getFullYear() + '-' +
          String(d.getMonth() + 1).padStart(2, '0') + '-' +
          String(d.getDate()).padStart(2, '0') + 'T' +
          String(d.getHours()).padStart(2, '0') + ':' +
          String(d.getMinutes()).padStart(2, '0');
      }
      setFormData({
        title: task.title || '',
        description: task.description || '',
        estimatedTime: task.estimatedTime ?? '',
        dueDate: dueDateStr,
        insumos: task.insumos || '',
        evidenceText: task.evidenceText || '',
        observations: task.observations || '',
      });
      setExistingInsumoFiles(task.insumoFiles || []);
      setExistingEvidenceFiles(task.evidenceFiles || []);
    } else {
      setFormData({
        title: '',
        description: '',
        estimatedTime: '',
        dueDate: '',
        insumos: '',
        evidenceText: '',
        observations: '',
      });
      setExistingInsumoFiles([]);
      setExistingEvidenceFiles([]);
    }
    setInsumoFiles([]);
    setEvidenceFiles([]);
    setErrors({});
  }, [task, isOpen]);

  /* ── Validation ── */
  const validate = () => {
    const newErrors = {};

    if (!isColaborador) {
      if (!formData.title.trim()) newErrors.title = 'El titulo es requerido';
      if (!formData.description.trim()) newErrors.description = 'La descripcion es requerida';
    }

    insumoFiles.forEach((f) => {
      if (f.size > MAX_FILE_SIZE)
        newErrors.insumoFile = 'El archivo no debe superar los 20MB';
    });
    evidenceFiles.forEach((f) => {
      if (f.size > MAX_FILE_SIZE)
        newErrors.evidenceFile = 'El archivo no debe superar los 20MB';
    });

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  /* ── Handlers ── */
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) setErrors((prev) => ({ ...prev, [name]: '' }));
  };

  const handleRemoveExistingFile = async (fileId, fileType) => {
    const confirm = await Swal.fire({
      title: 'Eliminar archivo',
      text: '¿Esta seguro de eliminar este archivo?',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#E31837',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, eliminar',
      cancelButtonText: 'Cancelar',
    });
    if (!confirm.isConfirmed) return;

    try {
      await tasksService.removeFile(task.id, fileId, fileType);

      if (fileType === 'insumo') {
        setExistingInsumoFiles((prev) => prev.filter((f) => f.id !== fileId));
      } else {
        setExistingEvidenceFiles((prev) => prev.filter((f) => f.id !== fileId));
      }
      toast.success('Archivo eliminado exitosamente');
    } catch (err) {
      toast.error(`Error al eliminar archivo: ${err.message}`);
    }
  };

  const handleDownloadFile = async (fileId) => {
    try {
      await tasksService.downloadFile(task.id, fileId);
    } catch (err) {
      toast.error(`Error al descargar archivo: ${err.message}`);
    }
  };

  /* ── Build FormData for Lider/Gerente submit ── */
  const buildLiderFormData = () => {
    const data = new FormData();
    data.append('title', formData.title.trim());
    data.append('description', formData.description.trim());
    if (formData.estimatedTime !== '' && formData.estimatedTime !== null) {
      data.append('estimatedTime', formData.estimatedTime);
    }
    if (formData.dueDate) {
      data.append('dueDate', new Date(formData.dueDate).toISOString());
    }
    if (formData.insumos.trim()) {
      data.append('insumos', formData.insumos.trim());
    }
    if (formData.observations.trim()) {
      data.append('observations', formData.observations.trim());
    }
    // Multiple insumo files
    insumoFiles.forEach(f => data.append('InsumoFiles', f));
    /* When creating, include assigneeId if a leader was selected */
    if (!isEditing && selectedAssignee) {
      data.append('assigneeId', selectedAssignee);
    }
    /* Lider can also send evidence */
    if (isLider) {
      if (formData.evidenceText.trim()) {
        data.append('evidenceText', formData.evidenceText.trim());
      }
      // Multiple evidence files
      evidenceFiles.forEach(f => data.append('EvidenceFiles', f));
    }
    return data;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    /* SweetAlert confirmation */
    if (isColaborador) {
      const confirm = await Swal.fire({
        title: 'Guardar evidencia',
        text: '¿Desea guardar la evidencia para esta tarea?',
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#E31837',
        cancelButtonColor: '#6B7280',
        confirmButtonText: 'Si, guardar',
        cancelButtonText: 'Cancelar',
      });
      if (!confirm.isConfirmed) return;

      if (onUploadEvidence) {
        await onUploadEvidence(task.id, evidenceFiles, formData.evidenceText, formData.observations);
      }
      return;
    }

    /* Gerente / Lider — create or update via FormData */
    const confirm = await Swal.fire({
      title: isEditing ? 'Confirmar actualizacion' : 'Confirmar creacion',
      text: isEditing
        ? `Se actualizara la tarea "${formData.title}". ¿Desea continuar?`
        : `Se creara la tarea "${formData.title}". ¿Desea continuar?`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#E31837',
      cancelButtonColor: '#6B7280',
      confirmButtonText: isEditing ? 'Si, actualizar' : 'Si, crear',
      cancelButtonText: 'Cancelar',
    });
    if (!confirm.isConfirmed) return;

    const data = buildLiderFormData();

    onSubmit(data);
  };

  if (!isOpen) return null;

  /* ── Read-only style for Colaborador fields ── */
  const readOnlyStyle = {
    backgroundColor: 'var(--color-bg-main)',
    cursor: 'default',
  };

  /* ── Submit button label ── */
  const submitLabel = loading
    ? 'Guardando...'
    : isColaborador
      ? 'Guardar evidencia'
      : isEditing
        ? 'Actualizar'
        : 'Crear';

  return (
    <>
      <div className={`modal-backdrop ${isOpen ? 'modal-backdrop--open' : ''}`} />
      <div
        className={`modal task-modal ${isOpen ? 'modal--open' : ''}`}
        style={{ maxWidth: '800px', maxHeight: '90vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}
      >
        {/* ── Header ── */}
        <div className="modal__header" style={{ flexDirection: 'column', alignItems: 'stretch', gap: '8px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 className="modal__title">{modalTitle}</h3>
            <button className="modal__close" onClick={onClose} type="button">
              <X size={18} />
            </button>
          </div>
          {/* Assigned leader label — shown when editing and leader is already assigned */}
          {isEditing && (isGerente || isLider) && task?.assignedLeaderName && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{
                fontSize: '10px', fontWeight: 'bold', color: '#6B7280',
                textTransform: 'uppercase', letterSpacing: '0.05em', whiteSpace: 'nowrap',
              }}>
                Lider asignado:
              </span>
              <span className="badge badge--active" style={{ fontSize: '12px' }}>
                {task.assignedLeaderName}
              </span>
            </div>
          )}
          {/* Assign select — Gerente/Lider when creating or editing */}
          {(isGerente || isLider) && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <span style={{
                fontSize: '10px', fontWeight: 'bold', color: '#6B7280',
                textTransform: 'uppercase', letterSpacing: '0.05em', whiteSpace: 'nowrap',
              }}>
                Asignar {getAssignTarget()}:
              </span>
              <select
                className="form-control form-select"
                value={selectedAssignee}
                onChange={async (e) => {
                  setSelectedAssignee(e.target.value);
                  if (isEditing && e.target.value && onAssign) {
                    // Save form data before reassigning
                    if ((isLider || isGerente) && onSaveOnly) {
                      const data = buildLiderFormData();
                      try {
                        await onSaveOnly(data);
                      } catch (err) {
                        return;
                      }
                    }
                    onAssign(task, e.target.value);
                  }
                }}
                disabled={loadingAssignees}
                style={{ flex: 1, height: '32px', fontSize: '13px' }}
              >
                <option value="">
                  {loadingAssignees ? 'Cargando...' : 'Seleccione...'}
                </option>
                {assigneeList.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.nombreCompleto} — {(c.rolNames || []).join(', ')}
                  </option>
                ))}
              </select>
            </div>
          )}
          {/* Show current assignment for Colaborador */}
          {isColaborador && isEditing && (
            <div style={{ display: 'flex', gap: '16px', fontSize: '12px', color: '#6B7280' }}>
              {task?.assignedLeaderName && <span>Lider: <strong>{task.assignedLeaderName}</strong></span>}
            </div>
          )}
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0, overflow: 'hidden' }}>
          <div className="modal__body">
            {/* ── Row 1: Titulo (50%) + Fecha entrega (30%) + Tiempo estimado (20%) ── */}
            <div className="task-modal__row" style={{ display: 'flex', gap: '16px', marginBottom: '16px', flexWrap: 'wrap' }}>
              <div style={{ flex: '1 1 200px', minWidth: 0 }}>
                <Label required={!isColaborador}>Titulo</Label>
                <input
                  type="text"
                  name="title"
                  className={`form-control ${errors.title ? 'form-input--error' : ''}`}
                  value={formData.title}
                  onChange={handleChange}
                  placeholder="Titulo de la tarea"
                  readOnly={isColaborador}
                  style={isColaborador ? readOnlyStyle : undefined}
                />
                {errors.title && (
                  <span className="form-helper form-helper--error">{errors.title}</span>
                )}
              </div>
              <div style={{ flex: '0 1 200px', minWidth: '140px' }}>
                <Label>Fecha entrega</Label>
                <input
                  type="datetime-local"
                  name="dueDate"
                  className="form-control"
                  value={formData.dueDate}
                  onChange={handleChange}
                  readOnly={isColaborador || (isLider && isEditing)}
                  style={(isColaborador || (isLider && isEditing)) ? readOnlyStyle : undefined}
                />
              </div>
              <div style={{ flex: '0 1 120px', minWidth: '100px' }}>
                <Label>&#128339; (h)</Label>
                <input
                  type="number"
                  name="estimatedTime"
                  className="form-control"
                  value={formData.estimatedTime}
                  onChange={handleChange}
                  placeholder="Ej: 8"
                  min="0"
                  step="0.5"
                  readOnly={isColaborador}
                  style={isColaborador ? readOnlyStyle : undefined}
                />
              </div>
            </div>

            {/* ── Row 2: Descripcion (50%) | Insumos texto + Insumo drag&drop (50%) ── */}
            <div className="task-modal__row" style={{ display: 'flex', gap: '16px', marginBottom: '16px', flexWrap: 'wrap' }}>
              {/* Left — Descripcion */}
              <div style={{ flex: '1 1 280px', minWidth: 0 }}>
                <Label required={!isColaborador}>Descripcion</Label>
                <textarea
                  name="description"
                  className={`form-control form-textarea ${errors.description ? 'form-input--error' : ''}`}
                  value={formData.description}
                  onChange={handleChange}
                  placeholder="Descripcion de la tarea"
                  readOnly={isColaborador}
                  style={{
                    height: '240px',
                    resize: 'none',
                    ...(isColaborador ? readOnlyStyle : {}),
                  }}
                />
                {errors.description && (
                  <span className="form-helper form-helper--error">{errors.description}</span>
                )}
              </div>

              {/* Right — Insumos texto (top 50%) + Insumo archivo (bottom 50%) */}
              <div style={{ flex: '1 1 280px', minWidth: 0, display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
                  <Label>Insumos (texto)</Label>
                  <textarea
                    name="insumos"
                    className="form-control form-textarea"
                    value={formData.insumos}
                    onChange={handleChange}
                    placeholder="Descripcion de insumos necesarios"
                    readOnly={isColaborador}
                    style={{
                      flex: 1,
                      resize: 'none',
                      minHeight: '60px',
                      ...(isColaborador ? readOnlyStyle : {}),
                    }}
                  />
                </div>
                <div style={{ flex: 1 }}>
                  {(isGerente || isLider) ? (
                    <FileDropZone
                      label="Archivos de insumo"
                      files={insumoFiles}
                      existingFiles={existingInsumoFiles}
                      onChange={(newFiles, err) => {
                        if (newFiles.length > 0) {
                          setInsumoFiles((prev) => [...prev, ...newFiles]);
                        }
                        setErrors((prev) => ({ ...prev, insumoFile: err || '' }));
                      }}
                      onRemoveNew={(idx) => {
                        setInsumoFiles((prev) => prev.filter((_, i) => i !== idx));
                      }}
                      onRemoveExisting={(fileId) => handleRemoveExistingFile(fileId, 'insumo')}
                      onDownload={handleDownloadFile}
                      error={errors.insumoFile}
                    />
                  ) : (
                    <ReadOnlyFileList
                      label="Archivos de insumo"
                      files={existingInsumoFiles}
                      onDownload={handleDownloadFile}
                    />
                  )}
                </div>
              </div>
            </div>

            {/* ── Row: Observaciones (100%) ── */}
            <div style={{ marginBottom: '16px' }}>
              <Label>Observaciones</Label>
              <textarea
                name="observations"
                className="form-control form-textarea"
                value={formData.observations}
                onChange={handleChange}
                placeholder="Observaciones sobre la tarea"
                style={{ resize: 'none', height: '80px' }}
              />
            </div>

            {/* ── Row 3: Evidencia texto (50%) + Evidencia archivo (50%) ── */}
            <div className="task-modal__row" style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
              {/* Evidencia texto */}
              <div style={{ flex: '1 1 280px', minWidth: 0 }}>
                <Label>Evidencia (texto)</Label>
                <textarea
                  name="evidenceText"
                  className="form-control form-textarea"
                  value={formData.evidenceText}
                  onChange={handleChange}
                  placeholder="Descripcion de la evidencia"
                  readOnly={isGerente}
                  style={{
                    resize: 'none',
                    height: '120px',
                    ...(isGerente ? readOnlyStyle : {}),
                  }}
                />
              </div>

              {/* Evidencia archivo */}
              <div style={{ flex: '1 1 280px', minWidth: 0 }}>
                {isGerente ? (
                  <ReadOnlyFileList
                    label="Archivos de evidencia"
                    files={existingEvidenceFiles}
                    onDownload={handleDownloadFile}
                  />
                ) : (
                  <FileDropZone
                    label="Archivos de evidencia"
                    files={evidenceFiles}
                    existingFiles={existingEvidenceFiles}
                    onChange={(newFiles, err) => {
                      if (newFiles.length > 0) {
                        setEvidenceFiles((prev) => [...prev, ...newFiles]);
                      }
                      setErrors((prev) => ({ ...prev, evidenceFile: err || '' }));
                    }}
                    onRemoveNew={(idx) => {
                      setEvidenceFiles((prev) => prev.filter((_, i) => i !== idx));
                    }}
                    onRemoveExisting={(fileId) => handleRemoveExistingFile(fileId, 'evidence')}
                    onDownload={handleDownloadFile}
                    error={errors.evidenceFile}
                  />
                )}
              </div>
            </div>
          </div>

          {/* ── Footer ── */}
          <div className="modal__footer" style={{ flexWrap: 'wrap', gap: '8px' }}>
            <button
              type="button"
              className="btn btn--secondary"
              onClick={onClose}
              disabled={loading}
            >
              Cancelar
            </button>
            {/* Status transitions for all roles when editing */}
            {isEditing && onChangeStatus && (() => {
              const transitions = [];
              const s = task?.status;
              if (isGerente) {
                if (s === 'Completa - Validada') transitions.push('Completa', 'Reasignada');
              }
              if (isLider) {
                if (s === 'Completa - Por Validar') transitions.push('Completa - Validada', 'Reasignada');
              }
              if (isColaborador) {
                if (s === 'Asignada' || s === 'Reasignada') transitions.push('Completa - Por Validar');
              }
              return transitions.map((newStatus) => (
                <button
                  key={newStatus}
                  type="button"
                  className="btn"
                  disabled={loading}
                  style={{
                    backgroundColor: newStatus === 'Reasignada' ? 'var(--color-warning)' : 'var(--color-success)',
                    color: '#fff',
                    borderColor: newStatus === 'Reasignada' ? 'var(--color-warning)' : 'var(--color-success)',
                  }}
                  onClick={async () => {
                    // Colaborador: always save evidence + observations before status change
                    if (isColaborador && onUploadEvidence) {
                      try {
                        await onUploadEvidence(task.id, evidenceFiles, formData.evidenceText, formData.observations);
                      } catch (e) {
                        return;
                      }
                    }
                    // Lider/Gerente: always save form data before status change
                    if ((isLider || isGerente) && isEditing && onSaveOnly) {
                      const data = buildLiderFormData();
                      try {
                        await onSaveOnly(data);
                      } catch (e) {
                        return;
                      }
                    }
                    onChangeStatus(task, newStatus);
                  }}
                >
                  {newStatus}
                </button>
              ));
            })()}
            <button
              type="submit"
              className={isColaborador ? 'btn' : 'btn btn--primary'}
              disabled={loading}
              style={isColaborador ? { backgroundColor: 'var(--color-success)', color: '#fff', borderColor: 'var(--color-success)' } : {}}
            >
              {submitLabel}
            </button>
          </div>
        </form>
      </div>
    </>
  );
};

export default TaskModal;
