# BSC BackOffice - Registro de Funcionalidades

> Este archivo lleva el registro de todas las funcionalidades desarrolladas en el proyecto.
> Se actualiza al finalizar cada iteracion aprobada.

## Indice de Funcionalidades

| ID | Nombre | Estado | Fecha |
|----|--------|--------|-------|
| FUNC-000 | Estructura base del proyecto | Completada | 2026-03-16 |
| FUNC-001 | Gestion de Roles | En Progreso | 2026-03-17 |
| FUNC-002 | CRUD Colaboradores | Completada | 2026-03-17 |
| FUNC-003 | Gestion de Tareas | En Progreso | 2026-03-17 |
| FUNC-009 | Modo Responsive (móvil/tablet) | Completada | 2026-03-18 |
| FUNC-010 | Bugfix evidencias y observaciones en tareas | Completada | 2026-03-18 |
| FUNC-011 | Dashboard solo Gerente, switch rol, plantilla carga masiva | Completada | 2026-03-18 |

---

## Detalle de Funcionalidades

### [FUNC-000] Estructura Base del Proyecto
- **Estado:** Completada
- **Fecha:** 2026-03-16
- **Descripcion:** Creacion de la estructura base del proyecto incluyendo solucion .NET Core 8, proyecto React con Vite, Dockerfiles, y configuracion inicial de MongoDB.
- **Backend:** Solucion BSC.sln con 4 proyectos (API, Application, Domain, Infrastructure). Endpoint GET /api/health retorna "Backend activo". Swagger en /swagger. MongoDB configurado. ExceptionHandlingMiddleware. CORS para localhost:3000.
- **Frontend:** Proyecto Vite + React 18. Layout con sidebar (menu Home) + header + content area. Pagina Home llama a /api/health y muestra resultado. Design system integrado desde /style/. Routing con react-router-dom v6 y lazy loading.
- **Security:** Aprobado. SonarQube configurado (http://localhost:9000). Re-scan limpio: 0 vulnerabilidades, 0 hotspots, 0 code smells en backend. Frontend: 1 code smell menor (contraste CSS). Correcciones aplicadas: credenciales removidas de codigo, Dockerfile con usuario no-root, Swagger condicionado a Development, security headers agregados, exception message generico al cliente.

### [FUNC-001] Gestion de Roles
- **Estado:** En Progreso
- **Fecha:** 2026-03-17
- **Descripcion:** CRUD de roles para el sistema BackOffice. Permite crear, listar, editar y eliminar roles con nombre, descripcion y permisos asociados.
- **Backend:** Pendiente. No hay endpoints implementados aun.
- **Frontend:** Pagina placeholder Roles.jsx ("Hola Mundo") con ruta /roles y lazy loading. Sidebar actualizado con icono Shield y enlace a Roles. Header muestra titulo "Roles" en la ruta. Build generado.
- **Security:** Pendiente
- **Notas:** Puertos Docker actualizados (MongoDB: 27018, API: 5001, Frontend: 3001). Script start-pm.sh agregado.

---

### [FUNC-002] CRUD Colaboradores
- **Estado:** Completada
- **Fecha:** 2026-03-17
- **Descripcion:** Gestion completa de colaboradores del area. Primera entidad del sistema que establece los patrones base (repositorio, validacion, pipeline MediatR) reutilizables en funcionalidades futuras.
- **Backend:**
  - **Entidad:** Colaborador (NombreCompleto, Cedula, Area, Correo, PasswordHash, campos de auditoria CreatedAt/UpdatedAt/IsDeleted/DeletedAt)
  - **Endpoints:** GET /api/colaboradores, GET /api/colaboradores/{id}, POST /api/colaboradores, PUT /api/colaboradores/{id}, DELETE /api/colaboradores/{id}
  - **Patrones base creados:** ValidationBehavior (pipeline MediatR + FluentValidation automatico), ValidationException (400), IPasswordHasher (abstraccion BCrypt), MongoDbMappings (BsonClassMap), soft delete
  - **Validaciones:** Nombre requerido max 100, cedula 10 digitos unica, correo valido unico, password min 8 con complejidad (mayuscula, minuscula, numero, especial)
  - **Seguridad:** Password hasheado con BCrypt via IPasswordHasher, nunca expuesto en DTOs. Soft delete (IsDeleted + DeletedAt). Errores genericos al cliente.
  - **Archivos nuevos (22):** Domain/Entities/Colaborador.cs, Domain/Interfaces/IColaboradorRepository.cs, Domain/Interfaces/IPasswordHasher.cs, Application/DTOs/ColaboradorDto.cs, Application/DTOs/CreateColaboradorDto.cs, Application/DTOs/UpdateColaboradorDto.cs, Application/Exceptions/ValidationException.cs, Application/Behaviors/ValidationBehavior.cs, Application/Features/Colaboradores/ (6 Commands/Queries + Handlers), Application/Validators/CreateColaboradorValidator.cs, Application/Validators/UpdateColaboradorValidator.cs, Infrastructure/Repositories/ColaboradorRepository.cs, Infrastructure/Persistence/MongoDbMappings.cs, Infrastructure/Services/BcryptPasswordHasher.cs, API/Controllers/ColaboradoresController.cs
  - **Archivos modificados:** Application/DependencyInjection.cs (ValidationBehavior pipeline), Infrastructure/DependencyInjection.cs (repositorio + hasher DI), Infrastructure.csproj (BCrypt.Net-Next), Application.csproj (Logging.Abstractions), ExceptionHandlingMiddleware.cs (400 para ValidationException)
- **Frontend:**
  - **Pagina:** Colaboradores.jsx - Tabla con listado, modal crear/editar, dialogo confirmar eliminacion, estados de carga/error/vacio
  - **Componentes comunes (reutilizables):** Modal.jsx, ConfirmDialog.jsx
  - **Servicio:** colaboradorService.js (CRUD via apiClient)
  - **Mejora api.js:** Parseo de errores backend (message + errors array)
  - **Validacion frontend:** Nombre, cedula (10 digitos), area, correo (formato), password (min 8, solo al crear)
  - **Design system:** Usa clases del design system (card, table, btn, form-group, form-input, modal, alert). Sin inline styles.
- **Security:** Aprobado. 0 criticos, 0 altos, 3 medios corregidos (complejidad password, validacion cedula/password frontend), 3 bajos documentados (Authorize pendiente hasta implementar auth, CreatedBy hardcodeado "system" hasta implementar auth, inline style eliminado).

---

### [FUNC-003] Gestion de Tareas
- **Estado:** En Progreso
- **Fecha:** 2026-03-17
- **Descripcion:** CRUD de tareas para el sistema BackOffice. Permite crear, listar, editar y eliminar tareas.
- **Backend:** Pendiente.
- **Frontend:** Pagina placeholder Tasks.jsx con ruta /tasks y lazy loading. Sidebar actualizado con icono ClipboardList y enlace a Tareas.
- **Security:** Pendiente

### [FUNC-009] Modo Responsive (móvil/tablet)
- **Estado:** Completada
- **Fecha:** 2026-03-18
- **Descripcion:** Soporte responsive completo para móvil y tablet con breakpoint principal en 1024px.
- **Backend:** Sin cambios.
- **Frontend:**
  - Layout responsive: ancho completo en < 1024px
  - Sidebar: drawer overlay con hamburguesa, cierre por backdrop/link/botón X
  - Header: botón hamburguesa, nombre usuario compacto con truncado
  - Tablas (Tasks, Colaboradores): scroll horizontal, columnas secundarias ocultas en < 640px
  - Modales: fullscreen en < 640px (95vw, 90vh), scroll interno
  - Dashboard: cards 1 columna, gráficos scrolleables, filtros apilados
  - Formularios: 1 columna en móvil, touch targets 44px
  - Labels de formularios corregidos (sin floating label)
  - Utilidades CSS ampliadas (sm:, mobile:, md:, lg:)
- **Security:** Aprobado (Fase 1: aprobado con observaciones menores, Fase 2: aprobado)

### [FUNC-010] Bugfix evidencias y observaciones en tareas
- **Estado:** Completada
- **Fecha:** 2026-03-18
- **Descripcion:** Correccion de 4 bugs relacionados con evidencias y observaciones al reasignar tareas, cambiar estado y visualizacion por rol.
- **Backend:** UpdateTaskItemCommandHandler: null-check para preservar EvidenceText y Observations existentes cuando no vienen en el request (evita que el Gerente al editar borre la evidencia del Colaborador).
- **Frontend:** TaskModal.jsx: (1) Evidencias visibles como solo-lectura para Gerente, (2) Boton "Completa - Por Validar" ahora guarda evidencias antes de cambiar estado, (3) Botones de estado del Lider guardan cambios del formulario (observaciones/evidencia) antes de cambiar estado. Helper buildLiderFormData() extraido para evitar duplicacion.
- **Security:** Aprobado (0 criticos, 0 altos, 2 bajos: observaciones campo abierto a todos los roles y race condition menor en guardado+cambio de estado)

### [FUNC-011] Dashboard solo Gerente, switch rol, plantilla carga masiva
- **Estado:** Completada
- **Fecha:** 2026-03-18
- **Descripcion:** Tres correcciones: (1) Dashboard visible solo para Gerente, (2) Toast de error en switch de rol, (3) Plantilla de carga masiva con ejemplo y formato de fecha corregido.
- **Backend:** Sin cambios.
- **Frontend:**
  - Header.jsx: toast de error al fallar switch de rol, título "Dashboard"
  - Sidebar.jsx: enlace Dashboard condicionado a rol Gerente
  - routes.jsx: HomeOrRedirect redirige Lider/Colaborador a /tasks
  - Tasks.jsx: plantilla con fila de ejemplo, header de fecha con formato DD/MM/AAAA HH:mm, parseo robusto de fechas (serial Excel + string), fix conteo de tareas creadas (totalCreated/totalFailed del backend)
- **Security:** Aprobado (0 criticos, 0 altos, 2 bajos: console.error en produccion e inline styles menores)

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
