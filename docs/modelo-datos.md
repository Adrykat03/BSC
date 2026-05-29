# Modelo de datos

El sistema tiene **dos motores de persistencia**:

- **MongoDB** (principal) — datos del BackOffice: colaboradores, roles, tareas, configuración de dashboards.
- **SQL Server** (a través de DAB) — datos legacy del sistema de nómina: alertas consolidadas.

## MongoDB

Contenedor `bsc_mongo`. Base de datos: `${MONGO_DATABASE}` del `.env`.

Convención (`lineamientos/02-backend-netcore.md`):
- Colecciones en **PascalCase plural** (`Colaboradores`, `Roles`, `Tasks`).
- Campos en **camelCase** en la base, **PascalCase** en C# (mapeo explícito vía `[BsonElement(...)]`).
- IDs de tipo `ObjectId` serializados como `string` en las entidades (`StringSerializer(BsonType.ObjectId)` o `BsonRepresentation(BsonType.ObjectId)`).
- **Soft delete** por convención (`isDeleted` + `deletedAt`), nunca borrado físico.
- Campos de auditoría en todas las entidades: `createdAt`, `createdBy`, `updatedAt`, `updatedBy`.

### Colecciones

#### `Colaboradores`
Entidad: `BSC.Domain.Entities.Colaborador` (`backend/src/BSC.Domain/Entities/Colaborador.cs`).

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId (string) | PK |
| `nombreCompleto` | string | |
| `cedula` | string | |
| `area` | string | |
| `correo` | string | Login y destinatario |
| `rolIds` | string[] | FK múltiple a `Roles._id`. Un colaborador puede tener varios roles. |
| `passwordHash` | string | BCrypt (ver `BcryptPasswordHasher`) |
| `createdAt`, `createdBy`, `updatedAt`, `updatedBy` | auditoría | |
| `isDeleted`, `deletedAt` | soft delete | |
| `lastLoginAt` | DateTime? | Último login exitoso |

#### `Roles`
Entidad: `BSC.Domain.Entities.Role`.

| Campo | Tipo |
|---|---|
| `_id` | ObjectId |
| `name` | string |
| `description` | string |
| auditoría + soft delete | iguales a Colaborador |

Roles conocidos en el negocio (valores de `name`): Gerente, Líder, Colaborador (ver [reglas-negocio.md](reglas-negocio.md)).

#### `Tasks`
Entidad: `BSC.Domain.Entities.TaskItem` — la más rica del dominio.

| Campo | Tipo | Notas |
|---|---|---|
| `_id` | ObjectId | |
| `title`, `description` | string | |
| `status` | string | Uno de los valores en `BSC.Domain.Constants.TaskStatuses` |
| `assignedLeaderId/Name/Email` | string? | Líder asignado por el Gerente |
| `assignedToId/Name/Email` | string? | Colaborador asignado por el Líder (o Gerente) |
| `dueDate` | DateTime? | |
| `estimatedTime`, `actualTime` | decimal | En horas (convención) |
| `insumos` | string? | Recursos que sube el Gerente al crear |
| `insumoFiles` | `FileAttachment[]` (embebido) | |
| `evidenceFiles` | `FileAttachment[]` (embebido) | Los sube el Colaborador al completar |
| `evidenceText` | string? | |
| `statusHistory` | `StatusChange[]` (embebido, append-only) | Auditoría de cambios de estado |
| `observations` | string? | |
| `rating` | int? | Calificación automática 0–100 |
| auditoría + soft delete | | |

Value Objects embebidos:
- `FileAttachment` (`backend/src/BSC.Domain/ValueObjects/FileAttachment.cs`) — metadatos de archivo subido (nombre, path, tamaño, mime).
- `StatusChange` (`.../StatusChange.cs`) — snapshot del cambio de estado (de, a, quién, cuándo, notas).

Estados válidos (`TaskStatuses.cs`):
`Creada`, `Asignada`, `Completa - Por Validar`, `Reasignada`, `Completa - Validada`, `Completa`, `Cancelada`.

#### `BscDashboardConfigs`
Entidad: `BscDashboardConfig` — configura qué usuarios (por email) ven un dashboard BSC adicional y qué patrón de título identifica las tareas BSC.

| Campo | Tipo |
|---|---|
| `_id` | ObjectId |
| `emails` | string[] — destinatarios que tienen el dashboard habilitado |
| `taskTitlePattern` | string — patrón para filtrar tareas BSC |
| `isActive` | bool |
| `createdAt`, `updatedAt` | auditoría (sin `createdBy`/`updatedBy` en esta entidad) |

### Mappings de BSON

Solo `Colaborador` tiene mapping explícito en `MongoDbMappings.cs` (para forzar `StringObjectIdGenerator`). El resto usa atributos `[BsonId]` / `[BsonRepresentation]` / `[BsonElement]` directamente en la clase. `[BsonIgnoreExtraElements]` en `TaskItem` y `BscDashboardConfig` evita errores si la colección tiene campos no mapeados.

### Seeds

Scripts en `seeds/` (`seed_100_tareas.js`, `seed_bsc_config.js`, `seed_prueba.js`, `seed_tareas_estadisticas.py`, `seed_usuarios_nomina.js`) — montados en `bsc_mongo:/seeds:ro`. Se ejecutan manualmente (ver `levantar_seed_prueba.md`).

---

## SQL Server (vía DAB)

Acceso: solo lectura/escritura a través de [DAB](integracion-dab.md). El backend .NET **no toca** SQL Server directamente.

### `Avisos.notificacionesConsolidadas`

Tabla consolidada que alimentan los SPs de nómina. Script de creación: `scripts/001_crear_notificacionesConsolidadas.sql`.

| Columna | Tipo | Notas |
|---|---|---|
| `idNotificacion` | BIGINT IDENTITY, PK | |
| `fechaCreacion` | DATETIME NOT NULL DEFAULT GETDATE() | |
| `fechaEnvio` | DATETIME NULL | Cuando se envió el correo al usuario |
| `fechaResolucion` | DATETIME NULL | |
| `estado` | CHAR(1) NOT NULL DEFAULT 'A' | Check constraint: `IN ('A','P','R','C','E')`. Ver [reglas-negocio.md](reglas-negocio.md) para el significado de cada código. |
| `origen` | VARCHAR(100) NOT NULL | Categoría de la alerta (Biométricos, Vacaciones, etc.) |
| `spOrigen` | VARCHAR(128) NOT NULL | Nombre del SP que la generó |
| `asunto` | VARCHAR(300) NOT NULL | |
| `descripcion` | VARCHAR(500) NULL | Resumen en texto plano |
| `descripcionHtml` | VARCHAR(MAX) NULL | HTML completo del correo — es lo que renderiza el modal de previsualización |
| `cantidadRegistros` | INT NULL | |
| `destinatarios` | VARCHAR(MAX) NOT NULL | Separados por `|`, `;` o `,` |
| `destinatariosCc` | VARCHAR(MAX) NULL | |
| `periodoInicio`, `periodoFin` | DATE NULL | Rango contextual de la alerta |
| `fechaModificacion` | DATETIME NULL | Última edición desde la UI |
| `usuarioResolucion` | VARCHAR(100) NULL | Quien resolvió (email) |
| `notasResolucion` | VARCHAR(500) NULL | |

Índices:
- `IX_notifConsolidadas_estado` sobre `(estado)` INCLUDE `(fechaCreacion, origen, asunto, destinatarios)`.
- `IX_notifConsolidadas_fechaCreacion` sobre `(fechaCreacion DESC)` INCLUDE `(estado, origen)`.
- `IX_notifConsolidadas_origen` sobre `(origen)` INCLUDE `(estado, fechaCreacion)`.

Default: `DF_notifConsolidadas_estado` = `'A'`.

### Mapeo de SPs a categoría `origen`

El script `scripts/001_crear_notificacionesConsolidadas.sql` incluye (como comentario, en la sección 4) el mapeo canónico de cada SP del schema `Avisos` al valor de `origen`. Categorías principales: **Biométricos**, **Vacaciones**, **Marcajes**, **Horarios**, **Ausencias**, **Bajas**, **Cambios**, **Cargas Familiares**, **Transferencias**, **Jerarquías**, **Trabajadores**, **Cuentas Bancarias**, **Créditos Tienda**, **Aniversarios**, **General**, **Avisos Tiendas**, **Estructura**, **Horas Extra**, **Beneficios**, **Calendario**.

Los SPs están en `SP/` (un archivo por procedimiento). Los scripts que empiezan con `pa_*` o `cco*` son los productores de alertas.

