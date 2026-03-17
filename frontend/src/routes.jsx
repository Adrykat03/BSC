import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/layout/Layout';

const Home = lazy(() => import('./pages/Home/Home'));
const Roles = lazy(() => import('./pages/Roles/Roles'));
const Tasks = lazy(() => import('./pages/Tasks/Tasks'));
const Colaboradores = lazy(() => import('./pages/Colaboradores/Colaboradores'));

const AppRoutes = () => (
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route
          index
          element={
            <Suspense fallback={<div className="text-center p-6">Cargando...</div>}>
              <Home />
            </Suspense>
          }
        />
        <Route
          path="roles"
          element={
            <Suspense fallback={<div className="text-center p-6">Cargando...</div>}>
              <Roles />
            </Suspense>
          }
        />
        <Route
          path="tasks"
          element={
            <Suspense fallback={<div className="text-center p-6">Cargando...</div>}>
              <Tasks />
            </Suspense>
          }
        />
        <Route
          path="colaboradores"
          element={
            <Suspense fallback={<div className="text-center p-6">Cargando...</div>}>
              <Colaboradores />
            </Suspense>
          }
        />
      </Route>
    </Routes>
  </BrowserRouter>
);

export default AppRoutes;
