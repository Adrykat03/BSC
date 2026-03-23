import { useState, useEffect, useCallback, useContext, useRef } from 'react';
import {
  Plus, Pencil, Trash2, ClipboardList, ChevronLeft, ChevronRight,
  Eye, Search, History, Undo2, Download, FileSpreadsheet, Upload,
} from 'lucide-react';
import * as XLSX from 'xlsx';
import Swal from 'sweetalert2';
import toast, { Toaster } from 'react-hot-toast';
import { tasksService } from '../../services/tasksService';
import { colaboradorService } from '../../services/colaboradorService';
import SessionContext from '../../context/SessionContext';
import TaskModal from './TaskModal';
import './Tasks.css';

const PAGE_SIZE = 20;

const STATUS_BADGE_MAP = {
  'Creada': 'badge badge--inactive',
  'Asignada': 'badge badge--draft',
  'Completa - Por Validar': 'badge badge--editing',
  'Reasignada': 'badge badge--blocked',
  'Completa - Validada': 'badge badge--active',
  'Completa': 'badge badge--published',
  'Cancelada': 'badge badge--error',
};

const getBadgeClass = (status) => STATUS_BADGE_MAP[status] || 'badge badge--inactive';

/** Returns valid next statuses based on current status, role and deadline */
const getStatusTransitions = (currentStatus, role) => {
  if (role === 'Gerente') {
    if (currentStatus === 'Completa - Validada') return ['Completa', 'Reasignada'];
    if (['Asignada', 'Completa - Por Validar', 'Reasignada'].includes(currentStatus)) return ['Cancelada'];
  }
  if (role === 'Lider') {
    if (currentStatus === 'Completa - Por Validar') return ['Completa - Validada', 'Reasignada'];
  }
  if (role === 'Colaborador') {
    if (currentStatus === 'Asignada' || currentStatus === 'Reasignada') return ['Completa - Por Validar'];
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

  // Detail view modal (Colaborador)
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [detailTask, setDetailTask] = useState(null);

  // Row selection (visual only)
  const [selectedRowId, setSelectedRowId] = useState(null);

  // Bulk upload file input ref
  const bulkFileInputRef = useRef(null);

  // Search debounce ref
  const searchDebounceRef = useRef(null);
  const searchRef = useRef('');

  // History modal
  const [historyModalOpen, setHistoryModalOpen] = useState(false);
  const [historyTask, setHistoryTask] = useState(null);

  // Filters
  const [searchText, setSearchText] = useState('');
  const [filterStatus, setFilterStatus] = useState(''); // '' = todas
  const [filterDate, setFilterDate] = useState(''); // '' = todas, 'hoy', 'ayer', 'semana'

  // Close inline modals with Escape
  useEffect(() => {
    const handleEsc = (e) => {
      if (e.key === 'Escape') {
        if (historyModalOpen) { setHistoryModalOpen(false); setHistoryTask(null); }
      }
    };
    document.addEventListener('keydown', handleEsc);
    return () => document.removeEventListener('keydown', handleEsc);
  }, [historyModalOpen]);

  const isGerente = role === 'Gerente';
  const isLider = role === 'Lider';
  const isColaborador = role === 'Colaborador';

  const loadTasks = useCallback(async (currentPage = 1, search) => {
    try {
      setLoading(true);
      setError(null);
      const searchValue = search !== undefined ? search : searchRef.current;
      if (search !== undefined) {
        searchRef.current = search;
      }
      const data = await tasksService.getAll(currentPage, PAGE_SIZE, searchValue);
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

    try {
      setSaving(true);
      if (isEditing) {
        formData.append('updatedByEmail', email);
        await tasksService.update(selectedTask.id, formData);
        toast.success('Tarea actualizada exitosamente');
      } else {
        formData.append('createdByEmail', email);
        const result = await tasksService.create(formData);
        toast.success('Tarea creada exitosamente');
        // If a leader was selected during creation, assign immediately
        const assigneeId = formData.get('assigneeId');
        if (assigneeId && result?.data?.id) {
          try {
            await tasksService.assignTask(result.data.id, { assigneeId });
            toast.success('Lider asignado exitosamente');
          } catch (assignErr) {
            toast.error(`Tarea creada pero error al asignar lider: ${assignErr.message}`);
          }
        }
      }
      closeModal();
      await loadTasks(isEditing ? page : 1);
    } catch (err) {
      toast.error(`Error al ${isEditing ? 'actualizar' : 'crear'} la tarea: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  // ---- Save only (no close modal) — used by status buttons ----
  const handleSaveOnly = async (formData) => {
    try {
      if (selectedTask) {
        formData.append('updatedByEmail', email);
        await tasksService.update(selectedTask.id, formData);
      }
    } catch (err) {
      toast.error(`Error al guardar: ${err.message}`);
      throw err;
    }
  };

  // ---- Delete or Cancel (Gerente only) ----
  const handleDelete = async (task) => {
    const isNotAssigned = !task.assignedLeaderId && !task.assignedToId;
    const title = isNotAssigned ? 'Eliminar tarea' : 'Cancelar tarea';
    const text = isNotAssigned
      ? `¿Esta seguro de eliminar la tarea "${task.title}"? Esta accion no se puede deshacer.`
      : `¿Esta seguro de cancelar la tarea "${task.title}"? Pasara a estado Cancelada.`;
    const confirmText = isNotAssigned ? 'Si, eliminar' : 'Si, cancelar';

    const result = await Swal.fire({
      title,
      text,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#6B7280',
      confirmButtonText: confirmText,
      cancelButtonText: 'Volver',
    });
    if (!result.isConfirmed) return;

    try {
      if (isNotAssigned) {
        await tasksService.delete(task.id);
        toast.success('Tarea eliminada exitosamente');
      } else {
        await tasksService.changeStatus(task.id, {
          newStatus: 'Cancelada',
          comment: 'Tarea cancelada por el Gerente',
        });
        toast.success('Tarea cancelada exitosamente');
      }
      const newPage = tasks.length === 1 && page > 1 ? page - 1 : page;
      await loadTasks(newPage);
    } catch (err) {
      toast.error(`Error: ${err.message}`);
    }
  };

  // ---- Restore cancelled task (Gerente only) ----
  const handleRestore = async (task) => {
    // Find the last status before cancellation from statusHistory
    let previousStatus = 'Creada'; // fallback
    if (task.statusHistory && task.statusHistory.length > 0) {
      // Find the last entry where toStatus is 'Cancelada'
      const cancelEntry = [...task.statusHistory].reverse().find(e => e.toStatus === 'Cancelada');
      if (cancelEntry) {
        previousStatus = cancelEntry.fromStatus;
      }
    }

    const result = await Swal.fire({
      title: 'Restaurar tarea',
      text: `¿Restaurar "${task.title}" al estado "${previousStatus}"?`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#E31837',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, restaurar',
      cancelButtonText: 'Cancelar',
    });
    if (!result.isConfirmed) return;

    try {
      await tasksService.changeStatus(task.id, {
        newStatus: previousStatus,
        comment: `Tarea restaurada desde Cancelada a ${previousStatus}`,
      });
      toast.success(`Tarea restaurada a "${previousStatus}"`);
      await loadTasks(page);
    } catch (err) {
      toast.error(`Error al restaurar: ${err.message}`);
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
        targetRole = task.assignedLeaderName ? 'Colaborador' : 'Lider';
      } else if (isLider) {
        targetRole = 'Colaborador';
      }
      const filtered = targetRole
        ? data.filter((c) => {
            const names = c.rolNames || (c.rolName ? [c.rolName] : []);
            return names.includes(targetRole);
          })
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
      await tasksService.uploadEvidence(evidenceTask.id, evidenceFile);
      toast.success('Evidencia subida exitosamente');
      setEvidenceModalOpen(false);
      setEvidenceTask(null);
      setEvidenceFile(null);
      await loadTasks(page);
    } catch (err) {
      toast.error(`Error al subir evidencia: ${err.message}`);
    }
  };

  // Downloads are now handled inside the TaskModal via tasksService.downloadFile

  const formatTime = (hours) => {
    if (hours === null || hours === undefined || hours === '') return '-';
    return `${hours}h`;
  };

  /**
   * Urgency based on dueDate and estimatedTime.
   * - timeToDeadline: ms until dueDate
   * - estimatedMs: estimatedTime in ms
   * - level: 'normal' (timeToDeadline > 2x estimated), 'warning' (1x-2x estimated), 'danger' (<= estimated)
   */
  const getUrgency = (task) => {
    if (!task.dueDate) return { level: 'normal', dueDate: null };
    if (['Completa', 'Completa - Validada'].includes(task.status)) return { level: 'normal', dueDate: task.dueDate };
    const deadline = new Date(task.dueDate).getTime();
    const now = Date.now();
    const timeToDeadline = deadline - now;
    const estimatedMs = (task.estimatedTime || 0) * 60 * 60 * 1000;
    let level = 'normal';
    if (estimatedMs > 0) {
      if (timeToDeadline <= estimatedMs) level = 'danger';
      else if (timeToDeadline <= estimatedMs * 2) level = 'warning';
    } else {
      // No estimated time — just check if overdue
      if (timeToDeadline <= 0) level = 'danger';
    }
    return { level, dueDate: task.dueDate };
  };

  const getRowBgColor = (level) => {
    if (level === 'danger') return 'rgba(239,68,68,0.08)';
    if (level === 'warning') return 'rgba(245,158,11,0.08)';
    return undefined;
  };

  const formatDueDate = (dueDate) => {
    if (!dueDate) return '-';
    const d = new Date(dueDate);
    return d.toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' }) +
      ' ' + d.toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' });
  };

  // ---- Export XLSX ----
  const handleExportXlsx = () => {
    const rows = filteredTasks.map((t) => ({
      'Titulo': t.title || '',
      'Descripcion': t.description || '',
      'Estado': t.status || '',
      'Lider asignado': t.assignedLeaderName || '',
      'Colaborador asignado': t.assignedToName || '',
      'Fecha de entrega': t.dueDate ? new Date(t.dueDate).toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '',
      'Tiempo estimado (h)': t.estimatedTime ?? '',
      'Tiempo real (h)': t.actualTime ?? '',
      'Observaciones': t.observations || '',
      'Fecha de creacion': t.createdAt ? new Date(t.createdAt).toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '',
    }));

    const ws = XLSX.utils.json_to_sheet(rows);
    // Auto-size columns
    const colWidths = Object.keys(rows[0] || {}).map((key) => ({
      wch: Math.max(key.length, ...rows.map((r) => String(r[key]).length)) + 2,
    }));
    ws['!cols'] = colWidths;

    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Tareas');
    XLSX.writeFile(wb, `Tareas_${new Date().toISOString().slice(0, 10)}.xlsx`);
  };

  // ---- Download template XLSX ----
  const handleDownloadTemplate = async () => {
    try {
      // Sheet 1: template with headers + example row
      const templateHeaders = [
        'Titulo', 'Descripcion', 'Fecha de entrega (DD/MM/AAAA HH:mm)',
        'Tiempo estimado (h)', 'Insumos', 'Observaciones',
        'Email lider', 'Email colaborador',
      ];
      const exampleRow = [
        'Tarea de ejemplo (eliminar esta fila)', 'Descripción de ejemplo',
        '25/03/2026 14:30', '8', 'Documentos necesarios', 'Sin observaciones', '', '',
      ];
      const wsTemplate = XLSX.utils.aoa_to_sheet([templateHeaders, exampleRow]);
      wsTemplate['!cols'] = templateHeaders.map((h) => ({ wch: Math.max(h.length + 2, 20) }));

      // Sheet 2: collaborators list
      const allColabs = await colaboradorService.getAll();
      const colabRows = allColabs.map((c) => ({
        'Nombre completo': c.nombreCompleto || '',
        'Correo': c.correo || '',
        'Rol': (c.rolNames || (c.rolName ? [c.rolName] : [])).join(', '),
      }));
      const wsColabs = XLSX.utils.json_to_sheet(colabRows.length > 0 ? colabRows : [{ 'Nombre completo': '', 'Correo': '', 'Rol': '' }]);
      if (colabRows.length > 0) {
        const colabKeys = Object.keys(colabRows[0]);
        wsColabs['!cols'] = colabKeys.map((key) => ({
          wch: Math.max(key.length, ...colabRows.map((r) => String(r[key]).length)) + 2,
        }));
      }

      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, wsTemplate, 'Tareas');
      XLSX.utils.book_append_sheet(wb, wsColabs, 'Colaboradores');
      XLSX.writeFile(wb, 'Plantilla_Carga_Tareas.xlsx');
    } catch (err) {
      toast.error(`Error al generar plantilla: ${err.message}`);
    }
  };

  // ---- Bulk upload XLSX ----
  const handleBulkFileChange = async (e) => {
    const file = e.target.files?.[0];
    // Reset the input so the same file can be selected again
    if (bulkFileInputRef.current) bulkFileInputRef.current.value = '';
    if (!file) return;

    try {
      const data = await file.arrayBuffer();
      const workbook = XLSX.read(data, { type: 'array' });
      const sheetName = workbook.SheetNames[0];
      const sheet = workbook.Sheets[sheetName];
      const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

      if (rows.length === 0) {
        toast.error('El archivo no contiene tareas.');
        e.target.value = '';
        return;
      }

      if (rows.length > 100) {
        toast.error('El archivo excede el limite de 100 tareas por carga.');
        e.target.value = '';
        return;
      }

      // Map rows to task objects
      const tasks = rows.map((row, idx) => {
        // Parse date: supports DD/MM/YYYY HH:mm, DD/MM/YYYY, and Excel serial numbers
        let dueDate = null;
        const rawDate = row['Fecha de entrega (DD/MM/AAAA HH:mm)'] ?? row['Fecha de entrega (DD/MM/AAAA)'] ?? '';
        const rawDateStr = String(rawDate).trim();
        if (rawDateStr) {
          let parsed = null;
          // Check if it's an Excel serial number (numeric value)
          if (!isNaN(rawDate) && Number(rawDate) > 0) {
            const excelDate = XLSX.SSF.parse_date_code(Number(rawDate));
            if (excelDate) {
              parsed = new Date(excelDate.y, excelDate.m - 1, excelDate.d, excelDate.H || 0, excelDate.M || 0, excelDate.S || 0);
            }
          }
          // Try DD/MM/YYYY HH:mm format
          if (!parsed) {
            const partsWithTime = rawDateStr.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\s+(\d{1,2}):(\d{2})$/);
            if (partsWithTime) {
              const [, day, month, year, hours, minutes] = partsWithTime;
              parsed = new Date(Number(year), Number(month) - 1, Number(day), Number(hours), Number(minutes));
            }
          }
          // Try DD/MM/YYYY format (no time)
          if (!parsed) {
            const partsDateOnly = rawDateStr.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
            if (partsDateOnly) {
              const [, day, month, year] = partsDateOnly;
              parsed = new Date(Number(year), Number(month) - 1, Number(day), 0, 0);
            }
          }
          if (parsed && !isNaN(parsed.getTime())) {
            dueDate = parsed.toISOString();
          }
        }

        const estimatedRaw = row['Tiempo estimado (h)'];
        const estimatedTime = estimatedRaw !== '' ? Number(estimatedRaw) : null;

        return {
          title: String(row['Titulo'] || '').trim(),
          description: String(row['Descripcion'] || '').trim(),
          dueDate,
          estimatedTime: isNaN(estimatedTime) ? null : estimatedTime,
          insumos: String(row['Insumos'] || '').trim(),
          observations: String(row['Observaciones'] || '').trim(),
          leaderEmail: String(row['Email lider'] || '').trim(),
          collaboratorEmail: String(row['Email colaborador'] || '').trim(),
        };
      });

      // Validate emails (must be email format, not names)
      const escapeHtml = (str) => String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      const emailErrors = [];
      tasks.forEach((t, idx) => {
        if (t.leaderEmail && !emailRegex.test(t.leaderEmail)) {
          emailErrors.push(`Fila ${idx + 2}: "Email lider" no es un email valido ("${escapeHtml(t.leaderEmail)}"). Debe ser un correo electronico, no un nombre.`);
        }
        if (t.collaboratorEmail && !emailRegex.test(t.collaboratorEmail)) {
          emailErrors.push(`Fila ${idx + 2}: "Email colaborador" no es un email valido ("${escapeHtml(t.collaboratorEmail)}"). Debe ser un correo electronico, no un nombre.`);
        }
      });
      if (emailErrors.length > 0) {
        Swal.fire({
          title: 'Emails invalidos',
          html: `<p style="margin-bottom:8px">Las columnas de email deben contener correos electronicos (ej: usuario@empresa.com), no nombres.</p><ul style="text-align:left;max-height:300px;overflow:auto;font-size:13px;">${emailErrors.map((e) => `<li>${e}</li>`).join('')}</ul>`,
          icon: 'error',
          confirmButtonColor: '#E31837',
        });
        return;
      }

      // Confirm
      const confirm = await Swal.fire({
        title: 'Carga masiva de tareas',
        text: `Se cargaran ${tasks.length} tareas. ¿Continuar?`,
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#E31837',
        cancelButtonColor: '#6B7280',
        confirmButtonText: 'Si, cargar',
        cancelButtonText: 'Cancelar',
      });
      if (!confirm.isConfirmed) return;

      const result = await tasksService.bulkCreate(tasks);
      const created = result?.totalCreated ?? result?.created ?? result?.successCount ?? 0;
      const failed = result?.totalFailed ?? result?.failed ?? result?.failCount ?? 0;
      const errors = result?.results?.filter((r) => !r.success) ?? result?.errors ?? [];

      if (failed === 0) {
        toast.success(`${created} tareas creadas exitosamente.`);
      } else {
        toast.error(`${created} tareas creadas, ${failed} fallidas.`);
        // Show error details
        if (errors.length > 0) {
          const esc = (str) => String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
          const errorHtml = errors
            .map((e) => `<li>Fila ${e.row ?? e.index ?? '?'}: ${esc(e.message ?? e.error ?? 'Error desconocido')}</li>`)
            .join('');
          Swal.fire({
            title: 'Errores en carga masiva',
            html: `<ul style="text-align:left;max-height:300px;overflow:auto;font-size:13px;">${errorHtml}</ul>`,
            icon: 'warning',
            confirmButtonColor: '#E31837',
          });
        }
      }

      await loadTasks(1);
    } catch (err) {
      toast.error(`Error al procesar archivo: ${err.message}`);
    }
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

  // ---- Filter logic (client-side on loaded data) ----
  const VISIBLE_STATUSES = (() => {
    if (isGerente) return ['Creada', 'Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada', 'Completa', 'Cancelada'];
    if (isLider) return ['Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada'];
    if (isColaborador) return ['Asignada', 'Completa - Por Validar', 'Reasignada'];
    return [];
  })();
  const DATE_OPTIONS = [
    { value: '', label: 'Todas' },
    { value: 'hoy', label: 'Hoy' },
    { value: 'ayer', label: 'Ayer' },
    { value: 'semana', label: 'Esta semana' },
  ];

  const matchesDate = (task) => {
    if (!filterDate) return true;
    const created = new Date(task.createdAt);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1);
    const weekStart = new Date(today); weekStart.setDate(weekStart.getDate() - today.getDay());
    if (filterDate === 'hoy') return created >= today;
    if (filterDate === 'ayer') return created >= yesterday && created < today;
    if (filterDate === 'semana') return created >= weekStart;
    return true;
  };

  const filteredTasks = tasks.filter((task) => {
    const beforeDeadline = !task.dueDate || new Date() < new Date(task.dueDate);

    if (isColaborador) {
      // Colaborador ve: Asignada, Reasignada y CPV siempre; puede avanzar aunque venza la fecha
      const allowed = ['Asignada', 'Reasignada', 'Completa - Por Validar'];
      if (!allowed.includes(task.status)) return false;
    } else if (isLider) {
      // Lider ve: Asignada, Reasignada siempre; CPV y CV solo antes de fecha limite
      const allowed = ['Asignada', 'Reasignada'];
      if (beforeDeadline) allowed.push('Completa - Por Validar', 'Completa - Validada');
      if (!allowed.includes(task.status)) return false;
    }
    // Gerente ve todo (Creada, Asignada, CPV, Reasignada, CV, Completa, Cancelada)

    if (filterStatus && task.status !== filterStatus) return false;
    if (!matchesDate(task)) return false;
    return true;
  });

  const startItem = (page - 1) * PAGE_SIZE + 1;
  const endItem = Math.min(page * PAGE_SIZE, totalCount);

  return (
    <div>
      <Toaster position="top-center" />

      {/* Hidden file input for bulk upload */}
      <input
        type="file"
        ref={bulkFileInputRef}
        style={{ display: 'none' }}
        accept=".xlsx,.xls"
        onChange={handleBulkFileChange}
      />

      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <div>
            <h1 className="page-header__title">Tareas</h1>
            <p className="page-header__subtitle">
              Gestion de tareas del sistema
            </p>
          </div>
          <div style={{ display: 'flex', gap: '4px' }}>
            <button
              className="btn btn--secondary btn--sm btn--icon"
              onClick={handleExportXlsx}
              disabled={filteredTasks.length === 0}
              data-tooltip="Descargar tareas"
            >
              <Download size={16} />
            </button>
            {(isGerente || isLider) && (
              <button
                className="btn btn--secondary btn--sm btn--icon"
                onClick={handleDownloadTemplate}
                data-tooltip="Descargar plantilla para carga masiva"
              >
                <FileSpreadsheet size={16} />
              </button>
            )}
            {(isGerente || isLider) && (
              <button
                className="btn btn--secondary btn--sm btn--icon"
                onClick={() => bulkFileInputRef.current?.click()}
                data-tooltip="Cargar tareas desde XLSX"
              >
                <Upload size={16} />
              </button>
            )}
          </div>
        </div>
        {(isGerente || isLider) && (
          <button className="btn btn--primary" onClick={openCreateModal}>
            <Plus size={18} />
            Nueva Tarea
          </button>
        )}
      </div>

      {/* ── Toolbar: Search + Filters in one row ── */}
      <div className="tasks-toolbar" style={{ marginBottom: '16px', display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
        <div className="header__search" style={{ flex: '1 1 200px', minWidth: 0 }}>
          <input
            type="text"
            className="header__search-input"
            placeholder="Buscar.."
            value={searchText}
            onChange={(e) => {
              const val = e.target.value;
              setSearchText(val);
              if (searchDebounceRef.current) clearTimeout(searchDebounceRef.current);
              searchDebounceRef.current = setTimeout(() => {
                loadTasks(1, val);
              }, 300);
            }}
            style={{ width: '100%' }}
          />
          <Search size={18} className="header__search-icon" />
        </div>

        <select
          className="form-control form-select"
          value={filterStatus}
          onChange={(e) => { setFilterStatus(e.target.value); setSearchText(''); searchRef.current = ''; loadTasks(1, ''); }}
          style={{ width: '220px', minWidth: '150px', height: '36px', padding: '0 32px 0 12px', fontSize: '13px', flex: '0 1 220px' }}
        >
          <option value="">Estado: Todas</option>
          {VISIBLE_STATUSES.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>

        <select
          className="form-control form-select"
          value={filterDate}
          onChange={(e) => setFilterDate(e.target.value)}
          style={{ width: '180px', minWidth: '140px', height: '36px', padding: '0 32px 0 12px', fontSize: '13px', flex: '0 1 180px' }}
        >
          {DATE_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>Fecha: {opt.label}</option>
          ))}
        </select>
      </div>

      <div className="card">
        <div className="card__body">
          {filteredTasks.length === 0 && !loading ? (
            <div className="empty-state">
              <ClipboardList size={48} className="empty-state__icon" />
              <h3 className="empty-state__title">No hay tareas</h3>
              <p className="empty-state__description">
                {(isGerente || isLider)
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
                      {(isGerente || isLider) && <th>Asignado a</th>}
                      <th className="table__col--secondary">Lider</th>
                      <th>Estado</th>
                      <th className="table__col--secondary">Entrega</th>
                      <th className="table__col--secondary" data-tooltip="Tiempo estimado (horas)">&#128339;</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[...filteredTasks]
                      .map((t) => ({ ...t, _urgency: getUrgency(t) }))
                      .sort((a, b) => {
                        const aDate = a.dueDate ? new Date(a.dueDate).getTime() : Infinity;
                        const bDate = b.dueDate ? new Date(b.dueDate).getTime() : Infinity;
                        return aDate - bDate;
                      })
                      .map((task) => {
                      const transitions = getStatusTransitions(task.status, role);
                      const isSelected = selectedRowId === task.id;
                      const urgencyBg = getRowBgColor(task._urgency.level);
                      return (
                        <tr
                          key={task.id}
                          onClick={() => setSelectedRowId(isSelected ? null : task.id)}
                          style={{
                            cursor: 'pointer',
                            backgroundColor: urgencyBg,
                            outline: isSelected ? '3px solid #166534' : 'none',
                            outlineOffset: '-3px',
                            transition: 'outline 150ms',
                          }}
                        >
                          <td className="font-semibold">{task.title}</td>
                          {(isGerente || isLider) && (
                            <td className="text-secondary">
                              {task.assignedToName || 'Sin asignar'}
                            </td>
                          )}
                          <td className="text-secondary table__col--secondary">
                            {task.assignedLeaderName || '-'}
                          </td>
                          <td>
                            <span className={getBadgeClass(task.status)}>
                              {task.status}
                            </span>
                          </td>
                          <td className="text-secondary table__col--secondary" style={{ fontSize: '12px', whiteSpace: 'nowrap' }}>
                            {formatDueDate(task.dueDate)}
                          </td>
                          <td className="table__col--secondary">{formatTime(task.estimatedTime)}</td>
                          <td>
                            <div className="table__actions">
                              {/* Edit button — Gerente (full) or Lider (limited) */}
                              {(isGerente || isLider) && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={(e) => { e.stopPropagation(); openEditModal(task); }}
                                  data-tooltip="Editar"
                                >
                                  <Pencil size={16} />
                                </button>
                              )}

                              {/* View detail — Colaborador */}
                              {isColaborador && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={(e) => { e.stopPropagation(); setDetailTask(task); setDetailModalOpen(true); }}
                                  data-tooltip="Ver detalle"
                                >
                                  <Eye size={16} />
                                </button>
                              )}

                              {/* History */}
                              <button
                                className="btn btn--icon btn--sm btn--ghost"
                                onClick={(e) => { e.stopPropagation(); setHistoryTask(task); setHistoryModalOpen(true); }}
                                data-tooltip="Historial"
                              >
                                <History size={16} />
                              </button>

                              {/* Restore — Gerente only, cancelled tasks */}
                              {isGerente && task.status === 'Cancelada' && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost"
                                  onClick={(e) => { e.stopPropagation(); handleRestore(task); }}
                                  data-tooltip="Restaurar"
                                >
                                  <Undo2 size={16} />
                                </button>
                              )}

                              {/* Delete — Gerente only, not for cancelled tasks */}
                              {isGerente && task.status !== 'Cancelada' && (
                                <button
                                  className="btn btn--icon btn--sm btn--ghost text-error"
                                  onClick={(e) => { e.stopPropagation(); handleDelete(task); }}
                                  data-tooltip="Eliminar"
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

      {/* Create / Edit / Detail modal */}
      <TaskModal
        isOpen={modalOpen || detailModalOpen}
        onClose={() => { closeModal(); setDetailModalOpen(false); setDetailTask(null); }}
        onSubmit={handleSubmit}
        onSaveOnly={handleSaveOnly}
        onUploadEvidence={async (taskId, file, text, observations) => {
          try {
            await tasksService.uploadEvidence(taskId, file, text, observations);
            toast.success('Evidencia guardada exitosamente');
            closeModal();
            setDetailModalOpen(false);
            setDetailTask(null);
            await loadTasks(page);
          } catch (err) {
            toast.error(`Error al guardar: ${err.message}`);
            throw err;
          }
        }}
        onChangeStatus={async (t, newStatus) => {
          await handleChangeStatus(t, newStatus);
          setDetailModalOpen(false);
          setDetailTask(null);
          setModalOpen(false);
        }}
        onAssign={async (t, assigneeId) => {
          try {
            await tasksService.assignTask(t.id, {
              assigneeId,
            });
            toast.success('Tarea asignada exitosamente');
            await loadTasks(page);
          } catch (err) {
            toast.error(`Error al asignar: ${err.message}`);
          }
        }}
        task={detailModalOpen ? detailTask : selectedTask}
        loading={saving}
        userRole={role}
        userEmail={email}
      />


      {/* ── History modal ── */}
      {historyModalOpen && historyTask && (
        <>
          <div className="modal-backdrop modal-backdrop--open" />
          <div className="modal modal--open task-history-modal" style={{ maxWidth: '650px' }}>
            <div className="modal__header">
              <h3 className="modal__title">Historial — {historyTask.title}</h3>
              <button
                className="modal__close"
                onClick={() => { setHistoryModalOpen(false); setHistoryTask(null); }}
                type="button"
              >
                &times;
              </button>
            </div>
            <div className="modal__body">
              {/* Current state */}
              <div style={{ marginBottom: '16px', padding: '12px', backgroundColor: 'rgba(34,197,94,0.08)', borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-success)' }}>
                <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Estado actual</span>
                <div style={{ marginTop: '4px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span className={getBadgeClass(historyTask.status)}>{historyTask.status}</span>
                  {historyTask.assignedLeaderName && <span style={{ fontSize: '13px' }}>Lider: <strong>{historyTask.assignedLeaderName}</strong></span>}
                  {historyTask.assignedToName && <span style={{ fontSize: '13px' }}>Colaborador: <strong>{historyTask.assignedToName}</strong></span>}
                </div>
              </div>

              {/* Timeline */}
              {historyTask.statusHistory && historyTask.statusHistory.length > 0 ? (
                <div>
                  <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: '12px' }}>Historial de cambios</span>
                  {[...historyTask.statusHistory].reverse().map((entry, idx) => {
                    const isLast = idx === 0;
                    const date = new Date(entry.changedAt);
                    const dateStr = date.toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' });
                    const timeStr = date.toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' });
                    return (
                      <div
                        key={idx}
                        style={{
                          display: 'flex',
                          gap: '12px',
                          padding: '10px 0',
                          borderBottom: '1px solid var(--color-border-light)',
                          opacity: isLast ? 1 : 0.7,
                        }}
                      >
                        {/* Timeline dot */}
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '20px', flexShrink: 0 }}>
                          <div style={{
                            width: '10px', height: '10px', borderRadius: '50%',
                            backgroundColor: isLast ? 'var(--color-success)' : 'var(--color-border-main)',
                            marginTop: '4px',
                          }} />
                          {idx < historyTask.statusHistory.length - 1 && (
                            <div style={{ width: '2px', flex: 1, backgroundColor: 'var(--color-border-light)', marginTop: '4px' }} />
                          )}
                        </div>
                        {/* Content */}
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '2px' }}>
                            <span className={getBadgeClass(entry.fromStatus)} style={{ fontSize: '10px' }}>{entry.fromStatus}</span>
                            <span style={{ fontSize: '12px', color: '#6B7280' }}>→</span>
                            <span className={getBadgeClass(entry.toStatus)} style={{ fontSize: '10px' }}>{entry.toStatus}</span>
                          </div>
                          <div style={{ fontSize: '12px', color: '#6B7280' }}>
                            <strong>{entry.changedByName}</strong> — {dateStr} {timeStr}
                          </div>
                          {entry.comment && (
                            <div style={{ fontSize: '12px', color: '#9CA3AF', fontStyle: 'italic', marginTop: '2px' }}>
                              {entry.comment}
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div style={{ textAlign: 'center', color: '#9CA3AF', padding: '24px 0' }}>
                  No hay cambios de estado registrados
                </div>
              )}

              {/* Creation info */}
              <div style={{ marginTop: '16px', padding: '10px 0', borderTop: '1px solid var(--color-border-light)', fontSize: '12px', color: '#6B7280' }}>
                Creada: {new Date(historyTask.createdAt).toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' })} {new Date(historyTask.createdAt).toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' })}
              </div>
            </div>
            <div className="modal__footer">
              <button className="btn btn--secondary" onClick={() => { setHistoryModalOpen(false); setHistoryTask(null); }}>
                Cerrar
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default Tasks;
