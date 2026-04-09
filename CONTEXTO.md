# BSC BackOffice - Registro de Funcionalidades

> Este archivo lleva el registro de todas las funcionalidades desarrolladas en el proyecto.
> Se actualiza al finalizar cada iteracion aprobada.

## Indice de Funcionalidades

| ID | Nombre | Estado | Fecha |
|----|--------|--------|-------|
| FUNC-000 | Estructura base del proyecto | Completada | 2026-03-16 |
| FUNC-001 | Gestion de Roles | En Progreso | 2026-03-17 |
| FUNC-002 | CRUD Colaboradores | Completada | 2026-03-17 |
| FUNC-003 | Gestion de Tareas | Completada | 2026-03-17 |
| FUNC-009 | Modo Responsive (móvil/tablet) | Completada | 2026-03-18 |
| FUNC-010 | Bugfix evidencias y observaciones en tareas | Completada | 2026-03-18 |
| FUNC-011 | Dashboard solo Gerente, switch rol, plantilla carga masiva | Completada | 2026-03-18 |
| FUNC-012 | Fix switch-role JWT y busqueda server-side en tareas | Completada | 2026-03-18 |
| FUNC-013 | Evidencias opcionales y auditoria completa en modal | Completada | 2026-03-18 |
| FUNC-014 | Dashboard multi-rol y visibilidad de tareas por perfil | Completada | 2026-03-23 |
| FUNC-015 | UX tareas: tooltips, transiciones de estado, toolbar modal | Completada | 2026-03-24 |
| FUNC-016 | Calificacion de tareas y campana de notificaciones | Completada | 2026-03-25 |
| FUNC-017 | Manual de usuario descargable (HTML/PDF) | Completada | 2026-03-27 |
| FUNC-018 | Calificacion automatica por porcentaje y estrellas mensuales | Completada | 2026-03-27 |
| FUNC-019 | Rebranding Nomina2, filtro colaboradores, grafico rendimiento | Completada | 2026-03-31 |
| FUNC-020 | Seleccion multiple de roles sin restriccion | Completada | 2026-04-01 |

---

## Detalle de Funcionalidades

### [FUNC-000] Estructura Base del Proyecto
- **Estado:** Completada
- **Fecha:** 2026-03-16
- **Descripcion:** Creacion de la estructura base del proyecto incluyendo solucion .NET Core 8, proyecto React con Vite, Dockerfiles, y configuracion inicial de MongoDB.
- **Backend:** Solucion BSC.sln con 4 proyectos (API, Application, Domain, Infrastructure). Endpoint GET /api/health retorna "Backend activo". Swagger en /swagger. MongoDB configurado. ExceptionHandlingMiddleware. CORS para localhost:3000.
- **Frontend:** Proyecto Vite + React 18. Layout con sidebar (menu Home) + header + content area. Pagina Home llama a /api/health y muestra resultado. Design system integrado desde /style/. Routing con react-router-dom v6 y lazy loading.
- **Security:** Aprobado. Re-scan limpio: 0 vulnerabilidades, 0 hotspots, 0 code smells en backend. Frontend: 1 code smell menor (contraste CSS). Correcciones aplicadas: credenciales removidas de codigo, Dockerfile con usuario no-root, Swagger condicionado a Development, security headers agregados, exception message generico al cliente.

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
- **Estado:** Completada
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

### [FUNC-012] Fix switch-role JWT y busqueda server-side en tareas
- **Estado:** Completada
- **Fecha:** 2026-03-18
- **Descripcion:** Correccion de parsing JWT para roles multiples y busqueda server-side en tareas con filtrado regex.
- **Backend:** AuthController y TasksController: fix lectura de claims JWT (ASP.NET remapea 'roles' a ClaimTypes.Role), fix GetUserRole que devolvia siempre el primer rol del array. GetTaskItemsQuery/Handler: busqueda server-side con regex en titulo, descripcion, nombre de colaborador/lider. Colaborador ahora ve tareas Completa y Completa-Validada.
- **Frontend:** Tasks.jsx: busqueda con debounce 300ms que consulta al backend. tasksService.js actualizado con parametro de busqueda.
- **Security:** Pendiente

---

### [FUNC-013] Evidencias opcionales y auditoria completa en modal
- **Estado:** Completada
- **Fecha:** 2026-03-18
- **Descripcion:** Refactorizacion de evidencias para que archivos y texto sean opcionales, y todos los botones del modal guarden datos antes de actuar.
- **Backend:** UploadEvidenceCommand/Handler/Validator: archivos y texto de evidencia opcionales, solo observaciones requeridas para guardar. Eliminada validacion FluentValidation que exigia evidencia obligatoria.
- **Frontend:** TaskModal.jsx: todos los botones (cambio de estado, guardar, asignar) ejecutan guardado previo de datos del formulario antes de la accion, eliminando race conditions. Colaborador puede guardar solo observaciones sin evidencia.
- **Security:** Pendiente

---

### [FUNC-014] Dashboard multi-rol y visibilidad de tareas por perfil
- **Estado:** Completada
- **Fecha:** 2026-03-23
- **Descripcion:** Dashboard habilitado para todos los roles con filtrado por perfil, visibilidad de tareas por rol, retomar tarea, exportacion XLSX y alertas payroll.
- **Backend:**
  - GetDashboardQuery/Handler: dashboard filtrado por rol (Gerente ve todo, Lider ve sus asignadas, Colaborador ve las propias)
  - GetTaskItemsQueryHandler: visibilidad de estados por rol (Colaborador: Asignada/Reasignada/Completa-Por Validar; Lider: hasta Completa-Validada; Gerente: todos incluyendo Completa/Cancelada)
  - PUT /api/tasks/{id}/revert: revertir estado de tarea
  - GET /api/tasks/export: exportacion filtrada XLSX
  - Heatmap basado en suma de horas estimadas (no conteo de tareas)
  - EstimatedTime como campo decimal (step 0.5)
  - Highlight cards: colaborador eficiente y lider top basados en suma de tiempo estimado completado
  - Ocultar Dashboard para rol Administrador, redirigir a /roles
- **Frontend:**
  - Home.jsx: dashboard multi-rol, heatmap oculto para Colaborador, total completas en doughnut, highlights solo para Gerente, click-to-download XLSX por colaborador/estado, Reasignadas Historicas como categoria oculta por defecto
  - Sidebar.jsx: Dashboard visible segun rol
  - routes.jsx: redireccion por rol (Lider/Colaborador a /tasks, Admin a /roles)
  - AlertasPayroll: nueva pagina con dashboard de payroll integrado
  - Seeds: seed_100_tareas.js para datos de prueba
- **Security:** Pendiente

---

### [FUNC-015] UX tareas: tooltips, transiciones de estado, toolbar modal
- **Estado:** Completada
- **Fecha:** 2026-03-24
- **Descripcion:** Mejoras de UX en gestion de tareas: tooltips, rediseno de transiciones de estado por rol, toolbar en modal y correcciones de graficos.
- **Backend:**
  - ChangeTaskStatusCommandHandler y TaskStateTransitions.cs: eliminada validacion de fecha limite al cambiar estado
  - TaskItemRepository/GetTaskItemsQueryHandler: eliminada restriccion de fecha en queries para Lider y Colaborador
- **Frontend:**
  - Tasks.jsx: tooltips en botones (descarga plantilla, carga, exportar), tareas vencidas gestionables por todos los roles
  - TaskModal.jsx: footer rediseñado como toolbar compacta con iconos y tooltips, transiciones de estado sincronizadas entre tabla y modal
  - Transiciones por rol: Gerente (completar/devolver/cancelar), Lider (validar/reasignar), Colaborador (enviar a validacion sin restriccion de fecha)
  - Icono de cancelar cambiado a Eraser
  - Home.jsx: conteo correcto de completas en grafico de distribucion, tareas canceladas excluidas del heatmap historico
  - Puerto frontend cambiado de 3000 a 3030
- **Security:** Pendiente

---

### [FUNC-016] Calificacion de tareas y campana de notificaciones
- **Estado:** Completada
- **Fecha:** 2026-03-25
- **Descripcion:** Sistema de calificacion manual 1-10 estrellas para tareas y campana de notificaciones con badge de tareas pendientes.
- **Backend:**
  - RateTaskCommand/Handler: nuevo comando para calificar tareas
  - TaskItem.cs: campo Rating agregado a la entidad
  - TaskItemDto/TaskItemMapper: rating incluido en DTOs y mapeo
  - TasksController: endpoint para calificar tareas
- **Frontend:**
  - TaskModal.jsx: selector de estrellas 1-10, solo Lider/Gerente pueden calificar, rating se guarda al cambiar estado/guardar/asignar
  - Tasks.jsx: columna Rating en tabla y exportacion XLSX
  - Header.jsx: campana de notificaciones con badge rojo mostrando tareas pendientes
  - Fix: 'Líder' con tilde en BD ahora coincide con constante 'Lider'
- **Security:** Pendiente

---

### [FUNC-017] Manual de usuario descargable (HTML/PDF)
- **Estado:** Completada
- **Fecha:** 2026-03-27
- **Descripcion:** Manual de usuario completo con 15 secciones, descargable desde el header, generacion PDF con capturas automaticas via Playwright.
- **Backend:** scripts/generate_manual_pdf.js: script Playwright que captura 18 screenshots de todas las paginas y roles para generar el PDF.
- **Frontend:**
  - Header.jsx: icono de ayuda (HelpCircle) junto a campana de notificaciones con tooltip
  - Manual_FlowPulse.html: manual completo con 15 secciones, tablas, badges y diagramas de flujo de estados
  - Manual_FlowPulse.pdf: PDF estatico generado con Playwright (portada, indice, tablas, capturas)
  - routes.jsx: ruta para descarga del manual
  - Fix alineacion de icono de ayuda y tooltip consistente con el sistema
- **Security:** Pendiente

---

### [FUNC-018] Calificacion automatica por porcentaje y estrellas mensuales
- **Estado:** Completada
- **Fecha:** 2026-03-27
- **Descripcion:** Reemplazo de calificacion manual por sistema automatico basado en porcentaje, grafico de promedio por colaborador y estrellas mensuales motivacionales.
- **Backend:**
  - ChangeTaskStatusCommandHandler: calificacion automatica al completar tarea (100% base, -30% por entrega tardia, -10% por cada reasignacion)
  - GetDashboardQueryHandler: nuevo calculo de promedio de calificacion por colaborador y estrellas mensuales
  - DashboardDto.cs: nuevos DTOs para promedio y estrellas mensuales
  - MonthlyStarsDto.cs: DTO para estrellas mensuales (1-5) con frases motivacionales
  - TaskItem.cs: campo Rating actualizado para almacenar porcentaje
- **Frontend:**
  - Home.jsx: nuevo grafico de barras con promedio de calificacion por colaborador, estrellas mensuales solo para colaboradores con reset mensual y frases motivacionales segun promedio
  - TaskModal.jsx: barra de progreso con codigo de color (verde/amarillo/rojo) mostrando porcentaje de calificacion
  - Tasks.jsx: exportacion XLSX muestra porcentajes en lugar de estrellas
- **Security:** Pendiente

---

### [FUNC-019] Rebranding Nomina2, filtro colaboradores, grafico rendimiento
- **Estado:** Completada
- **Fecha:** 2026-03-31
- **Descripcion:** Rebranding completo de FlowPulse a Nomina2, filtro de busqueda en colaboradores, grafico de rendimiento mensual y regeneracion del manual.
- **Backend:**
  - TasksController.cs: frase "día libre" con tilde corregida, logica de fin de mes muestra frase como principal (no bonus)
  - Docker: backend reconstruido
- **Frontend:**
  - Rebranding: logo Nomina2 (Logo2.png) reemplaza logo anterior en login y sidebar, titulo del navegador "Nomina2", todas las referencias FlowPulse eliminadas
  - Login.jsx: eliminado texto "FlowPulse", logo ampliado a 240px
  - Sidebar.jsx: logo centrado, maxHeight 160px, separacion reducida con menu
  - Header.jsx: fallback title "Nomina2", manual renombrado a Manual_Nomina2.pdf
  - Colaboradores.jsx: nuevo filtro de busqueda en tiempo real (nombre, cedula, area, correo, rol) con icono Search y paginacion ajustada
  - Home.jsx: grafico de dona (Doughnut) en MonthlyStarsCard mostrando porcentaje de rendimiento mensual del colaborador con color segun estrellas, frase "dia libre" con estilo destacado (badge verde)
  - Login.css: logo max-width 240px
  - components.css: sidebar__logo centrado con max-height 120px
  - Manual_Nomina2.html/pdf: renombrado, contenido actualizado con calificacion por porcentaje, estrellas mensuales, grafico de rendimiento, tildes y eñes corregidas, margenes del PDF ajustados
  - generateManualPdf.js: referencias actualizadas a Nomina2
  - config/nginx/default.conf: regla no-cache para logo.png
- **Datos:** Rol Lider agregado a los 18 colaboradores que tenian solo rol Colaborador (MongoDB)
- **Documentacion:** Presentacion PPTX generada (Presentacion_Nomina2.pptx) con 24 slides y capturas
- **Security:** Pendiente

---

### [FUNC-020] Seleccion multiple de roles sin restriccion
- **Estado:** Completada
- **Fecha:** 2026-04-01
- **Descripcion:** Eliminada la restriccion que impedia asignar mas de dos roles a un colaborador. Ahora se pueden seleccionar todos los roles disponibles.
- **Backend:** Sin cambios.
- **Frontend:** ColaboradorModal.jsx: eliminada logica de EXCLUSIVE_ROLES que restringia roles Gerente/Administrador como exclusivos. handleRoleToggle simplificado a toggle libre sin restricciones.
- **Security:** Pendiente

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
