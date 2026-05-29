# Usuario SQL dedicado — Alertas Payroll

Especificaciones del login/usuario de SQL Server que el backend BSC (.NET) usará tras el refactor que reemplaza DAB por un controller propio.

> **Estado:** Pendiente de creación manual por el usuario desde su máquina.
> **Script de referencia:** `scripts/003_create_user_payroll_app.sql`

---

## Contexto y decisión

Tras eliminar el contenedor `bsc_dab`, el backend BSC se conectará directamente a SQL Server desde un controller .NET. Para limitar el blast radius si la cadena de conexión se filtra, se usa un login dedicado con permisos acotados a **una sola tabla**.

**Decisión (2026-05-07):** Otorgar `SELECT, INSERT, UPDATE, DELETE` completos sobre la tabla — no se restringe por columna ni se omite DELETE.

**Razones:**
- Flexibilidad para requerimientos futuros (consolidación manual, edición masiva, etc.) sin tocar permisos.
- DELETE necesario porque habrá purga periódica (ver sección "Purga periódica").
- El límite crítico de seguridad es "una sola tabla", y eso se mantiene.

---

## Especificación del login

| Atributo | Valor |
|---|---|
| Nombre de login | `bsc_payroll_app` |
| Tipo | SQL Login (no Windows Auth) |
| Password | A definir al ejecutar — usar contraseña fuerte |
| `CHECK_POLICY` | `ON` |
| `CHECK_EXPIRATION` | `OFF` |
| Default database | `DB_NOMKFC` |

## Especificación del user (DB_NOMKFC)

| Atributo | Valor |
|---|---|
| Nombre de user | `bsc_payroll_app` |
| Mapea al login | `bsc_payroll_app` |
| Schema default | `dbo` (no se cambia) |

## Permisos otorgados

Únicamente sobre `Avisos.notificacionesConsolidadas`:

| Permiso | Justificación |
|---|---|
| `SELECT` | Lectura de alertas para el dashboard y listado |
| `INSERT` | Reservado para casos futuros (consolidación manual, importes) |
| `UPDATE` | Resolución de alertas (estado, notas, usuario, fechaModificacion) |
| `DELETE` | Purga periódica de alertas viejas (ver sección de purga) |
| `VIEW DEFINITION` | Permite a EF Core / Dapper introspeccionar columnas |

**Permisos NO otorgados (intencionalmente):**
- Acceso a cualquier otra tabla, vista o SP del schema `Avisos` o de la BD.
- `EXECUTE` sobre el SP de purga (la purga la dispara un Job o un admin, no el backend).
- Permisos a nivel servidor (`sysadmin`, `dbcreator`, etc.).

---

## Artefactos adicionales creados por el script 003

### Tabla de archivo histórico

`Avisos.notificacionesConsolidadasArchivo` — recibe filas antes de purgarlas.

- Mismo schema que `notificacionesConsolidadas` + columnas:
  - `idArchivo` (BIGINT IDENTITY, PK)
  - `fechaArchivado` (DATETIME, default GETDATE())
  - `idNotificacion` (BIGINT, conserva el ID original para trazabilidad)
- Índices: `idNotificacion`, `fechaCreacion DESC`
- **No otorgar permisos al usuario `bsc_payroll_app` sobre esta tabla** — solo lo escribe el SP.

### SP de purga

`Avisos.sp_purgar_notificacionesConsolidadas`

| Parámetro | Tipo | Default |
|---|---|---|
| `@MesesAntiguedad` | INT | 6 |

**Comportamiento:**
1. Calcula corte: `DATEADD(MONTH, -@MesesAntiguedad, GETDATE())`
2. `INSERT INTO ...Archivo SELECT ... WHERE fechaCreacion < @Corte AND estado IN ('R','C')`
3. `DELETE FROM ...Consolidadas WHERE fechaCreacion < @Corte AND estado IN ('R','C')`
4. Todo dentro de un `BEGIN TRANSACTION ... COMMIT`. Si falla el INSERT, no borra nada.
5. `PRINT` con cantidades archivadas/eliminadas.

**Filtro estricto:** nunca toca alertas en estado `A` (Activa), `P` (En Proceso) o `E` (Error envío).

**Ejecución manual:**
```sql
EXEC Avisos.sp_purgar_notificacionesConsolidadas @MesesAntiguedad = 6;
```

---

## Pasos de ejecución

1. Abrir SQL Server Management Studio (o tu cliente preferido) conectado a la instancia con un login admin.
2. Abrir `scripts/003_create_user_payroll_app.sql`.
3. Reemplazar `<STRONG_PASSWORD_HERE>` por una contraseña fuerte (≥16 chars, mixto).
4. Ejecutar el script completo.
5. Verificar que las salidas `PRINT` indiquen creación exitosa de:
   - Login `bsc_payroll_app`
   - User `bsc_payroll_app` en `DB_NOMKFC`
   - Permisos sobre `Avisos.notificacionesConsolidadas`
   - Tabla `Avisos.notificacionesConsolidadasArchivo`
   - SP `Avisos.sp_purgar_notificacionesConsolidadas`
6. Guardar la contraseña en un gestor seguro.
7. **No commitear la contraseña** ni el script con la contraseña real.

---

## Verificación post-creación

```sql
-- ¿El login existe?
SELECT name, type_desc, is_disabled
  FROM sys.sql_logins
 WHERE name = 'bsc_payroll_app';

-- ¿El user existe en DB_NOMKFC?
USE DB_NOMKFC;
SELECT name, type_desc, default_schema_name
  FROM sys.database_principals
 WHERE name = 'bsc_payroll_app';

-- ¿Qué permisos tiene? (debe listar SELECT/INSERT/UPDATE/DELETE/VIEW DEFINITION sobre la tabla)
SELECT
    pr.name AS principal,
    perm.permission_name,
    perm.state_desc,
    OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id) AS objeto
  FROM sys.database_permissions perm
  JOIN sys.database_principals pr ON pr.principal_id = perm.grantee_principal_id
 WHERE pr.name = 'bsc_payroll_app';

-- Probar conexión con el nuevo user (debería retornar filas)
-- (ejecutar conectándose como bsc_payroll_app)
SELECT TOP 5 idNotificacion, estado, asunto FROM Avisos.notificacionesConsolidadas;

-- Debería FALLAR (no tiene acceso a otras tablas)
SELECT TOP 1 * FROM Avisos.<otra_tabla_cualquiera>;
```

---

## Connection string para el backend

Agregar al `.env` del entorno correspondiente (`local`, `staging`, `prod`):

```
SQL_CONN_PAYROLL=Server=<host-sql>;Database=DB_NOMKFC;User Id=bsc_payroll_app;Password=<password>;TrustServerCertificate=True;Encrypt=True;
```

> Sugerencia de naming: usar `SQL_CONN_PAYROLL` para distinguirla de cualquier otra conexión SQL del proyecto. Confirmar el nombre final cuando se haga el refactor del backend.

---

## Tareas pendientes asociadas

- [ ] Reemplazar password placeholder y ejecutar `scripts/003_create_user_payroll_app.sql`
- [ ] Guardar password en gestor seguro
- [ ] Agregar `SQL_CONN_PAYROLL` al `.env` (local + prod)
- [ ] Programar SQL Agent Job mensual que ejecute el SP de purga
- [ ] Refactor: implementar `PayrollAlertasController` + repositorio en .NET
- [ ] Borrar contenedor `bsc_dab` y limpiar `dab/` del repo
- [ ] Eliminar ruta nginx `/dab/` del `config/nginx/default.conf`
- [ ] Actualizar `docs/integracion-dab.md` (marcar como obsoleto) y `docs/deploy-alertas-payroll.md` (reflejar el nuevo flujo sin DAB)
- [ ] Entrada en `docs/bitacora.md` con la decisión y fecha de ejecución
