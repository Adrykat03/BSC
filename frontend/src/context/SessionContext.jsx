import { createContext, useState, useEffect, useCallback } from 'react';
import authService from '../services/authService';

const TOKEN_KEY = 'fp_token';

export const SessionContext = createContext(null);

function parseJwt(token) {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}

function isTokenExpired(claims) {
  if (!claims || !claims.exp) return true;
  // exp is in seconds, Date.now() in ms
  return Date.now() >= claims.exp * 1000;
}

function extractUser(claims) {
  if (!claims) return null;
  let roles = [];
  if (claims.roles) {
    try {
      roles = typeof claims.roles === 'string' ? JSON.parse(claims.roles) : claims.roles;
    } catch {
      roles = Array.isArray(claims.roles) ? claims.roles : [claims.roles];
    }
  }
  if (!Array.isArray(roles)) roles = [roles];

  // .NET JWT uses full URI claim keys
  const nameId = claims.nameid || claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] || claims.sub || '';
  const name = claims.unique_name || claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] || '';
  const email = claims.email || claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] || '';
  const role = claims.role || claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] || (roles.length > 0 ? roles[0] : '');

  return {
    id: nameId,
    name,
    email,
    role,
    roles,
  };
}

export const SessionProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [initialized, setInitialized] = useState(false);

  // On mount, restore session from sessionStorage
  useEffect(() => {
    const storedToken = sessionStorage.getItem(TOKEN_KEY);
    if (storedToken) {
      const claims = parseJwt(storedToken);
      if (claims && !isTokenExpired(claims)) {
        setToken(storedToken);
        setUser(extractUser(claims));
      } else {
        sessionStorage.removeItem(TOKEN_KEY);
      }
    }
    setInitialized(true);
  }, []);

  const login = useCallback(async (email, password) => {
    const data = await authService.login(email, password);
    const newToken = data.token;
    sessionStorage.setItem(TOKEN_KEY, newToken);
    setToken(newToken);
    const claims = parseJwt(newToken);
    setUser(extractUser(claims));
    return data;
  }, []);

  const switchRole = useCallback(async (newRole) => {
    const data = await authService.switchRole(newRole);
    const newToken = data.token;
    sessionStorage.setItem(TOKEN_KEY, newToken);
    if (data.lastLoginAt) {
      sessionStorage.setItem('fp_last_login', data.lastLoginAt);
    }
    setToken(newToken);
    const claims = parseJwt(newToken);
    setUser(extractUser(claims));
  }, []);

  const logout = useCallback(() => {
    setUser(null);
    setToken(null);
    sessionStorage.removeItem(TOKEN_KEY);
    window.location.href = '/login';
  }, []);

  const isAuthenticated = !!user && !!token;

  if (!initialized) {
    return <div className="text-center p-6">Cargando...</div>;
  }

  return (
    <SessionContext.Provider value={{ user, token, login, logout, switchRole, isAuthenticated }}>
      {children}
    </SessionContext.Provider>
  );
};

export default SessionContext;
