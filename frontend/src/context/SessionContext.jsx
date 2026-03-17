import { createContext, useState, useEffect, useCallback } from 'react';
import { colaboradorService } from '../services/colaboradorService';
import { LogIn, Users, Shield } from 'lucide-react';
import toast, { Toaster } from 'react-hot-toast';

const SESSION_KEY = 'bsc_session';

export const SessionContext = createContext(null);

const RoleSelector = ({ colaborador, onSelect, onBack }) => {
  const rolNames = colaborador.rolNames || [];

  return (
    <>
      <Toaster position="top-right" />
      <div className="modal-backdrop modal-backdrop--open" />
      <div className="modal modal--open">
        <div className="modal__header">
          <h3 className="modal__title">Seleccionar Rol</h3>
        </div>
        <div className="modal__body">
          <p className="text-sm mb-4">
            <strong>{colaborador.nombreCompleto}</strong> tiene multiples roles.
            Seleccione con cual rol desea operar:
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {rolNames.map((rolName, idx) => (
              <button
                key={idx}
                className="btn btn--outline-primary"
                style={{ justifyContent: 'flex-start', gap: '8px', padding: '12px 16px' }}
                onClick={() => onSelect(rolName)}
              >
                <Shield size={18} />
                {rolName}
              </button>
            ))}
          </div>
        </div>
        <div className="modal__footer">
          <button className="btn btn--secondary" onClick={onBack}>
            Volver
          </button>
        </div>
      </div>
    </>
  );
};

const SessionSelector = ({ onSelect }) => {
  const [colaboradores, setColaboradores] = useState([]);
  const [selectedId, setSelectedId] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [roleStep, setRoleStep] = useState(false);
  const [selectedColaborador, setSelectedColaborador] = useState(null);

  useEffect(() => {
    loadColaboradores();
  }, []);

  const loadColaboradores = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await colaboradorService.getAll();
      setColaboradores(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!selectedId) {
      toast.error('Seleccione un colaborador');
      return;
    }
    const colaborador = colaboradores.find((c) => c.id === selectedId);
    if (!colaborador) return;

    const rolNames = colaborador.rolNames || (colaborador.rolName ? [colaborador.rolName] : []);

    if (rolNames.length > 1) {
      setSelectedColaborador({ ...colaborador, rolNames });
      setRoleStep(true);
      return;
    }

    const activeRole = rolNames[0] || 'Colaborador';
    const user = {
      id: colaborador.id,
      name: colaborador.nombreCompleto,
      email: colaborador.correo,
      role: activeRole,
      roles: rolNames,
    };
    onSelect(user);
  };

  const handleRoleSelect = (rolName) => {
    if (!selectedColaborador) return;
    const rolNames = selectedColaborador.rolNames || [];
    const user = {
      id: selectedColaborador.id,
      name: selectedColaborador.nombreCompleto,
      email: selectedColaborador.correo,
      role: rolName,
      roles: rolNames,
    };
    onSelect(user);
  };

  const handleBackFromRole = () => {
    setRoleStep(false);
    setSelectedColaborador(null);
  };

  if (roleStep && selectedColaborador) {
    return (
      <RoleSelector
        colaborador={selectedColaborador}
        onSelect={handleRoleSelect}
        onBack={handleBackFromRole}
      />
    );
  }

  const getRolDisplay = (c) => {
    if (c.rolNames && c.rolNames.length > 0) {
      return c.rolNames.join(', ');
    }
    return c.rolName || 'Sin rol';
  };

  return (
    <>
      <Toaster position="top-right" />
      <div className="modal-backdrop modal-backdrop--open" />
      <div className="modal modal--open">
        <div className="modal__header">
          <h3 className="modal__title">Iniciar Sesion (Simulado)</h3>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal__body">
            {loading && (
              <div className="text-center p-6">Cargando colaboradores...</div>
            )}

            {error && (
              <div className="alert alert--error mb-4">
                <div className="alert__content">
                  <div className="alert__title">Error de conexion</div>
                  <div className="alert__message">
                    No se pudieron cargar los colaboradores: {error}
                  </div>
                </div>
              </div>
            )}

            {!loading && !error && colaboradores.length === 0 && (
              <div className="alert alert--warning">
                <div className="alert__content">
                  <div className="alert__title">Sin colaboradores</div>
                  <div className="alert__message">
                    No hay colaboradores registrados. Primero debe crear roles y colaboradores desde la API.
                  </div>
                </div>
              </div>
            )}

            {!loading && !error && colaboradores.length > 0 && (
              <div className="form-group mb-4">
                <label className="form-label">Colaborador</label>
                <select
                  className="form-control form-select"
                  value={selectedId}
                  onChange={(e) => setSelectedId(e.target.value)}
                >
                  <option value="">Seleccione un colaborador...</option>
                  {colaboradores.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.nombreCompleto} — {getRolDisplay(c)}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>
          <div className="modal__footer">
            {error && (
              <button
                type="button"
                className="btn btn--secondary"
                onClick={loadColaboradores}
              >
                Reintentar
              </button>
            )}
            <button
              type="submit"
              className="btn btn--primary"
              disabled={loading || !selectedId}
            >
              <LogIn size={16} />
              Ingresar
            </button>
          </div>
        </form>
      </div>
    </>
  );
};

export const SessionProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [initialized, setInitialized] = useState(false);

  useEffect(() => {
    const stored = sessionStorage.getItem(SESSION_KEY);
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        if (parsed && parsed.name && parsed.email && parsed.role) {
          setUser(parsed);
        }
      } catch {
        sessionStorage.removeItem(SESSION_KEY);
      }
    }
    setInitialized(true);
  }, []);

  const handleSetUser = useCallback((userData) => {
    setUser(userData);
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(userData));
  }, []);

  const switchRole = useCallback((newRole) => {
    setUser((prev) => {
      if (!prev) return prev;
      const updated = { ...prev, role: newRole };
      sessionStorage.setItem(SESSION_KEY, JSON.stringify(updated));
      return updated;
    });
  }, []);

  const logout = useCallback(() => {
    setUser(null);
    sessionStorage.removeItem(SESSION_KEY);
  }, []);

  if (!initialized) {
    return <div className="text-center p-6">Cargando...</div>;
  }

  if (!user) {
    return <SessionSelector onSelect={handleSetUser} />;
  }

  return (
    <SessionContext.Provider value={{ user, setUser: handleSetUser, logout, switchRole }}>
      {children}
    </SessionContext.Provider>
  );
};

export default SessionContext;
