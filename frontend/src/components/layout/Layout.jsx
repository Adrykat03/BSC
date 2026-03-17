import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';

const Layout = () => {
  return (
    <div className="layout">
      <aside className="layout__sidebar">
        <Sidebar />
      </aside>
      <div className="layout__main">
        <div className="layout__header">
          <Header />
        </div>
        <div className="layout__content">
          <Outlet />
        </div>
      </div>
    </div>
  );
};

export default Layout;
