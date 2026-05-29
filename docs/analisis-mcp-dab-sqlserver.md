# Análisis MCP `dab-sqlserver` — Estado actual y mejoras a futuro

**Fecha:** 2026-04-23
**Última revisión:** 2026-04-27
**Alcance:** Prueba de conexión del MCP expuesto por Data API Builder (DAB) sobre SQL Server, y revisión de la configuración asociada.

> **Decisión 2026-04-27 — Integración con Claude Code diferida.**
>
> La activación del MCP `dab-sqlserver` dentro de Claude Code (para que el agente pueda invocar `read_records`, `update_record`, etc. directamente) **se deja para más adelante**. Hoy la app no lo necesita: el frontend lee la tabla vía DAB REST (`/dab/NotificacionesConsolidadas`) y el feature de descarga de adjuntos pasa por el backend BSC (`/api/alertas-payroll/adjunto`). El MCP queda configurado en `.mcp.json` y el endpoint sigue respondiendo 200 al handshake — solo no se ha aprobado la conexión en la sesión de Claude Code.
>
> **Para activarlo cuando se decida:** reiniciar Claude Code en `C:\Proyectos\BSC`, aceptar el prompt de confianza al detectar `.mcp.json`, y verificar con `/mcp` que `dab-sqlserver` aparece como conectado. Las mejoras de la sección 4 (sobre todo 4.1 Seguridad y 4.2 Metadata `fields:[]`) deberían atacarse antes de exponer el MCP a usuarios distintos al equipo.

---

## 1. Conexión

- ✅ Handshake OK: el MCP responde y expone las herramientas `describe_entities`, `read_records`, `create_record`, `update_record`, `delete_record`.
- Cadena de conexión: `dab/dab-config.json:5` → `@env('SQL_CONN')`. La base es **SQL Server**, no MongoDB.

## 2. Entidades expuestas

- Solo **1 entidad**: `NotificacionesConsolidadas` → tabla `Avisos.notificacionesConsolidadas` (`dab/dab-config.json:42-46`).
- Permisos concedidos a `anonymous` **y** `authenticated` para `create/read/update/delete` (`dab/dab-config.json:47-56`).

## 3. Hallazgos

### 3.1 `fields: []` al describir la entidad
Al llamar `describe_entities` con detalle sobre `NotificacionesConsolidadas`, DAB devuelve `fields: []`. No está publicando el esquema de columnas.

Posibles causas:
- Metadata cacheada antes de que la tabla existiera.
- Login de SQL sin permisos para leer `sys.columns` / `INFORMATION_SCHEMA`.
- Desalineación entre el `source.object` de la config y el objeto real en la DB.

Impacto: un cliente MCP no conoce nombres/tipos de campos, por lo que `create_record` y `update_record` son difíciles de invocar correctamente sin adivinar.

### 3.2 Postura de seguridad del runtime DAB (crítico si sale a prod)
- `authentication.provider: "Simulator"` (`dab/dab-config.json:36`) → simula autenticación, no la valida. Uso solo en dev.
- `mode: "development"` (`dab/dab-config.json:38`).
- `allow-introspection: true` en GraphQL (`dab/dab-config.json:18`).
- `cors.origins: []` con `allow-credentials: false` (`dab/dab-config.json:32-33`) → CORS cerrado por defecto, pero no compensa el resto.
- Role `anonymous` con **CRUD completo** sobre la tabla. Cualquiera con acceso de red al endpoint puede leer/crear/actualizar/eliminar notificaciones.

### 3.3 Drift de esquema entre scripts
- `scripts/001_crear_notificacionesConsolidadas.sql:53-54` crea la tabla con `CHECK (estado IN ('A','R','C','E'))`.
- `scripts/002_alter_estado_agregar_p.sql:48` amplía a `('A','P','R','C','E')` porque la UI de Alertas Payroll envía `'P'` (En Proceso).
- El `002` está **untracked** en git y podría no estar aplicado en la DB que consume el MCP. Si no se aplicó, los PATCH con estado `P` fallan por violación del CHECK.

### 3.4 Cobertura funcional limitada
- Hay **60+ SPs** en `SP/` que generan alertas (biométricos, vacaciones, marcajes, horarios, jerarquías, etc.), pero DAB solo expone la tabla consolidada.
- No hay stored procedures ni vistas registrados como entidades → cualquier consulta sobre datos crudos queda fuera del MCP.

### 3.5 Contradicción con `CLAUDE.md`
- `CLAUDE.md` indica "MongoDB como base de datos (no SQL)" pero el stack real es SQL Server + DAB.
- El documento de lineamientos está desactualizado y debería reflejar la realidad.

---

## 4. Mejoras propuestas

### 4.1 Seguridad (prioridad alta)
- [ ] Cambiar `authentication.provider` de `Simulator` a un proveedor real (JWT / EntraID) antes de cualquier despliegue no-dev.
- [ ] Eliminar permisos del role `anonymous` o limitarlos a `read` en entornos compartidos.
- [ ] Pasar `runtime.host.mode` a `production` en despliegues no-dev.
- [ ] Evaluar si `allow-introspection` debe quedar `false` fuera de desarrollo.
- [ ] Definir explícitamente `cors.origins` con los orígenes de la UI de Alertas Payroll.
- [ ] Rotar/validar que `SQL_CONN` usa un login con permisos mínimos (solo sobre schema `Avisos`, sin `db_owner`).

### 4.2 Metadata / DX
- [ ] Investigar por qué `describe_entities` devuelve `fields: []`:
  - Revisar permisos del login sobre `sys.columns` e `INFORMATION_SCHEMA`.
  - Reiniciar el runtime DAB tras crear la tabla para refrescar cache.
  - Confirmar que `Avisos.notificacionesConsolidadas` existe con exactamente ese nombre/schema.
- [ ] Agregar `mappings` explícitos en la config si se quiere renombrar columnas hacia la API.
- [ ] Registrar una versión/tag del script `001` y `002` en `CONTEXTO.md` para rastreo.

### 4.3 Gobernanza de esquema
- [ ] Commitear `scripts/002_alter_estado_agregar_p.sql` (hoy untracked).
- [ ] Verificar en cada ambiente si `002` ya se aplicó: `SELECT definition FROM sys.check_constraints WHERE name = 'CK_notifConsolidadas_estado'`.
- [ ] Adoptar un patrón consistente de numeración y registro de scripts (`scripts/NNN_descripcion.sql`) + bitácora de aplicación por ambiente.
- [ ] Considerar una herramienta de migraciones (DbUp, Flyway, EF Core Migrations) para evitar drift.

### 4.4 Cobertura del MCP
- [ ] Evaluar qué SPs del catálogo `SP/` deberían exponerse como entidades `stored-procedure` en DAB para que el MCP pueda invocarlos.
- [ ] Crear vistas de solo lectura sobre datos operativos (marcajes, vacaciones, jerarquías) y registrarlas como entidades `view` con permisos `read` únicamente.
- [ ] Documentar en `docs/integracion-dab.md` el mapeo SP → categoría de `origen` (ya hay referencia en el comentario del script `001`).

### 4.5 Documentación
- [ ] Actualizar `CLAUDE.md` para reflejar que la DB es SQL Server + DAB (no MongoDB).
- [ ] Añadir en `docs/integracion-dab.md` las convenciones de entidades, roles y permisos.
- [ ] Mantener este documento (`analisis-mcp-dab-sqlserver.md`) como checklist vivo hasta que las mejoras de la sección 4.1 estén cerradas.

---

## 5. Verificaciones sugeridas (solo lectura, sin cambios)

- `read_records` sobre `NotificacionesConsolidadas` con `first: 1` y sin `select` → confirma si DAB devuelve filas pese al `fields:[]`.
- Revisar si el login de `SQL_CONN` tiene `VIEW DEFINITION` sobre el schema `Avisos`.
- Verificar contra `sys.check_constraints` que el script `002` esté aplicado en el ambiente que consume el MCP.

---

## Referencias

- `dab/dab-config.json`
- `scripts/001_crear_notificacionesConsolidadas.sql`
- `scripts/002_alter_estado_agregar_p.sql`
- `SP/` (catálogo de stored procedures fuente de alertas)
- `CLAUDE.md` (requiere actualización)
