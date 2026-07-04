USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[sp_fpv_aviso_vacaciones_descuadre_dias_asignados]        Script Date: 5/6/2026 17:18:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----Creado Dennis Suarez
-----Fecha 14/07/2016
----Version 1.2
----Recorre la tabla saldo vacaciones y validamos contra la tabla de rangos de dias por anio y vemos quien tiene los dias mal asignados.
----se modifico el 18-08-2016 para que sea dinamico el correo copia
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 05/06/2026
-- Description:	Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER PROCEDURE [dbo].[sp_fpv_aviso_vacaciones_descuadre_dias_asignados]
AS
DECLARE @trabajador CHAR(10)
        , @compania CHAR(4)
        , @fecha_antiguedad SMALLDATETIME
        , @fecha_ingreso SMALLDATETIME
        , @fecha_iniVacaciones SMALLDATETIME
        , @diasToca SMALLINT = 0
        , @diasDisfrutados SMALLINT = 0
        , @diasPorCiclo SMALLINT = 0
        , @aniosTrabajador SMALLINT = 0
        , @ciclo VARCHAR(10)
        , @mensaje VARCHAR(3000)
        , @empresa VARCHAR(100)
        , @asunto VARCHAR(250)
        , @nombreTrab VARCHAR(100)
        , @html VARCHAR(4000)
        , @saludos VARCHAR(100)
        , @correo VARCHAR(1000)
        , @correoCC VARCHAR(1000)
        , @x SMALLINT = 0
        , @fecha DATETIME
        , @dia SMALLINT
        , @mes SMALLINT
        , @anio SMALLINT
        , @i SMALLINT = 0
        , @b SMALLINT = 0
        , @totalRegistros INT
        , @descripcion VARCHAR(50)
        , @estado CHAR(1)
        , @html_nc VARCHAR(MAX)

BEGIN
        ----- Seccion B Descuadre entre dias asignados y dias que realmente le tocan al trabajador
        SET @fecha = GETDATE()
        SET @dia = datepart(day, @fecha)
        SET @mes = datepart(month, @fecha)
        SET @anio = datepart(year, @fecha)

        --select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'
        --   select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'
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

        -- Contar total de registros
        SELECT @totalRegistros = COUNT(*)
        FROM dbo.VW_FPV_Vacaciones_Valida_Dias_Asignados
        WHERE dias_toca <> vac_por_ciclo

        set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
        set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

        -----------------------------------------------------------------------------------------
        DECLARE C_SBDescuadre CURSOR
        FOR
        SELECT compania
                , trabajador
                , fecha_antiguedad
                , fecha_ingreso
                , vac_por_ciclo
                , fecha_ini_prog_vac
                , ciclo_laboral
                , anios
                , dias_toca
                , vac_disfrutadas
        FROM dbo.VW_FPV_Vacaciones_Valida_Dias_Asignados
        WHERE dias_toca <> vac_por_ciclo

        OPEN C_SBDescuadre

        WHILE @@Fetch_Status < 1
        BEGIN
                FETCH C_SBDescuadre
                INTO @compania
                        , @trabajador
                        , @fecha_antiguedad
                        , @fecha_ingreso
                        , @diasPorCiclo
                        , @fecha_iniVacaciones
                        , @ciclo
                        , @aniosTrabajador
                        , @diasToca
                        , @diasDisfrutados

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

                IF @aniosTrabajador > 0
                BEGIN
                        IF @diasDisfrutados > 0
                        BEGIN
                                SET @mensaje = '  El presente correo tiene como fin informarle que el trabajador de nombre: ' + @nombreTrab + ', con cedula : ' + @trabajador + ', que se encuentra activo(a) en la empresa: ' + @empresa + ', y tiene como fecha de antiguedad : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ' y fecha de ingreso : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ', tiene asignado : ' + CONVERT(VARCHAR(3), @diasPorCiclo) + ' dias en el ciclo ' + @ciclo + ' , lo cual no es correcto , ya que segun la tabla de vacaciones le deberian asignar = ' + CONVERT(VARCHAR(3), @diasToca) + ' dias. Tomando en cuenta que este ' + ' trabajador ya disfruto de estos dias asignado de una manera parcial o total.'
                        END
                        ELSE
                        BEGIN
                                SET @mensaje = '  El presente correo tiene como fin informarle que el trabajador de nombre: ' + @nombreTrab + ', con cedula : ' + @trabajador + ', que se encuentra activo(a) en la empresa: ' + @empresa + ', y tiene como fecha de antiguedad : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ' y fecha de ingreso : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ', tiene asignado : ' + CONVERT(VARCHAR(3), @diasPorCiclo) + ' dias en el ciclo ' + @ciclo + ' , lo cual no es correcto , ya que segun la tabla de vacaciones le deberian asignar = ' + CONVERT(VARCHAR(3), @diasToca) + ' dias. No ha disfrutado de estas vacaciones. '
                        END
                END

                BEGIN
                        SET @mensaje = '  El presente correo tiene como fin informarle que el trabajador de nombre: ' + @nombreTrab + ', con cedula : ' + @trabajador + ', que se encuentra activo(a) en la empresa: ' + @empresa + ', y tiene como fecha de antiguedad : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ' y fecha de ingreso : ' + CONVERT(VARCHAR(15), @fecha_antiguedad, 103) + ', tiene asignado : ' + CONVERT(VARCHAR(3), @diasPorCiclo) + ' dias en el ciclo ' + @ciclo + ' , lo cual no es correcto , ya que segun la tabla de vacaciones le deberian' + ' asignar = ' + CONVERT(VARCHAR(3), @diasToca) + ' dias. Pero los dias no cuadran ya que esta mal colocada la fecha de inicio de vacaciones contra su fecha de antiguedad, ya que tiene menos de un a&#241;o. '
                END

                SET @asunto = 'Punto B: Error de descuadre en la cantidad de dias asignados. Con el trabajador: ' + @nombreTrab
                SET @saludos = 'Buenos Dias'

                SELECT @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }   </style></head>' + N'<body><H1  style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' + @saludos + '</H1>' + N'<b></b> ' + N'<p> ' + @mensaje + '</p> ' + N'<br/><br /><br/><br/>' + ' </body>';

                EXEC msdb.dbo.Sp_send_dbmail
		            @profile_name = 'Informacion_Nomina'
		        ,   @Subject = @asunto
                        ,   @recipients = @correo
                        ,   @body_format = 'html'
                        ,   @copy_recipients = @correoCC
                        ,   @body = @html;

                ----insertar registro de envio
                EXEC sp_fpv_inserta_avisos_vacaciones 'PTO_B_Rangos'
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

        CLOSE C_SBDescuadre

        DEALLOCATE C_SBDescuadre

        IF @x = 0
        BEGIN
                EXEC msdb.dbo.Sp_send_dbmail
		           @profile_name = 'Informacion_Nomina'
			 , @Subject = 'Punto B: Aviso Descuadre de dias en vacaciones'
                        ,   @recipients = @correo
                        ,   @body_format = 'html'
                        ,   @copy_recipients = @correoCC
                        ,   @body = 'No Existen descuadres de este tipo en la base';
        END

        set @html_nc =
            '<div style="font-family:Calibri;">' +
            '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
            '<table style="border-collapse:collapse;width:95%;" border="1">' +
            '<tr style="background-color:black;color:white;">' +
            '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
            '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
            '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
            '<tr><td style="padding:4px;">&nbsp;Punto B: Error de descuadre en la cantidad de dias asignados</td>' +
            '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
            '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=39" target="_blank">Ver Informe</a></td>' +
            '</tr></table></div>'

        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_descuadre_dias_asignados',
             'Punto B: Error de descuadre en la cantidad de dias asignados',
             @html_nc, @totalRegistros, @correo, @correoCC,
             NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)

END ---fin
