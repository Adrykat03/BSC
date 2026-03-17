import { useState, useEffect, useCallback } from 'react';
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
import { Zap, Trophy, Calendar, Filter } from 'lucide-react';
import { apiClient } from '../../services/api';
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

const Home = () => {
  const [filterType, setFilterType] = useState(FILTER_OPTIONS.ALL);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedCollaborators, setSelectedCollaborators] = useState([]);

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
          {/* Highlight Cards */}
          <HighlightCards highlights={dashboard.highlights} />

          {/* Heatmap with tabs */}
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
                <TasksByCollaboratorChart data={dashboard.tasksByCollaboratorAndStatus} />
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
          <div className="highlight-card__label">Colaborador mas eficiente</div>
          <div className="highlight-card__value">
            {highlights.fastestCollaboratorName || 'N/A'}
          </div>
          <div className="highlight-card__detail">
            Promedio: {highlights.fastestCollaboratorAvgHours != null
              ? `${highlights.fastestCollaboratorAvgHours.toFixed(1)} horas`
              : 'Sin datos'}
          </div>
        </div>
      </div>

      <div className="highlight-card">
        <div className="highlight-card__icon">
          <Trophy size={24} />
        </div>
        <div className="highlight-card__content">
          <div className="highlight-card__label">Lider con mas tareas completas</div>
          <div className="highlight-card__value">
            {highlights.topLeaderName || 'N/A'}
          </div>
          <div className="highlight-card__detail">
            Completadas: {highlights.topLeaderCompletedCount != null
              ? highlights.topLeaderCompletedCount
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

  const maxCount = Math.max(...data.map((d) => d.taskCount), 1);

  const getHeatColor = (count) => {
    const intensity = count / maxCount;
    // From light pink to deep BSC red (#E31837)
    const r = Math.round(255 - (255 - 227) * intensity);
    const g = Math.round(245 - (245 - 24) * intensity);
    const b = Math.round(247 - (247 - 55) * intensity);
    return `rgb(${r}, ${g}, ${b})`;
  };

  const getTextColor = (count) => {
    const intensity = count / maxCount;
    return intensity > 0.5 ? '#FFFFFF' : '#1A1A2E';
  };

  return (
    <div className="heatmap-grid">
      {data.map((item, index) => (
        <div
          key={index}
          className="heatmap-cell"
          style={{
            backgroundColor: getHeatColor(item.taskCount),
            color: getTextColor(item.taskCount),
          }}
        >
          <span className="heatmap-cell__name">{item.name}</span>
          <span className="heatmap-cell__count">{item.taskCount}</span>
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

  return <Doughnut data={chartData} options={options} />;
};

/* ========================================
   Tasks by Collaborator & Status (Horizontal Stacked Bar)
   ======================================== */
const TasksByCollaboratorChart = ({ data }) => {
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

  const chartData = {
    labels: data.map((d) => d.name),
    datasets: statuses.map((status) => ({
      label: status,
      data: data.map((d) => (d.statusCounts ? d.statusCounts[status] || 0 : 0)),
      backgroundColor: STATUS_COLORS[status] || '#7B8794',
      borderRadius: 4,
      maxBarThickness: 30,
    })),
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
        mode: 'index',
        intersect: false,
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
        },
        grid: { display: false },
      },
    },
  };

  return <Bar data={chartData} options={options} />;
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
