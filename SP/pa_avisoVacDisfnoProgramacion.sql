USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[pa_avisoVacDisfnoProgramacion]        Script Date: 8/6/2026 12:09:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:      Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
  ALTER procedure [dbo].[pa_avisoVacDisfnoProgramacion]
  AS

declare
@mensaje        varchar(3000),
@asunto         varchar(250),
@html           varchar(4000),
@saludos        varchar(100),
@correo         varchar(1000),
@b              smallint = 0,
@i              smallint = 0,
@query1         varchar(max),
@w              smallint = 0,
@comilla        char(1),
@correoCC       varchar(1000),
@totalRegistros INT,
@descripcion    VARCHAR(50),
@estado         CHAR(1),
@html_nc        VARCHAR(MAX)


  Begin
    BEGIN TRY

----Asignamos el correo

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

  -------------------------------------------------------------------------

   select @w = COUNT(*) from Adam.dbo.VW_TrabajadoresDifSaldosDisfProg

   set @totalRegistros = @w
   set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
   set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

       if @w > 0
       Begin
    BEGIN TRY
       set @mensaje = 'Se adjunta listado en formato csv de trabajadores con este problema. Pueden abrir con Excel, el separador de columnas es la coma(,).'

         Set @asunto = 'Punto E-6: Trabajadores que tienen datos en vacaciones disfrutadas y no posee datos en el detalle.'

   set @saludos = 'Buenos Dias'

   select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }   </head>' +
       N'<body><H1  style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' + @saludos + '</H1>' +
       N'<b></b> ' +
       N'<p> ' + @mensaje + ' </p> ' +
       N'<br/><div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=8" target="_blank">Ver Informe</a></p>' +
       N'<br><label>Atentamente,</label><br><br><label><strong>Departamento de N&oacute;mina</strong></label></div> </body>' ;

	 select @query1 = '   select compania,Compania_Desc ,Clase_Nomina,Desc_Clase_Nomina,Codigo , trabajador, nombre, vac_disfrutadas, ciclo_laboral  from Adam.dbo.VW_TrabajadoresDifSaldosDisfProg order by trabajador '

       exec msdb.dbo.Sp_send_dbmail
	     @profile_name = 'Informacion_nomina',
             @Subject = @asunto,
             @recipients = @correo,
             @body_format = 'html',
             @body = @html,
	     @copy_recipients = @correoCC;
         --@query = @query1,
         --@query_result_width = 32767,
         --@query_result_separator= ',',
         --@query_attachment_filename = 'ListadoTrabDisfsinProg.csv',
         --@attach_query_result_as_file = 1;

         end
         else
         begin
                 set @mensaje = '  No existe trabajadores con vac disfrutadas y no en programacion'

                 set @asunto = 'Punto E-6: Trabajadores que tienen datos en vacaciones disfrutadas y no posee datos en el detalle. '

                 set @saludos = 'Buenos Dias'

   select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }   </head>' +
       N'<body><H1  style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' + @saludos + '</H1>' +
       N'<b></b> ' +
       N'<p> ' + @mensaje + ' </p> ' +
       N'<br/><br /><br/><br/><br/>' +
       '  </body>' ;

       exec msdb.dbo.Sp_send_dbmail
         @profile_name = 'Informacion_nomina',
         @Subject = @asunto,
         @recipients = @correo,
         @body_format = 'html',
         @body = @html,
         @copy_recipients = @correoCC;
         end

        set @html_nc =
            '<div style="font-family:Calibri;">' +
            '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
            '<table style="border-collapse:collapse;width:95%;" border="1">' +
            '<tr style="background-color:black;color:white;">' +
            '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
            '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
            '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
            '<tr><td style="padding:4px;">&nbsp;Punto E-6: Trabajadores con vac. disfrutadas sin datos en el detalle</td>' +
            '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
            '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=8" target="_blank">Ver Informe</a></td>' +
            '</tr></table></div>'

        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            (@estado, 'Mail_AvVac', 'pa_avisoVacDisfnoProgramacion',
             'Punto E-6: Trabajadores con vac. disfrutadas sin datos en el detalle',
             @html_nc, @totalRegistros, @correo, @correoCC,
             NULL, NULL, @descripcion, 'Alta', 'VACACIONES', NULL)

    END TRY
    BEGIN CATCH
        --Insert en notificaciones consolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'pa_avisoVacDisfnoProgramacion',
             'Punto E-6: Trabajadores con vac. disfrutadas sin datos en el detalle',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Alta', 'VACACIONES', ERROR_MESSAGE())
    END CATCH
        End
