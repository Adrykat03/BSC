# BSC BackOffice - Registro de Funcionalidades

> Este archivo lleva el registro de todas las funcionalidades desarrolladas en el proyecto.
> Se actualiza al finalizar cada iteracion aprobada.

## Indice de Funcionalidades

| ID | Nombre | Estado | Fecha |
|----|--------|--------|-------|
| FUNC-000 | Estructura base del proyecto | Completada | 2026-03-16 |

---

## Detalle de Funcionalidades

### [FUNC-000] Estructura Base del Proyecto
- **Estado:** Completada
- **Fecha:** 2026-03-16
- **Descripcion:** Creacion de la estructura base del proyecto incluyendo solucion .NET Core 8, proyecto React con Vite, Dockerfiles, y configuracion inicial de MongoDB.
- **Backend:** Solucion BSC.sln con 4 proyectos (API, Application, Domain, Infrastructure). Endpoint GET /api/health retorna "Backend activo". Swagger en /swagger. MongoDB configurado. ExceptionHandlingMiddleware. CORS para localhost:3000.
- **Frontend:** Proyecto Vite + React 18. Layout con sidebar (menu Home) + header + content area. Pagina Home llama a /api/health y muestra resultado. Design system integrado desde /style/. Routing con react-router-dom v6 y lazy loading.
- **Security:** Aprobado. SonarQube configurado (http://localhost:9000). Re-scan limpio: 0 vulnerabilidades, 0 hotspots, 0 code smells en backend. Frontend: 1 code smell menor (contraste CSS). Correcciones aplicadas: credenciales removidas de codigo, Dockerfile con usuario no-root, Swagger condicionado a Development, security headers agregados, exception message generico al cliente.

---

<!--
Plantilla para nuevas funcionalidades:

### [FUNC-XXX] Nombre de la Funcionalidad
- **Estado:** Completada | En Progreso | Pendiente
- **Fecha:** YYYY-MM-DD
- **Descripcion:** Breve descripcion de lo que hace la funcionalidad.
- **Backend:** Endpoints, entidades, servicios creados.
- **Frontend:** Paginas, componentes, hooks creados.
- **Security:** Aprobado | Con observaciones | Pendiente
-->
