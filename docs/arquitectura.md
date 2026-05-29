# Arquitectura del sistema

Visión general del stack, servicios y cómo se comunican. Para detalle de datos ver [modelo-datos.md](modelo-datos.md); para la integración con SQL Server vía DAB ver [integracion-dab.md](integracion-dab.md).

## Stack

| Capa | Tecnología | Dónde vive |
|---|---|---|
| Frontend | React 18 + Vite + React Router, servido estático por nginx | `frontend/` (build) → `html/` (servido) |
| Backend API | .NET Core 8, Clean/Hexagonal + CQRS (MediatR) + FluentValidation + Serilog | `backend/src/` |
| Base de datos principal | MongoDB 7 | Contenedor `bsc_mongo` |
| Base de datos secundaria | SQL Server (externo) expuesto vía Data API Builder | Contenedor `bsc_dab` |
| File server | Apache httpd sirviendo `./files/` | Contenedor `bsc_fileserver` |
| UI de MongoDB | mongo-express | Contenedor `bsc_mongoexpress` |

## Red Docker

Red bridge `bsc_net` con subred **`19.168.78.0/24`** (gateway `.1`). IPs fijas por servicio para que las referencias internas sean estables.

| Servicio | Contenedor | IP | Puerto interno | Puerto host |
|---|---|---|---|---|
| MongoDB | `bsc_mongo` | 19.168.78.10 | 27017 | — |
| Backend API | `bsc_backend` | 19.168.78.11 | 8080 | 5000 |
| Frontend (nginx) | `bsc_frontend` | 19.168.78.12 | 3000 | 3030 |
| File server | `bsc_fileserver` | 19.168.78.13 | 80 | 8082 |
| Mongo-express | `bsc_mongoexpress` | 19.168.78.15 | 8081 | 8081 |
| DAB | `bsc_dab` | — | 5000 | 5555 |

> **Nota:** `bsc_dab` se opera **por fuera del `docker-compose.yml`** de forma intencional. No se integrará al compose principal por ahora — se levanta/mantiene manualmente.

## Flujo de requests (frontend → servicios)

Todo el tráfico del frontend pasa por **nginx** (`config/nginx/default.conf`), que funciona como reverse proxy:

```
Navegador (host)
    │  http://localhost:3030
    ▼
bsc_frontend (nginx)
    │
    ├─ /           → /usr/share/nginx/html (SPA, try_files → /index.html)
    ├─ /assets/    → estáticos con Cache-Control: immutable (1 año)
    ├─ /api/       → proxy_pass http://bsc_backend:8080/api/
    ├─ /dab/       → proxy_pass http://bsc_dab:5000/api/
    └─ (files)     → (servido por bsc_fileserver en :8082 directamente)
```

- `index.html` se sirve con `Cache-Control: no-store` para que cada build tome efecto sin esperar expiración de caché.
- `logo.png` también se sirve sin caché (permite cambios de branding inmediatos).
- `client_max_body_size: 11m` en `/api/` para soportar upload de evidencias.

## Backend (Clean / Hexagonal)

Regla de dependencia: `API → Application → Domain ← Infrastructure`. Domain no depende de nada.

```
backend/src/
├── BSC.Domain/          # Entidades, VOs, interfaces de repositorio (puertos)
├── BSC.Application/     # CQRS: Commands/Queries, DTOs, Validators, Behaviors
├── BSC.Infrastructure/  # MongoDB repos, servicios externos (adaptadores)
└── BSC.API/             # Controllers, Middlewares, Program.cs
```

Patrones y librerías clave:
- **CQRS con MediatR** (Commands / Queries separados).
- **FluentValidation** con pipeline behavior (`ValidationBehavior.cs`).
- **Serilog** para logging estructurado.
- **Swagger / OpenAPI** en `/swagger` (obligatorio por lineamiento).
- **JWT** para autenticación (`JwtTokenService`, env vars `JwtSettings__*`).
- **BCrypt** para hashing de contraseñas (`BcryptPasswordHasher`).
- **Middleware global de excepciones** (`ExceptionHandlingMiddleware`).

## Frontend

- **Vite** como bundler, **React 18** + **react-router-dom 6**.
- UI compuesta con el **design system propio** en `style/` (`variables.css`, `components.css`, `utilities.css`). Variables de spacing, color, z-index, tipografía. **Siempre usarlas** en vez de hardcodear.
- SweetAlert2 para confirmaciones; lucide-react para iconografía; react-hot-toast para notificaciones.
- **No hay dev-server en Docker**. El workflow de deploy es:
  ```bash
  cd frontend && npx vite build
  rm -rf ../html/assets && cp -r dist/assets ../html/
  cp dist/index.html ../html/index.html
  docker restart bsc_frontend
  ```
  Pendiente empaquetarlo en un script `npm run deploy` (TODO conocido).

## Variables de entorno clave

Vienen del `.env` (no versionado). Las referencia `docker-compose.yml`:

| Variable | Uso |
|---|---|
| `MONGO_ROOT_USER`, `MONGO_ROOT_PASSWORD`, `MONGO_DATABASE` | Credenciales de MongoDB |
| `JWT_SECRET_KEY`, `JWT_ISSUER`, `JWT_AUDIENCE` | Firma de tokens en el backend |
| `ME_BASICAUTH_USERNAME`, `ME_BASICAUTH_PASSWORD` | Basic auth de mongo-express |
| `SQL_CONN` | Connection string que DAB pasa a SQL Server (referenciada como `@env('SQL_CONN')` en `dab/dab-config.json`) |

## Volúmenes

- `bsc_mongo_data` (named volume): datos de MongoDB.
- `./seeds:/seeds:ro` montado en `bsc_mongo` para poblar datos iniciales.
- `./files:/app/files` (backend) y `./files:/usr/local/apache2/htdocs` (fileserver): evidencias e insumos compartidos.
- `./html:/usr/share/nginx/html:ro` (frontend): build estático del SPA.
- `./config/nginx/*.conf`: configuración de nginx montada read-only.

## Lineamientos relacionados

- `lineamientos/02-backend-netcore.md` — reglas del backend (arquitectura hexagonal, CQRS, nombres de colecciones).
- `lineamientos/03-frontend-react.md` — reglas del frontend (design system obligatorio).
- `lineamientos/agente-*.md` — flujos de los sub-agentes (PM, Dev Backend, Dev Frontend, Security).
