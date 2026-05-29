import { useState, useEffect, useCallback, useContext, useRef } from 'react';
import {
  Plus, Pencil, Trash2, ClipboardList, ChevronLeft, ChevronRight,
  Eye, Search, History, Undo2, Download, FileSpreadsheet, Upload,
  ArrowUpDown, ArrowUp, ArrowDown, Calendar, X, Check,
} from 'lucide-react';
import * as XLSX from '@e965/xlsx';
import Swal from 'sweetalert2';
import toast, { Toaster } from 'react-hot-toast';
import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';
import { tasksService } from '../../services/tasksService';
import { colaboradorService } from '../../services/colaboradorService';
import SessionContext from '../../context/SessionContext';
import TaskModal from './TaskModal';
import ColumnFilterDropdown from './ColumnFilterDropdown';
import MonthMultiSelect from './MonthMultiSelect';
import './Tasks.css';

const PAGE_SIZE_OPTIONS = [10, 20, 50, 100, 200];
const DEFAULT_PAGE_SIZE = 20;

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

/** Convierte 'YYYY-MM' al rango {from: 'YYYY-MM-01', to: 'YYYY-MM-DD'} del último día. */
const monthBoundsToDates = (yyyymm) => {
  if (!yyyymm) return { from: '', to: '' };
  const [y, m] = yyyymm.split('-').map(Number);
  const first = new Date(y, m - 1, 1);
  const last = new Date(y, m, 0);
  const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return { from: fmt(first), to: fmt(last) };
};

const getCurrentMonth = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
};

/** Dado un Set<string> de meses (1..12) y un año, devuelve el rango {from, to} desde el primer
 * mes seleccionado hasta el último (los meses intermedios quedan dentro del rango). */
const monthsAndYearToBounds = (monthsSet, year) => {
  if (!year || !monthsSet || monthsSet.size === 0) return { from: '', to: '' };
  const months = Array.from(monthsSet).map(Number).sort((a, b) => a - b);
  const minMonth = months[0];
  const maxMonth = months[months.length - 1];
  const fromBounds = monthBoundsToDates(`${year}-${String(minMonth).padStart(2, '0')}`);
  const toBounds = monthBoundsToDates(`${year}-${String(maxMonth).padStart(2, '0')}`);
  return { from: fromBounds.from, to: toBounds.to };
};

const Tasks = () => {
  const { user } = useContext(SessionContext);
  const role = user?.role || '';
  const email = user?.email || '';

  // Filtro mes/año: por defecto el mes actual.
  const initialMonth = getCurrentMonth();
  const initialBounds = monthBoundsToDates(initialMonth);

  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [totalCount, setTotalCount] = useState(0);
  const [isExporting, setIsExporting] = useState(false);
  const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE);
  const pageSizeRef = useRef(DEFAULT_PAGE_SIZE);

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

  // Admin selection
  const [selectedIds, setSelectedIds] = useState(new Set());

  // Bulk upload file input ref
  const bulkFileInputRef = useRef(null);

  // Date picker ref
  const datePickerRef = useRef(null);

  // Search debounce ref
  const searchDebounceRef = useRef(null);
  const searchRef = useRef('');
  const filterStatusRef = useRef(''); // CSV: "Asignada,Reasignada"
  const filterDateFromRef = useRef(initialBounds.from); // YYYY-MM-DD string for API
  const filterDateToRef = useRef(initialBounds.to); // YYYY-MM-DD string for API
  const filterTitleRef = useRef(''); // CSV con valores exactos seleccionados
  const filterAssignedToRef = useRef('');
  const filterLeaderRef = useRef('');
  const sortByRef = useRef('');
  const sortDirRef = useRef('');

  // History modal
  const [historyModalOpen, setHistoryModalOpen] = useState(false);
  const [historyTask, setHistoryTask] = useState(null);

  // Filters
  const [searchText, setSearchText] = useState('');
  const [filterStatus, setFilterStatus] = useState(''); // legado: '' = todas (toolbar superior)
  // filterDateFrom/To = solo display del DatePicker (rango personalizado). NO se setea por Mes/Año.
  const [filterDateFrom, setFilterDateFrom] = useState(null);
  const [filterDateTo, setFilterDateTo] = useState(null);
  // Filtro mes/año (default = mes y año actuales). Mes acepta selección múltiple.
  const initialMonthNum = String(new Date().getMonth() + 1); // '1'..'12'
  const initialYear = String(new Date().getFullYear());
  const [filterMonths, setFilterMonths] = useState(() => new Set([initialMonthNum]));
  const [filterYear, setFilterYear] = useState(initialYear);
  // Filtros estilo Excel: Set<string> por columna con valores seleccionados.
  const [colTitles, setColTitles] = useState(() => new Set());
  const [colAssigned, setColAssigned] = useState(() => new Set());
  const [colLeaders, setColLeaders] = useState(() => new Set());
  const [colStatuses, setColStatuses] = useState(() => new Set());
  const [sortBy, setSortBy] = useState('');
  const [sortDir, setSortDir] = useState('');

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

  const isAdmin = role === 'Administrador';
  const isGerente = role === 'Gerente';
  const isLider = role === 'Lider';
  const isColaborador = role === 'Colaborador';

  const loadTasks = useCallback(async (currentPage = 1, search, statusVal, dateFromVal, dateToVal, sortVal) => {
    try {
      setLoading(true);
      setError(null);
      const searchValue = search !== undefined ? search : searchRef.current;
      if (search !== undefined) {
        searchRef.current = search;
      }
      const statusValue = statusVal !== undefined ? statusVal : filterStatusRef.current;
      const fromValue = dateFromVal !== undefined ? dateFromVal : filterDateFromRef.current;
      const toValue = dateToVal !== undefined ? dateToVal : filterDateToRef.current;
      // sortVal (legado: sortDueDate) ya no se usa; el sort vive en sortByRef/sortDirRef.
      const data = await tasksService.getAll(
        currentPage,
        pageSizeRef.current,
        searchValue,
        statusValue,
        fromValue,
        toValue,
        '',
        {
          titleFilter: filterTitleRef.current,
          assignedToFilter: filterAssignedToRef.current,
          leaderFilter: filterLeaderRef.current,
          sortBy: sortByRef.current,
          sortDir: sortDirRef.current,
        },
      );
      setTasks(data.items ?? []);
      setTotalPages(data.totalPages);
      setTotalCount(data.totalCount);
      setPage(data.page);
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  const toggleSelect = (id) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleSelectAll = () => {
    if (selectedIds.size === filteredTasks.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(filteredTasks.map((t) => t.id)));
    }
  };

  const handleBulkApprove = async () => {
    if (selectedIds.size === 0) return;

    const approvable = tasks.filter(
      (t) => selectedIds.has(t.id) && t.status === 'Completa - Validada'
    );

    if (approvable.length === 0) {
      toast.error('Ninguna tarea seleccionada esta en "Completa - Validada"');
      return;
    }

    const skipped = selectedIds.size - approvable.length;
    const skippedNote = skipped > 0
      ? `\n\nSe omitiran ${skipped} tarea${skipped > 1 ? 's' : ''} que no estan en "Completa - Validada".`
      : '';

    const result = await Swal.fire({
      title: 'Aprobar tareas',
      text: `Se cerraran definitivamente ${approvable.length} tarea${approvable.length > 1 ? 's' : ''} (estado "Completa").${skippedNote}`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#16A34A',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, aprobar',
      cancelButtonText: 'Cancelar',
    });

    if (!result.isConfirmed) return;

    const approveToast = toast.loading('Aprobando tareas...');
    try {
      const results = await Promise.allSettled(
        approvable.map((t) =>
          tasksService.changeStatus(t.id, {
            newStatus: 'Completa',
            comment: 'Aprobacion masiva por Gerente',
          })
        )
      );

      const ok = results.filter((r) => r.status === 'fulfilled').length;
      const fail = results.length - ok;

      toast.dismiss(approveToast);
      if (fail === 0) {
        toast.success(`${ok} tarea${ok > 1 ? 's' : ''} aprobada${ok > 1 ? 's' : ''}`);
      } else if (ok === 0) {
        toast.error(`No se pudo aprobar ninguna (${fail} fallida${fail > 1 ? 's' : ''})`);
      } else {
        toast.success(`${ok} aprobada${ok > 1 ? 's' : ''}, ${fail} fallida${fail > 1 ? 's' : ''}`);
      }

      setSelectedIds(new Set());
      loadTasks(page, searchRef.current, filterStatusRef.current, filterDateFromRef.current, filterDateToRef.current, '');
    } catch (err) {
      toast.dismiss(approveToast);
      toast.error('Error al aprobar: ' + (err.message || 'Error desconocido'));
    }
  };

  const handleBulkDelete = async () => {
    if (selectedIds.size === 0) return;
    const result = await Swal.fire({
      title: 'Eliminar tareas',
      text: `¿Estas seguro de eliminar ${selectedIds.size} tarea${selectedIds.size > 1 ? 's' : ''}? Esta accion no se puede deshacer.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#E31837',
      cancelButtonColor: '#6B7280',
      confirmButtonText: 'Si, eliminar',
      cancelButtonText: 'Cancelar',
    });
    if (result.isConfirmed) {
      try {
        await tasksService.bulkDelete(Array.from(selectedIds));
        toast.success(`${selectedIds.size} tarea${selectedIds.size > 1 ? 's' : ''} eliminada${selectedIds.size > 1 ? 's' : ''}`);
        setSelectedIds(new Set());
        loadTasks(1, searchRef.current, filterStatusRef.current, filterDateFromRef.current, filterDateToRef.current, '');
      } catch (err) {
        toast.error('Error al eliminar: ' + (err.message || 'Error desconocido'));
      }
    }
  };

  const goToPage = (newPage) => {
    if (newPage >= 1 && newPage <= totalPages) {
      loadTasks(newPage, searchRef.current, filterStatusRef.current, filterDateFromRef.current, filterDateToRef.current, '');
    }
  };

  // Sort cíclico por columna: '' → asc → desc → ''
  const cycleSort = (field) => {
    let nextDir = 'asc';
    let nextField = field;
    if (sortByRef.current === field) {
      if (sortDirRef.current === 'asc') nextDir = 'desc';
      else if (sortDirRef.current === 'desc') {
        nextDir = '';
        nextField = '';
      }
    }
    sortByRef.current = nextField;
    sortDirRef.current = nextDir;
    setSortBy(nextField);
    setSortDir(nextDir);
    loadTasks(1);
  };

  const sortIcon = (field) => {
    if (sortBy !== field) return <ArrowUpDown size={14} style={{ verticalAlign: 'middle', opacity: 0.4 }} />;
    if (sortDir === 'asc') return <ArrowUp size={14} style={{ verticalAlign: 'middle' }} />;
    return <ArrowDown size={14} style={{ verticalAlign: 'middle' }} />;
  };

  const setRefFromSet = (refObj, set) => {
    refObj.current = Array.from(set || []).join(',');
  };

  const onApplyColTitles = (set) => {
    setColTitles(set);
    setRefFromSet(filterTitleRef, set);
    loadTasks(1);
  };
  const onApplyColAssigned = (set) => {
    setColAssigned(set);
    setRefFromSet(filterAssignedToRef, set);
    loadTasks(1);
  };
  const onApplyColLeaders = (set) => {
    setColLeaders(set);
    setRefFromSet(filterLeaderRef, set);
    loadTasks(1);
  };
  const onApplyColStatuses = (set) => {
    setColStatuses(set);
    setRefFromSet(filterStatusRef, set);
    // Sincronizar el <select> del toolbar superior:
    // un solo valor seleccionado → mostrar ese valor; cero o varios → "Todas".
    if (set.size === 1) {
      setFilterStatus(Array.from(set)[0]);
    } else {
      setFilterStatus('');
    }
    loadTasks(1);
  };

  // Service factories for distinct-values fetching (passed to ColumnFilterDropdown).
  const distinctLoaderFor = (field) => () => tasksService.getDistinctValues(field);

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
    // Gerente: cambio directo sin Swal (la accion ya implica la confirmacion del click).
    // Otros roles: confirmacion previa via Swal.
    if (!isGerente) {
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
    }

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

  // ---- Export XLSX (todas las tareas que cumplen los filtros, no solo la pagina actual) ----
  const handleExportXlsx = async () => {
    if (isExporting) return;

    const getLastCollaboratorUpdate = (task) => {
      if (!task.statusHistory || !task.assignedToEmail) return '';
      const collabEntries = task.statusHistory
        .filter((h) => h.changedByEmail === task.assignedToEmail)
        .sort((a, b) => new Date(b.changedAt) - new Date(a.changedAt));
      if (collabEntries.length === 0) return '';
      return new Date(collabEntries[0].changedAt).toLocaleString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    };

    const FETCH_PAGE_SIZE = 100; // backend caps pageSize at 100
    const allItems = [];

    setIsExporting(true);
    const exportToast = toast.loading('Preparando descarga...');

    try {
      let currentPage = 1;
      let totalPagesLocal = 1;

      do {
        const data = await tasksService.getAll(
          currentPage,
          FETCH_PAGE_SIZE,
          searchRef.current,
          filterStatusRef.current,
          filterDateFromRef.current,
          filterDateToRef.current,
          '',
          {
            titleFilter: filterTitleRef.current,
            assignedToFilter: filterAssignedToRef.current,
            leaderFilter: filterLeaderRef.current,
            sortBy: sortByRef.current,
            sortDir: sortDirRef.current,
          },
        );
        const items = data.items ?? [];
        allItems.push(...items);
        totalPagesLocal = data.totalPages || 1;
        currentPage += 1;
      } while (currentPage <= totalPagesLocal);

      if (allItems.length === 0) {
        toast.dismiss(exportToast);
        toast('No hay tareas que coincidan con los filtros');
        return;
      }

      const rows = allItems.map((t) => ({
        'Titulo': t.title || '',
        'Descripcion': t.description || '',
        'Estado': t.status || '',
        'Lider asignado': t.assignedLeaderName || '',
        'Colaborador asignado': t.assignedToName || '',
        'Fecha de entrega': t.dueDate ? new Date(t.dueDate).toLocaleString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '',
        'Tiempo estimado (h)': t.estimatedTime ?? '',
        'Tiempo real (h)': t.actualTime ?? '',
        'Observaciones': t.observations || '',
        'Calificacion': t.rating != null ? `${t.rating}%` : 'Pendiente',
        'Fecha de creacion': t.createdAt ? new Date(t.createdAt).toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '',
        'Ultima actualizacion Colaborador': getLastCollaboratorUpdate(t),
      }));

      const { default: ExcelJS } = await import('exceljs');
      const wb = new ExcelJS.Workbook();
      const ws = wb.addWorksheet('Tareas');

      const taskHeaders = Object.keys(rows[0] || {});
      const taskColWidths = [30, 40, 22, 25, 25, 20, 18, 18, 35, 14, 18, 30];
      ws.columns = taskHeaders.map((h, i) => ({ header: h, key: h, width: taskColWidths[i] ?? 20 }));

      const headerRow = ws.getRow(1);
      headerRow.height = 22;
      headerRow.eachCell((cell) => {
        cell.font      = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11, name: 'Calibri' };
        cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };
        cell.border    = { top: { style: 'thin', color: { argb: 'FFC0C0C0' } }, bottom: { style: 'thin', color: { argb: 'FFC0C0C0' } }, left: { style: 'thin', color: { argb: 'FFC0C0C0' } }, right: { style: 'thin', color: { argb: 'FFC0C0C0' } } };
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
      });

      rows.forEach((r, idx) => {
        const row = ws.addRow(taskHeaders.map((h) => r[h]));
        row.height = 18;
        const bgArgb = idx % 2 === 0 ? 'FFEBF3FB' : 'FFFFFFFF';
        row.eachCell({ includeEmpty: true }, (cell) => {
          cell.font      = { size: 10, name: 'Calibri', color: { argb: 'FF000000' } };
          cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: bgArgb } };
          cell.border    = { top: { style: 'thin', color: { argb: 'FFE0E0E0' } }, bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } }, left: { style: 'thin', color: { argb: 'FFE0E0E0' } }, right: { style: 'thin', color: { argb: 'FFE0E0E0' } } };
          cell.alignment = { horizontal: 'left', vertical: 'middle' };
        });
      });

      ws.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

      const buffer = await wb.xlsx.writeBuffer();
      const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Tareas_${new Date().toISOString().slice(0, 10)}.xlsx`;
      a.click();
      URL.revokeObjectURL(url);

      toast.dismiss(exportToast);
      toast.success(`Descargadas ${rows.length} tarea${rows.length === 1 ? '' : 's'}`);
    } catch (err) {
      toast.dismiss(exportToast);
      toast.error(`Error al descargar: ${err.message}`);
    } finally {
      setIsExporting(false);
    }
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
      const { default: ExcelJS } = await import('exceljs');
      const wb = new ExcelJS.Workbook();

      // Sheet 1: plantilla de tareas
      const wsTemplate = wb.addWorksheet('Tareas');
      const tplColWidths = [35, 35, 28, 20, 30, 25, 30, 30];
      wsTemplate.columns = templateHeaders.map((h, i) => ({ header: h, key: h, width: tplColWidths[i] ?? 20 }));
      const tplHeaderRow = wsTemplate.getRow(1);
      tplHeaderRow.height = 22;
      tplHeaderRow.eachCell((cell) => {
        cell.font      = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11, name: 'Calibri' };
        cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };
        cell.border    = { top: { style: 'thin', color: { argb: 'FFC0C0C0' } }, bottom: { style: 'thin', color: { argb: 'FFC0C0C0' } }, left: { style: 'thin', color: { argb: 'FFC0C0C0' } }, right: { style: 'thin', color: { argb: 'FFC0C0C0' } } };
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
      });
      const exampleDataRow = wsTemplate.addRow(exampleRow);
      exampleDataRow.height = 18;
      exampleDataRow.eachCell({ includeEmpty: true }, (cell) => {
        cell.font      = { size: 10, name: 'Calibri', color: { argb: 'FF000000' }, italic: true };
        cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFF9C4' } };
        cell.border    = { top: { style: 'thin', color: { argb: 'FFE0E0E0' } }, bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } }, left: { style: 'thin', color: { argb: 'FFE0E0E0' } }, right: { style: 'thin', color: { argb: 'FFE0E0E0' } } };
        cell.alignment = { horizontal: 'left', vertical: 'middle' };
      });
      wsTemplate.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

      // Sheet 2: lista de colaboradores
      const allColabs = await colaboradorService.getAll();
      const colabRows = allColabs.map((c) => ({
        'Nombre completo': c.nombreCompleto || '',
        'Correo': c.correo || '',
        'Rol': (c.rolNames || (c.rolName ? [c.rolName] : [])).join(', '),
      }));
      const wsColabs = wb.addWorksheet('Colaboradores');
      const colabHeaders = ['Nombre completo', 'Correo', 'Rol'];
      wsColabs.columns = colabHeaders.map((h) => ({ header: h, key: h, width: Math.max(h.length + 4, 25) }));
      const colabHeaderRow = wsColabs.getRow(1);
      colabHeaderRow.height = 22;
      colabHeaderRow.eachCell((cell) => {
        cell.font      = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11, name: 'Calibri' };
        cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1F4E79' } };
        cell.border    = { top: { style: 'thin', color: { argb: 'FFC0C0C0' } }, bottom: { style: 'thin', color: { argb: 'FFC0C0C0' } }, left: { style: 'thin', color: { argb: 'FFC0C0C0' } }, right: { style: 'thin', color: { argb: 'FFC0C0C0' } } };
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
      });
      colabRows.forEach((r, idx) => {
        const row = wsColabs.addRow([r['Nombre completo'], r['Correo'], r['Rol']]);
        row.height = 18;
        const bgArgb = idx % 2 === 0 ? 'FFEBF3FB' : 'FFFFFFFF';
        row.eachCell({ includeEmpty: true }, (cell) => {
          cell.font      = { size: 10, name: 'Calibri', color: { argb: 'FF000000' } };
          cell.fill      = { type: 'pattern', pattern: 'solid', fgColor: { argb: bgArgb } };
          cell.border    = { top: { style: 'thin', color: { argb: 'FFE0E0E0' } }, bottom: { style: 'thin', color: { argb: 'FFE0E0E0' } }, left: { style: 'thin', color: { argb: 'FFE0E0E0' } }, right: { style: 'thin', color: { argb: 'FFE0E0E0' } } };
          cell.alignment = { horizontal: 'left', vertical: 'middle' };
        });
      });
      wsColabs.views = [{ state: 'frozen', xSplit: 0, ySplit: 1 }];

      const buffer = await wb.xlsx.writeBuffer();
      const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'Plantilla_Carga_Tareas.xlsx';
      a.click();
      URL.revokeObjectURL(url);
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

      if (rows.length > 600) {
        toast.error('El archivo excede el limite de 600 tareas por carga.');
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
    if (isAdmin || isGerente) return ['Creada', 'Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada', 'Completa', 'Cancelada'];
    if (isLider) return ['Asignada', 'Completa - Por Validar', 'Reasignada', 'Completa - Validada'];
    if (isColaborador) return ['Asignada', 'Completa - Por Validar', 'Reasignada'];
    return [];
  })();
  // DATE_OPTIONS removed - using date picker instead

  const filteredTasks = tasks;

  const startItem = (page - 1) * pageSize + 1;
  const endItem = Math.min(page * pageSize, totalCount);

  const handlePageSizeChange = (newSize) => {
    setPageSize(newSize);
    pageSizeRef.current = newSize;
    loadTasks(1, searchRef.current, filterStatusRef.current, filterDateFromRef.current, filterDateToRef.current, '');
  };

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
            {isGerente && selectedIds.size > 0 && (
              <button
                className="btn btn--sm"
                style={{ backgroundColor: '#16A34A', color: '#fff', border: 'none' }}
                onClick={handleBulkApprove}
                data-tooltip={`Aprobar ${selectedIds.size} tarea${selectedIds.size > 1 ? 's' : ''} (solo "Completa - Validada")`}
              >
                <Check size={16} />
                Aprobar ({selectedIds.size})
              </button>
            )}
            {isAdmin && selectedIds.size > 0 && (
              <button
                className="btn btn--sm"
                style={{ backgroundColor: '#E31837', color: '#fff', border: 'none' }}
                onClick={handleBulkDelete}
                data-tooltip={`Eliminar ${selectedIds.size} tarea${selectedIds.size > 1 ? 's' : ''}`}
              >
                <Trash2 size={16} />
                Eliminar ({selectedIds.size})
              </button>
            )}
            <button
              className="btn btn--secondary btn--sm btn--icon"
              onClick={handleExportXlsx}
              disabled={totalCount === 0 || isExporting}
              data-tooltip={isExporting ? 'Descargando...' : 'Descargar tareas (todas las que cumplen los filtros)'}
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
                loadTasks(1, val, filterStatusRef.current, filterDateFromRef.current, filterDateToRef.current, '');
              }, 300);
            }}
            style={{ width: '100%' }}
          />
          <Search size={18} className="header__search-icon" />
        </div>

        <select
          className="form-control form-select"
          value={filterStatus}
          onChange={(e) => {
            const val = e.target.value;
            setFilterStatus(val);
            const nextSet = val ? new Set([val]) : new Set();
            setColStatuses(nextSet);
            setRefFromSet(filterStatusRef, nextSet);
            loadTasks(1);
          }}
          style={{ width: '220px', minWidth: '150px', height: '36px', padding: '0 32px 0 12px', fontSize: '13px', flex: '0 1 220px' }}
        >
          <option value="">Estado: Todas</option>
          {VISIBLE_STATUSES.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>

        {/* Filtro Mes (selección múltiple) */}
        <MonthMultiSelect
          selected={filterMonths}
          onApply={(set) => {
            setFilterMonths(set);
            const { from, to } = monthsAndYearToBounds(set, filterYear);
            filterDateFromRef.current = from;
            filterDateToRef.current = to;
            // Limpiar visualmente el filtro Fecha (el rango del DatePicker queda como "Fecha")
            setFilterDateFrom(null);
            setFilterDateTo(null);
            loadTasks(1, searchRef.current, filterStatusRef.current, from, to, '');
          }}
          tooltip="Filtrar por mes (uno o varios meses)"
        />

        <select
          className="form-control form-select"
          value={filterYear}
          onChange={(e) => {
            const y = e.target.value;
            setFilterYear(y);
            const { from, to } = monthsAndYearToBounds(filterMonths, y);
            filterDateFromRef.current = from;
            filterDateToRef.current = to;
            // Limpiar visualmente el filtro Fecha
            setFilterDateFrom(null);
            setFilterDateTo(null);
            loadTasks(1, searchRef.current, filterStatusRef.current, from, to, '');
          }}
          style={{ width: '110px', height: '36px', padding: '0 32px 0 12px', fontSize: '13px' }}
          data-tooltip="Filtrar por año (fecha de entrega)"
        >
          <option value="">Año: Todos</option>
          {(() => {
            const currentYear = new Date().getFullYear();
            const years = [];
            for (let y = currentYear - 3; y <= currentYear + 2; y++) years.push(y);
            return years.map((y) => (
              <option key={y} value={String(y)}>{y}</option>
            ));
          })()}
        </select>

        {/* Filtro Fecha (rango personalizado) — toma prioridad sobre Mes/Año */}
        <div style={{ position: 'relative', display: 'inline-block' }}>
          <button
            className="btn btn--secondary btn--sm"
            onClick={() => datePickerRef.current?.setOpen(true)}
            style={{ height: '36px', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px', whiteSpace: 'nowrap' }}
            data-tooltip="Filtrar por rango de fechas de entrega (sobrescribe Mes/Año)"
          >
            <Calendar size={16} />
            {filterDateFrom && filterDateTo
              ? `${filterDateFrom.toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' })} - ${filterDateTo.toLocaleDateString('es-EC', { day: '2-digit', month: '2-digit', year: 'numeric' })}`
              : 'Fecha'}
            {filterDateFrom && (
              <X size={14} style={{ cursor: 'pointer', opacity: 0.6 }} onClick={(e) => {
                e.stopPropagation();
                setFilterDateFrom(null);
                setFilterDateTo(null);
                // Si hay Mes/Año seleccionado, restaurar esos bounds; si no, sin filtro.
                const { from, to } = monthsAndYearToBounds(filterMonths, filterYear);
                filterDateFromRef.current = from;
                filterDateToRef.current = to;
                loadTasks(1, searchRef.current, filterStatusRef.current, from, to, '');
              }} />
            )}
          </button>
          <div style={{ position: 'absolute', zIndex: 10 }}>
            <DatePicker
              ref={datePickerRef}
              selectsRange
              startDate={filterDateFrom}
              endDate={filterDateTo}
              onChange={(dates) => {
                const [start, end] = dates;
                setFilterDateFrom(start);
                setFilterDateTo(end);
                const fmt = (d) => d ? `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` : '';
                filterDateFromRef.current = fmt(start);
                filterDateToRef.current = fmt(end);
                if (start && end) {
                  // El rango personalizado tiene prioridad: limpiar visualmente Mes/Año
                  setFilterMonths(new Set());
                  setFilterYear('');
                  loadTasks(1, searchRef.current, filterStatusRef.current, fmt(start), fmt(end), '');
                }
              }}
              dateFormat="dd/MM/yyyy"
              customInput={<span />}
            />
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card__body">
          {(() => {
            const hasActiveFilters = !!(
              searchText || filterStatus || filterDateFrom || filterDateTo
              || filterMonths.size || filterYear
              || colTitles.size || colAssigned.size || colLeaders.size || colStatuses.size
              || sortBy
            );
            const tableColCount = 1 /* titulo */ + 1 /* descripcion */
              + ((isAdmin || isGerente || isLider) ? 1 : 0) /* asignado a */
              + 1 /* lider */ + 1 /* estado */ + 1 /* entrega */
              + 1 /* estimado */ + 1 /* calif */ + 1 /* acciones */
              + ((isAdmin || isGerente) ? 1 : 0); /* checkbox */
            return filteredTasks.length === 0 && !loading && !hasActiveFilters ? (
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
                      {(isAdmin || isGerente) && (
                        <th style={{ width: '40px', textAlign: 'center' }}>
                          <input
                            type="checkbox"
                            checked={filteredTasks.length > 0 && selectedIds.size === filteredTasks.length}
                            onChange={toggleSelectAll}
                            style={{ cursor: 'pointer', width: '16px', height: '16px' }}
                          />
                        </th>
                      )}
                      <th className="tasks-th">
                        <div className="tasks-th__inner">
                          <span
                            className="tasks-th__sort"
                            onClick={() => cycleSort('title')}
                            data-tooltip="Ordenar por título"
                          >
                            Titulo {sortIcon('title')}
                          </span>
                          <ColumnFilterDropdown
                            field="title"
                            label="título"
                            selected={colTitles}
                            onApply={onApplyColTitles}
                            loadOptions={distinctLoaderFor('title')}
                          />
                        </div>
                      </th>
                      <th
                        className="table__col--secondary"
                        style={{ cursor: 'pointer', userSelect: 'none', whiteSpace: 'nowrap' }}
                        onClick={() => cycleSort('description')}
                        data-tooltip="Ordenar por descripción"
                      >
                        Descripcion {sortIcon('description')}
                      </th>
                      {(isAdmin || isGerente || isLider) && (
                        <th className="tasks-th">
                          <div className="tasks-th__inner">
                            <span
                              className="tasks-th__sort"
                              onClick={() => cycleSort('assignedTo')}
                              data-tooltip="Ordenar por colaborador"
                            >
                              Asignado a {sortIcon('assignedTo')}
                            </span>
                            <ColumnFilterDropdown
                              field="assignedTo"
                              label="colaborador"
                              selected={colAssigned}
                              onApply={onApplyColAssigned}
                              loadOptions={distinctLoaderFor('assignedTo')}
                            />
                          </div>
                        </th>
                      )}
                      <th className="tasks-th table__col--secondary">
                        <div className="tasks-th__inner">
                          <span
                            className="tasks-th__sort"
                            onClick={() => cycleSort('leader')}
                            data-tooltip="Ordenar por líder"
                          >
                            Lider {sortIcon('leader')}
                          </span>
                          <ColumnFilterDropdown
                            field="leader"
                            label="líder"
                            selected={colLeaders}
                            onApply={onApplyColLeaders}
                            loadOptions={distinctLoaderFor('leader')}
                          />
                        </div>
                      </th>
                      <th className="tasks-th">
                        <div className="tasks-th__inner">
                          <span
                            className="tasks-th__sort"
                            onClick={() => cycleSort('status')}
                            data-tooltip="Ordenar por estado"
                          >
                            Estado {sortIcon('status')}
                          </span>
                          <ColumnFilterDropdown
                            field="status"
                            label="estado"
                            selected={colStatuses}
                            onApply={onApplyColStatuses}
                            loadOptions={distinctLoaderFor('status')}
                          />
                        </div>
                      </th>
                      <th
                        className="table__col--secondary"
                        style={{ cursor: 'pointer', userSelect: 'none', whiteSpace: 'nowrap' }}
                        onClick={() => cycleSort('dueDate')}
                        data-tooltip="Ordenar por entrega"
                      >
                        Entrega {sortIcon('dueDate')}
                      </th>
                      <th
                        className="table__col--secondary"
                        style={{ cursor: 'pointer', userSelect: 'none', whiteSpace: 'nowrap' }}
                        onClick={() => cycleSort('estimatedTime')}
                        data-tooltip="Ordenar por tiempo estimado"
                      >
                        &#128339; {sortIcon('estimatedTime')}
                      </th>
                      <th
                        className="table__col--secondary"
                        style={{ cursor: 'pointer', userSelect: 'none', whiteSpace: 'nowrap' }}
                        onClick={() => cycleSort('rating')}
                        data-tooltip="Ordenar por calificación"
                      >
                        Calificacion {sortIcon('rating')}
                      </th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredTasks.length === 0 ? (
                      <tr>
                        <td
                          colSpan={tableColCount}
                          style={{ textAlign: 'center', padding: '32px 16px', color: 'var(--color-text-secondary)' }}
                        >
                          {loading ? 'Cargando...' : 'Sin coincidencias con los filtros aplicados.'}
                        </td>
                      </tr>
                    ) : filteredTasks
                      .map((t) => ({ ...t, _urgency: getUrgency(t) }))
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
                          {(isAdmin || isGerente) && (
                            <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                              <input
                                type="checkbox"
                                checked={selectedIds.has(task.id)}
                                onChange={() => toggleSelect(task.id)}
                                style={{ cursor: 'pointer', width: '16px', height: '16px' }}
                              />
                            </td>
                          )}
                          <td className="font-semibold">{task.title}</td>
                          <td
                            className="text-secondary table__col--secondary"
                            style={{ maxWidth: '320px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                            title={task.description || ''}
                          >
                            {task.description || '—'}
                          </td>
                          {(isAdmin || isGerente || isLider) && (
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
                          <td className="table__col--secondary" style={{ whiteSpace: 'nowrap' }}>
                            {task.rating != null ? (
                              <span style={{
                                fontSize: '13px',
                                fontWeight: 600,
                                color: task.rating >= 80 ? '#2E7D32' : task.rating >= 50 ? '#F59E0B' : '#E31837',
                              }}>
                                {task.rating}%
                              </span>
                            ) : (
                              <span style={{ color: 'var(--color-text-disabled)', fontSize: '12px' }}>—</span>
                            )}
                          </td>
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
                    <label htmlFor="tasks-page-size">Filas por página:</label>
                    <select
                      id="tasks-page-size"
                      className="pagination__select"
                      value={pageSize}
                      onChange={(e) => handlePageSizeChange(Number(e.target.value))}
                    >
                      {PAGE_SIZE_OPTIONS.map((n) => (
                        <option key={n} value={n}>{n}</option>
                      ))}
                    </select>
                    <span>{startItem}–{endItem} de {totalCount}</span>
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
          );
          })()}
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
        onRatingOverride={async (t, { newRating, reason }) => {
          try {
            const result = await tasksService.overrideRating(t.id, { newRating, reason });
            const updated = result?.data || result?.Data || null;
            if (updated) {
              if (detailModalOpen) setDetailTask(updated);
              else if (selectedTask) setSelectedTask(updated);
            }
            toast.success('Calificación actualizada exitosamente');
            await loadTasks(page);
          } catch (err) {
            const msg = err?.response?.data?.message || err?.message || 'Error al modificar la calificación';
            toast.error(msg);
            throw err;
          }
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
