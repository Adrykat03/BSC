import { NavLink } from 'react-router-dom';
import { Home } from 'lucide-react';

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
        </ul>
      </nav>
    </div>
  );
};

export default Sidebar;
