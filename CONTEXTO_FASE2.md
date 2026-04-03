# Nomina2 - Registro de Funcionalidades - Fase 2

> Este archivo lleva el registro de todas las funcionalidades desarrolladas en la Fase 2 del proyecto.
> Se actualiza al finalizar cada iteracion aprobada.

## Indice de Funcionalidades

| ID | Nombre | Estado | Fecha |
|----|--------|--------|-------|
| F2-001 | Dashboard BSC con excepciones de promedio mensual | Completada | 2026-04-02 |

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
