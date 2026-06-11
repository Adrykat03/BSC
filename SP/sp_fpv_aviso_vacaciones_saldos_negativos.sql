USE [ADAM]
GO
/****** Object:  StoredProcedure [dbo].[sp_fpv_aviso_vacaciones_saldos_negativos] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----- Creado Dennis Suarez
----- Fecha 13/07/2016
---- Version 1.3
---- Recorre la tabla saldo vacaciones para buscar a quien se le diferencia los dias disfrutados con los asignados en el ciclo.

---- se modifico el 18-08-2016 para que sea dinamico el correo copia

---- se modifico el 15-09-2016 se le coloco una opcion nueva, donde si tienen mas disfrutadas que asignadas al ciclo mande mensaje
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 29/05/2026
-- Description:	Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER procedure [dbo].[sp_fpv_aviso_vacaciones_saldos_negativos]
AS
declare
 @x                             smallint = 0,
 @compania               char(4),
 @trabajador           char(10),
 @vacporCiclo         smallint,
 @VacDisfrutada     smallint,
 @ciclo                     varchar(10),
 @mensaje                 varchar(3000),
 @empresa                 varchar(100),
 @asunto                   varchar(250),
 @nombreTrab           varchar(100),
 @html                       varchar(4000),
 @saludos                 varchar(100),
 @correo                   varchar(1000),
 @vac_porgamadas   smallint = 0,
 @fecha                     datetime,
 @correoCC               varchar(1000),
 @dia                         smallint,
 @mes                         smallint,
 @anio                       smallint,
 @i                             smallint = 0,
 @b                             smallint = 0,
 @totalRegistros   int,
 @descripcion         varchar(50),
 @estado                   char(1),
 @html_nc              varchar(max)

Begin

set @fecha = GETDATE()
set @dia       = datepart(day,       @fecha)
set @mes       = datepart(month,   @fecha)
set @anio     = datepart(year,     @fecha)

---- Asignamos el correo
select @i = count(*) from FPV_Parametros where Parametro = 'Mail_AvVac'

        if @i > 1
                begin
                        select @correo = dbo.fn_correosVariosRemitentes('Mail_AvVac')
                end
        else
                begin
                        select @correo = Valor from FPV_Parametros where Parametro = 'Mail_AvVac'
                end

select @b = count(*) from FPV_Parametros where Parametro = 'Mail_VacCC'

        if @b > 1
                begin
                        select @correoCC = dbo.fn_correosVariosRemitentes('Mail_VacCC')
                end
        else
                begin
                        select @correoCC = Valor from FPV_Parametros where Parametro = 'Mail_VacCC'
                end

-- Contar total de registros con saldos negativos
SELECT @totalRegistros = count(*) FROM (
        SELECT T.trabajador FROM saldos_vacaciones V INNER JOIN trabajadores_grales T
        ON v.trabajador = T.trabajador AND V.compania = T.compania
        WHERE vac_programadas < 0 AND T.sit_trabajador = 1
        UNION ALL
        SELECT T.trabajador FROM saldos_vacaciones V INNER JOIN trabajadores_grales T
        ON v.trabajador = T.trabajador AND V.compania = T.compania
        WHERE vac_disfrutadas < 0 AND T.sit_trabajador = 1
        UNION ALL
        SELECT T.trabajador FROM saldos_vacaciones V INNER JOIN trabajadores_grales T
        ON v.trabajador = T.trabajador AND V.compania = T.compania
        WHERE vac_por_ciclo < 0 AND T.sit_trabajador = 1
        UNION ALL
        SELECT T.trabajador FROM saldos_vacaciones V INNER JOIN trabajadores_grales T
        ON v.trabajador = T.trabajador AND V.compania = T.compania
        WHERE vac_por_ciclo < vac_disfrutadas AND T.sit_trabajador = 1
) q

set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

---------------------------------------------------------------------

---- Punto 2.1
---- Seccion A.1 Negativos
---- identificar quienes tienen vacaciones en negativo

Declare C_2A_Negativos Cursor For
        select T.compania, T.trabajador, V.vac_por_ciclo, V.vac_disfrutadas, V.ciclo_laboral
        , V.vac_programadas from saldos_vacaciones V inner join trabajadores_grales T
        on v.trabajador = T.trabajador and V.compania = T.compania
        where vac_programadas < 0
        and T.sit_trabajador = 1
        union all
        select T.compania, T.trabajador, V.vac_por_ciclo, V.vac_disfrutadas, V.ciclo_laboral
        , V.vac_programadas from saldos_vacaciones V inner join trabajadores_grales T
        on v.trabajador = T.trabajador and V.compania = T.compania
        where vac_disfrutadas < 0
        and T.sit_trabajador = 1
        union all
        select T.compania, T.trabajador, V.vac_por_ciclo, V.vac_disfrutadas, V.ciclo_laboral
        , V.vac_programadas from saldos_vacaciones V inner join trabajadores_grales T
        on v.trabajador = T.trabajador and V.compania = T.compania
        where vac_por_ciclo < 0
        and T.sit_trabajador = 1
        union all
        select T.compania, T.trabajador, V.vac_por_ciclo, V.vac_disfrutadas, V.ciclo_laboral
        , V.vac_programadas from saldos_vacaciones V inner join trabajadores_grales T
        on v.trabajador = T.trabajador and V.compania = T.compania
        where vac_por_ciclo < vac_disfrutadas
        and T.sit_trabajador = 1
        -- order by T.trabajador

Open C_2A_Negativos

        While @@Fetch_Status < 1
                Begin
                        Fetch C_2A_Negativos Into @compania, @trabajador, @vacporCiclo, @VacDisfrutada, @ciclo, @vac_porgamadas

                        If @@Fetch_Status <> 0
                                Begin
                                        Break
                                End
                        set @x = @x + 1

                        select @nombreTrab = replace(nombre, '/', ' ') from trabajadores where trabajador = @trabajador
                        select @empresa = ltrim(rtrim(nombre_cia)) from companias where compania = @compania

                        set @mensaje = '  El presente correo tiene como fin informarle que el trabajador de nombre: ' + @nombreTrab +
                                                      ', con cedula: ' + @trabajador + ', que se encuentra activo(a) en la empresa: ' + @empresa + ', en el ciclo: ' + @ciclo +
                                                      ' tiene numero de dias asignado: ' + CONVERT(varchar(4), @vacporCiclo) + ' y en disfrutadas tiene: ' +
                                                      CONVERT(varchar(4), @vacporCiclo) + ' y en dias de programacion de vacaciones ' + CONVERT(varchar(4), @vacporCiclo) + ' presenta un saldo negativo.'

                        set @asunto     = 'Punto A.1: Error de saldos negativos en vacaciones. Con el trabajador: ' + @nombreTrab

                        set @saludos   = 'Buenos Dias'

                        select @html   = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center; } .style12 { color: #800000;text-decoration: underline; } </style></head>' +
                                N'<body><H1 style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' + @saludos + '</H1>' +
                                N'<b></b> ' +
                                N'<p> ' + @mensaje + ' </p> ' +
                                N'<br/><br/><br/><br/><br/><br/><br/><br/>' +
                                ' </body>'

                        exec msdb.dbo.Sp_send_dbmail
                                @profile_name = 'Informacion_Nomina',
                                @Subject             = @asunto,
                                @recipients       = @correo,
                                @body_format     = 'html',
                                @copy_recipients   = @correoCC,
                                @body                   = @html;

                        ---- insertar registro de envio
                        Exec sp_fpv_inserta_avisos_vacaciones 'PTO_A1_Negativos', @mensaje, @ciclo, @dia, @mes, @anio, @trabajador, @fecha, null, null, null, @correo

                end
        Close C_2A_Negativos
        Deallocate C_2A_Negativos

        if @x = 0
                Begin
                        exec msdb.dbo.Sp_send_dbmail
                                @profile_name = 'Informacion_Nomina',
                                @Subject             = 'Punto A.1: Aviso Saldos negativos en vacaciones',
                                @recipients       = @correo,
                                @body_format     = 'html',
                                @copy_recipients   = @correoCC,
                                @body                   = 'No Existen saldos negativos en la base de vacaciones';
                End

        -- Registro en notificacionesConsolidadas
        set @html_nc =
            '<div style="font-family:Calibri;">' +
            '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
            '<table style="border-collapse:collapse;width:95%;" border="1">' +
            '<tr style="background-color:black;color:white;">' +
            '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
            '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
            '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
            '<tr><td style="padding:4px;">&nbsp;Punto A.1: Error de saldos negativos en vacaciones</td>' +
            '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
            '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=36" target="_blank">Ver Informe</a></td>' +
            '</tr></table></div>'

        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
                (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
                  periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
                (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_saldos_negativos',
                  'Punto A.1: Error de saldos negativos en vacaciones',
                  @html_nc, @totalRegistros, @correo, @correoCC,
                  NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)

End --- fin
