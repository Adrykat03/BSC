import { useContext } from 'react';
import { NavLink } from 'react-router-dom';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import SessionContext from '../../context/SessionContext';
import { getAllowedModules } from '../../utils/modules';

const Sidebar = ({ isMobile, onCloseSidebar, collapsed = false, onToggleCollapse }) => {
  const { user } = useContext(SessionContext);
  const allowedModules = getAllowedModules(user?.modules || []);

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
          {allowedModules.map(({ key, path, label, icon: Icon }) => (
            <li className="sidebar__nav-item" key={key}>
              <NavLink
                to={path}
                end={path === '/'}
                aria-label={label}
                data-tooltip={label}
                className={({ isActive }) =>
                  `sidebar__nav-link${isActive ? ' sidebar__nav-link--active' : ''}`
                }
                onClick={handleNavClick}
              >
                <Icon className="sidebar__nav-icon" size={20} />
                <span>{label}</span>
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>
    </div>
  );
};

export default Sidebar;
