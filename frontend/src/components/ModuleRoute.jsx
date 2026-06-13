import { useContext } from 'react';
import { Navigate } from 'react-router-dom';
import SessionContext from '../context/SessionContext';
import { getFirstAllowedPath } from '../utils/modules';

/**
 * Guard de modulo: solo renderiza children si el usuario tiene el modulo `module`.
 * Si no lo tiene, redirige a su primer modulo permitido (orden del catalogo).
 * Si no tiene ningun modulo permitido, redirige a /login.
 */
const ModuleRoute = ({ module, children }) => {
  const { user } = useContext(SessionContext);
  const userModules = user?.modules || [];

  if (userModules.includes(module)) {
    return children;
  }

  const firstPath = getFirstAllowedPath(userModules);
  if (firstPath && firstPath !== window.location.pathname) {
    return <Navigate to={firstPath} replace />;
  }

  return <Navigate to="/login" replace />;
};

export default ModuleRoute;
