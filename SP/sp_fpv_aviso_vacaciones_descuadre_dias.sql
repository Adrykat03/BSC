USE [ADAM]
GO
/****** Object:  StoredProcedure [dbo].[sp_fpv_aviso_vacaciones_descuadre_dias]        Script Date: 5/6/2026 17:10:55 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----- Creado Dennis Suarez
----- Fecha 13/07/2016
---- Version 1.2
---- Recorre la tabla saldo vacaciones para buscar a quien se le diferencia el dia de entrada en la antiguedad, con la fecha de comienzo del ciclo.
---- se modifico el 18-08-2016 para que sea dinamico el correo copia
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 05/06/2026
-- Description:	Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER PROCEDURE [dbo].[sp_fpv_aviso_vacaciones_descuadre_dias]
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
        , @correoCC VARCHAR(1000)
        , @totalRegistros INT
        , @descripcion VARCHAR(50)
        , @estado CHAR(1)
        , @html_nc VARCHAR(MAX)

BEGIN
        ----- Seccion A.2 Descuadre
        --- vemos que el mes sea diferente entre la fecha de antiguedad y la fecha de inicio de la vacacion
        SET @fecha = GETDATE()
        SET @dia = datepart(day, @fecha)
        SET @mes = datepart(month, @fecha)
        SET @anio = datepart(year, @fecha)

        --select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'
        --  select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'
        ---- Asignamos el correo
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

        -- Contar total de registros
        SELECT @totalRegistros = COUNT(*)
        FROM saldos_vacaciones V
        INNER JOIN trabajadores_grales T
            ON v.trabajador = T.trabajador AND V.compania = T.compania
        WHERE T.sit_trabajador = 1
            AND V.fecha_ini_prog_vac > T.fecha_antiguedad
            AND datepart(day, T.fecha_antiguedad) <> datepart(day, V.fecha_ini_prog_vac)

        set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
        set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

        -----------------------------------------------------------------------
        DECLARE C_SA2Mes CURSOR
        FOR
        SELECT T.compania
                , T.trabajador
                , T.fecha_antiguedad
                , T.fecha_ingreso
                , V.fecha_ini_prog_vac
                , V.ciclo_laboral
        FROM saldos_vacaciones V
        INNER JOIN trabajadores_grales T
                ON v.trabajador = T.trabajador
                        AND V.compania = T.compania
        WHERE T.sit_trabajador = 1
                AND V.fecha_ini_prog_vac > T.fecha_antiguedad
                AND datepart(day, T.fecha_antiguedad) <> datepart(day, V.fecha_ini_prog_vac)
        ORDER BY T.trabajador

        OPEN C_SA2Mes

        WHILE @@Fetch_Status < 1
        BEGIN
                FETCH C_SA2Mes
                INTO @compania
                        , @trabajador
                        , @fecha_antiguedad
                        , @fecha_ingreso
                        , @fecha_iniVacaciones
                        , @ciclo

                IF @@Fetch_Status <> 0
                BEGIN
                        BREAK
                END

                SET @x = @x + 1

                SELECT @nombreTrab = replace(nombre, '/', ' ')
                FROM trabajadores
                WHERE trabajador = @trabajador

                SELECT @empresa = ltrim(rtrim(nombre_cia))
                FROM companias
                WHERE compania = @compania

                SET @mensaje = '  El presente correo tiene como fin informarle que el trabajador de nombre: ' + @nombreTrab + ', con cedula : ' + @trabajador + ', que se encuentra activo(a) en la empresa: ' + @empresa + ', y tiene como fecha de antiguedad : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ' y fecha de ingreso : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ', tiene como fecha de inicio en sus vacaciones lo siguiente: ' + CONVERT(VARCHAR(15), @fecha_iniVacaciones, 103) + ', en el ciclo ' + @ciclo + ' , lo cual no cuadra en el dia de antiguedad. '
                SET @asunto = 'Punto A.2: Error de descuadre en el dia de inicio de vacaciones. Con el trabajador: ' + @nombreTrab
                SET @saludos = 'Buenos Dias'

                SELECT @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }   </style></head>' + N'<body><H1  style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' + @saludos + '</H1>' + N'<b></b> ' + N'<p> ' + @mensaje + '</p> ' + N'<br/><br /><br/><br/><br/> <br/><br/><br/>' + '  </body>';

                EXEC msdb.dbo.Sp_send_dbmail
			       @profile_name = 'Informacion_Nomina',
			       @Subject = @asunto
                        , @recipients = @correo
                        , @body_format = 'html'
                        , @copy_recipients = @correoCC
                        , @body = @html;

                ---- insertar registro de envio
                EXEC sp_fpv_inserta_avisos_vacaciones 'PTO_A2_Dias'
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
        END

        CLOSE C_SA2Mes

        DEALLOCATE C_SA2Mes

        IF @x = 0
        BEGIN
                EXEC msdb.dbo.Sp_send_dbmail
			       @profile_name = 'Informacion_Nomina',
			       @Subject = 'Punto A.2: Aviso Descuadre de dias en vacaciones'
                        , @recipients = @correo
                        , @body_format = 'html'
                        , @copy_recipients = @correoCC
                        , @body = 'No Existen descuadres de este tipo en la base';
        END

        set @html_nc =
            '<div style="font-family:Calibri;">' +
            '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
            '<table style="border-collapse:collapse;width:95%;" border="1">' +
            '<tr style="background-color:black;color:white;">' +
            '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
            '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
            '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
            '<tr><td style="padding:4px;">&nbsp;Punto A.2: Error de descuadre en el dia de inicio de vacaciones</td>' +
            '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
            '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=38" target="_blank">Ver Informe</a></td>' +
            '</tr></table></div>'

        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_descuadre_dias',
             'Punto A.2: Error de descuadre en el dia de inicio de vacaciones',
             @html_nc, @totalRegistros, @correo, @correoCC,
             NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)
END
