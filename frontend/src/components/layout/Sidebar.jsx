import { NavLink } from 'react-router-dom';
import { Home, Shield, ClipboardList, Users } from 'lucide-react';

const Sidebar = () => {
  return (
    <div className="sidebar">
      <div className="sidebar__logo">
        <span className="text-xl font-bold text-brand">BSC</span>
        <span className="text-sm text-secondary ml-2">BackOffice</span>
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
        </ul>
      </nav>
    </div>
  );
};

export default Sidebar;
