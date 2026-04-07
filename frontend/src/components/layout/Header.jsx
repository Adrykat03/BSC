import { useContext, useState, useRef, useEffect, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { LogOut, User, ChevronDown, RefreshCw, Menu, Bell, HelpCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import SessionContext from '../../context/SessionContext';
import { tasksService } from '../../services/tasksService';

const pageTitles = {
  '/': 'Dashboard',
  '/roles': 'Roles',
  '/tasks': 'Tareas',
  '/colaboradores': 'Colaboradores',
  '/alertas-payroll': 'Alertas Payroll',
};

const Header = ({ isMobile, onOpenSidebar }) => {
  const location = useLocation();
  const title = pageTitles[location.pathname] || 'Nomina2';
  const { user, logout, switchRole } = useContext(SessionContext);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [switchingRole, setSwitchingRole] = useState(false);
  const dropdownRef = useRef(null);

  const hasMultipleRoles = user?.roles && user.roles.length > 1;
  const [pendingCount, setPendingCount] = useState(0);

  const fetchPendingCount = useCallback(async () => {
    if (!user) return;
    try {
      const asignadas = await tasksService.getAll(1, 1, '', 'Asignada');
      const reasignadas = await tasksService.getAll(1, 1, '', 'Reasignada');
      setPendingCount((asignadas.totalCount || 0) + (reasignadas.totalCount || 0));
    } catch {
      setPendingCount(0);
    }
  }, [user]);

  useEffect(() => {
    fetchPendingCount();
    const interval = setInterval(fetchPendingCount, 60000);
    return () => clearInterval(interval);
  }, [fetchPendingCount]);

  // Show last login permanently after login
  const [lastLoginText, setLastLoginText] = useState('');
  useEffect(() => {
    const lastLogin = sessionStorage.getItem('fp_last_login');
    if (lastLogin) {
      sessionStorage.removeItem('fp_last_login');
      const lastDate = new Date(lastLogin);
      if (!isNaN(lastDate.getTime())) {
        const formatted = lastDate.toLocaleString('es-EC', {
          day: '2-digit', month: '2-digit', year: 'numeric',
          hour: '2-digit', minute: '2-digit'
        });
        setLastLoginText(formatted);
      }
    }
  }, []);

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSwitchRole = async (newRole) => {
    try {
      setSwitchingRole(true);
      await switchRole(newRole);
      setDropdownOpen(false);
      window.location.reload();
    } catch (err) {
      console.error('Error switching role:', err);
      toast.error('Error al cambiar rol. Intente nuevamente.');
      setSwitchingRole(false);
    }
  };

  return (
    <div className="header">
      <div className="header__left">
        {isMobile && (
          <button
            className="header__hamburger"
            onClick={onOpenSidebar}
            aria-label="Abrir menu"
          >
            <Menu size={24} />
          </button>
        )}
        <h1 className="text-xl font-semibold m-0 header__title">{title}</h1>
      </div>
      <div className="header__right">
        {user && (
          <>
          {/* Help icon — download user manual PDF */}
          <a
            href="/Manual_Nomina2.pdf"
            download="Manual_Nomina2.pdf"
            data-tooltip="Descargar manual"
            style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}
          >
            <HelpCircle size={20} style={{ color: 'var(--color-text-secondary)' }} />
          </a>
          {/* Notification bell */}
          <div
            style={{ position: 'relative', display: 'flex', alignItems: 'center', cursor: 'pointer' }}
            onClick={() => {
              if (pendingCount > 0) {
                toast(`Tiene ${pendingCount} tarea${pendingCount > 1 ? 's' : ''} pendiente${pendingCount > 1 ? 's' : ''} por cumplir`, { icon: '\u{1F514}', duration: 4000 });
              } else {
                toast('No tiene tareas pendientes', { icon: '\u{2705}', duration: 3000 });
              }
            }}
            data-tooltip={pendingCount > 0 ? `${pendingCount} tarea${pendingCount > 1 ? 's' : ''} pendiente${pendingCount > 1 ? 's' : ''}` : 'Sin tareas pendientes'}
          >
            <Bell size={22} style={{ color: 'var(--color-text-secondary)' }} />
            {pendingCount > 0 && (
              <span style={{
                position: 'absolute',
                top: '-6px',
                right: '-8px',
                backgroundColor: '#E31837',
                color: '#fff',
                fontSize: '11px',
                fontWeight: 700,
                minWidth: '18px',
                height: '18px',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                lineHeight: 1,
                padding: '0 4px',
              }}>
                {pendingCount}
              </span>
            )}
          </div>
          <div
            className={`dropdown${dropdownOpen ? ' dropdown--open' : ''}`}
            ref={dropdownRef}
          >
            <div
              className="header__user"
              onClick={() => setDropdownOpen(!dropdownOpen)}
            >
              <div className="header__user-avatar">
                <User size={20} style={{ color: 'var(--color-user-avatar-icon)' }} />
              </div>
              <div className="header__user-info">
                <span className="header__user-name">{user.name}</span>
                <span className="badge badge--active" style={{ fontSize: '11px' }}>
                  {user.role}
                </span>
                {lastLoginText && (
                  <span style={{ fontSize: '10px', color: 'var(--color-text-secondary)', whiteSpace: 'nowrap' }}>
                    Última conexión: {lastLoginText}
                  </span>
                )}
              </div>
              <ChevronDown size={16} style={{ color: 'var(--color-text-secondary)' }} />
            </div>
            <div className="dropdown__menu">
              {hasMultipleRoles && (
                <>
                  <div style={{ padding: '8px 12px', fontSize: 'var(--font-size-xs)', color: 'var(--color-text-secondary)', fontWeight: 'var(--font-weight-medium)' }}>
                    Cambiar rol
                  </div>
                  {user.roles
                    .filter((r) => r !== user.role)
                    .map((roleName) => (
                      <button
                        key={roleName}
                        className="dropdown__item"
                        onClick={() => handleSwitchRole(roleName)}
                        disabled={switchingRole}
                      >
                        <RefreshCw size={16} className={switchingRole ? 'spin' : ''} />
                        {roleName}
                      </button>
                    ))}
                  <div style={{ borderTop: '1px solid var(--color-border-light)', margin: '4px 0' }} />
                </>
              )}
              <button className="dropdown__item" onClick={logout}>
                <LogOut size={16} />
                Cerrar sesion
              </button>
            </div>
          </div>
          </>
        )}
      </div>
    </div>
  );
};

export default Header;
