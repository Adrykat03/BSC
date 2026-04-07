import { useState, useEffect, useCallback } from 'react';
import { Outlet } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import Sidebar from './Sidebar';
import Header from './Header';

const MOBILE_BREAKPOINT = 1024;

const Layout = () => {
  const [isMobile, setIsMobile] = useState(window.innerWidth < MOBILE_BREAKPOINT);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    const mql = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`);
    const handleChange = (e) => {
      setIsMobile(e.matches);
      if (!e.matches) {
        setSidebarOpen(false);
      }
    };

    mql.addEventListener('change', handleChange);
    return () => mql.removeEventListener('change', handleChange);
  }, []);

  const openSidebar = useCallback(() => setSidebarOpen(true), []);
  const closeSidebar = useCallback(() => setSidebarOpen(false), []);

  return (
    <div className="layout">
      <Toaster position="top-center" />
      {/* Backdrop for mobile sidebar */}
      {isMobile && (
        <div
          className={`sidebar-backdrop${sidebarOpen ? ' sidebar-backdrop--open' : ''}`}
          onClick={closeSidebar}
        />
      )}

      <aside
        className={`layout__sidebar${isMobile && sidebarOpen ? ' layout__sidebar--mobile-open' : ''}`}
      >
        <Sidebar isMobile={isMobile} onCloseSidebar={closeSidebar} />
      </aside>

      <div className="layout__main">
        <div className="layout__header">
          <Header isMobile={isMobile} onOpenSidebar={openSidebar} />
        </div>
        <div className="layout__content">
          <Outlet />
        </div>
      </div>
    </div>
  );
};

export default Layout;
