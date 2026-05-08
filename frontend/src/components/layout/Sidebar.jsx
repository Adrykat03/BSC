import { useContext } from 'react';
import { NavLink } from 'react-router-dom';
import { Home, Shield, ClipboardList, Users, Bell, ChevronLeft, ChevronRight } from 'lucide-react';
import SessionContext from '../../context/SessionContext';

const Sidebar = ({ isMobile, onCloseSidebar, collapsed = false, onToggleCollapse }) => {
  const { user } = useContext(SessionContext);
  const role = user?.role || '';
  const isAdmin = role === 'Administrador';
  const handleNavClick = () => {
    if (isMobile && onCloseSidebar) {
      onCloseSidebar();
    }
  };

  return (
    <div className="sidebar">
      {isMobile && (
        <button
          className="sidebar__close-btn"
          onClick={onCloseSidebar}
          aria-label="Cerrar menu"
        >
          &#10005;
        </button>
      )}

      {!isMobile && onToggleCollapse && (
        <button
          type="button"
          className="sidebar__collapse-btn"
          onClick={onToggleCollapse}
          aria-label={collapsed ? 'Expandir menú' : 'Colapsar menú'}
          title={collapsed ? 'Expandir menú' : 'Colapsar menú'}
        >
          {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
        </button>
      )}

      <div className="sidebar__logo">
        <img src="/logo.png" alt="Nomina2" style={{ maxWidth: '100%', height: 'auto', maxHeight: '160px' }} />
      </div>

      <nav>
        <ul className="sidebar__nav">
          {!isAdmin && (
            <li className="sidebar__nav-item">
              <NavLink
                to="/"
                end
                aria-label="Dashboard"
                data-tooltip="Dashboard"
                className={({ isActive }) =>
                  `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                }
                onClick={handleNavClick}
              >
                <Home className="sidebar__nav-icon" size={20} />
                <span>Dashboard</span>
              </NavLink>
            </li>
          )}

          {/* Administrador: Roles y Colaboradores */}
          {isAdmin && (
            <>
              <li className="sidebar__nav-item">
                <NavLink
                  to="/roles"
                  aria-label="Roles"
                  data-tooltip="Roles"
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                  onClick={handleNavClick}
                >
                  <Shield className="sidebar__nav-icon" size={20} />
                  <span>Roles</span>
                </NavLink>
              </li>
              <li className="sidebar__nav-item">
                <NavLink
                  to="/colaboradores"
                  aria-label="Colaboradores"
                  data-tooltip="Colaboradores"
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                  onClick={handleNavClick}
                >
                  <Users className="sidebar__nav-icon" size={20} />
                  <span>Colaboradores</span>
                </NavLink>
              </li>
              <li className="sidebar__nav-item">
                <NavLink
                  to="/tasks"
                  aria-label="Tareas"
                  data-tooltip="Tareas"
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                  onClick={handleNavClick}
                >
                  <ClipboardList className="sidebar__nav-icon" size={20} />
                  <span>Tareas</span>
                </NavLink>
              </li>
            </>
          )}

          {/* Todos excepto Administrador: Tareas */}
          {!isAdmin && (
            <>
              <li><hr style={{ border: 'none', borderTop: '1px solid var(--color-border-main)', margin: 'var(--spacing-2) var(--spacing-4)' }} /></li>
              <li className="sidebar__nav-item">
                <NavLink
                  to="/tasks"
                  aria-label="Tareas"
                  data-tooltip="Tareas"
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                  onClick={handleNavClick}
                >
                  <ClipboardList className="sidebar__nav-icon" size={20} />
                  <span>Tareas</span>
                </NavLink>
              </li>
            </>
          )}

          <li><hr style={{ border: 'none', borderTop: '1px solid var(--color-border-main)', margin: 'var(--spacing-2) var(--spacing-4)' }} /></li>
          <li className="sidebar__nav-item">
            <NavLink
              to="/alertas-payroll"
              aria-label="Alertas Payroll"
              data-tooltip="Alertas Payroll"
              className={({ isActive }) =>
                `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
              }
              onClick={handleNavClick}
            >
              <Bell className="sidebar__nav-icon" size={20} />
              <span>Alertas Payroll</span>
            </NavLink>
          </li>
        </ul>
      </nav>
    </div>
  );
};

export default Sidebar;
