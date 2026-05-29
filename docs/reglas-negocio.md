# Reglas de negocio

Flujos funcionales, actores y decisiones de producto que no son evidentes del código. Los esquemas viven en [modelo-datos.md](modelo-datos.md).

## Actores (roles)

Los roles conocidos son datos en la colección `Roles` (no enum en código). Los tres valores canónicos que aparecen en la lógica de tareas:

- **Gerente** — crea tareas, sube insumos, asigna a Líder, valida entregables.
- **Líder** — reasigna/asigna tareas a Colaboradores, supervisa ejecución.
- **Colaborador** — ejecuta la tarea y sube evidencia.

Un mismo usuario puede tener **varios roles** (`Colaborador.rolIds` es array). El header del frontend permite cambiar de rol activo (`switchRole` en `SessionContext`) — al cambiar, la app recarga para re-renderizar con permisos del nuevo rol.

---

## Módulo: Tareas

### Ciclo de estados

Constantes en `BSC.Domain.Constants.TaskStatuses`:

```
Creada ──► Asignada ──► Completa - Por Validar ──► Completa - Validada ──► Completa
              │                    │
              └─► Reasignada       └─► (reabierta) Asignada
              
Cualquier estado ──► Cancelada
```

- **Creada**: la tarea existe pero no tiene colaborador asignado. El Gerente la creó.
- **Asignada**: el Líder (o Gerente) la asignó a un Colaborador.
- **Reasignada**: se movió de un Colaborador a otro. El `statusHistory` guarda el rastro.
- **Completa - Por Validar**: el Colaborador subió evidencia; queda esperando revisión.
- **Completa - Validada** / **Completa**: el Gerente validó la evidencia.
- **Cancelada**: terminal desde cualquier estado.

El `statusHistory` es **append-only** (nunca se edita ni elimina una entrada). Cada `StatusChange` registra `from`, `to`, `userId`, `userName`, `timestamp`, `notes`.

### Responsabilidades por artefacto

| Artefacto | Quién lo produce | Cuándo |
|---|---|---|
| `insumos` (texto) + `insumoFiles` | Gerente | Al crear la tarea |
| `assignedLeaderId` | Gerente | Al crear/asignar |
| `assignedToId` | Líder (o Gerente) | Al pasar a `Asignada` |
| `evidenceText` + `evidenceFiles` | Colaborador | Al pasar a `Completa - Por Validar` |
| `rating` (0–100) | Sistema (automático) | Al validar |
| `observations` | Cualquier rol con acceso | Libre |

### Archivos (insumos y evidencias)

- Se guardan en `./files/` del host, servidos por `bsc_fileserver` en `:8082` y montados también en el backend como `/app/files`.
- `nginx` del frontend proxea `/files/` hacia el fileserver (consultar `config/nginx/default.conf` si se cambia el routing).
- `FileAttachment` (value object embebido en `TaskItem`) guarda los metadatos; el binario vive en disco.

### Dashboard BSC adicional

Algunos colaboradores (configurados en `BscDashboardConfigs`) tienen un dashboard **BSC** extra además del dashboard general:

- `emails`: lista blanca de correos que ven el dashboard BSC.
- `taskTitlePattern`: regex/patrón para identificar qué tareas cuentan como "BSC" (se filtran del conjunto total).
- `isActive`: switch global.

Es configuración runtime, no hay que tocar código para agregar/quitar usuarios.

---

## Módulo: Alertas Payroll

Alertas consolidadas del sistema de nómina. Los SPs del schema `Avisos` en SQL Server insertan filas en `Avisos.notificacionesConsolidadas`; la UI las muestra y permite resolverlas.

### Estados (`estado`)

| Código | Label UI | Significado |
|---|---|---|
| `A` | Activa | Recién generada, no atendida |
| `P` | En Proceso | Alguien la está resolviendo |
| `R` | Resuelta | Resuelta y cerrada |
| `C` | Cerrada | Cerrada por el sistema (típicamente "Sin novedad" auto-cerrado por `NotificacionesConsolidadas.Insertar`) o manualmente |
| `E` | Error | Falló el envío del correo al destinatario |

### Flujo de resolución (UI)

1. El usuario hace click en 👁 (ver y resolver) sobre una fila — abre el modal unificado `AlertaModal`.
2. Panel derecho del modal con:
   - Meta de la alerta (estado actual, prioridad, categoría) en solo lectura.
   - Select **Cambiar estado**: `P` (En Proceso), `R` (Resuelto) o `E` (Error). No se puede volver a `A`. Default = estado actual si es uno de esos tres; si no, `P`.
   - Textarea **Notas de resolución** (`notasResolucion`) con **límite de 500 caracteres** (la columna SQL es `varchar(500)`). El frontend aplica `maxLength=500` y un `slice(0, 500)` defensivo en el `onChange` por si pegan texto largo. Contador visible debajo del campo (gris → amarillo ≥450 → rojo al llegar al tope).
   - Input **Usuario resolución**: autocompletado del usuario de la sesión, **solo lectura**.
3. Confirmación SweetAlert → PATCH a DAB con `{ estado, notasResolucion, usuarioResolucion, fechaModificacion }`.

`fechaModificacion` se calcula en el frontend como ISO local (`nowLocalIso`), no UTC — es la convención actual porque la tabla usa `DATETIME` (sin timezone).

### Prioridad y categoría

Campos **opcionales** en la tabla. Pueden venir como `null` — la UI muestra "Sin asignar" para prioridad y `—` para categoría. Los valores de `prioridad` conocidos: `critica`, `alta`, `media`, `baja` (strings en minúsculas).

### Origen y Categoría

Cada alerta tiene un `origen` que **agrupa por dominio de negocio** (Biométricos, Vacaciones, etc.). El mapeo de SPs a origen está en `scripts/001_crear_notificacionesConsolidadas.sql` (sección 4, comentario). Hoy se usa solo en el XLSX de descarga; **el gráfico anterior "Alertas por Origen" fue reemplazado por "Alertas por Categoría"** (commit `088aea6`), que agrupa por `categoria` y permite filtrar por descripción con chips multi-select.

### Descripciones reconocidas

Hay 4 valores canónicos de `descripcion` que el sistema reconoce y clasifica para gráficos, filtros y filas críticas:

| `descripcion` (raw) | Clave interna | Significado operativo |
|---|---|---|
| `Con Novedad` | `con_novedad` | Requiere atención y resolución manual |
| `Sin Novedad` | `sin_novedad` | El proceso pasó OK, queda como informativa |
| `Reportería` / `Reporteria` | `reporteria` | Generada por SPs de reporte |
| `Error Proceso` | `error_proceso` | El SP/proceso interno falló |

El matching es case-insensitive y trim. Cualquier otro valor se trata como **"sin clasificar"** y aparece en el contador "Z sin clasificar" del dashboard, pero no entra a las gráficas por descripción ni dispara la regla de filas críticas.

### Filas críticas (resaltado rojo en la tabla "Alertas")

Una fila se resalta con fondo rojo + barra lateral cuando cumple **las tres** condiciones a la vez:

- `prioridad === Alta` (case-insensitive).
- `estado ∈ {A, P, E}` — Activa, En Proceso o Error.
- `descripcion` clasifica como `con_novedad` o `error_proceso`.

Razón: estas son alertas **pendientes de acción del usuario** que además son urgentes (Alta) y representan novedades reales o errores de proceso. "Reportería" y "Sin Novedad" no califican porque son informativas.

### Pendientes por resolver (donut del listado)

Métrica visual: alertas con `estado ∈ {A, P, E}` agrupadas por descripción, **excluyendo `Sin Novedad`**. "Sin novedad" no representa trabajo pendiente por definición, así que se descarta del indicador para no diluirlo. Las otras tres descripciones sí aparecen como segmentos del donut.

### Destinatarios

`destinatarios` es un string con correos separados por `|`, `;` o `,`. Se normalizan (trim + lowercase) en la UI con `parseDestinatarios()`. `destinatariosCc` sigue la misma convención.

---

## Autenticación y sesión

- Login con email + password → JWT (`JwtSettings__*` en backend).
- Tras login exitoso, el backend devuelve los roles del colaborador; el primero queda activo.
- El JWT contiene el `userId` + `role` activo. Se envía en cada request via `Authorization: Bearer`.
- `lastLoginAt` se actualiza en el `Colaborador` al login exitoso; se muestra en el header como "Última conexión".
- Logout: limpia el token del lado cliente (sessionStorage). No hay revocación de tokens del lado servidor (limitación conocida).

## Soft delete

Todas las entidades de MongoDB usan soft delete (`isDeleted`, `deletedAt`). Los repositorios filtran `isDeleted: false` por defecto; las operaciones de "borrar" hacen un `UpdateOne` seteando los campos, nunca `DeleteOne`.

La tabla SQL `notificacionesConsolidadas` **no** tiene soft delete — las alertas se cierran cambiando `estado`, no se borran.
