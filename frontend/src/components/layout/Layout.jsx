import { useState, useEffect, useCallback } from 'react';
import { Outlet } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import Sidebar from './Sidebar';
import Header from './Header';

const MOBILE_BREAKPOINT = 1024;

const COLLAPSED_KEY = 'fp_sidebar_collapsed';

const Layout = () => {
  const [isMobile, setIsMobile] = useState(window.innerWidth < MOBILE_BREAKPOINT);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(
    () => localStorage.getItem(COLLAPSED_KEY) === '1'
  );

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
  const toggleCollapse = useCallback(() => {
    setCollapsed((c) => {
      const next = !c;
      localStorage.setItem(COLLAPSED_KEY, next ? '1' : '0');
      return next;
    });
  }, []);

  const isCollapsed = !isMobile && collapsed;

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
        className={
          'layout__sidebar' +
          (isMobile && sidebarOpen ? ' layout__sidebar--mobile-open' : '') +
          (isCollapsed ? ' layout__sidebar--collapsed' : '')
        }
      >
        <Sidebar
          isMobile={isMobile}
          onCloseSidebar={closeSidebar}
          collapsed={isCollapsed}
          onToggleCollapse={toggleCollapse}
        />
      </aside>

      <div className={`layout__main${isCollapsed ? ' layout__main--expanded' : ''}`}>
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
