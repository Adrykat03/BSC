# Lineamientos Frontend - React con Design System BSC

## Principios Generales
- React 18 con Vite como bundler
- JavaScript (JSX) - no TypeScript a menos que se indique
- **Arquitectura de componentes reutilizables** para maximizar flexibilidad
- Componentes funcionales exclusivamente (no class components)
- Custom hooks para logica reutilizable
- CSS puro usando el design system existente en `/style`
- Estructura modular por feature/pagina

## Arquitectura de Componentes

La arquitectura se basa en **tres niveles de componentes** para maximizar reutilizacion:

### 1. Componentes Base (Atoms)
Componentes genericos y reutilizables que no tienen logica de negocio. Son los bloques fundamentales.

```
components/common/
├── Button.jsx          # Wrapper sobre clases .btn del design system
├── Input.jsx           # Input con label, error, validacion visual
├── Select.jsx          # Select con opciones
├── Modal.jsx           # Modal generico (open/close, titulo, body, footer)
├── Table.jsx           # Tabla generica con headers y rows como props
├── Badge.jsx           # Badge con variantes de estado
├── Alert.jsx           # Alerta con tipo (info, success, warning, error)
├── Pagination.jsx      # Paginacion reutilizable
├── SearchInput.jsx     # Input de busqueda con debounce
├── ConfirmDialog.jsx   # Dialogo de confirmacion (eliminar, etc.)
└── LoadingSpinner.jsx  # Indicador de carga
```

**Regla:** Estos componentes reciben TODO por props. No hacen fetch, no acceden a contextos de negocio.

### 2. Componentes de Composicion (Molecules)
Combinan componentes base para formar bloques funcionales reutilizables.

```
components/common/
├── DataTable.jsx       # Table + Pagination + SearchInput + Loading
├── FormField.jsx       # Label + Input/Select + Error message
├── PageHeader.jsx      # Titulo + Subtitulo + Acciones (botones)
├── FilterBar.jsx       # Barra de filtros reutilizable
└── EmptyState.jsx      # Estado vacio con icono y mensaje
```

### 3. Componentes de Feature (Organisms)
Especificos de cada funcionalidad. Usan los componentes base y de composicion.

```
components/products/
├── ProductForm.jsx     # Formulario de producto (usa FormField, Button, Modal)
├── ProductList.jsx     # Lista de productos (usa DataTable)
└── ProductCard.jsx     # Card de producto (usa Badge, Button)
```

### Principios de Componentes
- **Single Responsibility:** Cada componente hace una sola cosa
- **Props como contrato:** Definir props claras, usar valores por defecto
- **Composicion sobre herencia:** Combinar componentes simples para crear complejos
- **Sin logica de negocio en componentes base:** La logica vive en hooks y services
- **Consistencia visual:** Siempre usar clases del design system, no estilos inline

## Design System Existente
El proyecto cuenta con un design system completo en la carpeta `/style`:

| Archivo | Contenido |
|---------|-----------|
| `variables.css` | CSS Custom Properties (colores, tipografia, spacing, shadows, z-index, componentes) |
| `components.css` | Estilos de componentes (layout, sidebar, header, cards, buttons, forms, tables, modals, badges, etc.) |
| `utilities.css` | Clases utilitarias (display, flexbox, spacing, text, colors, borders, shadows, etc.) |
| `main.css` | Entry point que importa todo |
| `design-tokens.json` | Tokens de diseno en formato JSON |
| `design-tokens.scss` | Tokens en formato SCSS |

### Colores Principales (de variables.css)
- **Primary:** `#E31837` (rojo BSC)
- **Secondary:** `#1A1A2E` (dark navy)
- **Background:** `#F0EEF5` (light lavender)
- **Paper:** `#FFFFFF`

### Como Usar los Estilos
1. Copiar la carpeta `/style` dentro de `frontend/src/styles/`
2. Importar en `App.jsx`: `import './styles/main.css'`
3. Usar las clases CSS definidas en `components.css` y `utilities.css`
4. Usar CSS Custom Properties (variables) para estilos inline o CSS modules adicionales

```jsx
// Ejemplo correcto - usar clases del design system
<button className="btn btn--primary">Guardar</button>
<div className="card">
  <div className="card__header">
    <h2 className="card__title">Titulo</h2>
  </div>
  <div className="card__body">Contenido</div>
</div>
```

## Estructura del Proyecto Frontend

```
frontend/src/
├── assets/
│   └── images/
├── components/
│   ├── common/          # Componentes reutilizables (Button, Input, Modal, Table, etc.)
│   ├── layout/          # Layout, Sidebar, Header, Breadcrumb
│   └── [feature]/       # Componentes especificos de feature
├── pages/
│   ├── Dashboard/
│   ├── Products/
│   └── ...
├── hooks/
│   ├── useApi.js        # Hook para llamadas HTTP
│   ├── useAuth.js       # Hook de autenticacion
│   └── usePagination.js # Hook de paginacion
├── services/
│   ├── api.js           # Configuracion base de axios/fetch
│   └── [entity]Service.js
├── store/
│   └── AuthContext.jsx
├── styles/              # Copia del design system (/style)
│   ├── main.css
│   ├── variables.css
│   ├── components.css
│   └── utilities.css
├── utils/
│   ├── constants.js
│   └── helpers.js
├── App.jsx
├── main.jsx
└── routes.jsx
```

## Convenciones de Codigo

### Nombrado
- Componentes: PascalCase (`ProductList.jsx`)
- Hooks: camelCase con prefijo `use` (`useProducts.js`)
- Servicios: camelCase con sufijo `Service` (`productService.js`)
- Utilidades: camelCase (`formatDate.js`)
- Constantes: UPPER_SNAKE_CASE (`API_BASE_URL`)

### Componentes
```jsx
// Estructura estandar de un componente
import { useState, useEffect } from 'react';
import './ProductList.css'; // Solo si necesita estilos adicionales al design system

const ProductList = ({ category, onSelect }) => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // logica
  }, [category]);

  if (loading) return <div className="text-center p-6">Cargando...</div>;

  return (
    <div className="card">
      {/* contenido */}
    </div>
  );
};

export default ProductList;
```

### Llamadas API
```javascript
// services/api.js
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

export const apiClient = {
  async get(endpoint) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },
  async post(endpoint, data) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  },
  // put, delete...
};
```

## Routing
- Usar `react-router-dom` v6
- Rutas lazy-loaded para optimizar carga

```jsx
import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/layout/Layout';

const Dashboard = lazy(() => import('./pages/Dashboard/Dashboard'));
const Products = lazy(() => import('./pages/Products/Products'));

const AppRoutes = () => (
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Suspense fallback="..."><Dashboard /></Suspense>} />
        <Route path="products" element={<Suspense fallback="..."><Products /></Suspense>} />
      </Route>
    </Routes>
  </BrowserRouter>
);
```

## Layout Principal
Seguir la estructura definida en `components.css`:
- `.layout` - contenedor flex
- `.layout__sidebar` - sidebar fijo con nav
- `.layout__main` - area de contenido
- `.layout__header` - header sticky
- `.layout__content` - contenido de la pagina

## Paquetes npm Requeridos

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.x",
    "lucide-react": "^0.x"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.x",
    "vite": "^5.x"
  }
}
```

## Compilacion y Despliegue Local

El frontend se compila **localmente** y se sirve mediante Nginx en Docker a traves de un volumen compartido. Esto evita reconstruir la imagen Docker en cada cambio.

### Flujo de trabajo
1. Instalar dependencias: `cd frontend && npm install`
2. Compilar: `npm run build` (genera output en `frontend/dist/`)
3. Copiar el build al volumen compartido: copiar contenido de `frontend/dist/` a `./html/`
4. El contenedor `bsc_frontend` (nginx:alpine) sirve `./html/` automaticamente
5. Si el contenedor ya esta corriendo, los cambios se reflejan al recargar el navegador

### Configuracion
- **Nginx config:** `nginx/nginx.conf` y `nginx/default.conf`
- **Volumen:** `./html` montado en `/usr/share/nginx/html` (read-only)
- **Proxy API:** Nginx redirige `/api/` al backend (`bsc_backend:8080`)
- **SPA fallback:** Todas las rutas no encontradas redirigen a `index.html`
- **Puerto:** 3000
- **Variable de entorno:** `VITE_API_URL` para la URL del backend (en build time)

### Cuando recompilar el frontend
- Cualquier cambio en archivos `.jsx`, `.js`, `.css` dentro de `frontend/src/`
- Cambios en dependencias (`package.json`)
- Cambios en variables de entorno de Vite

### Script rapido
```bash
cd frontend
npm run build
cp -r dist/* ../html/
```
