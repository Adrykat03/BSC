-- ============================================================
-- Script: 003 - Crear usuario dedicado para módulo Alertas Payroll
--               + tabla de archivo + SP de purga periódica
--
-- Propósito: Tras el refactor que reemplaza DAB por un controller
--            propio en .NET, el backend BSC se conecta a SQL Server
--            con un login dedicado de mínimo privilegio acotado a
--            UNA sola tabla: Avisos.notificacionesConsolidadas.
--
--            Permisos otorgados (solo sobre esa tabla):
--              SELECT, INSERT, UPDATE, DELETE
--
--            Adicionalmente se crea:
--              - Avisos.notificacionesConsolidadasArchivo  (histórico)
--              - Avisos.sp_purgar_notificacionesConsolidadas (job periódico)
--
-- Fecha:    2026-05-07
-- Base:     DB_NOMKFC
-- Schema:   Avisos
-- ============================================================

-- ============================================================
-- IMPORTANTE: reemplazar <STRONG_PASSWORD_HERE> antes de ejecutar
--             y guardar la credencial en el .env del backend BSC
--             como SQL_CONN_PAYROLL (o el nombre que se decida).
-- ============================================================

USE master;
GO

-- ============================================================
-- 1. LOGIN a nivel servidor
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'bsc_payroll_app')
BEGIN
    CREATE LOGIN bsc_payroll_app
        WITH PASSWORD = '<STRONG_PASSWORD_HERE>',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF,
             DEFAULT_DATABASE = DB_NOMKFC;
    PRINT 'Login bsc_payroll_app creado.';
END
ELSE
BEGIN
    PRINT 'Login bsc_payroll_app ya existe, no se realizaron cambios.';
END
GO

USE DB_NOMKFC;
GO

-- ============================================================
-- 2. USER a nivel base de datos
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'bsc_payroll_app')
BEGIN
    CREATE USER bsc_payroll_app FOR LOGIN bsc_payroll_app;
    PRINT 'User bsc_payroll_app creado en DB_NOMKFC.';
END
ELSE
BEGIN
    PRINT 'User bsc_payroll_app ya existe en DB_NOMKFC.';
END
GO

-- ============================================================
-- 3. GRANTS — únicamente sobre Avisos.notificacionesConsolidadas
--    No se otorga acceso a ninguna otra tabla, vista o SP.
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE
    ON Avisos.notificacionesConsolidadas
    TO bsc_payroll_app;
PRINT 'Permisos SELECT/INSERT/UPDATE/DELETE otorgados sobre Avisos.notificacionesConsolidadas.';
GO

-- VIEW DEFINITION permite a EF Core / Dapper introspeccionar columnas.
GRANT VIEW DEFINITION
    ON Avisos.notificacionesConsolidadas
    TO bsc_payroll_app;
PRINT 'Permiso VIEW DEFINITION otorgado.';
GO

-- ============================================================
-- 4. Tabla de archivo histórico
--    Recibe filas antes de ser purgadas, conservando el
--    idNotificacion original para trazabilidad.
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'Avisos' AND t.name = 'notificacionesConsolidadasArchivo'
)
BEGIN
    CREATE TABLE Avisos.notificacionesConsolidadasArchivo (
        idArchivo           BIGINT IDENTITY(1,1) PRIMARY KEY,
        idNotificacion      BIGINT NOT NULL,
        fechaArchivado      DATETIME NOT NULL DEFAULT GETDATE(),

        fechaCreacion       DATETIME NOT NULL,
        fechaEnvio          DATETIME NULL,
        fechaResolucion     DATETIME NULL,
        estado              CHAR(1) NOT NULL,
        origen              VARCHAR(100) NOT NULL,
        spOrigen            VARCHAR(128) NOT NULL,
        asunto              VARCHAR(300) NOT NULL,
        descripcion         VARCHAR(500) NULL,
        descripcionHtml     VARCHAR(MAX) NULL,
        cantidadRegistros   INT NULL,
        destinatarios       VARCHAR(MAX) NOT NULL,
        destinatariosCc     VARCHAR(MAX) NULL,
        periodoInicio       DATE NULL,
        periodoFin          DATE NULL,
        fechaModificacion   DATETIME NULL,
        usuarioResolucion   VARCHAR(100) NULL,
        notasResolucion     VARCHAR(500) NULL
    );
    PRINT 'Tabla Avisos.notificacionesConsolidadasArchivo creada.';
END
ELSE
BEGIN
    PRINT 'Tabla Avisos.notificacionesConsolidadasArchivo ya existe.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifConsolidadasArchivo_idNotificacion')
    CREATE INDEX IX_notifConsolidadasArchivo_idNotificacion
    ON Avisos.notificacionesConsolidadasArchivo (idNotificacion);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifConsolidadasArchivo_fechaCreacion')
    CREATE INDEX IX_notifConsolidadasArchivo_fechaCreacion
    ON Avisos.notificacionesConsolidadasArchivo (fechaCreacion DESC);
GO

-- ============================================================
-- 5. SP de purga periódica
--    - Mueve a archivo + elimina filas resueltas/cerradas
--      con más de @MesesAntiguedad meses.
--    - Nunca toca alertas en estado A (Activa), P (En Proceso)
--      o E (Error envío).
--    - Transaccional: si el INSERT falla, no borra nada.
-- ============================================================
IF OBJECT_ID('Avisos.sp_purgar_notificacionesConsolidadas', 'P') IS NOT NULL
    DROP PROCEDURE Avisos.sp_purgar_notificacionesConsolidadas;
GO

CREATE PROCEDURE Avisos.sp_purgar_notificacionesConsolidadas
    @MesesAntiguedad INT = 6
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Corte DATETIME = DATEADD(MONTH, -@MesesAntiguedad, GETDATE());
    DECLARE @Archivadas INT = 0;
    DECLARE @Eliminadas INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Archivar
        INSERT INTO Avisos.notificacionesConsolidadasArchivo (
            idNotificacion, fechaCreacion, fechaEnvio, fechaResolucion,
            estado, origen, spOrigen, asunto, descripcion, descripcionHtml,
            cantidadRegistros, destinatarios, destinatariosCc,
            periodoInicio, periodoFin, fechaModificacion,
            usuarioResolucion, notasResolucion
        )
        SELECT
            idNotificacion, fechaCreacion, fechaEnvio, fechaResolucion,
            estado, origen, spOrigen, asunto, descripcion, descripcionHtml,
            cantidadRegistros, destinatarios, destinatariosCc,
            periodoInicio, periodoFin, fechaModificacion,
            usuarioResolucion, notasResolucion
        FROM Avisos.notificacionesConsolidadas
        WHERE fechaCreacion < @Corte
          AND estado IN ('R', 'C');

        SET @Archivadas = @@ROWCOUNT;

        -- Eliminar
        DELETE FROM Avisos.notificacionesConsolidadas
        WHERE fechaCreacion < @Corte
          AND estado IN ('R', 'C');

        SET @Eliminadas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT CONCAT('Purga OK. Archivadas: ', @Archivadas, ' | Eliminadas: ', @Eliminadas, ' | Corte: ', CONVERT(VARCHAR, @Corte, 120));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @Err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en purga: %s', 16, 1, @Err);
    END CATCH
END
GO

PRINT 'SP Avisos.sp_purgar_notificacionesConsolidadas creado.';
GO

-- ============================================================
-- NOTA: el SP no requiere otorgar EXECUTE a bsc_payroll_app si
-- la purga la dispara un SQL Agent Job o un usuario administrador.
-- Si en el futuro el backend BSC quiere llamarlo, ejecutar:
--
--   GRANT EXECUTE ON Avisos.sp_purgar_notificacionesConsolidadas
--     TO bsc_payroll_app;
-- ============================================================

PRINT 'Script 003 ejecutado completamente.';
GO
