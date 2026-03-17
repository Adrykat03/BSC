import { useContext } from 'react';
import { Navigate } from 'react-router-dom';
import SessionContext from '../context/SessionContext';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated } = useContext(SessionContext);
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return children;
};

export default ProtectedRoute;
