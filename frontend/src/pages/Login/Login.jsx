import { useState, useContext } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import SessionContext from '../../context/SessionContext';
import './Login.css';

const Login = () => {
  const { login, isAuthenticated } = useContext(SessionContext);
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!email || !password) {
      setError('Ingrese correo y contraseña.');
      return;
    }

    try {
      setLoading(true);
      const data = await login(email, password);
      if (data.lastLoginAt) {
        sessionStorage.setItem('fp_last_login', data.lastLoginAt);
      }
      navigate('/', { replace: true });
    } catch (err) {
      const msg =
        err.status === 401
          ? 'Credenciales incorrectas. Verifique su correo y contraseña.'
          : err.message || 'Error al iniciar sesión. Intente nuevamente.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="card">
          <div className="card__body">
            <div className="login-logo">
              <img src="/logo.png" alt="Nomina2" />
            </div>

            {error && (
              <div className="alert alert--error mb-4">
                <div className="alert__content">
                  <div className="alert__message">{error}</div>
                </div>
              </div>
            )}

            <form className="login-form" onSubmit={handleSubmit}>
              <div className="form-group">
                <label className="form-label" htmlFor="login-email">
                  Correo electrónico
                </label>
                <input
                  id="login-email"
                  type="email"
                  className="form-control"
                  placeholder="Correo electrónico"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="email"
                  disabled={loading}
                />
              </div>

              <div className="form-group">
                <label className="form-label" htmlFor="login-password">
                  Contraseña
                </label>
                <input
                  id="login-password"
                  type="password"
                  className="form-control"
                  placeholder="Contraseña"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  disabled={loading}
                />
              </div>

              <button
                type="submit"
                className="btn btn--primary btn--lg login-btn"
                disabled={loading}
              >
                {loading ? 'Ingresando...' : 'Iniciar sesión'}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
