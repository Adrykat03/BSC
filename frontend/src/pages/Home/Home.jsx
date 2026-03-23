import { useState, useEffect, useCallback, useContext, useRef } from 'react';
import {
  Chart as ChartJS,
  ArcElement,
  Tooltip,
  Legend,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  LineElement,
  PointElement,
  Filler,
} from 'chart.js';
import { Doughnut, Bar, Line } from 'react-chartjs-2';
import { Zap, Trophy, Calendar, Filter, Download } from 'lucide-react';
import * as XLSX from 'xlsx';
import { apiClient } from '../../services/api';
import { tasksService } from '../../services/tasksService';
import { SessionContext } from '../../context/SessionContext';
import './Home.css';

ChartJS.register(ArcElement, Tooltip, Legend, CategoryScale, LinearScale, BarElement, Title, LineElement, PointElement, Filler);

const STATUS_COLORS = {
  'Creada': '#7B8794',
  'Asignada': '#4A90D9',
  'Completa - Por Validar': '#F5A623',
  'Reasignada': '#E85D75',
  'Completa - Validada': '#50C878',
  'Completa': '#2E7D32',
  'Cancelada': '#B71C1C',
};

const STATUS_ORDER = [
  'Creada',
  'Asignada',
  'Reasignada',
  'Completa - Por Validar',
  'Completa - Validada',
  'Completa',
  'Cancelada',
];

const sortByStatusOrder = (items, statusKey = 'status') => {
  return [...items].sort((a, b) => {
    const indexA = STATUS_ORDER.indexOf(a[statusKey]);
    const indexB = STATUS_ORDER.indexOf(b[statusKey]);
    const orderA = indexA === -1 ? STATUS_ORDER.length : indexA;
    const orderB = indexB === -1 ? STATUS_ORDER.length : indexB;
    return orderA - orderB;
  });
};

const sortStatuses = (statuses) => {
  return [...statuses].sort((a, b) => {
    const indexA = STATUS_ORDER.indexOf(a);
    const indexB = STATUS_ORDER.indexOf(b);
    const orderA = indexA === -1 ? STATUS_ORDER.length : indexA;
    const orderB = indexB === -1 ? STATUS_ORDER.length : indexB;
    return orderA - orderB;
  });
};

const FILTER_OPTIONS = {
  ALL: 'all',
  RANGE: 'range',
};

const formatDateDDMMYYYY = (dateStr) => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  return `${dd}/${mm}/${yyyy}`;
};

const formatDateTimeDDMMYYYY = (dateStr) => {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  const hh = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm}/${yyyy} ${hh}:${min}`;
};

const Home = () => {
  const { user } = useContext(SessionContext);
  const [filterType, setFilterType] = useState(FILTER_OPTIONS.ALL);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedCollaborators, setSelectedCollaborators] = useState([]);
  const [generatingReport, setGeneratingReport] = useState(false);

  const isGerente = user?.role === 'Gerente';
  const isColaborador = user?.role === 'Colaborador';

  const handleDownloadReport = async () => {
    try {
      setGeneratingReport(true);
      // Fetch all pages (backend caps at 100 per page)
      const PAGE_SIZE = 100;
      let allTasks = [];
      let currentPage = 1;
      let totalPages = 1;
      do {
        const result = await tasksService.getAll(currentPage, PAGE_SIZE);
        const items = result.items || result || [];
        allTasks = allTasks.concat(items);
        totalPages = result.totalPages || 1;
        currentPage++;
      } while (currentPage <= totalPages);
      const tasks = allTasks;

      const rows = tasks.map((t) => ({
        'Titulo': t.title || '',
        'Descripcion': t.description || '',
        'Estado': t.status || '',
        'Lider asignado': t.assignedLeaderName || '',
        'Email lider': t.assignedLeaderEmail || '',
        'Colaborador asignado': t.assignedToName || '',
        'Email colaborador': t.assignedToEmail || '',
        'Fecha de entrega': formatDateDDMMYYYY(t.dueDate),
        'Tiempo estimado (h)': t.estimatedTime ?? '',
        'Tiempo real (h)': t.actualTime ?? '',
        'Insumos': t.insumos || '',
        'Observaciones': t.observations || '',
        'Evidencia': t.evidenceText || '',
        'Creado por': t.createdBy || '',
        'Fecha de creacion': formatDateTimeDDMMYYYY(t.createdAt),
        'Ultima actualizacion': formatDateTimeDDMMYYYY(t.updatedAt),
      }));

      const ws = XLSX.utils.json_to_sheet(rows);

      // Auto-adjust column widths
      const colWidths = Object.keys(rows[0] || {}).map((key) => {
        const maxLen = Math.max(
          key.length,
          ...rows.map((r) => String(r[key] || '').length)
        );
        return { wch: Math.min(maxLen + 2, 60) };
      });
      ws['!cols'] = colWidths;

      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Reporte de Tareas');

      const today = new Date();
      const yyyy = today.getFullYear();
      const mm = String(today.getMonth() + 1).padStart(2, '0');
      const dd = String(today.getDate()).padStart(2, '0');
      const fileName = `Reporte_Tareas_${yyyy}-${mm}-${dd}.xlsx`;

      XLSX.writeFile(wb, fileName);
    } catch (err) {
      alert('Error al generar el reporte: ' + (err.message || 'Error desconocido'));
    } finally {
      setGeneratingReport(false);
    }
  };

  const fetchDashboard = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      let endpoint = '/tasks/dashboard';
      if (filterType === FILTER_OPTIONS.RANGE && dateFrom && dateTo) {
        endpoint += `?from=${dateFrom}&to=${dateTo}`;
      }
      const result = await apiClient.get(endpoint);
      setDashboard(result.data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [filterType, dateFrom, dateTo]);

  useEffect(() => {
    if (filterType === FILTER_OPTIONS.ALL) {
      fetchDashboard();
    } else if (filterType === FILTER_OPTIONS.RANGE && dateFrom && dateTo) {
      fetchDashboard();
    }
  }, [fetchDashboard, filterType, dateFrom, dateTo]);

  if (loading && !dashboard) {
    return <div className="text-center p-6">Cargando dashboard...</div>;
  }

  if (error && !dashboard) {
    return (
      <div>
        <div className="alert alert--error mb-4">
          <div className="alert__content">
            <div className="alert__title">Error de conexion</div>
            <div className="alert__message">
              No se pudieron cargar los datos del dashboard: {error}
            </div>
          </div>
        </div>
        <button className="btn btn--primary" onClick={fetchDashboard}>
          Reintentar
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-header__title">Dashboard</h1>
          <p className="page-header__subtitle">Resumen estadistico de tareas y colaboradores</p>
        </div>
        {isGerente && (
          <button
            className="btn btn--primary"
            onClick={handleDownloadReport}
            disabled={generatingReport}
          >
            <Download size={16} className="mr-1" style={{ display: 'inline', verticalAlign: 'middle' }} />
            {generatingReport ? 'Generando reporte...' : 'Descargar Reporte'}
          </button>
        )}
      </div>

      {/* Filter */}
      <div className="card mb-6">
        <div className="card__body">
          <div className="dashboard-filter">
            <div className="dashboard-filter__group">
              <span className="dashboard-filter__label">
                <Filter size={12} className="mr-1" style={{ display: 'inline', verticalAlign: 'middle' }} />
                Periodo
              </span>
              <select
                className="form-input"
                value={filterType}
                onChange={(e) => {
                  setFilterType(e.target.value);
                  if (e.target.value === FILTER_OPTIONS.ALL) {
                    setDateFrom('');
                    setDateTo('');
                  }
                }}
              >
                <option value={FILTER_OPTIONS.ALL}>Todos</option>
                <option value={FILTER_OPTIONS.RANGE}>Rango de fechas</option>
              </select>
            </div>
            {filterType === FILTER_OPTIONS.RANGE && (
              <>
                <div className="dashboard-filter__group">
                  <span className="dashboard-filter__label">Desde</span>
                  <input
                    type="date"
                    className="form-input"
                    value={dateFrom}
                    onChange={(e) => setDateFrom(e.target.value)}
                  />
                </div>
                <div className="dashboard-filter__group">
                  <span className="dashboard-filter__label">Hasta</span>
                  <input
                    type="date"
                    className="form-input"
                    value={dateTo}
                    onChange={(e) => setDateTo(e.target.value)}
                  />
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {loading && (
        <div className="text-center p-4 mb-4 text-secondary">Actualizando datos...</div>
      )}

      {dashboard && (
        <>
          {/* Highlight Cards - solo Gerente */}
          {isGerente && <HighlightCards highlights={dashboard.highlights} />}

          {/* Heatmap with tabs - oculto para Colaborador */}
          {!isColaborador && (
            <div className="card mb-6">
              <div className="card__header">
                <h2 className="card__title">Carga de trabajo por colaborador</h2>
                <p className="card__subtitle">Intensidad basada en cantidad de tareas asignadas</p>
              </div>
              <div className="card__body">
                <HeatMapTabs
                  activeData={dashboard.collaboratorHeatmapActive}
                  historicData={dashboard.collaboratorHeatmap}
                />
              </div>
            </div>
          )}

          {/* Charts row: Avg Time + Doughnut */}
          <div className="dashboard-grid mb-6">
            <div className="card">
              <div className="card__header">
                <h2 className="card__title">Tiempo promedio por estado</h2>
                <p className="card__subtitle">Horas promedio en cada estado</p>
              </div>
              <div className="card__body">
                <div className="chart-container" style={{ height: '320px' }}>
                  <AvgTimeByStatusChart data={dashboard.avgTimeByStatus} />
                </div>
              </div>
            </div>

            <div className="card">
              <div className="card__header">
                <h2 className="card__title">Distribucion de tareas por estado</h2>
                <p className="card__subtitle">Total de tareas segun su estado actual</p>
              </div>
              <div className="card__body">
                <div className="chart-container" style={{ height: '320px' }}>
                  <TasksByStatusDoughnut data={dashboard.tasksByStatus} />
                </div>
              </div>
            </div>
          </div>

          {/* Full width: Tasks by collaborator and status */}
          <div className="card mb-6">
            <div className="card__header">
              <h2 className="card__title">Tareas por colaborador y estado</h2>
              <p className="card__subtitle">Desglose de tareas asignadas a cada colaborador</p>
            </div>
            <div className="card__body">
              <div className="chart-container" style={{ height: Math.max(300, (dashboard.tasksByCollaboratorAndStatus?.length || 1) * 40 + 80) + 'px' }}>
                <TasksByCollaboratorChart data={dashboard.tasksByCollaboratorAndStatus} historicReassigned={dashboard.historicReassignedByCollaborator} dateFrom={dateFrom} dateTo={dateTo} />
              </div>
            </div>
          </div>

          {/* Full width: Completion timeline comparison */}
          <CompletionTimelineCard
            completionTimeline={dashboard.completionTimeline}
            selectedCollaborators={selectedCollaborators}
            setSelectedCollaborators={setSelectedCollaborators}
          />
        </>
      )}
    </div>
  );
};

/* ========================================
   Highlight Cards Component
   ======================================== */
const HighlightCards = ({ highlights }) => {
  if (!highlights) return null;

  return (
    <div className="highlight-cards mb-6">
      <div className="highlight-card">
        <div className="highlight-card__icon">
          <Zap size={24} />
        </div>
        <div className="highlight-card__content">
          <div className="highlight-card__label">Colaborador más eficiente</div>
          <div className="highlight-card__value">
            {highlights.fastestCollaboratorName || 'N/A'}
          </div>
          <div className="highlight-card__detail">
            {highlights.fastestCollaboratorCompletedCount != null
              ? `${highlights.fastestCollaboratorCompletedCount} tareas · ${highlights.fastestCollaboratorEstimatedTimeSum ?? 0}h estimadas`
              : 'Sin datos'}
          </div>
        </div>
      </div>

      <div className="highlight-card">
        <div className="highlight-card__icon">
          <Trophy size={24} />
        </div>
        <div className="highlight-card__content">
          <div className="highlight-card__label">Líder top en tiempo completado</div>
          <div className="highlight-card__value">
            {highlights.topLeaderName || 'N/A'}
          </div>
          <div className="highlight-card__detail">
            {highlights.topLeaderCompletedCount != null
              ? `${highlights.topLeaderCompletedCount} tareas · ${highlights.topLeaderEstimatedTimeSum ?? 0}h estimadas`
              : 'Sin datos'}
          </div>
        </div>
      </div>
    </div>
  );
};

/* ========================================
   HeatMap Tabs Component
   ======================================== */
const HeatMapTabs = ({ activeData, historicData }) => {
  const [activeTab, setActiveTab] = useState('actual');

  return (
    <div>
      <div style={{ display: 'flex', gap: '4px', marginBottom: '16px' }}>
        <button
          className={`btn btn--sm ${activeTab === 'actual' ? 'btn--primary' : 'btn--ghost'}`}
          onClick={() => setActiveTab('actual')}
          type="button"
        >
          Actual
        </button>
        <button
          className={`btn btn--sm ${activeTab === 'historico' ? 'btn--primary' : 'btn--ghost'}`}
          onClick={() => setActiveTab('historico')}
          type="button"
        >
          Histórico
        </button>
      </div>
      <HeatMap data={activeTab === 'actual' ? activeData : historicData} />
    </div>
  );
};

/* ========================================
   HeatMap Component
   ======================================== */
const HeatMap = ({ data }) => {
  if (!data || data.length === 0) {
    return <div className="text-center text-secondary p-4">No hay datos de colaboradores</div>;
  }

  const maxHours = Math.max(...data.map((d) => d.estimatedTimeSum), 1);

  const getHeatColor = (hours) => {
    const intensity = hours / maxHours;
    // From light pink to deep BSC red (#E31837)
    const r = Math.round(255 - (255 - 227) * intensity);
    const g = Math.round(245 - (245 - 24) * intensity);
    const b = Math.round(247 - (247 - 55) * intensity);
    return `rgb(${r}, ${g}, ${b})`;
  };

  const getTextColor = (hours) => {
    const intensity = hours / maxHours;
    return intensity > 0.5 ? '#FFFFFF' : '#1A1A2E';
  };

  return (
    <div className="heatmap-grid">
      {data.map((item, index) => (
        <div
          key={index}
          className="heatmap-cell"
          style={{
            backgroundColor: getHeatColor(item.estimatedTimeSum),
            color: getTextColor(item.estimatedTimeSum),
          }}
        >
          <span className="heatmap-cell__name">{item.name}</span>
          <span className="heatmap-cell__count">{item.estimatedTimeSum}h</span>
        </div>
      ))}
    </div>
  );
};

/* ========================================
   Avg Time by Status Chart (Vertical Bar)
   ======================================== */
const AvgTimeByStatusChart = ({ data }) => {
  if (!data || data.length === 0) {
    return <div className="text-center text-secondary p-4">No hay datos disponibles</div>;
  }

  const sorted = sortByStatusOrder(data);

  const chartData = {
    labels: sorted.map((d) => d.status),
    datasets: [
      {
        label: 'Horas promedio',
        data: sorted.map((d) => d.avgHours),
        backgroundColor: sorted.map((d) => STATUS_COLORS[d.status] || '#7B8794'),
        borderColor: sorted.map((d) => STATUS_COLORS[d.status] || '#7B8794'),
        borderWidth: 1,
        borderRadius: 6,
        maxBarThickness: 50,
      },
    ],
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        callbacks: {
          label: (ctx) => `${ctx.parsed.y.toFixed(1)} horas`,
        },
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        title: {
          display: true,
          text: 'Horas',
          font: { size: 12, weight: '600' },
          color: '#6B7280',
        },
        ticks: {
          color: '#6B7280',
          font: { size: 11 },
        },
        grid: { color: '#F0EEF5' },
      },
      x: {
        ticks: {
          color: '#6B7280',
          font: { size: 11 },
          maxRotation: 45,
          minRotation: 0,
        },
        grid: { display: false },
      },
    },
  };

  return <Bar data={chartData} options={options} />;
};

/* ========================================
   Tasks by Status Doughnut Chart
   ======================================== */
const TasksByStatusDoughnut = ({ data }) => {
  if (!data || data.length === 0) {
    return <div className="text-center text-secondary p-4">No hay datos disponibles</div>;
  }

  const sorted = sortByStatusOrder(data);
  const completedCount = sorted
    .filter((d) => d.status === 'Completa')
    .reduce((sum, d) => sum + d.count, 0);
  const totalCount = sorted.reduce((sum, d) => sum + d.count, 0);

  const chartData = {
    labels: sorted.map((d) => d.status),
    datasets: [
      {
        data: sorted.map((d) => d.count),
        backgroundColor: sorted.map((d) => STATUS_COLORS[d.status] || '#7B8794'),
        borderColor: '#FFFFFF',
        borderWidth: 2,
        hoverOffset: 8,
      },
    ],
  };

  const centerTextPlugin = {
    id: 'centerText',
    afterDraw: (chart) => {
      const { ctx, width, height } = chart;
      ctx.save();
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      const centerX = width / 2;
      const centerY = height / 2 - 16;
      ctx.font = 'bold 28px Inter, sans-serif';
      ctx.fillStyle = '#2E7D32';
      ctx.fillText(completedCount, centerX, centerY);
      ctx.font = '12px Inter, sans-serif';
      ctx.fillStyle = '#6B7280';
      ctx.fillText(`de ${totalCount} completas`, centerX, centerY + 22);
      ctx.restore();
    },
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          padding: 16,
          usePointStyle: true,
          pointStyle: 'circle',
          font: { size: 11 },
          color: '#1A1A2E',
        },
      },
      tooltip: {
        callbacks: {
          label: (ctx) => {
            const total = ctx.dataset.data.reduce((a, b) => a + b, 0);
            const pct = ((ctx.parsed / total) * 100).toFixed(1);
            return `${ctx.label}: ${ctx.parsed} (${pct}%)`;
          },
        },
      },
    },
    cutout: '60%',
  };

  return <Doughnut data={chartData} options={options} plugins={[centerTextPlugin]} />;
};

/* ========================================
   Tasks by Collaborator & Status (Horizontal Stacked Bar)
   ======================================== */
const downloadTasksXlsx = (tasks, fileName) => {
  const rows = tasks.map((t) => ({
    'Titulo': t.title || '',
    'Descripcion': t.description || '',
    'Estado': t.status || '',
    'Lider asignado': t.assignedLeaderName || '',
    'Colaborador asignado': t.assignedToName || '',
    'Fecha de entrega': formatDateDDMMYYYY(t.dueDate),
    'Tiempo estimado (h)': t.estimatedTime ?? '',
    'Tiempo real (h)': t.actualTime ?? '',
    'Insumos': t.insumos || '',
    'Observaciones': t.observations || '',
    'Evidencia': t.evidenceText || '',
    'Creado por': t.createdBy || '',
    'Fecha de creacion': formatDateTimeDDMMYYYY(t.createdAt),
  }));
  if (rows.length === 0) {
    alert('No hay tareas para descargar.');
    return;
  }
  const ws = XLSX.utils.json_to_sheet(rows);
  const colWidths = Object.keys(rows[0]).map((key) => {
    const maxLen = Math.max(key.length, ...rows.map((r) => String(r[key] || '').length));
    return { wch: Math.min(maxLen + 2, 60) };
  });
  ws['!cols'] = colWidths;
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Tareas');
  XLSX.writeFile(wb, fileName);
};

const TasksByCollaboratorChart = ({ data, historicReassigned, dateFrom, dateTo }) => {
  const chartRef = useRef(null);

  if (!data || data.length === 0) {
    return <div className="text-center text-secondary p-4">No hay datos disponibles</div>;
  }

  // Collect all unique statuses
  const allStatuses = new Set();
  data.forEach((item) => {
    if (item.statusCounts) {
      Object.keys(item.statusCounts).forEach((s) => allStatuses.add(s));
    }
  });

  const statuses = sortStatuses(Array.from(allStatuses));
  const collaboratorNames = data.map((d) => d.name);

  // Build lookup for historic reassigned counts
  const reassignedMap = {};
  if (historicReassigned) {
    historicReassigned.forEach((item) => {
      reassignedMap[item.name] = item.count;
    });
  }

  const datasets = statuses.map((status) => ({
    label: status,
    data: data.map((d) => (d.statusCounts ? d.statusCounts[status] || 0 : 0)),
    backgroundColor: STATUS_COLORS[status] || '#7B8794',
    borderRadius: 4,
    maxBarThickness: 30,
  }));

  // Add "Reasignadas - Históricas" dataset, hidden by default
  datasets.push({
    label: 'Reasignadas - Históricas',
    data: collaboratorNames.map((name) => reassignedMap[name] || 0),
    backgroundColor: '#9B59B6',
    borderRadius: 4,
    maxBarThickness: 30,
    hidden: true,
  });

  const chartData = {
    labels: collaboratorNames,
    datasets,
  };

  const handleClick = async (event) => {
    const chart = chartRef.current;
    if (!chart) return;

    // Check if clicked on a bar element
    const elements = chart.getElementsAtEventForMode(event.nativeEvent, 'nearest', { intersect: true }, false);
    if (elements.length > 0) {
      const el = elements[0];
      const collaboratorName = collaboratorNames[el.index];
      const statusLabel = chartData.datasets[el.datasetIndex].label;
      const isHistoric = statusLabel === 'Reasignadas - Históricas';
      const statusParam = isHistoric ? null : statusLabel;
      try {
        const exportOpts = isHistoric ? { historicStatus: 'Reasignada' } : {};
        const tasks = await tasksService.exportByCollaborator(collaboratorName, statusParam, dateFrom || undefined, dateTo || undefined, exportOpts);
        const safeStatus = (isHistoric ? 'Reasignadas_Historicas' : statusLabel).replace(/[^a-zA-Z0-9áéíóúñÁÉÍÓÚÑ ]/g, '').replace(/\s+/g, '_');
        const safeName = collaboratorName.replace(/\s+/g, '_');
        downloadTasksXlsx(tasks, `${safeName}_${safeStatus}.xlsx`);
      } catch (err) {
        alert('Error al descargar: ' + (err.message || 'Error desconocido'));
      }
      return;
    }

    // Check if clicked on a Y-axis label (collaborator name)
    const yScale = chart.scales.y;
    if (!yScale) return;
    const { top, bottom, left } = yScale;
    const mouseX = event.nativeEvent.offsetX;
    const mouseY = event.nativeEvent.offsetY;
    if (mouseX <= left && mouseY >= top && mouseY <= bottom) {
      const labelIndex = yScale.getValueForPixel(mouseY);
      if (labelIndex >= 0 && labelIndex < collaboratorNames.length) {
        const collaboratorName = collaboratorNames[Math.round(labelIndex)];
        try {
          const tasks = await tasksService.exportByCollaborator(collaboratorName, null, dateFrom || undefined, dateTo || undefined);
          const safeName = collaboratorName.replace(/\s+/g, '_');
          downloadTasksXlsx(tasks, `${safeName}_Todas.xlsx`);
        } catch (err) {
          alert('Error al descargar: ' + (err.message || 'Error desconocido'));
        }
      }
    }
  };

  const options = {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          padding: 12,
          usePointStyle: true,
          pointStyle: 'circle',
          font: { size: 11 },
          color: '#1A1A2E',
        },
      },
      tooltip: {
        mode: 'nearest',
        intersect: true,
        callbacks: {
          title: (tooltipItems) => {
            if (tooltipItems.length > 0) {
              return tooltipItems[0].label;
            }
            return '';
          },
        },
      },
    },
    scales: {
      x: {
        stacked: true,
        beginAtZero: true,
        title: {
          display: true,
          text: 'Cantidad de tareas',
          font: { size: 12, weight: '600' },
          color: '#6B7280',
        },
        ticks: {
          color: '#6B7280',
          font: { size: 11 },
          stepSize: 1,
        },
        grid: { color: '#F0EEF5' },
      },
      y: {
        stacked: true,
        ticks: {
          color: '#1A1A2E',
          font: { size: 12, weight: '500' },
          cursor: 'pointer',
        },
        grid: { display: false },
      },
    },
    onHover: (event, elements, chart) => {
      const yScale = chart.scales.y;
      if (!yScale) return;
      const mouseX = event.native?.offsetX;
      const mouseY = event.native?.offsetY;
      const isOverLabel = mouseX <= yScale.left && mouseY >= yScale.top && mouseY <= yScale.bottom;
      chart.canvas.style.cursor = (elements.length > 0 || isOverLabel) ? 'pointer' : 'default';
    },
  };

  return <Bar ref={chartRef} data={chartData} options={options} onClick={handleClick} />;
};

/* ========================================
   Completion Timeline Line Chart
   ======================================== */
const TIMELINE_COLORS = [
  '#E31837', '#4A90D9', '#50C878', '#F5A623', '#9B59B6',
  '#1ABC9C', '#E67E22', '#2C3E50', '#E85D75', '#3498DB',
];

const CompletionTimelineCard = ({ completionTimeline, selectedCollaborators, setSelectedCollaborators }) => {
  const [selectedValue, setSelectedValue] = useState('');

  if (!completionTimeline || completionTimeline.length === 0) {
    return null;
  }

  const availableCollaborators = completionTimeline.filter(
    (c) => !selectedCollaborators.includes(c.name)
  );

  const handleAdd = () => {
    if (selectedValue && !selectedCollaborators.includes(selectedValue)) {
      setSelectedCollaborators([...selectedCollaborators, selectedValue]);
      setSelectedValue('');
    }
  };

  const handleRemove = (name) => {
    setSelectedCollaborators(selectedCollaborators.filter((c) => c !== name));
  };

  // Build chart data from selected collaborators
  const buildChartData = () => {
    const datasets = selectedCollaborators.map((name, index) => {
      const collaborator = completionTimeline.find((c) => c.name === name);
      const color = TIMELINE_COLORS[index % TIMELINE_COLORS.length];
      const points = collaborator?.dataPoints || [];
      return {
        label: name,
        data: points.map((p) => ({ x: p.date, y: p.cumulativeCount })),
        borderColor: color,
        backgroundColor: color + '1A',
        pointBackgroundColor: color,
        pointBorderColor: '#FFFFFF',
        pointBorderWidth: 2,
        pointRadius: 4,
        pointHoverRadius: 6,
        tension: 0.3,
        fill: false,
        borderWidth: 2,
      };
    });

    // Collect all unique dates sorted
    const allDates = [
      ...new Set(
        datasets.flatMap((ds) => ds.data.map((p) => p.x))
      ),
    ].sort();

    return {
      labels: allDates,
      datasets: datasets.map((ds) => ({
        ...ds,
        data: allDates.map((date) => {
          const point = ds.data.find((p) => p.x === date);
          return point ? point.y : null;
        }),
      })),
    };
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          padding: 12,
          usePointStyle: true,
          pointStyle: 'circle',
          font: { size: 11 },
          color: '#1A1A2E',
        },
      },
      tooltip: {
        mode: 'index',
        intersect: false,
      },
    },
    scales: {
      x: {
        title: {
          display: true,
          text: 'Fecha',
          font: { size: 12, weight: '600' },
          color: '#6B7280',
        },
        ticks: {
          color: '#6B7280',
          font: { size: 11 },
          maxRotation: 45,
          minRotation: 0,
        },
        grid: { color: '#F0EEF5' },
      },
      y: {
        beginAtZero: true,
        title: {
          display: true,
          text: 'Tareas completadas',
          font: { size: 12, weight: '600' },
          color: '#6B7280',
        },
        ticks: {
          color: '#6B7280',
          font: { size: 11 },
          stepSize: 1,
        },
        grid: { color: '#F0EEF5' },
      },
    },
    spanGaps: true,
  };

  return (
    <div className="card mb-6">
      <div className="card__header">
        <h2 className="card__title">Comparativa de tareas completadas en el tiempo</h2>
        <p className="card__subtitle">Seleccione colaboradores para comparar su progreso de completacion</p>
      </div>
      <div className="card__body">
        <div className="timeline-selector">
          <select
            className="form-input"
            value={selectedValue}
            onChange={(e) => setSelectedValue(e.target.value)}
          >
            <option value="">-- Seleccionar colaborador --</option>
            {availableCollaborators.map((c) => (
              <option key={c.name} value={c.name}>
                {c.name}
              </option>
            ))}
          </select>
          <button
            className="btn btn--primary btn--sm"
            onClick={handleAdd}
            disabled={!selectedValue}
          >
            Agregar
          </button>
        </div>

        {selectedCollaborators.length > 0 && (
          <div className="timeline-tags">
            {selectedCollaborators.map((name, index) => (
              <span
                key={name}
                className="timeline-tag"
                style={{ borderLeftColor: TIMELINE_COLORS[index % TIMELINE_COLORS.length] }}
              >
                {name}
                <button
                  className="timeline-tag__remove"
                  onClick={() => handleRemove(name)}
                  title={`Quitar ${name}`}
                >
                  &times;
                </button>
              </span>
            ))}
          </div>
        )}

        {selectedCollaborators.length === 0 ? (
          <div className="text-center text-secondary p-6">
            Seleccione al menos un colaborador para ver el grafico
          </div>
        ) : (
          <div className="chart-container" style={{ height: '360px' }}>
            <Line data={buildChartData()} options={chartOptions} />
          </div>
        )}
      </div>
    </div>
  );
};

export default Home;
