import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/layout/Layout';
import ProtectedRoute from './components/ProtectedRoute';

const Login = lazy(() => import('./pages/Login/Login'));
const Home = lazy(() => import('./pages/Home/Home'));
const Roles = lazy(() => import('./pages/Roles/Roles'));
const Tasks = lazy(() => import('./pages/Tasks/Tasks'));
const Colaboradores = lazy(() => import('./pages/Colaboradores/Colaboradores'));

const SuspenseWrap = ({ children }) => (
  <Suspense fallback={<div className="text-center p-6">Cargando...</div>}>
    {children}
  </Suspense>
);

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
        <Route
          index
          element={
            <SuspenseWrap>
              <Home />
            </SuspenseWrap>
          }
        />
        <Route
          path="roles"
          element={
            <SuspenseWrap>
              <Roles />
            </SuspenseWrap>
          }
        />
        <Route
          path="tasks"
          element={
            <SuspenseWrap>
              <Tasks />
            </SuspenseWrap>
          }
        />
        <Route
          path="colaboradores"
          element={
            <SuspenseWrap>
              <Colaboradores />
            </SuspenseWrap>
          }
        />
      </Route>
    </Routes>
  </BrowserRouter>
);

export default AppRoutes;
