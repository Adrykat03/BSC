import useApi from '../../hooks/useApi';
import {
  Chart as ChartJS,
  ArcElement,
  Tooltip,
  Legend,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
} from 'chart.js';
import { Doughnut, Bar } from 'react-chartjs-2';

ChartJS.register(ArcElement, Tooltip, Legend, CategoryScale, LinearScale, BarElement, Title);

const doughnutData = {
  labels: ['Bebidas', 'Snacks', 'Postres', 'Combos', 'Otros'],
  datasets: [
    {
      data: [35, 25, 20, 15, 5],
      backgroundColor: [
        '#E31837',
        '#1A1A2E',
        '#4A90D9',
        '#F5A623',
        '#7B8794',
      ],
      borderColor: '#FFFFFF',
      borderWidth: 2,
    },
  ],
};

const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        padding: 16,
        usePointStyle: true,
        font: { size: 13 },
      },
    },
  },
};

const barData = {
  labels: ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'],
  datasets: [
    {
      label: 'Ventas ($)',
      data: [4200, 3800, 5100, 4700, 5600, 6100],
      backgroundColor: '#E31837',
      borderRadius: 4,
    },
    {
      label: 'Costos ($)',
      data: [2800, 2600, 3200, 3000, 3500, 3800],
      backgroundColor: '#1A1A2E',
      borderRadius: 4,
    },
  ],
};

const barOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        padding: 16,
        usePointStyle: true,
        font: { size: 13 },
      },
    },
    title: {
      display: false,
    },
  },
  scales: {
    y: {
      beginAtZero: true,
      grid: { color: 'rgba(0,0,0,0.06)' },
    },
    x: {
      grid: { display: false },
    },
  },
};

const Home = () => {
  const { data, loading, error, execute } = useApi('/health');

  if (loading) {
    return <div className="text-center p-6">Cargando...</div>;
  }

  if (error) {
    return (
      <div>
        <div className="alert alert--error mb-4">
          <div className="alert__content">
            <div className="alert__title">Error de conexion</div>
            <div className="alert__message">
              No se pudo conectar con el backend: {error}
            </div>
          </div>
        </div>
        <button className="btn btn--primary" onClick={execute}>
          Reintentar
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="d-flex items-center gap-3 mb-6">
        <h2 className="text-2xl font-bold m-0">Dashboard</h2>
        <span className="badge badge--active">Conectado</span>
      </div>

      <div className="card">
        <div className="card__header">
          <h3 className="card__title">Estado del Sistema</h3>
          <p className="card__subtitle">Informacion del backend</p>
        </div>
        <div className="card__body">
          <p className="text-sm text-secondary mb-2">Estado del servicio:</p>
          <p className="text-lg font-semibold">
            Backend activo
          </p>
          {data && (
            <pre className="text-xs text-secondary mt-4" style={{ whiteSpace: 'pre-wrap' }}>
              {JSON.stringify(data, null, 2)}
            </pre>
          )}
        </div>
      </div>

      <div className="d-grid gap-4 mt-6" style={{ gridTemplateColumns: '1fr 1fr' }}>
        <div className="card">
          <div className="card__header">
            <h3 className="card__title">Productos por Categoria</h3>
          </div>
          <div className="card__body" style={{ height: '320px' }}>
            <Doughnut data={doughnutData} options={doughnutOptions} />
          </div>
        </div>

        <div className="card">
          <div className="card__header">
            <h3 className="card__title">Ventas vs Costos por Mes</h3>
          </div>
          <div className="card__body" style={{ height: '320px' }}>
            <Bar data={barData} options={barOptions} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;
