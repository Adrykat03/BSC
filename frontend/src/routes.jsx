import { lazy, Suspense, useContext } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/layout/Layout';
import ProtectedRoute from './components/ProtectedRoute';
import ModuleRoute from './components/ModuleRoute';
import SessionContext from './context/SessionContext';
import { getFirstAllowedPath } from './utils/modules';

const Login = lazy(() => import('./pages/Login/Login'));
const Home = lazy(() => import('./pages/Home/Home'));
const Roles = lazy(() => import('./pages/Roles/Roles'));
const Tasks = lazy(() => import('./pages/Tasks/Tasks'));
const Colaboradores = lazy(() => import('./pages/Colaboradores/Colaboradores'));
const AlertasPayroll = lazy(() => import('./pages/AlertasPayroll/AlertasPayroll'));

const SuspenseWrap = ({ children }) => (
  <Suspense fallback={<div className="text-center p-6">Cargando...</div>}>
    {children}
  </Suspense>
);

const HomeOrRedirect = () => {
  const { user } = useContext(SessionContext);
  const userModules = user?.modules || [];

  // Si tiene dashboard, se queda en Home; si no, va a su primer modulo permitido.
  if (userModules.includes('dashboard')) {
    return <SuspenseWrap><Home /></SuspenseWrap>;
  }

  const firstPath = getFirstAllowedPath(userModules);
  if (firstPath) {
    return <Navigate to={firstPath} replace />;
  }

  return <Navigate to="/login" replace />;
};

const AppRoutes = () => (
  <BrowserRouter>
    <Routes>
      {/* Public route */}
      <Route
        path="/login"
        element={
          <SuspenseWrap>
            <Login />
          </SuspenseWrap>
        }
      />

      {/* Protected routes with layout */}
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route index element={<HomeOrRedirect />} />
        <Route
          path="roles"
          element={
            <ModuleRoute module="roles">
              <SuspenseWrap>
                <Roles />
              </SuspenseWrap>
            </ModuleRoute>
          }
        />
        <Route
          path="tasks"
          element={
            <ModuleRoute module="tareas">
              <SuspenseWrap>
                <Tasks />
              </SuspenseWrap>
            </ModuleRoute>
          }
        />
        <Route
          path="colaboradores"
          element={
            <ModuleRoute module="colaboradores">
              <SuspenseWrap>
                <Colaboradores />
              </SuspenseWrap>
            </ModuleRoute>
          }
        />
        <Route
          path="alertas-payroll"
          element={
            <ModuleRoute module="alertas-payroll">
              <SuspenseWrap>
                <AlertasPayroll />
              </SuspenseWrap>
            </ModuleRoute>
          }
        />
      </Route>
    </Routes>
  </BrowserRouter>
);

export default AppRoutes;
