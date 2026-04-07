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
