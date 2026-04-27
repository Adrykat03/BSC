-- ============================================================
-- Script: 002 - Ampliar estados permitidos en notificacionesConsolidadas
-- Propósito: Agregar el estado 'P' (En Proceso) a la constraint
--            CK_notifConsolidadas_estado.
--
--            La UI de Alertas Payroll permite marcar una alerta como
--            "En Proceso" mientras se resuelve. Sin este cambio, el
--            PATCH contra DAB falla por violación del CHECK constraint.
--
-- Fecha:    2026-04-22
-- Base:     DB_NOMKFC
-- Schema:   Avisos
-- Tabla:    notificacionesConsolidadas
-- ============================================================

-- ============================================================
-- 1. Eliminar la constraint vieja (si existe con cualquier definición)
-- ============================================================
IF EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_notifConsolidadas_estado'
      AND parent_object_id = OBJECT_ID('Avisos.notificacionesConsolidadas')
)
BEGIN
    ALTER TABLE Avisos.notificacionesConsolidadas
    DROP CONSTRAINT CK_notifConsolidadas_estado;
    PRINT 'Constraint CK_notifConsolidadas_estado eliminada.';
END
ELSE
BEGIN
    PRINT 'Constraint CK_notifConsolidadas_estado no existía previamente.';
END
GO

-- ============================================================
-- 2. Recrear la constraint con el set ampliado de estados
--    A = Activa | P = En Proceso | R = Resuelta
--    C = Cerrada/Caducada | E = Error envío
-- ============================================================
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_notifConsolidadas_estado'
      AND parent_object_id = OBJECT_ID('Avisos.notificacionesConsolidadas')
)
BEGIN
    ALTER TABLE Avisos.notificacionesConsolidadas
    ADD CONSTRAINT CK_notifConsolidadas_estado
        CHECK (estado IN ('A','P','R','C','E'));
    PRINT 'Constraint CK_notifConsolidadas_estado recreada con estados A, P, R, C, E.';
END
GO

PRINT 'Script 002 ejecutado completamente.';
GO
