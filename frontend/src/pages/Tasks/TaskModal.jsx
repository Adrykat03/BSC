import { useState, useEffect, useRef, useCallback } from 'react';
import { X, Upload, FileText, Download, Eye, Trash2, CheckCircle, CornerDownLeft, UserCheck, ArrowRightCircle, Eraser, Save, Send, ZoomIn, ZoomOut, RotateCcw } from 'lucide-react';
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

/* Thumbnail para archivos imagen nuevos (aún no guardados en servidor) */
const ImageThumb = ({ file, onClick }) => {
  const [url, setUrl] = useState('');
  useEffect(() => {
    const u = URL.createObjectURL(file);
    setUrl(u);
    return () => URL.revokeObjectURL(u);
  }, [file]);
  if (!url) return <FileText size={16} style={{ color: 'var(--color-text-secondary)', flexShrink: 0 }} />;
  return (
    <img
      src={url}
      alt=""
      onClick={onClick}
      style={{
        width: 36, height: 36, objectFit: 'cover',
        borderRadius: 4, border: '1px solid var(--color-border-main)',
        cursor: onClick ? 'pointer' : 'default', flexShrink: 0,
      }}
    />
  );
};

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
  onPreview,
  onPreviewNew,
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
              {onPreview && (
                <button
                  type="button"
                  data-tooltip="Previsualizar"
                  onClick={() => onPreview(ef.id)}
                  style={{
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    padding: '2px',
                    color: 'var(--color-text-secondary)',
                    flexShrink: 0,
                  }}
                >
                  <Eye size={14} />
                </button>
              )}
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
          {files.map((f, idx) => {
            const isImg = f.type.startsWith('image/');
            return (
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
                {isImg
                  ? <ImageThumb file={f} onClick={onPreviewNew ? () => onPreviewNew(f) : undefined} />
                  : <FileText size={16} style={{ color: 'var(--color-text-secondary)', flexShrink: 0 }} />
                }
                <span style={{ flex: 1, wordBreak: 'break-all' }}>{f.name}</span>
                {isImg && onPreviewNew && (
                  <button
                    type="button"
                    data-tooltip="Previsualizar"
                    onClick={() => onPreviewNew(f)}
                    style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '2px', color: 'var(--color-text-secondary)', flexShrink: 0 }}
                  >
                    <Eye size={14} />
                  </button>
                )}
                <button
                  type="button"
                  data-tooltip="Eliminar"
                  onClick={() => onRemoveNew(idx)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '2px', color: 'var(--color-text-secondary)', flexShrink: 0 }}
                >
                  <Trash2 size={14} />
                </button>
              </div>
            );
          })}
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
const ReadOnlyFileList = ({ files, onPreview, onDownload, label }) => (
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
            {onPreview && (
              <button
                type="button"
                data-tooltip="Previsualizar"
                className="btn btn--sm btn--ghost"
                onClick={() => onPreview(ef.id)}
                style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '2px 6px' }}
              >
                <Eye size={14} />
              </button>
            )}
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

/* ────────────────────────────────────────────
   RatingBar — automatic percentage rating display
   ──────────────────────────────────────────── */
const RatingBar = ({ value }) => {
  if (value == null) return <span style={{ fontSize: '13px', color: 'var(--color-text-disabled)' }}>Pendiente</span>;
  const color = value >= 80 ? '#2E7D32' : value >= 50 ? '#F59E0B' : '#E31837';
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
      <div style={{ flex: 1, height: '8px', background: '#e5e7eb', borderRadius: '4px', overflow: 'hidden', minWidth: '100px' }}>
        <div style={{ width: `${value}%`, height: '100%', background: color, borderRadius: '4px', transition: 'width 300ms' }} />
      </div>
      <span style={{ fontSize: '14px', fontWeight: 700, color, minWidth: '40px' }}>{value}%</span>
    </div>
  );
};

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
  onRatingOverride,
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

  useEffect(() => {
    if (!isOpen) return;
    const handleDocPaste = (e) => {
      const cd = e.clipboardData;
      if (!cd) return;
      // clipboardData.files es más confiable para imágenes pegadas desde el SO
      const raw = cd.files.length
        ? Array.from(cd.files)
        : Array.from(cd.items || [])
            .filter((it) => it.kind === 'file')
            .map((it) => it.getAsFile())
            .filter(Boolean);
      const imageFiles = raw
        .filter((f) => f && f.type.startsWith('image/'))
        .map((f) => {
          const ext = f.type.split('/')[1] || 'png';
          const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
          return new File([f], `imagen-${ts}.${ext}`, { type: f.type });
        });
      if (imageFiles.length > 0) {
        e.preventDefault();
        setEvidenceFiles((prev) => [...prev, ...imageFiles]);
      }
    };
    document.addEventListener('paste', handleDocPaste);
    return () => document.removeEventListener('paste', handleDocPaste);
  }, [isOpen]);

  const [existingInsumoFiles, setExistingInsumoFiles] = useState([]);
  const [existingEvidenceFiles, setExistingEvidenceFiles] = useState([]);
  const [previewData, setPreviewData] = useState(null); // { url, fileName, mimeType }
  const [previewZoom, setPreviewZoom] = useState(100);
  const previewContainerRef = useRef(null);
  const isDragging = useRef(false);
  const dragStart = useRef({ x: 0, y: 0, scrollLeft: 0, scrollTop: 0 });
  const [errors, setErrors] = useState({});

  const [showRatingOverride, setShowRatingOverride] = useState(false);
  const [overrideRatingValue, setOverrideRatingValue] = useState('');
  const [overrideReason, setOverrideReason] = useState('');
  const [savingRatingOverride, setSavingRatingOverride] = useState(false);

  const isEditing = Boolean(task);
  const isGerente = userRole === 'Gerente';
  const isLider = userRole === 'Lider';
  const isColaborador = userRole === 'Colaborador';
  const canOverrideRating = isGerente && isEditing
    && (task?.status === 'Completa - Validada' || task?.status === 'Completa');


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
    setShowRatingOverride(false);
    setOverrideRatingValue('');
    setOverrideReason('');
    setSavingRatingOverride(false);
    if (previewData?.url) window.URL.revokeObjectURL(previewData.url);
    setPreviewData(null);
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
    // No permitir quedarse sin evidencia: bloquear la eliminación del último
    // archivo de evidencia si no hay otro (nuevo o ya guardado) que lo reemplace.
    if (fileType === 'evidence') {
      const remainingExisting = existingEvidenceFiles.filter((f) => f.id !== fileId).length;
      if (remainingExisting === 0 && evidenceFiles.length === 0) {
        Swal.fire({
          title: 'Evidencia requerida',
          text: 'No puede eliminar el único archivo de evidencia. Si desea reemplazarlo, adjunte primero el nuevo archivo.',
          icon: 'warning',
          confirmButtonColor: '#E31837',
        });
        return;
      }
    }

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

  const handlePreviewFile = async (fileId) => {
    try {
      if (previewData?.url) window.URL.revokeObjectURL(previewData.url);
      const data = await tasksService.previewFile(task.id, fileId);
      setPreviewData(data);
      setPreviewZoom(100);
    } catch (err) {
      toast.error(`Error al previsualizar archivo: ${err.message}`);
    }
  };

  const handlePreviewNewFile = (file) => {
    if (previewData?.url) window.URL.revokeObjectURL(previewData.url);
    const url = URL.createObjectURL(file);
    setPreviewData({ url, fileName: file.name, mimeType: file.type });
    setPreviewZoom(100);
  };

  const closePreview = () => {
    if (previewData?.url) window.URL.revokeObjectURL(previewData.url);
    setPreviewData(null);
    setPreviewZoom(100);
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
      // No permitir guardar sin evidencia adjunta (nueva o ya guardada).
      const hasEvidence = evidenceFiles.length > 0 || existingEvidenceFiles.length > 0;
      if (!hasEvidence) {
        Swal.fire({
          title: 'Evidencia requerida',
          text: 'Debe adjuntar al menos un archivo de evidencia para guardar.',
          icon: 'warning',
          confirmButtonColor: '#E31837',
        });
        return;
      }

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
        style={{
          maxWidth: previewData ? '1400px' : '800px',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'row',
          overflow: 'hidden',
          transition: 'max-width 0.3s ease',
        }}
      >
      {/* ── Left panel: form ── */}
      <div style={{ flex: previewData ? '0 0 50%' : '1 1 100%', display: 'flex', flexDirection: 'column', overflow: 'hidden', minWidth: 0, transition: 'flex 0.3s ease' }}>
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
                      onPreview={handlePreviewFile}
                      onDownload={handleDownloadFile}
                      error={errors.insumoFile}
                    />
                  ) : (
                    <ReadOnlyFileList
                      label="Archivos de insumo"
                      files={existingInsumoFiles}
                      onPreview={handlePreviewFile}
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

            {/* ── Row: Calificacion (con override por Gerente) ── */}
            {isEditing && (task?.rating != null || canOverrideRating) && (
              <div style={{ marginBottom: '16px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                  <Label style={{ marginBottom: 0 }}>Calificacion</Label>
                  {task?.ratingOverride != null && (
                    <span
                      title={task.ratingOverrideReason ? `Justificación: ${task.ratingOverrideReason}` : 'Modificada por Gerencia'}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '4px',
                        padding: '2px 8px',
                        background: '#FEF3C7',
                        color: '#92400E',
                        fontSize: '10px',
                        fontWeight: 600,
                        textTransform: 'uppercase',
                        letterSpacing: '0.05em',
                        borderRadius: '999px',
                      }}
                    >
                      Modificada por Gerencia
                    </span>
                  )}
                </div>
                {task?.rating != null && <RatingBar value={task.rating} />}

                {canOverrideRating && !showRatingOverride && (
                  <button
                    type="button"
                    className="btn btn--secondary btn--sm"
                    style={{ marginTop: '10px' }}
                    onClick={() => {
                      setOverrideRatingValue(task?.rating != null ? String(task.rating) : '');
                      setOverrideReason('');
                      setShowRatingOverride(true);
                    }}
                  >
                    Modificar calificación
                  </button>
                )}

                {canOverrideRating && showRatingOverride && (
                  <div
                    style={{
                      marginTop: '12px',
                      padding: '14px 16px',
                      background: '#F9FAFB',
                      border: '1px solid #E5E7EB',
                      borderRadius: '8px',
                    }}
                  >
                    <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', marginBottom: '10px' }}>
                      <div style={{ flex: '0 0 140px' }}>
                        <Label>Nueva calificación (0-100)</Label>
                        <input
                          type="number"
                          className="form-control"
                          min={0}
                          max={100}
                          step={1}
                          value={overrideRatingValue}
                          onChange={(e) => setOverrideRatingValue(e.target.value)}
                          disabled={savingRatingOverride}
                          placeholder="0-100"
                        />
                      </div>
                      <div style={{ flex: '1 1 240px', minWidth: 0 }}>
                        <Label>Justificación (mínimo 10 caracteres)</Label>
                        <textarea
                          className="form-control form-textarea"
                          rows={3}
                          maxLength={1000}
                          value={overrideReason}
                          onChange={(e) => setOverrideReason(e.target.value)}
                          disabled={savingRatingOverride}
                          placeholder="Explica por qué se modifica la calificación..."
                          style={{ resize: 'vertical', minHeight: '70px' }}
                        />
                        <small style={{ display: 'block', textAlign: 'right', fontSize: '11px', color: '#6B7280', marginTop: '2px' }}>
                          {overrideReason.length} / 1000
                        </small>
                      </div>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
                      <button
                        type="button"
                        className="btn btn--secondary btn--sm"
                        onClick={() => {
                          setShowRatingOverride(false);
                          setOverrideRatingValue('');
                          setOverrideReason('');
                        }}
                        disabled={savingRatingOverride}
                      >
                        Cancelar
                      </button>
                      <button
                        type="button"
                        className="btn btn--primary btn--sm"
                        disabled={
                          savingRatingOverride ||
                          overrideRatingValue === '' ||
                          isNaN(Number(overrideRatingValue)) ||
                          Number(overrideRatingValue) < 0 ||
                          Number(overrideRatingValue) > 100 ||
                          overrideReason.trim().length < 10
                        }
                        onClick={async () => {
                          if (!onRatingOverride) return;
                          try {
                            setSavingRatingOverride(true);
                            await onRatingOverride(task, {
                              newRating: Number(overrideRatingValue),
                              reason: overrideReason.trim(),
                            });
                            setShowRatingOverride(false);
                            setOverrideRatingValue('');
                            setOverrideReason('');
                          } finally {
                            setSavingRatingOverride(false);
                          }
                        }}
                      >
                        {savingRatingOverride ? 'Guardando...' : 'Guardar calificación'}
                      </button>
                    </div>
                    {task?.ratingHistory && task.ratingHistory.length > 0 && (
                      <details style={{ marginTop: '12px' }}>
                        <summary style={{ cursor: 'pointer', fontSize: '12px', color: '#6B7280', fontWeight: 500 }}>
                          Historial de modificaciones ({task.ratingHistory.length})
                        </summary>
                        <ul style={{ margin: '8px 0 0 0', padding: '0 0 0 16px', fontSize: '12px', color: '#374151' }}>
                          {[...task.ratingHistory].reverse().map((h, i) => (
                            <li key={i} style={{ marginBottom: '6px' }}>
                              <strong>{h.fromRating != null ? `${h.fromRating}%` : '—'} → {h.toRating}%</strong>{' '}
                              por {h.changedByName || h.changedByEmail}{' '}
                              ({new Date(h.changedAt).toLocaleString('es-ES')})
                              {h.reason && <div style={{ color: '#6B7280', fontStyle: 'italic' }}>{h.reason}</div>}
                            </li>
                          ))}
                        </ul>
                      </details>
                    )}
                  </div>
                )}
              </div>
            )}

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
                  placeholder="Descripcion de la evidencia · Ctrl+V para pegar imagen"
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
                    onPreview={handlePreviewFile}
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
                    onPreview={handlePreviewFile}
                    onPreviewNew={handlePreviewNewFile}
                    onDownload={handleDownloadFile}
                    error={errors.evidenceFile}
                  />
                )}
              </div>
            </div>
          </div>

          {/* ── Footer toolbar ── */}
          <div className="modal__footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px', padding: '12px 24px' }}>
            {/* Left: close */}
            <button
              type="button"
              className="btn btn--secondary btn--sm"
              onClick={onClose}
              disabled={loading}
              title="Cerrar sin guardar"
              style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}
            >
              <X size={16} /> Cerrar
            </button>

            {/* Right: action toolbar */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              {/* Status transitions */}
              {isEditing && onChangeStatus && (() => {
                const buttons = [];
                const s = task?.status;

                if (isGerente) {
                  if (s === 'Completa - Validada') {
                    buttons.push({ icon: <CheckCircle size={16} />, title: 'Marcar como Completa', status: 'Completa', color: 'var(--color-success)' });
                    buttons.push({ icon: <CornerDownLeft size={16} />, title: 'Devolver al Lider (Completa - Por Validar)', status: 'Completa - Por Validar', color: 'var(--color-warning)' });
                    buttons.push({ icon: <><CornerDownLeft size={16} /><UserCheck size={16} /></>, title: 'Devolver al Colaborador (Reasignada)', status: 'Reasignada', color: 'var(--color-warning)' });
                  }
                  if (['Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada'].includes(s)) {
                    buttons.push({ icon: <Trash2 size={16} />, title: 'Cancelar tarea', status: 'Cancelada', color: 'var(--color-error)' });
                  }
                }

                if (isLider) {
                  if (s === 'Completa - Por Validar') {
                    buttons.push({ icon: <CheckCircle size={16} />, title: 'Validar y enviar al Gerente', status: 'Completa - Validada', color: '#3B82F6' });
                    buttons.push({ icon: <CornerDownLeft size={16} />, title: 'Reasignar al Colaborador', status: 'Reasignada', color: 'var(--color-warning)' });
                  }
                }

                if (isColaborador) {
                  if (s === 'Asignada' || s === 'Reasignada') {
                    buttons.push({ icon: <Send size={16} />, title: 'Enviar a validacion', status: 'Completa - Por Validar', color: 'var(--color-success)' });
                  }
                }

                return buttons.map((btn) => (
                  <button
                    key={btn.status + btn.title}
                    type="button"
                    className="btn btn--sm"
                    disabled={loading}
                    title={btn.title}
                    data-tooltip={btn.title}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '3px',
                      backgroundColor: btn.color,
                      color: '#fff',
                      borderColor: btn.color,
                      padding: '6px 10px',
                    }}
                    onClick={async () => {
                      // El colaborador no puede enviar a validación sin evidencia adjunta
                      // (cuenta tanto la evidencia recién añadida como la ya guardada).
                      if (isColaborador && btn.status === 'Completa - Por Validar') {
                        const hasEvidence = evidenceFiles.length > 0 || existingEvidenceFiles.length > 0;
                        if (!hasEvidence) {
                          Swal.fire({
                            title: 'Evidencia requerida',
                            text: 'Debe adjuntar al menos un archivo de evidencia antes de enviar la tarea a validación.',
                            icon: 'warning',
                            confirmButtonColor: '#E31837',
                          });
                          return;
                        }
                      }
                      if (isColaborador && onUploadEvidence) {
                        try {
                          await onUploadEvidence(task.id, evidenceFiles, formData.evidenceText, formData.observations);
                        } catch (e) {
                          return;
                        }
                      }
                      if ((isLider || isGerente) && isEditing && onSaveOnly) {
                        const data = buildLiderFormData();
                        try {
                          await onSaveOnly(data);
                        } catch (e) {
                          return;
                        }
                      }
                      onChangeStatus(task, btn.status);
                    }}
                  >
                    {btn.icon}
                  </button>
                ));
              })()}

              {/* Separator when there are transition buttons */}
              {isEditing && onChangeStatus && (() => {
                const s = task?.status;
                const hasTransitions =
                  (isGerente && (s === 'Completa - Validada' || ['Asignada', 'Completa - Por Validar', 'Reasignada'].includes(s))) ||
                  (isLider && s === 'Completa - Por Validar') ||
                  (isColaborador && (s === 'Asignada' || s === 'Reasignada'));
                return hasTransitions ? <div style={{ width: '1px', height: '24px', backgroundColor: 'var(--color-border-main)', margin: '0 4px' }} /> : null;
              })()}

              {/* Save / Submit */}
              <button
                type="submit"
                className="btn btn--sm"
                disabled={loading}
                title={isColaborador ? 'Guardar evidencia y observaciones' : isEditing ? 'Guardar cambios de la tarea' : 'Crear nueva tarea'}
                data-tooltip="Guardar cambios"
                style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '6px 12px', backgroundColor: '#1B2A4A', color: '#fff', border: 'none' }}
              >
                <Save size={16} />
              </button>
            </div>
          </div>
        </form>
      </div>

      {/* ── Right panel: file preview ── */}
      {previewData && (
        <div style={{
          flex: '0 0 50%',
          display: 'flex',
          flexDirection: 'column',
          borderLeft: '1px solid var(--color-border-main)',
          background: '#f9fafb',
          minWidth: 0,
          overflow: 'hidden',
        }}>
          {/* Preview header: filename + zoom controls + close */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '8px 12px',
            borderBottom: '1px solid var(--color-border-main)',
            background: '#fff',
            flexShrink: 0,
          }}>
            <span style={{ flex: 1, fontSize: '13px', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {previewData.fileName}
            </span>
            {/* Zoom controls — only for images (PDFs have their own viewer controls) */}
            {previewData.mimeType?.startsWith('image/') && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '2px', flexShrink: 0 }}>
                <button type="button" data-tooltip="Alejar" onClick={() => setPreviewZoom((z) => Math.max(25, z - 25))}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '4px', color: 'var(--color-text-secondary)', display: 'flex' }}>
                  <ZoomOut size={16} />
                </button>
                <span style={{ fontSize: '12px', fontWeight: 600, minWidth: '42px', textAlign: 'center', color: 'var(--color-text-secondary)', userSelect: 'none' }}>
                  {previewZoom}%
                </span>
                <button type="button" data-tooltip="Acercar" onClick={() => setPreviewZoom((z) => Math.min(400, z + 25))}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '4px', color: 'var(--color-text-secondary)', display: 'flex' }}>
                  <ZoomIn size={16} />
                </button>
                <button type="button" data-tooltip="Restablecer zoom" onClick={() => setPreviewZoom(100)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '4px', color: 'var(--color-text-secondary)', display: 'flex' }}>
                  <RotateCcw size={14} />
                </button>
              </div>
            )}
            <button type="button" onClick={closePreview} data-tooltip="Cerrar vista previa"
              style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '4px', color: 'var(--color-text-secondary)', flexShrink: 0, display: 'flex' }}>
              <X size={16} />
            </button>
          </div>

          {/* Preview content area */}
          {previewData.mimeType?.startsWith('image/') ? (
            <div
              ref={previewContainerRef}
              style={{
                flex: 1,
                overflow: 'auto',
                cursor: isDragging.current ? 'grabbing' : previewZoom > 100 ? 'grab' : 'default',
                userSelect: 'none',
              }}
              onWheel={(e) => {
                if (e.ctrlKey) {
                  e.preventDefault();
                  setPreviewZoom((z) => Math.min(400, Math.max(25, z + (e.deltaY < 0 ? 25 : -25))));
                }
              }}
              onMouseDown={(e) => {
                if (e.button !== 0) return;
                const el = previewContainerRef.current;
                if (!el) return;
                isDragging.current = true;
                dragStart.current = { x: e.clientX, y: e.clientY, scrollLeft: el.scrollLeft, scrollTop: el.scrollTop };
                el.style.cursor = 'grabbing';
              }}
              onMouseMove={(e) => {
                if (!isDragging.current) return;
                const el = previewContainerRef.current;
                if (!el) return;
                el.scrollLeft = dragStart.current.scrollLeft - (e.clientX - dragStart.current.x);
                el.scrollTop = dragStart.current.scrollTop - (e.clientY - dragStart.current.y);
              }}
              onMouseUp={() => {
                isDragging.current = false;
                const el = previewContainerRef.current;
                if (el) el.style.cursor = previewZoom > 100 ? 'grab' : 'default';
              }}
              onMouseLeave={() => {
                isDragging.current = false;
                const el = previewContainerRef.current;
                if (el) el.style.cursor = previewZoom > 100 ? 'grab' : 'default';
              }}
            >
              <div style={{
                width: `${previewZoom}%`,
                minHeight: '100%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                padding: '16px',
                boxSizing: 'border-box',
                margin: previewZoom <= 100 ? '0 auto' : '0',
                transition: 'width 0.15s ease',
              }}>
                <img
                  src={previewData.url}
                  alt={previewData.fileName}
                  draggable={false}
                  style={{
                    width: '100%',
                    height: 'auto',
                    display: 'block',
                    borderRadius: '4px',
                  }}
                />
              </div>
            </div>
          ) : previewData.mimeType === 'application/pdf' ? (
            <iframe
              src={previewData.url}
              title={previewData.fileName}
              style={{ flex: 1, width: '100%', border: 'none' }}
            />
          ) : (
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '32px', textAlign: 'center', color: 'var(--color-text-secondary)' }}>
              <div>
                <FileText size={48} style={{ marginBottom: '12px', opacity: 0.4 }} />
                <p style={{ fontSize: '13px', margin: '0 0 12px' }}>
                  Vista previa no disponible para este tipo de archivo.
                </p>
                <button type="button" className="btn btn--sm btn--primary"
                  onClick={() => { const a = document.createElement('a'); a.href = previewData.url; a.download = previewData.fileName; a.click(); }}>
                  <Download size={14} /> Descargar
                </button>
              </div>
            </div>
          )}
        </div>
      )}
      </div>
    </>
  );
};

export default TaskModal;
