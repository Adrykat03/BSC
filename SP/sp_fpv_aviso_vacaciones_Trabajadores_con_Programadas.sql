USE [ADAM]
GO
/****** Object:  StoredProcedure [dbo].[sp_fpv_aviso_vacaciones_Trabajadores_con_Programadas]        Script Date: 8/6/2026 10:47:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----- Creado Dennis Suarez
----- Fecha 20/06/2017
----Version 1.0
----Recorre la tabla saldo vacaciones para buscar a quien tienen vacaciones programadas
----Es el punto I
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 08/06/2026
-- Description:	Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER PROCEDURE [dbo].[sp_fpv_aviso_vacaciones_Trabajadores_con_Programadas]
AS
DECLARE @trabajador CHAR(10)
        , @compania CHAR(4)
        , @fecha_ingreso SMALLDATETIME
        , @fecha_antiguedad SMALLDATETIME
        , @fecha_iniVacaciones SMALLDATETIME
        , @ciclo VARCHAR(10)
        , @mensaje VARCHAR(3000)
        , @empresa VARCHAR(100)
        , @asunto VARCHAR(250)
        , @nombreTrab VARCHAR(100)
        , @html VARCHAR(4000)
        , @saludos VARCHAR(100)
        , @correo VARCHAR(1000)
        , @x SMALLINT = 0
        , @fecha DATETIME
        , @dia SMALLINT
        , @mes SMALLINT
        , @anio SMALLINT
        , @i SMALLINT = 0
        , @b SMALLINT = 0
        , @query1 VARCHAR(max)
        , @comilla CHAR(1)
        , @correoCC VARCHAR(1000)
        , @totalRegistros INT
        , @descripcion    VARCHAR(50)
        , @estado         CHAR(1)
        , @html_nc        VARCHAR(MAX)

BEGIN
    BEGIN TRY
        ---vemos que el mes sea diferente entre la fecha de antiguedad y la fecha de inicio de la vacacion
        SET @comilla = CHAR(39)
        SET @fecha = GETDATE()
        SET @dia = datepart(day,  @fecha)
        SET @mes = datepart(month, @fecha)
        SET @anio = datepart(year, @fecha)

        ----Asignamos el correo
        SELECT @i = count(*)
        FROM FPV_Parametros
        WHERE Parametro = 'Mail_AvVac'

        IF @i > 1
        BEGIN
                SELECT @correo = dbo.fn_correosVariosRemitentes('Mail_AvVac')
        END
        ELSE
        BEGIN
                SELECT @correo = Valor
                FROM FPV_Parametros
                WHERE Parametro = 'Mail_AvVac'
        END

        SELECT @b = count(*)
        FROM FPV_Parametros
        WHERE Parametro = 'Mail_VacCC'

        IF @b > 1
        BEGIN
                SELECT @correoCC = dbo.fn_correosVariosRemitentes('Mail_VacCC')
        END
        ELSE
        BEGIN
                SELECT @correoCC = Valor
                FROM FPV_Parametros
                WHERE Parametro = 'Mail_VacCC'
        END

        ---------------------------------------------------------------------------------------------------------------------------------------
        -- select @query1   = 'Select T.compania,T.clase_nomina,T.trabajador, t.nombre, ciclo_laboral, vac_programadas as diasProgramados from Adam.dbo.saldos_vacaciones VAc inner join Adam.dbo.vw_datos_trabajador_nomina T on Vac.trabajador = T.trabajador and Vac.compania = T.compania where situacion = + ' + @comilla +'Activo'+ @comilla +  '   and vac_programadas > 0 '
        set @mensaje =   ' Le adjuntamos un listado de los trabajadores que tienen vacaciones programadas, como aparece en la cabecera de vacaciones en el sistema de n뿯½mina. ' +
                                        ', por favor revisar. '
        SET @asunto = 'Punto E-5: Listado de trabajadores con vacaciones programadas.   '
        SET @saludos = 'Buenos D뿯½as'

        SELECT @html = '<head><title></title><style type="text/css">.style10{width:153px;text-align:center}.style12{color:maroon;text-decoration:underline}</style></head><body><div class="panel panel-default"><div class="panel-heading" style="padding:15px">Punto E-5: Listado de trabajadores con vacaciones programadas.</div><div class="row"><div class="col-md-12" style="padding:15px"><h1 style="font-family:''Calibri'';font-size:medium;font-weight:700;font-style:normal;color:#930">Buenos D뿯½as</h1><hr><p>Le adjuntamos un listado de los trabajadores que tienen vacaciones programadas, como aparece en la cabecera de vacaciones en el sistema de n뿯½mina, por favor revisar.</p><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=1" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de N뿯½mina</strong></label></div></div></div></body>';

        EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
                , @Subject = @asunto
                , @recipients = @correo
                , @body_format = 'html'
                , @body = @html
                , @copy_recipients = @correoCC;

        ----insertar registro de envio
        EXEC sp_fpv_inserta_avisos_vacaciones 'PTO_I_Programadas'
                , @mensaje
                , @ciclo
                , @dia
                , @mes
                , @anio
                , @trabajador
                , @fecha
                , NULL
                , NULL
                , NULL
                , @correo

        SELECT @totalRegistros = count(*)
        FROM Adam.dbo.saldos_vacaciones VAc
        INNER JOIN Adam.dbo.vw_datos_trabajador_nomina T
                ON Vac.trabajador = T.trabajador
                        AND Vac.compania = T.compania
        WHERE situacion = 'Activo'
                AND vac_programadas > 0

        set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
        set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

        IF @totalRegistros = 0
        BEGIN
                EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
                        , @Subject = 'Punto E-5: Listado de trabajadores con vacaciones programadas.   '
                        , @recipients = @correo
                        , @body_format = 'html'
                        , @copy_recipients = @correoCC
                        , @body = 'No Existen trabajadores con programaci뿯½n de vacaciones';
        END

        set @html_nc =
            '<div style="font-family:Calibri;">' +
            '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
            '<table style="border-collapse:collapse;width:95%;" border="1">' +
            '<tr style="background-color:black;color:white;">' +
            '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
            '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
            '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
            '<tr><td style="padding:4px;">&nbsp;Punto E-5: Trabajadores con vacaciones programadas</td>' +
            '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
            '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=1" target="_blank">Ver Informe</a></td>' +
            '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Trabajadores_con_Programadas',
     'Punto E-5: Trabajadores con vacaciones programadas',
     @html_nc, @totalRegistros, @correo, @correoCC,
     NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)

    END TRY
    BEGIN CATCH
        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Trabajadores_con_Programadas',
             'Punto E-5: Trabajadores con vacaciones programadas',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Media', 'VACACIONES', ERROR_MESSAGE())
    END CATCH

END
