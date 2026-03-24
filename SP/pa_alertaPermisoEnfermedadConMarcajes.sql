CREATE PROCEDURE [Avisos].[pa_alertaPermisoEnfermedadConMarcajes]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fechaHoy DATE = CAST(GETDATE() AS DATE);

    CREATE TABLE #Resultado (
        Cedula NVARCHAR(10),
        NombreTrabajador NVARCHAR(200),
        CCO NVARCHAR(50),
        DescCCO NVARCHAR(200),
        CantidadMarcajes INT
    );

    DECLARE permisos_cursor CURSOR FOR
    SELECT 
        LEFT(pt.codigo, 10) AS Cedula,
        pt.cco
    FROM [DB_NOMKFC].[Asistencia].[permisos_trabajadores] pt
    WHERE 
        pt.idPermiso = 12
        AND pt.estado = 1
        AND CAST(pt.fecha_ini AS DATE) <= @fechaHoy
        AND CAST(pt.fecha_fin AS DATE) >= @fechaHoy;

    DECLARE @Cedula NVARCHAR(10), @CCO NVARCHAR(50);

    OPEN permisos_cursor;
    FETCH NEXT FROM permisos_cursor INTO @Cedula, @CCO;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO #Resultado (Cedula, NombreTrabajador, CCO, DescCCO, CantidadMarcajes)
        SELECT 
            @Cedula,
            t.Nombre,
            @CCO,
            vwcc.Descripcion,
            COUNT(*) AS CantidadMarcajes
        FROM [Asistencia].[fn_Obtenermarcajes1234Reglas](@fechaHoy, @Cedula) m
        INNER JOIN [DB_NOMKFC].[RRHH].[vw_datosTrabajadores] t ON t.Trabajador = @Cedula
        LEFT JOIN [DB_NOMKFC].[Catalogos].[VW_CCO] vwcc ON vwcc.CCO = @CCO
        GROUP BY t.Nombre, vwcc.Descripcion;

        FETCH NEXT FROM permisos_cursor INTO @Cedula, @CCO;
    END

    CLOSE permisos_cursor;
    DEALLOCATE permisos_cursor;

    IF EXISTS (SELECT 1 FROM #Resultado)
    BEGIN
        DECLARE @Body NVARCHAR(MAX) = 
        N'<h3>Permisos por enfermedad u hospitalización con marcajes detectados (' + CONVERT(NVARCHAR(10), @fechaHoy, 120) + ')</h3>' +
        N'<table border="1" cellpadding="5" cellspacing="0">' +
        N'<tr><th>Cédula</th><th>Nombre</th><th>CCO</th><th>Descripción CCO</th><th>Marcajes</th></tr>' +
        (
            SELECT 
                td = Cedula, '', td = NombreTrabajador, '', td = CCO, '', td = DescCCO, '', td = CantidadMarcajes, ''
            FROM #Resultado
            FOR XML PATH('tr'), TYPE
        ).value('.', 'NVARCHAR(MAX)') +
        N'</table>';
		
        -- INSERT notificación consolidada
        INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
        VALUES ('A', 'Ausencias', 'pa_alertaPermisoEnfermedadConMarcajes', 'Permisos por enfermedad u hospitalización con marcajes', @Body, 'smosquera@sipecom.com');
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'Informacion_Nomina',
            @recipients = 'smosquera@sipecom.com',
            @subject = 'Permisos por enfermedad u hospitalización con marcajes',
            @body = @Body,
            @body_format = 'HTML';
    END

    DROP TABLE #Resultado;
END