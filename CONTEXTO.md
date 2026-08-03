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
| FUNC-021 | Alertas Payroll: historial de estados con auditoria MongoDB | Completada | 2026-05-10 |
| FUNC-022 | Formato profesional XLSX y boton Actualizar en Alertas | Completada | 2026-05-29 |
| FUNC-023 | Fix links iframe Alertas y manual de usuario HTML | Completada | 2026-05-29 |
| FUNC-024 | Ajuste visual gráfico Pendientes por Resolver (prioridad) | Completada | 2026-06-09 |
| FUNC-025 | Permisos por módulo en roles (Fase 1: visibilidad) | Completada | 2026-06-12 |
| FUNC-026 | Fix modal Colaborador: scroll footer + roles como botones | Completada | 2026-06-13 |
| FUNC-027 | Alertas Payroll — Listado: Finalizadas, agrupación por categoría y gráfico apilado | Completada | 2026-06-29 |
| FUNC-028 | Tareas — Evidencia adjunta obligatoria para Colaborador | Completada | 2026-06-29 |
| FIX-029 | Despliegue a producción + fix nginx Host (AllowedHosts) | Completada | 2026-06-29 |
| FIX-030 | Tareas — restaurar selector de asignables (regresión por permisos por módulo) | Completada | 2026-07-02 |
| FIX-031 | Visor de alertas: HTML mal formado (blanco) + corrección de SP de correos | Completada | 2026-07-03 |
| FIX-032 | Tareas: promedio mensual por fecha de entrega + mejoras del visor y filtros de Alertas | Completada | 2026-07-06 |
| FUNC-033 | Alertas: adjuntos de resolución + varios ajustes de UI del módulo | Completada | 2026-07-08 |
| FUNC-034 | Catálogo de Alertas del Monitor (reporte HTML standalone) | Completada | 2026-07-28 |
| FUNC-035 | Tareas: columna "Cargado por" en export XLSX + script de consulta prod | Completada | 2026-07-30 |
| FIX-036 | Alertas: columnas congeladas en tabla Listado + fix de layout global (scroll horizontal) | Completada | 2026-08-03 |

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

### [FUNC-021] Alertas Payroll: historial de estados con auditoria MongoDB
- **Estado:** Completada
- **Fecha:** 2026-05-10
- **Descripcion:** Cambio de estado de alertas desde la UI con registro de historial auditable en MongoDB. Arquitectura hibrida: actualizacion en SQL Server via DAB + historial en coleccion MongoDB `alertasEstadosHistorial`.
- **Backend:**
  - `AlertaEstados.cs` — constantes A/P/R/C/E con validacion `IsValid`.
  - `AlertaEstadoHistorial.cs` — entidad MongoDB con indice `(idNotificacion ASC, fecha DESC)`.
  - `ChangeAlertaStatusCommand/Handler/Validator` — MediatR command. Extrae `usuarioEmail` y `usuarioRol` del JWT (ClaimsPrincipal), no del body. Manejo graceful DAB↔Mongo: si Mongo falla, devuelve `historialPersistido=false` sin bloquear.
  - `GetAlertaHistorialQuery/Handler` — consulta historial por idNotificacion.
  - `IDabAlertasClient` + `DabAlertasClient` — cliente HTTP tipado a DAB.
  - `AlertaHistorialRepository` — implementacion MongoDB con `EnsureIndexes`.
  - `AlertasController` — `[Authorize(Roles = RolesPermitidos)]` a nivel clase (Administrador, Gerente, Lider — excluye Colaborador). Fail-fast JWT en produccion.
  - `appsettings.json/Development.json` — `DabSettings:BaseUrl`.
  - Tests: 9/9 OK (5 handlers + 4 autorizacion por reflexion).
- **Frontend:**
  - `alertasService.js` — `cambiarEstado` y `getHistorial`.
  - `AlertasPayroll.jsx` — historial inline en modal + popup de historial desde columna Acciones (icono Clock). Error 5xx visible, loading state, banner `historialPersistido=false`.
- **Security:** Aprobado para produccion. A1 (IDOR historial) cerrado con roles. A2 (JWT fail-fast) cerrado en Program.cs.

---

### [FUNC-022] Formato profesional XLSX y boton Actualizar en Alertas
- **Estado:** Completada
- **Fecha:** 2026-05-29
- **Descripcion:** Formato visual profesional en todos los reportes XLSX del sistema y boton para recargar datos de Alertas sin refrescar la pagina.
- **Backend:** Sin cambios.
- **Frontend:**
  - `AlertasPayroll.jsx` — boton "Actualizar" (RefreshCw, icono animado durante carga) en toolbar del Listado. Descarga XLSX con formato via exceljs.
  - `Tasks.jsx` — exportacion de tareas y plantilla de carga con formato exceljs. Fila de ejemplo en amarillo (#FFF9C4) para distinguirla.
  - `Home.jsx` — reporte general y descarga por colaborador con formato exceljs.
  - Formato comun: encabezado azul #1F4E79 texto blanco negrita, filas alternas blanco/#EBF3FB, bordes thin, header congelado.
  - Nueva dependencia: `exceljs` (dynamic import — solo carga al descargar, no en arranque).
  - Motivo del cambio de libreria: `@e965/xlsx` v0.20.3 ignora silenciosamente los estilos de celda al escribir XLSX.
- **Security:** Sin cambios de superficie de ataque (logica 100% cliente).

---

### [FUNC-023] Fix links iframe Alertas y manual de usuario HTML
- **Estado:** Completada
- **Fecha:** 2026-05-29
- **Descripcion:** Correccion del bloqueo de navegacion en el preview del correo y generacion del manual de usuario del modulo Alertas Payroll en formato HTML.
- **Backend:** Sin cambios.
- **Frontend:**
  - `AlertasPayroll.jsx` — atributo `sandbox` del `<iframe>` corregido para permitir apertura de links en nueva pestana (allow-popups, allow-popups-to-escape-sandbox, allow-top-navigation-by-user-activation). Scripts siguen bloqueados.
  - `docs/manual-usuario-alertas-payroll.md` — manual en Markdown como fuente de verdad.
  - `docs/manual-usuario-alertas-payroll.html` — manual renderizado con sidebar de navegacion fija, tablas formateadas, badges de estado en colores reales, FAQ acordeon y demo de fila critica.
  - `.gitignore` actualizado: se agrego excepcion `!docs/*.md` para que toda la carpeta `docs/` quede trackeada en el repo.
- **Security:** Sin cambios de superficie. El sandbox del iframe se relajo minimamente (solo navegacion, scripts siguen bloqueados).

---

### [FUNC-024] Ajuste visual gráfico Pendientes por Resolver (prioridad)
- **Estado:** Completada
- **Fecha:** 2026-06-09
- **Descripcion:** Pulido visual del gráfico donut "Pendientes por Resolver" en Alertas Payroll: reduccion de separacion entre SVG y leyenda, centrado del conjunto en la card, y alineacion columnar de numeros y porcentajes en la leyenda.
- **Backend:** Sin cambios.
- **Frontend:**
  - `AlertasPayroll.css` — `.payroll-donut` gap reducido a `spacing-3`, `height: 100%` para centrado vertical; `.payroll-donut__legend` sin `flex: 1`; `.payroll-donut__legend-item` cambiado de flex a CSS grid `10px 1fr 28px 40px` para alinear columnas.
  - `AlertasPayroll.jsx` — leyenda separada en dos spans distintos (`.payroll-donut__legend-value` y `.payroll-donut__legend-pct`) en lugar de un span anidado.
- **Security:** Sin cambios de superficie.

---

### [FUNC-025] Permisos por módulo en roles (Fase 1: visibilidad)
- **Estado:** Completada
- **Fecha:** 2026-06-12
- **Descripcion:** Se reemplaza la visibilidad de módulos hardcodeada por nombre de rol por un sistema de permisos por módulo. Al crear/editar un rol, el admin elige qué módulos puede ver (Dashboard, Roles, Colaboradores, Tareas, Alertas Payroll). Menú, rutas y landing pasan a ser data-driven según los módulos del rol activo. Alcance acotado a visibilidad de módulos; el workflow de Tareas y las cards del Dashboard por rol quedan intactos (eso son permisos de acción, otra fase).
- **Backend:**
  - `Domain/Constants/Modules.cs` — catálogo de 5 keys (dashboard, roles, colaboradores, tareas, alertas-payroll).
  - `Domain/Entities/Role.cs` — campo `List<string> Modules` (`[BsonElement("modules")]`).
  - CRUD de roles: `CreateRole`/`UpdateRole` (Command/Handler/Validator) + `RoleDto` + queries GetRoles/GetRoleById incluyen `Modules` (validado contra catálogo).
  - JWT: claim `modules` (array JSON, mismo patrón que `roles`) calculado del **rol activo**; emitido en login y switch-role (`IJwtTokenService`/`JwtTokenService`, `LoginCommandHandler`, `SwitchRoleCommandHandler`).
  - Enforcement: atributo `[RequireModule("key")]` policy-based (`Authorization/RequireModuleAttribute.cs`, `ModuleRequirement.cs`, `ModuleAuthorizationHandler.cs`, `ModulePolicyProvider.cs`). Falla cerrado (sin claim → 403). Aplicado: Alertas/AlertasPayroll→alertas-payroll, Roles→roles, Colaboradores→colaboradores, Tasks→tareas con override `dashboard` en GetDashboard. Auth/Health sin requerimiento.
  - Tests: `AlertasControllerAuthorizationTests` adaptado a `[RequireModule]`. Build 0 errores, 9/9 tests verdes.
- **Frontend:**
  - `utils/modules.js` — catálogo único (key, path, label, icon) + helpers (única fuente de verdad).
  - `context/SessionContext.jsx` — `extractUser` parsea claim `modules` → `user.modules`.
  - `components/ModuleRoute.jsx` — guard por módulo; redirige al primer módulo permitido.
  - `Sidebar.jsx` y `routes.jsx` — data-driven según `user.modules`. Landing = primer módulo permitido.
  - `Header.jsx` — títulos derivados del catálogo; oculta campana y evita fetch a Tareas si el rol no tiene módulo `tareas`.
  - `Roles/RoleModal.jsx` — selector de módulos (toggle-group design system). `Roles.jsx` — columna de módulos como badges.
- **Datos:** `seeds/seed_usuarios_nomina.js` actualizado con `modules` por rol; `seeds/migrate_roles_modules.js` (migración idempotente para BD ya poblada). Matriz: Administrador=roles/colaboradores/tareas/alertas-payroll; Gerente/Lider/Colaborador=dashboard/tareas/alertas-payroll.
- **Security:** Aprobado con observaciones. Núcleo sólido (fail-closed, override clase+acción correcto, sin escalada). Hallazgo ALTO **preexistente**: acceso a alertas vía `/dab` sin auth (lectura y PATCH) elude el control por módulo — pendiente de corregir canalizando por backend o autenticando DAB. Medios: `usuarioResolucion` desde cliente (misma raíz DAB), CORS hardcodeado. Bajos: JWT estático (cambios de permiso aplican tras re-login/switch), guard frontend solo UX (confirmado sin bypass real).

---

### [FUNC-026] Fix modal Colaborador: scroll footer + roles como botones
- **Estado:** Completada
- **Fecha:** 2026-06-13
- **Descripcion:** Correccion de UX detectada al probar FUNC-025. En el modal de crear colaborador no se veian los botones de accion (Cancelar/Crear) porque el `<form>` envolvia `modal__body` + `modal__footer` y rompia el layout flex: en modo crear (mas alto, con reglas de password) el footer se salia de los 90vh. Ademas el selector de roles se veia roto al hacer wrap.
- **Backend:** Sin cambios.
- **Frontend:**
  - `styles/components.css` — nueva clase `.modal__form` (columna flex que llena el modal) para que el body haga scroll y el footer quede fijo.
  - `pages/Colaboradores/ColaboradorModal.jsx` — `<form>` con clase `modal__form`; selector de roles convertido a botones individuales (`btn btn--sm`, primary/secondary) con `d-flex flex-wrap gap-2`, reemplazando el grupo segmentado con estilos inline. Label estandar del design system.
  - `pages/Roles/RoleModal.jsx` — misma clase `modal__form` aplicada (estructura identica, mas alto por el selector de modulos de FUNC-025).
- **Security:** Sin cambios de superficie (solo UI).

---

### [FUNC-027] Alertas Payroll — Listado: Finalizadas, agrupación por categoría y gráfico apilado
- **Estado:** Completada
- **Fecha:** 2026-06-29
- **Descripcion:** Conjunto de mejoras al Listado de Alertas. (1) Sub-pestaña "Finalizadas" (estados Resuelta R + Cerrada C) separada de "Pendientes" (A/P/E), cada una con su contador. (2) Vista agrupada por categoría con cabeceras colapsables; modo agrupado por defecto + toggle Lista/Agrupado y botón Expandir/Contraer todo; la cabecera de categoría queda fija (sticky) al hacer scroll, debajo del encabezado de columnas. (3) Columna "Origen" movida al final de la tabla. (4) Contador de totales (X de Y) reubicado junto al título "Alertas". (5) Gráfico "Alertas por Categoría" cambiado de barra simple a barras apiladas coloreadas por tipo de descripción (con novedad/sin novedad/reportería/error proceso), respetando los chips de filtro.
- **Backend:** Sin cambios.
- **Frontend:**
  - `AlertasPayroll.jsx` — estados `viewMode`/`expandedGroups`; `groupedData` (agrupa `filteredSorted` por categoría, orden por cantidad desc); sub-pestaña Finalizadas (`ESTADOS_FINALIZADOS=['R','C']`); render de `<tbody>` por grupo con fila-cabecera clickeable (reutiliza `col.render`); paginación oculta en modo agrupado; `categoriaItems` reescrito a desglose por descripción; `HorizontalBar` reescrito a segmentos apilados; columna `origen` al final; contador en el `card__title`.
  - `AlertasPayroll.css` — `.payroll-viewmode*` (toggle), `.payroll-group*` (cabecera de grupo + sticky `top: var(--payroll-header-h)`), `.payroll-hbar__stack/__seg` (barra apilada), `.payroll-title-count`.
- **Security:** Sin cambios de superficie (solo UI).

---

### [FUNC-028] Tareas — Evidencia adjunta obligatoria para Colaborador
- **Estado:** Completada
- **Fecha:** 2026-06-29
- **Descripcion:** El Colaborador no puede dejar una tarea sin evidencia por ninguna vía: (1) no puede "Enviar a validación" sin al menos un archivo de evidencia (nuevo o ya guardado); (2) no puede "Guardar evidencia" sin adjunto; (3) no puede eliminar el último archivo de evidencia (permite reemplazo si primero adjunta el nuevo). Validación de frontend; pendiente blindarlo también en backend.
- **Backend:** Sin cambios (recomendado reforzar en el endpoint de cambio de estado/upload).
- **Frontend:** `pages/Tasks/TaskModal.jsx` — guardas en el `onClick` de la transición "Completa - Por Validar", en `handleSubmit` (rama Colaborador) y en `handleRemoveExistingFile` (tipo evidence).
- **Security:** Sin cambios de superficie (validación de UX/cliente).

---

### [FIX-029] Despliegue a producción + fix nginx Host (AllowedHosts)
- **Estado:** Completada
- **Fecha:** 2026-06-29
- **Descripcion:** Release acumulado desplegado al servidor (cx@192.168.100.9, ~/BSC): git pull (fast-forward), migración idempotente `seeds/migrate_roles_modules.js`, rebuild de `bsc_backend`, build local del frontend copiado a `html/` y restart de `bsc_frontend`. Tras el deploy, el login fallaba con "Unexpected token '<' ... is not valid JSON": el backend rechazaba el acceso por IP pública con 400 "Invalid Hostname" porque `AllowedHosts=localhost;bsc_backend;bsc-backend` y nginx reenviaba `Host $host`. Fix: `config/nginx/default.conf` `/api/` usa `proxy_set_header Host bsc-backend;`.
- **Backend:** Sin cambios (solo redeploy).
- **Frontend/Infra:** `config/nginx/default.conf` — Host fijo a `bsc-backend` con comentario. Commit `f0dfffc`.
- **Security:** El blindaje de DAB (eliminación del bloque `/dab/` del proxy) quedó activo en producción tras este deploy.

---

### [FIX-030] Tareas — restaurar selector de asignables (regresión por permisos por módulo)
- **Estado:** Completada
- **Fecha:** 2026-07-02
- **Descripcion:** Tras FUNC-025, al crear/asignar tareas no aparecían colaboradores ni líderes en el selector. Causa: el modal de tareas poblaba la lista con `GET /api/colaboradores`, endpoint que quedó protegido por `[RequireModule(colaboradores)]`; Gerente y Líder no tienen ese módulo (solo Administrador), por lo que recibían 403 y la lista quedaba vacía. La asignación en sí (`PUT /api/tasks/{id}/assign`) y el reflejo de tareas a cada usuario nunca se rompieron (van por el módulo `tareas`). Solo fallaba el lookup de nombres.
- **Backend:** `TasksController` — nuevo `GET /api/tasks/assignees` protegido por el módulo `tareas`, que reutiliza `GetAllColaboradoresQuery` (mismo `ColaboradorDto`, sin duplicar lógica). Así Gerente/Líder listan asignables sin necesitar el módulo `colaboradores`.
- **Frontend:** `tasksService.getAssignees()` nuevo; los 3 puntos que usaban `colaboradorService.getAll()` para asignación pasan a `tasksService.getAssignees()` (`TaskModal.jsx`, `Tasks.jsx` modal de asignar y plantilla Excel). Import de `colaboradorService` removido donde quedó sin uso. El filtrado por rol (Lider/Colaborador) del selector se mantiene igual.
- **Security:** Sin relajar permisos: la gestión de Colaboradores sigue exigiendo el módulo `colaboradores`; solo el lookup de asignación se habilita bajo `tareas`.

---

### [FIX-031] Visor de alertas: HTML mal formado (blanco) + corrección de SP de correos
- **Estado:** Completada
- **Fecha:** 2026-07-03
- **Descripcion:** Alertas con HTML (ej. "Reporte Correos en más de un trabajador", avisos de Jerarquías/vacaciones) salían **en blanco** en el visor. Causa raíz: los correos generados por SP de Nómina traían un `<style>` **sin cerrar** (`</style>` faltante antes de `</head>`) — el navegador se traga todo el resto del documento como CSS. Doble corrección: (a) visor resiliente que repara el `<style>` al vuelo (cubre alertas **ya guardadas**); (b) corrección de los SP en la raíz (para alertas **nuevas**). De paso se corrigieron textos de `<H1>` copiados por error y un `<p>` que usaba un `@msg` desfasado.
- **Frontend:** `AlertasPayroll.jsx` — nueva `repairUnclosedStyle()` (inserta el `</style>` faltante antes de `</head>`/`<body>`, sin tocar los ya cerrados) usada en `buildPreviewDocument`. Desplegado a prod vía copia de `html/` (sin rebuild de backend).
- **SP (schema Avisos, DB_NOMKFC/ADAM):** 12 archivos con `<style>` sin cerrar corregidos: `pa_aviso_CorreosProblemas.sql` + 11 de avisos de vacaciones/nómina (`pa_avisoVacDisfnoProgramacion`, `pa_aviso_vac_E01`, `sp_fpv_aviso_vacaciones_*`). En `pa_aviso_CorreosProblemas` además: 3 `<H1>` con texto equivocado corregidos (bloques "no tienen correo", "vacío el valor de correo", "empresa de baja correo") y reordenado `SET @asunto/@msg/@saludos` antes del `SELECT @html` en el bloque "no tienen correo" (el `<p>` usaba el mensaje del bloque anterior). **Requiere ejecutar los `ALTER PROCEDURE` en el SQL Server** para que aplique a alertas nuevas; las viejas quedan cubiertas por el fix del visor.
- **Security:** Sin impacto.

---

### [FIX-032] Tareas: promedio mensual por fecha de entrega + mejoras del visor y filtros de Alertas
- **Estado:** Completada
- **Fecha:** 2026-07-06
- **Descripcion:** Varios ajustes de la sesión. (1) **Promedio mensual de Tareas** (estrella del mes): agrupaba cada tarea por la fecha de ENVÍO a validación (`firstCpv.ChangedAt`), así una tarea entregada tarde en otro mes se promediaba en el mes equivocado. Ahora agrupa por el mes de **`DueDate`** (fecha de entrega), con `CreatedAt` como respaldo — coherente con el filtro por DueDate del Dashboard. (2) **Visor de alertas**: el calendario de filtro por fecha no se abría en el Listado (quedaba tapado detrás del encabezado sticky de la tabla → z-index). (3) **Visor de correo**: se hizo el tamaño de la "página" **dinámico** (alto y ancho medidos del contenido) para que reportes largos/anchos se vean completos con **un solo scroll** (el del visor), en vez de recortarse a 1100px o mostrar doble scroll. (4) **Filtro de columna tipo Excel**: al buscar un valor y dar "Aceptar", no filtraba (quedaba "todo marcado" = sin filtro); ahora con búsqueda activa "Aceptar" filtra por los resultados de la búsqueda.
- **Backend:** `TasksController.cs` — `monthly-stars` y `bsc-monthly-stars` agrupan por `DueDate ?? CreatedAt` en vez de `firstCpv.ChangedAt`.
- **Frontend:** `AlertasPayroll.css` — `z-index` del `.react-datepicker-popper` elevado sobre la tabla sticky. `AlertasPayroll.jsx` — `buildPreviewDocument`/iframe con medición dinámica de alto y ancho (`allow-same-origin` en sandbox, sin `allow-scripts`; `scrolling="no"`) para un solo scroll; `apply` del `ColumnFilterMenu` filtra por resultados de búsqueda cuando hay término activo.
- **Security:** `allow-same-origin` en el iframe del correo es seguro (no hay `allow-scripts`, el correo no ejecuta JS); solo permite medir el contenido.

---

### [FUNC-033] Alertas: adjuntos de resolución + varios ajustes de UI del módulo
- **Estado:** Completada
- **Fecha:** 2026-07-08
- **Descripcion:** (1) **Adjuntos de resolución**: en el modal de resolución de una alerta se pueden adjuntar archivos y **pegar imágenes (Ctrl+V)**, igual que Tareas. Se suben al guardar el cambio de estado; se listan con **previsualizar** (lightbox con zoom + scroll para imágenes, visor para PDF), descargar y eliminar. **Regla:** el estado "Error" (E) exige al menos un adjunto. (2) Ajustes del Listado: al **ordenar por columna** ya ordena TODAS las filas (el pin de críticas al tope solo aplica en el orden por defecto); columna **Asunto** más ancha; fix de **descarga XLSX** (era caché de un chunk lazy de exceljs, no los campos). (3) Gráfico **"Pendientes por Resolver"**: bajo el donut, una línea por prioridad (Alta/Media/Baja) con su total, % y desglose de pendientes por tipo de descripción (Con novedad / Reportería / Error Proceso), en columnas alineadas con divisor.
- **Backend (Mongo, SIN tocar SQL):** entidad `AlertaResolucionAdjunto` + `IAlertaAdjuntoRepository`/`AlertaAdjuntoRepository` (colección `alertasResolucionAdjuntos`). Endpoints en `AlertasController`: `POST/GET /alertas/{id}/adjuntos`, `GET/DELETE /alertas/{id}/adjuntos/{adjuntoId}`. Archivos en disco `/app/files/alertas-resolucion` (validación tamaño 20MB + magic bytes; descarga con protección de path traversal). DTO `AlertaAdjuntoDto`; repo registrado en DI.
- **Frontend:** `alertasService` — métodos de adjuntos (upload multipart, list, preview, download, remove). `AlertasPayroll.jsx` — UI de adjuntos en el panel de resolución (drag/select + paste + lightbox con zoom), regla de "Error" obligatorio, orden sin pin al ordenar columna, desglose de "Pendientes por Resolver". `AlertasPayroll.css` — estilos de adjuntos, lightbox, ancho de Asunto, desglose de pendientes.
- **Security:** Adjuntos gateados por el módulo `alertas-payroll` (como el resto del controlador); validación de tipo por magic bytes; sin exponer la ruta en disco al cliente.
- **Despliegue:** Commit `7d11fa3` en `origin/main`; desplegado a producción (`cx@192.168.100.9`) el 2026-07-08 — backend recompilado, frontend reconstruido y `bsc_frontend` recreado (verificado: `/api/alertas/{id}/adjuntos` → 401 sin token, frontend HTTP 200). Sin migración BD (colección Mongo y `/app/files/alertas-resolucion` se autocrean).

---

### [FUNC-034] Catálogo de Alertas del Monitor (reporte HTML standalone)
- **Estado:** Completada
- **Fecha:** 2026-07-28
- **Descripcion:** Reporte HTML **informativo, NO integrado en la aplicación** (documento aparte, mismo estilo visual que `SP/reporte_SP_nomina.html`) que cataloga las **119 alertas reales** actualmente registradas en `Avisos.notificacionesConsolidadas` — la tabla que alimenta el monitor Alertas Payroll. Por cada alerta: SP de origen (o clase .NET del backend de Nómina, cuando aplica), qué hace, categoría/prioridad, asunto y destinatarios del último envío real, y una vista previa del HTML de correo tal como quedó guardado. Ordenado por categoría y, dentro de cada una, alfabéticamente por asunto, con encabezado de sección por categoría. Búsqueda + filtro por tipo (SP / clase C#).
- **Cómo se armó:** Consulta directa a `Avisos.notificacionesConsolidadas` vía la API REST de DAB (mismo backend que usa el monitor) agregada por `spOrigen`/`origen` (120 grupos iniciales → 119 tras excluir "CONSULTA ERRORES MASIVO", que resultó ser el estado de error del propio `pa_consultaErroresMasivo`, no una alerta distinta). ~62 orígenes son SPs de SQL (`C:\Proyectos\BSC\SP\*.sql`, analizados en paralelo por 3 sub-agentes); ~56 son clases .NET (`AvisosMarcajes.*`, `AvisosJerarquias.Jerarquia_01..35`, `VerificadorAlertas` — origen real de la categoría "PROCESO VERIFICACION ALERTAS" —, etc.) cuyo código fuente vive en el repo separado `C:\Proyectos\avisos`, documentadas a partir de los asuntos/categorías reales de la BD.
- **Correcciones aplicadas tras revisión:** (1) La clasificación "envía correo" inicialmente confiaba en el análisis estático del código (que se equivocó para 2 SPs que sí insertan HTML por una rama no vista); se cambió a usar como verdad el HTML real del último registro — y finalmente se **eliminó por completo** esa distinción visual (tag, contadores, filtro) por no aportar valor. (2) Tildes corruptas (`dÃ­a`) en la vista previa del correo: el `<iframe src="data:text/html;base64,...">` no declaraba `charset`, así que el navegador adivinaba mal la codificación pese a que los archivos ya estaban en UTF-8 correcto; se agregó `charset=utf-8` al data URI.
- **Archivo:** `SP/reporte_alertas_monitor.html` (autocontenido, sin dependencias de servidor — se abre directo desde el explorador). Script generador y datos intermedios de la consulta se mantuvieron fuera del repo (scratchpad de la sesión), no comiteados. Adicional: `SP/alertas_monitor.xlsx` — mismo listado de las 119 alertas en Excel (columnas SP/.NET, nombre, categoría, asunto, destinatarios, fecha y hora de última ejecución, prioridad, registros), a pedido para compartir sin necesidad de abrir el HTML.
- **Security:** Sin impacto — documento estático de solo lectura, no integrado en la app ni en el pipeline de build/deploy. Contiene datos ya visibles para quien tiene acceso al monitor (destinatarios de correo, asuntos); no expone credenciales ni endpoints nuevos.

---

### [FUNC-035] Tareas: columna "Cargado por" en export XLSX + script de consulta prod
- **Estado:** Completada
- **Fecha:** 2026-07-30
- **Descripcion:** (1) El Excel que se descarga desde el módulo Tareas (botón de exportar del listado) ahora incluye la columna **"Cargado por"** con el correo de quien creó la tarea, entre "Fecha de creación" y "Última actualización Colaborador". (2) Se agregó un script de consulta ad-hoc de solo lectura contra la base Mongo de **producción**, para casos como "¿quién creó/cargó esta tarea?" sin tener que repetir manualmente la conexión SSH cada vez.
- **Backend:** Sin cambios — `createdBy` ya venía expuesto en `TaskItemDto`/`TaskItemMapper`, solo faltaba mostrarlo en el export del frontend.
- **Frontend:** `pages/Tasks/Tasks.jsx` — `handleExportXlsx`: nueva key `'Cargado por': t.createdBy` en el mapeo de filas; ancho de columna agregado a `taskColWidths`.
- **Herramientas:** `scripts/consultar-tareas-prod.sh` — script bash parametrizado (`./scripts/consultar-tareas-prod.sh "texto a buscar"`) que busca por texto en `title`/`description` de `TaskItems` en producción (`cx@192.168.100.9`) y muestra estado, `createdBy`, `createdAt`, líder/colaborador asignado y fecha de entrega. Pide la contraseña SSH de forma interactiva (no se guarda en ningún archivo); documenta en comentarios el workaround necesario para `sshpass` en este entorno (`ssh` intentaba abrir `/dev/tty` directo e ignoraba el prompt interceptado por `sshpass`, mecanismo `SSH_ASKPASS_REQUIRE=force` con script temporal autodestruible).
- **Despliegue:** Build local + copia a `html/` + restart de `bsc_frontend` para pruebas; pendiente desplegar a producción.
- **Security:** Sin cambios de superficie de ataque (campo ya expuesto por la API, solo se agrega a la vista de export). El script de consulta es de solo lectura y no persiste credenciales.

---

### [FIX-036] Alertas: columnas congeladas en tabla Listado + fix de layout global (scroll horizontal)
- **Estado:** Completada
- **Fecha:** 2026-08-03
- **Descripcion:** (1) **Total del día en el tooltip del gráfico "Alertas vs Tiempo"**: al pasar el cursor sobre un segmento de Reportería/Con novedad/Sin novedad se muestra primero (`beforeBody`) el total de alertas de ese día/semana/mes (suma de las 4 descripciones), antes de la línea del segmento y del hint de clic para descargar. Error Proceso queda sin ese total (no pedido). (2) **Columnas congeladas** en la tabla del Listado: Acciones, Fecha, Estado, Prioridad, Categoría y Asunto quedan fijas a la izquierda al hacer scroll horizontal hacia las columnas de la derecha (Descripción, Notificados, Fecha Resolución, etc.), con anchos fijos + offsets acumulados y borde de separación tras Asunto.
- **Bug real detrás de "las columnas no se congelan" (el más importante de la sesión):** no era un problema de las reglas `sticky` en sí. `frontend/src/styles/components.css` → `.layout__main` (contenedor principal de TODA la app, junto al sidebar) es un hijo flex (`flex:1`) **sin `min-width:0`**. Sin eso, cuando un hijo necesita más ancho del disponible (la tabla con columnas de ancho fijo), el navegador **estira toda la página** en vez de activar el scroll interno del contenedor de la tabla — bug de layout preexistente (afecta cualquier página con contenido ancho) que solo se hizo visible ahora. Fix de una línea, verificado con Playwright (login real + medición de `scrollWidth`/`clientWidth` antes/después) porque no hay navegador para probar visualmente en este entorno.
- **Bugs secundarios encontrados y corregidos en cadena, todos verificados con el mismo método (Playwright + Chromium real, no solo revisión de CSS):**
  1. Fondo semi-transparente (`rgba`) en columnas congeladas de filas **críticas** (alertas urgentes en rojo) dejaba ver el contenido no congelado pasando por debajo al hacer scroll ("doble texto"). Fix: overrides con el equivalente **opaco** del mismo tinte (`--color-error-bg` / `#FCDDDD` en hover), con especificidad CSS suficiente para ganarle a la regla `rgba` sin depender del orden de las reglas.
  2. En modo **Agrupado**, el título de la categoría (fila-cabecera colapsable, celda con `colSpan` a todo el ancho) no se quedaba fijo horizontalmente pese a que el sticky **vertical** de esa misma celda sí funciona: verificado que `position:sticky;left:0` no se aplica de forma confiable en un `<td colSpan>` ni en un hijo directo suyo en Chromium. Se resolvió a mano con JS: `onScroll` en el contenedor (`handleTableScroll`, con `requestAnimationFrame`) desplaza un `<span>` interno vía `transform: translateX(scrollLeft)`.
  3. Esa primera versión del fix por JS causaba **scroll infinito con espacio en blanco**: el elemento transformado tenía el ancho de toda la fila (colSpan completo, ~2000px), y un `transform` así de ancho **infla el `scrollWidth`** del contenedor (el navegador sí contempla las cajas transformadas al calcular el área de scroll) — bucle: al scrollear, el elemento se corre, lo que agranda el área desplazable. Fix: separar el `<button>` de click (ancho real de la fila, sin transformar) del `<span>` visual angosto (solo el contenido: ícono+nombre+contador) que sí se transforma — verificado que `scrollWidth` queda estable y el navegador clampea correctamente el scroll máximo.
- **Frontend:** `AlertasPayroll.jsx` — `options.plugins.tooltip.callbacks.beforeBody` (total del día); `data-col` ya existente reutilizado para las reglas de congelado; `groupHeaderShift` (estado) + `handleTableScroll` (handler con rAF) + `onScroll` en `.payroll-sticky-table`; wrapper `<span className="payroll-group__toggle-inner">` dentro del botón de categoría. `AlertasPayroll.css` — reglas de columnas congeladas (`[data-col='...']`, anchos fijos, offsets `left` acumulados, z-index en capas: header congelado > header normal > body congelado > body normal), overrides opacos para fila crítica + congelada, `.payroll-group__toggle-inner` (chip visual, `will-change:transform`). `styles/components.css` — `.layout__main { min-width: 0; }`.
- **Metodología:** dado que este entorno no tiene navegador para verificación visual directa, se instaló Playwright (`playwright/` — antes solo tenía el script de capturas del manual, sin `node_modules`) y se hicieron logins reales contra la app local (usuario Administrador, password = cédula en seeds de dev) para medir posiciones/`scrollWidth` reales y confirmar cada fix antes de reportarlo, en vez de asumir que el CSS "debería" funcionar.
- **Security:** Sin cambios de superficie de ataque (solo UI/CSS/JS de presentación).

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
