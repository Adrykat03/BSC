# Nomina2 - Registro de Funcionalidades - Fase 2

> Este archivo lleva el registro de todas las funcionalidades desarrolladas en la Fase 2 del proyecto.
> Se actualiza al finalizar cada iteracion aprobada.

## Indice de Funcionalidades

| ID | Nombre | Estado | Fecha |
|----|--------|--------|-------|
| F2-001 | Dashboard BSC con excepciones de promedio mensual | Completada | 2026-04-02 |
| F2-002 | Columna ultima actualizacion colaborador en reportes | Completada | 2026-04-07 |
| F2-003 | Fecha y hora en campo Fecha de entrega en reportes | Completada | 2026-04-07 |
| F2-004 | Filtro Tareas Tardias en grafico por colaborador | Completada | 2026-04-07 |
| F2-005 | Menu de tareas para Administrador con eliminacion masiva | Completada | 2026-04-07 |
| F2-006 | Ultima conexion visible para Gerente al iniciar sesion | Completada | 2026-04-07 |
| F2-007 | Aumentar limite de carga masiva a 600 tareas | Completada | 2026-04-07 |
| F2-008 | Ultima conexion en cambio de rol para todos los roles | Completada | 2026-04-07 |
| F2-009 | Grafico promedio BSC por colaborador en dashboard Gerente | Completada | 2026-04-07 |
| F2-010 | Filtro rango de fechas por Entrega y mejoras iconos modal | Completada | 2026-04-07 |
| F2-011 | Correccion campana de notificaciones y mensaje al clic | Completada | 2026-04-07 |
| F2-012 | Corregir filtro dashboard por DueDate y seed automatico BSC | Completada | 2026-04-07 |

---

## Detalle de Funcionalidades

### [F2-001] Dashboard BSC con excepciones de promedio mensual
- **Estado:** Completada
- **Fecha:** 2026-04-02
- **Descripcion:** Card adicional "BSC" en el dashboard de colaboradores configurados, mostrando el promedio mensual solo de tareas con titulo "Proceso mensual liquidaciones". Esas tareas se excluyen del promedio general. Configuracion flexible en MongoDB (agregar/quitar usuarios, desactivar excepcion).
- **Backend:**
  - Nueva entidad BscDashboardConfig (emails, taskTitlePattern, isActive) en coleccion MongoDB `BscDashboardConfigs`
  - IBscDashboardConfigRepository + BscDashboardConfigRepository: lectura de config activa
  - TasksController: helper CalculateMonthlyStarsFromTasks extraido, endpoint monthly-stars modificado para excluir tareas BSC de usuarios configurados, nuevos endpoints GET /api/tasks/bsc-monthly-stars y GET /api/tasks/has-bsc-dashboard
  - GetDashboardQueryHandler: AvgRatingByCollaborator excluye tareas BSC del promedio general para colaboradores configurados
  - Archivos nuevos: BscDashboardConfig.cs, IBscDashboardConfigRepository.cs, BscDashboardConfigRepository.cs
  - Archivos modificados: TasksController.cs, GetDashboardQueryHandler.cs, DependencyInjection.cs
- **Frontend:**
  - tasksService.js: metodos hasBscDashboard() y getBscMonthlyStars()
  - Home.jsx: estado bscMonthlyStars, fetch condicional, segundo MonthlyStarsCard con badge "BSC" y texto "Promedio BSC {mes}"
- **Datos:** Seed seed_bsc_config.js con emails isabella.sanchez@kfc.com.ec y manuel.zapata@kfc.com.ec, patron "Proceso mensual liquidaciones"
- **Security:** Pendiente

---

### [F2-002] Columna ultima actualizacion colaborador en reportes
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Nueva columna "Ultima actualizacion Colaborador" en todos los reportes XLSX, mostrando la fecha y hora de la ultima accion realizada por el colaborador asignado (basada en StatusHistory).
- **Backend:** Sin cambios (StatusHistory ya se incluia en DTOs).
- **Frontend:**
  - Home.jsx: funcion `getLastCollaboratorUpdate` extraida a nivel de modulo, columna agregada en `handleDownloadReport` (Descargar Reporte) y `downloadTasksXlsx` (grid Tareas por colaborador y estado)
  - Tasks.jsx: columna agregada en `handleExportXlsx` (descarga desde pantalla Tareas)
- **Security:** Pendiente

---

### [F2-003] Fecha y hora en campo Fecha de entrega en reportes
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** El campo "Fecha de entrega" en todos los reportes XLSX ahora muestra fecha y hora (DD/MM/YYYY HH:mm) en lugar de solo la fecha.
- **Backend:** Sin cambios.
- **Frontend:**
  - Home.jsx: `formatDateDDMMYYYY` reemplazado por `formatDateTimeDDMMYYYY` en los dos reportes (Descargar Reporte y grid por colaborador)
  - Tasks.jsx: formato actualizado con `toLocaleString` incluyendo hora y minuto
- **Security:** Pendiente

---

### [F2-004] Filtro Tareas Tardias en grafico por colaborador
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Nuevo dataset "Tareas Tardias" (color rosa #E91E63) en el grafico "Tareas por colaborador y estado", oculto por defecto. Muestra tareas enviadas a validacion despues de la fecha de entrega. Clic en barra descarga XLSX filtrado.
- **Backend:**
  - DashboardDto.cs: nuevo campo `LateTasksByCollaborator` (List<CollaboratorReassignedCount>)
  - GetDashboardQueryHandler.cs: metodo `CalculateLateTasks` que detecta tareas con transicion a "Completa - Por Validar" despues de DueDate
  - TasksController.cs: parametro `lateTasks` (bool) en endpoint export, filtra tareas tardias post-mapeo
- **Frontend:**
  - Home.jsx: prop `lateTasks` en TasksByCollaboratorChart, dataset rosa oculto por defecto, handleClick soporta export de tareas tardias
  - tasksService.js: parametro `lateTasks` en `exportByCollaborator`
- **Security:** Pendiente

---

### [F2-005] Menu de tareas para Administrador con eliminacion masiva
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Nuevo menu "Tareas" para el rol Administrador que muestra todas las tareas del sistema independiente del estado. Permite seleccionar una, varias o todas las tareas y eliminarlas masivamente con confirmacion previa indicando la cantidad.
- **Backend:**
  - TaskStateTransitions.cs: nueva constante `RolAdministrador = "Administrador"`
  - GetTaskItemsQueryHandler.cs: caso Administrador que ve todas las tareas (igual que Gerente)
  - ITaskItemRepository.cs: nuevo metodo `BulkDeleteAsync(List<string> ids)`
  - TaskItemRepository.cs: implementacion con `UpdateManyAsync` para soft delete masivo
  - TasksController.cs: endpoint `POST /api/tasks/bulk-delete` con `BulkDeleteRequest`
- **Frontend:**
  - Sidebar.jsx: enlace "Tareas" agregado en seccion Administrador con icono ClipboardList
  - Tasks.jsx: checkboxes de seleccion individual/total, boton "Eliminar (N)" con confirmacion SweetAlert2, VISIBLE_STATUSES incluye todos los estados para admin, columna "Asignado a" visible para admin
  - tasksService.js: metodo `bulkDelete(ids)` via POST
- **Security:** Pendiente

---

### [F2-006] Ultima conexion visible para Gerente al iniciar sesion
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Al iniciar sesion se muestra la fecha y hora de la ultima conexion del usuario, fija debajo del badge del rol en la esquina superior derecha del header.
- **Backend:**
  - Colaborador.cs: nuevo campo `LastLoginAt` (DateTime nullable)
  - IColaboradorRepository.cs: nuevo metodo `UpdateLastLoginAsync(string id, DateTime loginAt)`
  - ColaboradorRepository.cs: implementacion con `UpdateOneAsync`
  - LoginCommandHandler.cs: guarda timestamp actual y devuelve el anterior en la respuesta
  - LoginDto.cs: campo `LastLoginAt` agregado a `LoginResponseDto`
- **Frontend:**
  - SessionContext.jsx: login retorna `data` para acceder a `lastLoginAt`
  - Login.jsx: guarda `lastLoginAt` en sessionStorage al loguearse
  - Header.jsx: lee sessionStorage, muestra texto fijo "Ultima conexion: DD/MM/YYYY HH:mm" debajo del rol
  - Layout.jsx: Toaster global agregado para toasts del layout
- **Security:** Pendiente

---

### [F2-007] Aumentar limite de carga masiva a 600 tareas
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Limite de carga masiva de tareas aumentado de 100 a 600 en frontend y backend.
- **Backend:**
  - CreateTaskItemsBulkCommandValidator.cs: limite cambiado a 600
  - CreateTaskItemsBulkCommandHandler.cs: validacion hardcodeada cambiada a 600
- **Frontend:**
  - Tasks.jsx: validacion de filas cambiada a 600
- **Security:** Pendiente

---

### [F2-008] Ultima conexion en cambio de rol para todos los roles
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Al cambiar de rol se actualiza LastLoginAt y se muestra la ultima conexion en el header para todos los roles.
- **Backend:**
  - SwitchRoleCommandHandler.cs: inyeccion de IColaboradorRepository, actualiza LastLoginAt y devuelve conexion previa
- **Frontend:**
  - SessionContext.jsx: switchRole guarda lastLoginAt en sessionStorage
- **Security:** Pendiente

---

### [F2-009] Grafico promedio BSC por colaborador en dashboard Gerente
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Nuevo grafico de barras "Calificacion promedio BSC por colaborador" en el dashboard del Gerente, debajo del promedio general. Muestra el promedio solo de tareas BSC (titulo "Proceso mensual liquidaciones") para colaboradores configurados en BscDashboardConfig.
- **Backend:**
  - DashboardDto.cs: nuevo campo `BscAvgRatingByCollaborator` (List<CollaboratorAvgRating>)
  - GetDashboardQueryHandler.cs: metodo `CalculateBscAvgRating` que filtra tareas por emails BSC y patron de titulo
- **Frontend:**
  - Home.jsx: nuevo card con AvgRatingChart reutilizado, visible solo si hay datos BSC
- **Security:** Pendiente

---

### [F2-010] Filtro rango de fechas por Entrega y mejoras iconos modal
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Filtro de fecha cambiado a Date Range Picker (react-datepicker) que filtra por DueDate (fecha de entrega) en rango. Mejoras en iconos del modal de tareas.
- **Backend:**
  - GetTaskItemsQuery.cs: `DateFilter` reemplazado por `DateFrom`/`DateTo`
  - TasksController.cs: parametros `dateFrom`/`dateTo` en endpoint GetAll
  - ITaskItemRepository.cs: parametros `dateFrom`/`dateTo` en metodos de listado
  - TaskItemRepository.cs: ApplyDateFilter filtra por DueDate con rango y zona horaria Ecuador UTC-5
- **Frontend:**
  - Tasks.jsx: react-datepicker con selectsRange como boton con icono Calendar, filtra por fecha de entrega
  - Tasks.css: estilos para react-datepicker-flex
  - tasksService.js: parametros `dateFrom`/`dateTo` en getAll
  - TaskModal.jsx: Cancelar usa Trash2, Enviar a validacion usa solo Send, Validar y enviar al Gerente usa CheckCircle celeste, Guardar solo icono Save color navy con tooltip "Guardar cambios"
  - Dependencia react-datepicker agregada
- **Security:** Pendiente

---

### [F2-011] Correccion campana de notificaciones y mensaje al clic
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Corregido el conteo de tareas pendientes en la campana usando filtro server-side por estado (Asignada + Reasignada) con totalCount. Al dar clic en la campana muestra toast con "Tiene N tareas pendientes por cumplir".
- **Backend:** Sin cambios (usa filtros server-side existentes).
- **Frontend:**
  - Header.jsx: fetchPendingCount usa tasksService.getAll con filtro status para Asignada y Reasignada, suma totalCount de ambas consultas. Clic en campana muestra toast con cantidad o "No tiene tareas pendientes".
- **Security:** Pendiente

---

### [F2-012] Corregir filtro dashboard por DueDate y seed automatico BSC
- **Estado:** Completada
- **Fecha:** 2026-04-07
- **Descripcion:** Dos correcciones: (1) El filtro de rango de fechas del dashboard filtraba por CreatedAt en vez de DueDate, excluyendo tareas completadas del grafico "Comparativa de tareas completadas en el tiempo". Corregido para usar DueDate con timezone Ecuador UTC-5, consistente con el listado de tareas. (2) La configuracion BSC (BscDashboardConfigs) solo existia en MongoDB local, impidiendo que el servidor mostrara los cards BSC para Isabella Sanchez y Manuel Zapata. Se agrego seed automatico al startup del backend.
- **Backend:**
  - TaskItemRepository.cs: nuevo metodo `ApplyDashboardDateFilter` que filtra por DueDate con UTC-5 Ecuador, aplicado a GetAllForDashboardAsync, GetForDashboardByLeaderAsync y GetForDashboardByAssigneeAsync
  - IBscDashboardConfigRepository.cs: nuevo metodo `SeedIfEmptyAsync()`
  - BscDashboardConfigRepository.cs: implementacion de SeedIfEmptyAsync que crea el documento de configuracion BSC si no existe (emails Isabella Sanchez y Manuel Zapata, patron "Proceso mensual liquidaciones")
  - Program.cs: llamada a SeedIfEmptyAsync al iniciar la aplicacion
- **Frontend:** Sin cambios.
- **Security:** Pendiente

---

<!--
Plantilla para nuevas funcionalidades:

### [F2-XXX] Nombre de la Funcionalidad
- **Estado:** Completada | En Progreso | Pendiente
- **Fecha:** YYYY-MM-DD
- **Descripcion:** Breve descripcion de lo que hace la funcionalidad.
- **Backend:** Endpoints, entidades, servicios creados.
- **Frontend:** Paginas, componentes, hooks creados.
- **Security:** Aprobado | Con observaciones | Pendiente
-->
