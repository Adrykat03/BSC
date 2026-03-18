import { useContext, useState, useRef, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { LogOut, User, ChevronDown, RefreshCw, Menu } from 'lucide-react';
import SessionContext from '../../context/SessionContext';

const pageTitles = {
  '/': 'Home',
  '/roles': 'Roles',
  '/tasks': 'Tareas',
  '/colaboradores': 'Colaboradores',
};

const Header = ({ isMobile, onOpenSidebar }) => {
  const location = useLocation();
  const title = pageTitles[location.pathname] || 'FlowPulse';
  const { user, logout, switchRole } = useContext(SessionContext);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [switchingRole, setSwitchingRole] = useState(false);
  const dropdownRef = useRef(null);

  const hasMultipleRoles = user?.roles && user.roles.length > 1;

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
    } catch {
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
        )}
      </div>
    </div>
  );
};

export default Header;
