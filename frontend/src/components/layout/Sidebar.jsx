import { useContext } from 'react';
import { NavLink } from 'react-router-dom';
import { Home, Shield, ClipboardList, Users } from 'lucide-react';
import SessionContext from '../../context/SessionContext';

const Sidebar = () => {
  const { user } = useContext(SessionContext);
  const role = user?.role || '';
  const isAdmin = role === 'Administrador';

  return (
    <div className="sidebar">
      <div className="sidebar__logo">
        <img src="/logo.png" alt="FlowPulse" style={{ maxWidth: '100%', height: 'auto', maxHeight: '48px' }} />
      </div>

      <nav>
        <ul className="sidebar__nav">
          <li className="sidebar__nav-item">
            <NavLink
              to="/"
              end
              className={({ isActive }) =>
                `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
              }
            >
              <Home className="sidebar__nav-icon" size={20} />
              <span>Home</span>
            </NavLink>
          </li>

          {/* Administrador: Roles y Colaboradores */}
          {isAdmin && (
            <>
              <li className="sidebar__nav-item">
                <NavLink
                  to="/roles"
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                >
                  <Shield className="sidebar__nav-icon" size={20} />
                  <span>Roles</span>
                </NavLink>
              </li>
              <li className="sidebar__nav-item">
                <NavLink
                  to="/colaboradores"
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                >
                  <Users className="sidebar__nav-icon" size={20} />
                  <span>Colaboradores</span>
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
                  className={({ isActive }) =>
                    `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                  }
                >
                  <ClipboardList className="sidebar__nav-icon" size={20} />
                  <span>Tareas</span>
                </NavLink>
              </li>
            </>
          )}
        </ul>
      </nav>
    </div>
  );
};

export default Sidebar;
