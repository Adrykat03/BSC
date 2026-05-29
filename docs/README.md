# Documentación del proyecto — BSC BackOffice

Índice de la documentación del sistema. Un archivo por tema. Actualizar esta lista al agregar o renombrar documentos.

## Arquitectura y stack
- [arquitectura.md](arquitectura.md) — stack general, red Docker `bsc_net`, servicios, flujo de requests vía nginx, variables de entorno.

## Integraciones y datos
- [integracion-dab.md](integracion-dab.md) — Data API Builder exponiendo SQL Server. Config, entities, OData queries, cómo agregar un entity.
- [modelo-datos.md](modelo-datos.md) — esquemas de MongoDB (Colaboradores, Roles, Tasks, BscDashboardConfigs) y tabla SQL `Avisos.notificacionesConsolidadas`.

## Reglas de negocio
- [reglas-negocio.md](reglas-negocio.md) — actores (Gerente/Líder/Colaborador), ciclo de estados de tareas, flujo de resolución de alertas, autenticación, soft delete.

## Módulos / funcionalidades
- [alertas-payroll.md](alertas-payroll.md) — Dashboard de Alertas Payroll: KPIs, tabla con sort/filtros/sticky, modal de previsualización HTML con zoom.

## Deploys / runbooks
- [deploy-alertas-payroll.md](deploy-alertas-payroll.md) — Runbook del primer despliegue de Alertas Payroll + stand-up inicial de DAB en prod. Incluye plan abreviado para releases posteriores.

## Bitácora
- [bitacora.md](bitacora.md) — registro cronológico de avances, decisiones y fixes relevantes.

---

**Convenciones** (ver `memory/CLAUDE.md` para el detalle):
- Idioma: español. Formato: Markdown.
- Un tema por archivo. Nombres en minúsculas con guiones: `alertas-payroll.md`, `integracion-dab.md`.
- Fechas absolutas (`2026-04-22`), nunca relativas.
- Actualizar este índice al agregar/renombrar.
