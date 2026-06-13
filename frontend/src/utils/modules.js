import { Home, Shield, Users, ClipboardList, Bell } from 'lucide-react';

/**
 * Catalogo unico de modulos de la aplicacion.
 * Unica fuente de verdad para Sidebar, rutas, guard de rutas y titulos del Header.
 *
 * Las `key` deben coincidir EXACTAMENTE con las que envia el backend en el claim "modules".
 */
export const MODULES = [
  { key: 'dashboard', path: '/', label: 'Dashboard', icon: Home },
  { key: 'roles', path: '/roles', label: 'Roles', icon: Shield },
  { key: 'colaboradores', path: '/colaboradores', label: 'Colaboradores', icon: Users },
  { key: 'tareas', path: '/tasks', label: 'Tareas', icon: ClipboardList },
  { key: 'alertas-payroll', path: '/alertas-payroll', label: 'Alertas Payroll', icon: Bell },
];

/** Devuelve los modulos del catalogo permitidos para el usuario, en el orden del catalogo. */
export const getAllowedModules = (userModules = []) =>
  MODULES.filter((m) => userModules.includes(m.key));

/** Devuelve la ruta del primer modulo permitido del usuario (orden del catalogo). */
export const getFirstAllowedPath = (userModules = []) => {
  const allowed = getAllowedModules(userModules);
  return allowed.length > 0 ? allowed[0].path : null;
};

/** Mapa path -> label, derivado del catalogo (para titulos del Header). */
export const PAGE_TITLES = MODULES.reduce((acc, m) => {
  acc[m.path] = m.label;
  return acc;
}, {});

export default MODULES;
