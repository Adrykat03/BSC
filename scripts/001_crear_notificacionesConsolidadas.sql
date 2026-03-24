-- ============================================================
-- Script: Crear tabla Avisos.notificacionesConsolidadas
-- Propósito: Consolidar las alertas generadas por los SPs
--            del schema Avisos para visualización en Dashboard
-- Base de datos: DB_NOMKFC
-- Schema: Avisos
-- ============================================================

-- ============================================================
-- 1. Tabla principal: notificacionesConsolidadas
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'Avisos' AND t.name = 'notificacionesConsolidadas'
)
BEGIN
    CREATE TABLE Avisos.notificacionesConsolidadas (
        idNotificacion      BIGINT IDENTITY(1,1) PRIMARY KEY,

        -- FECHA
        fechaCreacion       DATETIME NOT NULL DEFAULT GETDATE(),
        fechaEnvio          DATETIME NULL,
        fechaResolucion     DATETIME NULL,

        -- ESTADO: A=Activa, R=Resuelta, C=Caducada, E=Error al enviar
        estado              CHAR(1) NOT NULL DEFAULT 'A',

        -- ORIGEN (categoría dinámica derivada del SP que genera la alerta)
        origen              VARCHAR(100) NOT NULL,
        spOrigen            VARCHAR(128) NOT NULL,

        -- DESCRIPCIÓN
        asunto              VARCHAR(300) NOT NULL,
        descripcion         VARCHAR(500) NULL,
        descripcionHtml     VARCHAR(MAX) NULL,
        cantidadRegistros   INT NULL,

        -- USUARIO ASIGNADO (destinatario(s) del email)
        destinatarios       VARCHAR(MAX) NOT NULL,
        destinatariosCc     VARCHAR(MAX) NULL,

        -- CONTEXTO
        periodoInicio       DATE NULL,
        periodoFin          DATE NULL,

        -- RESOLUCIÓN
        fechaModificacion   DATETIME NULL,
        usuarioResolucion   VARCHAR(100) NULL,
        notasResolucion     VARCHAR(500) NULL,

        -- CONSTRAINTS
        CONSTRAINT CK_notifConsolidadas_estado
            CHECK (estado IN ('A','R','C','E'))
    );

    PRINT 'Tabla Avisos.notificacionesConsolidadas creada exitosamente.';
END
ELSE
BEGIN
    PRINT 'La tabla Avisos.notificacionesConsolidadas ya existe, no se realizaron cambios.';
END
GO

-- ============================================================
-- 2. Índices para consultas del Dashboard
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifConsolidadas_estado')
    CREATE INDEX IX_notifConsolidadas_estado
    ON Avisos.notificacionesConsolidadas (estado)
    INCLUDE (fechaCreacion, origen, asunto, destinatarios);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifConsolidadas_fechaCreacion')
    CREATE INDEX IX_notifConsolidadas_fechaCreacion
    ON Avisos.notificacionesConsolidadas (fechaCreacion DESC)
    INCLUDE (estado, origen);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifConsolidadas_origen')
    CREATE INDEX IX_notifConsolidadas_origen
    ON Avisos.notificacionesConsolidadas (origen)
    INCLUDE (estado, fechaCreacion);
GO

-- ============================================================
-- 3. Defaults de estado por defecto
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.default_constraints
    WHERE name = 'DF_notifConsolidadas_estado'
)
BEGIN
    ALTER TABLE Avisos.notificacionesConsolidadas
    ADD CONSTRAINT DF_notifConsolidadas_estado DEFAULT 'A' FOR estado;
END
GO

-- ============================================================
-- 4. Mapeo de SPs a categorías de origen
--    (referencia para poblar el campo 'origen')
-- ============================================================
/*
    SP                                          → origen
    ─────────────────────────────────────────────────────────────
    pa_biometricos_inactivos                    → Biométricos
    pa_avisos_biometricosDiel                   → Biométricos
    pa_notificacionBiometrico                   → Biométricos
    pa_enrolado_mas_un_cco                      → Biométricos
    pa_enrolado_no_consta                       → Biométricos
    pa_errorVacacionesGeneral                   → Vacaciones
    pa_errorVacacionesGeneralDennis             → Vacaciones
    pa_erroresVacacionesSinDetalle              → Vacaciones
    pa_erroresSolVacvsSolVacPre                 → Vacaciones
    pa_vacaciones_pasantes                      → Vacaciones
    pa_vacacionesPtosE3                         → Vacaciones
    pa_errorVacacionMarcaje                     → Vacaciones
    pa_validarMarcajes_correo                   → Marcajes
    pa_existemarcaje                            → Marcajes
    pa_fnjMarcaje                               → Marcajes
    pa_avisos_problemas_marcajes_horarios       → Marcajes
    pa_errorAusenciaMarcaje                     → Marcajes
    pa_calculosHorarios                         → Horarios
    pa_JornadaMalCreada                         → Horarios
    pa_trabajadoresHorariosCostoHorario         → Horarios
    pa_errorAusencia                            → Ausencias
    pa_alertaPermisoEnfermedadConMarcajes       → Ausencias
    pa_enfermedadconsecutiva                    → Ausencias
    pa_permisosconsecutivos                     → Ausencias
    pa_Errores_Bajas                            → Bajas
    pa_cambiosFechasBajas                       → Bajas
    pa_Cambio_Cargo                             → Cambios
    pa_Cambio_cco                               → Cambios
    pa_Cambio_RelacionLaboral                   → Cambios
    pa_cambiosEmpresasAP                        → Cambios
    pa_avisos_cargasFamiliares                  → Cargas Familiares
    pa_cargafamiliarimpuestoalarenta            → Cargas Familiares
    pa_cargasFamiliaresEstadoCivilConyugue      → Cargas Familiares
    pa_Transferencias                           → Transferencias
    pa_transferencias_vencidas                  → Transferencias
    pa_avisos_jerarquias2                       → Jerarquías
    pa_validarJerarquiasCarNoPlanta             → Jerarquías
    pa_validarJerarquiasCarPlanta               → Jerarquías
    pa_validarJerarquiasLocales                 → Jerarquías
    pa_cargosgtesjefoprTiendasMal               → Jerarquías
    pa_mismojefe1y2                             → Jerarquías
    pa_TrabajadoresValidacion                   → Trabajadores
    pa_trabajadoresCreados                      → Trabajadores
    pa_colaboradores_reingresos                 → Trabajadores
    pa_colaboradores_expatriados                → Trabajadores
    pa_PersonalActualizadoNA                    → Trabajadores
    pa_usuarios_sin_datos                       → Trabajadores
    pa_usuarios_sin_datosBiometricos            → Trabajadores
    pa_diferencias_usuarios_documentId          → Trabajadores
    pa_cuentas_duplicadas                       → Cuentas Bancarias
    pa_creditosPrtvsSinCupon                    → Créditos Tienda
    pa_faltantecaja                             → Créditos Tienda
    pa_aniversario                              → Aniversarios
    pa_usuarioIngresoCumplea                    → Aniversarios
    pa_correo_avisos_varios                     → General
    pa_ConsultaAvisosTiendasCCO                 → Avisos Tiendas
    pa_llenarAvisosTiendas                      → Avisos Tiendas
    ccoSinPersonal                              → Estructura
    pa_diferencias_he_a_hea                     → Horas Extra
    pa_trabMenos2Benf                           → Beneficios
    pa_trabVarEmpCorreosDif                     → Trabajadores
    pa_trabajadoresVariasEmpresasDifCargo       → Trabajadores
    pa_trabVariasEmpresasJerDif                 → Trabajadores
    pa_fechas_calendario                        → Calendario
    pa_enviarDatosCCO                           → Estructura
*/

PRINT 'Script ejecutado completamente.';
GO
