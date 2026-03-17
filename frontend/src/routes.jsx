import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/layout/Layout';

const Home = lazy(() => import('./pages/Home/Home'));

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
      </Route>
    </Routes>
  </BrowserRouter>
);

export default AppRoutes;
