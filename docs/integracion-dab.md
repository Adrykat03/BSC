# Integración con Data API Builder (DAB)

Uso, configuración y operación de **Data API Builder** como capa REST/GraphQL sobre **SQL Server**. Aquí viven datos que no están en MongoDB — hoy, las alertas consolidadas del sistema de nómina.

## Por qué existe

El core del BackOffice usa MongoDB, pero los SPs legacy de nómina (en SQL Server) alimentan una tabla consolidada de alertas (`Avisos.notificacionesConsolidadas`). En vez de duplicar esa información en MongoDB, se expone tal cual con DAB — se obtiene REST + GraphQL + MCP gratis, sin escribir un backend propio para esos datos.

## Componentes

- **Contenedor:** `bsc_dab`, imagen `mcr.microsoft.com/azure-databases/data-api-builder:latest`.
- **Puerto:** interno `5000`, host `5555`.
- **Configuración:** `dab/dab-config.json` (único archivo).
- **Proxy:** nginx expone `/dab/` → `http://bsc_dab:5000/api/` (ver `config/nginx/default.conf`).
- **Frontend:** `frontend/src/services/payrollService.js` consume `/dab/NotificacionesConsolidadas`.

> `bsc_dab` se opera **por fuera del `docker-compose.yml`** de forma intencional. Se levanta y mantiene manualmente — la integración al compose principal está descartada por ahora.

## Configuración (`dab/dab-config.json`)

### Data source
- `database-type`: `mssql`.
- `connection-string`: `@env('SQL_CONN')` — viene del `.env` del host.
- `set-session-context`: `false`.

### Runtime
- **REST** habilitado en path `/api` → por el proxy queda accesible como `/dab/...`.
- **GraphQL** habilitado en `/graphql`, con `allow-introspection: true`.
- **MCP** (Model Context Protocol) habilitado con todas las `dml-tools`: describe-entities, read-records, create-record, update-record, delete-record. Esto permite que Claude (u otro agente MCP) consulte/modifique datos directamente.
- **Auth provider:** `Simulator` (desarrollo). Roles permitidos: `anonymous` y `authenticated` con CRUD completo.
- **CORS:** `origins: []`, `allow-credentials: false` — se accede solo vía el proxy de nginx, no directo desde el navegador.

### Entities declaradas

| Entity | Source SQL | Permisos |
|---|---|---|
| `NotificacionesConsolidadas` | `Avisos.notificacionesConsolidadas` (table) | anonymous/authenticated: create, read, update, delete |

Agregar un entity nuevo = editar `dab-config.json` y reiniciar `bsc_dab`. No requiere despliegue de código.

## Convenciones REST (OData-like)

DAB expone los entities con query parameters estilo OData:

| Query | Qué hace |
|---|---|
| `$select=col1,col2` | Proyecta columnas |
| `$filter=estado eq 'A'` | Filtra (operadores: `eq`, `ne`, `gt`, `lt`, `ge`, `le`, `and`, `or`) |
| `$orderby=fechaCreacion desc` | Ordena |
| `$first=100` | Limita resultados (equivalente a `TOP`) |
| `$after=<cursor>` | Paginación por cursor |

Respuesta envuelta en `{ "value": [...] }`.

### Ejemplos en uso
`frontend/src/services/payrollService.js`:

```js
// Lista — los 100 más recientes por fecha de creación
GET /dab/NotificacionesConsolidadas?$orderby=fechaCreacion desc&$first=100

// Actualizar resolución — PATCH por PK
PATCH /dab/NotificacionesConsolidadas/idNotificacion/123
Body: { estado, notasResolucion, usuarioResolucion, fechaModificacion }
```

La sintaxis `PATCH /entity/<pk-column>/<pk-value>` es específica de DAB.

## Cómo agregar un nuevo entity

1. Editar `dab/dab-config.json`, bloque `entities`:
   ```json
   "MiEntidad": {
     "source": { "object": "MiEsquema.mi_tabla", "type": "table" },
     "permissions": [
       { "role": "anonymous", "actions": ["read"] }
     ]
   }
   ```
2. `docker restart bsc_dab` para que recargue la config.
3. Verificar: `curl http://localhost:5555/api/MiEntidad?$first=1` (o `GET /dab/MiEntidad` vía proxy).

## Seguridad — notas importantes

El estado actual está **adecuado para desarrollo**, no para producción:

- `authentication.provider: Simulator` deja pasar cualquier request como autenticada.
- Permisos `anonymous: create/read/update/delete` — cualquiera con acceso a la red puede escribir.
- Mitigación parcial: DAB sólo es accesible vía `/dab/` tras el reverse proxy de nginx. Nginx a su vez está expuesto al host. **No hay autenticación a nivel de DAB hoy**; si se expone la app a producción, hay que:
  - Cambiar el provider a `AzureAD` / `StaticWebApps` / JWT custom.
  - Restringir acciones por rol.
  - Deshabilitar `allow-introspection` en GraphQL.
  - Quitar o restringir `dml-tools` de MCP.

## Operación

| Tarea | Cómo |
|---|---|
| Reiniciar DAB tras editar config | `docker restart bsc_dab` |
| Ver logs | `docker logs -f bsc_dab` |
| Probar conexión a SQL | `docker exec bsc_dab dab validate` (valida el config + conecta a la DB) |
| Probar GraphQL | `GET http://localhost:5555/graphql` (Banana Cake Pop UI) |
| Acceso directo (sin proxy) | `http://localhost:5555/api/NotificacionesConsolidadas` |

## Ver también
- [arquitectura.md](arquitectura.md) — stack general.
- [modelo-datos.md](modelo-datos.md) — esquema de `Avisos.notificacionesConsolidadas`.
- [alertas-payroll.md](alertas-payroll.md) — frontend que consume este entity.
