USE [ADAM]
GO
/****** Object:  StoredProcedure [dbo].[sp_fpv_aviso_vacaciones_Listado_FaltaCiclos]       Script Date: 8/6/2026 10:48:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
----Creado Dennis Suarez
----- Fecha 14/07/2016
---- Version 1.1
---- e) 	f) 	Aviso de ciclos no creados por trabajador (con el mes de ingreso)
----  Ejemplo: ingreso en abril de 2016, al finalizar la nomina de abril se debe crear el ciclo 2016-2017.
--- Ejemplo. Ingreso en mayo 2010, al finalizar la nomina de abril, s뿯½lo debe tener el per뿯½odo 2015-2016.


--- se modifico el 18-08-2016 para que sea dinamico el correo copia

-- Author: Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas

ALTER  procedure [dbo].[sp_fpv_aviso_vacaciones_Listado_FaltaCiclos]
AS
declare
@query1 varchar(max),
@asunto varchar(250),
@html varchar(4000),
@saludos varchar(100),
@correoCC varchar(1000),
@correo varchar(1000) ,
@msg varchar(500),
@tope smallint = 0,
@i smallint=0,
@b smallint=0
, @totalRegistros_F   INT
, @totalRegistros_F1  INT
, @descripcion_F      VARCHAR(50)
, @descripcion_F1     VARCHAR(50)
, @estado_F           CHAR(1)
, @estado_F1          CHAR(1)
, @html_nc_F          VARCHAR(MAX)
, @html_nc_F1         VARCHAR(MAX)

Begin
    BEGIN TRY

select  @tope= Valor_Numeric FROM   dbo.FPV_Parametros   WHERE   Parametro = 'Dias_maxV '

---armamos el correo
--select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'

--select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'


----Asignamos el correo

select @i= count(*) from FPV_Parametros where Parametro ='Mail_AvVac'

    if @i> 1
      begin

          select @correo = dbo.fn_correosVariosRemitentes('Mail_AvVac')
      end


    else
      begin
        select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'

      end


  select @b= count(*) from FPV_Parametros where Parametro =  'Mail_VacCC'

  if @b> 1
      begin

          select  @correoCC   = dbo.fn_correosVariosRemitentes('Mail_VacCC')
      end


    else
      begin
        select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'

      end

  ----------------------------------------------------------------------------------------------------------------------------------------------



set @asunto = 'Punto F: Listado de trabajadores que no tienen completos sus ciclos creados.'

set @msg = ' Le adjuntamos un listado de los trabajadores que el ultimo ciclo, el del mes en ejercicio no se encuentra creado ' +
                        ' , por favor revisar.  '


set @saludos = 'Buenos dias'

      select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }   </head>' +
        N'<body><H1 style="font-family: ''Calibri''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">'+ @saludos + '</H1>' +
        N'</b> ' +
        N'<p> ' +   @msg  +  '</p> ' +
        N'<br/><div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=7" target="_blank">Ver Informe</a></p>
	     <br><label>Atentamente,</label><br><br><label><strong>Departamento de N뿯½mina</strong></label></div>' +
        ' </body>'   ;


  -- select @query1   = ' Select Compania, trabajador, fecha_antiguedad, fecha_ingreso , maxciclo as ultimoCicloQuetiene, ciclo_Toca as faltaEsteCiclo  ' +
  --                                   ' from Adam.dbo.VW_FPV_Vacaciones_avisos_Ciclos_Toca where Maxciclo<> ciclo_toca ' +
  --                                   ' and diaHoy >datepart(day, fecha_antiguedad) and ciclo_toca not in (select ciclo_laboral from adam.dbo.saldos_vacaciones where ' +
  --                                   ' trabajador =VW_FPV_Vacaciones_avisos_Ciclos_Toca.trabajador' +
  --                                   ' and   VW_FPV_Vacaciones_avisos_Ciclos_Toca.compania = compania )'

      exec msdb.dbo.Sp_send_dbmail
          @profile_name = 'Informacion_Nomina',
        @Subject = @asunto,
        @recipients = @correo	,
        @body_format= 'html',
        @body = @html   ,
        -- @query = @query1 ,
        -- @query_result_width =300,
        -- @query_result_separator=',' ,
        @copy_recipients = @correoCC;
      --  @query_attachment_filename = 'Listado_trabajadores_FaltaCiclos.csv',
      --  @attach_query_result_as_file = 1 ;

	set   @query1   = ' '

------------ Count Punto F
SELECT @totalRegistros_F = COUNT(*)
FROM Adam.dbo.VW_FPV_Vacaciones_avisos_Ciclos_Toca
WHERE Maxciclo <> ciclo_toca

------------ Variables Punto F
SET @descripcion_F = 'Punto F: Sin ciclos completos'
SET @estado_F = CASE WHEN @totalRegistros_F > 0 THEN 'A' ELSE 'I' END

------------ HTML NC Punto F
set @html_nc_F =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto F: Trabajadores sin ciclos completos</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros_F as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=7" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas Punto F
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado_F, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Listado_FaltaCiclos',
     'Punto F: Trabajadores sin ciclos completos',
     @html_nc_F, @totalRegistros_F, @correo, @correoCC,
     NULL, NULL, @descripcion_F, 'Baja', 'VACACIONES', NULL)


        -- select @query1   = 'Select Compania, trabajador, fecha_antiguedad, fecha_ingreso , 0 as ultimoCicloQuetiene,   CASE WHEN datepart(YEAR, fecha_antiguedad) <> datepart(YEAR, getdate()) ' +
        --                                       ' AND datepart(MONTH, getdate()) >= datepart(MONTH, fecha_antiguedad) ' +
        --                                       '   THEN CONVERT(char(4), datepart(YEAR,  getdate())) + CONVERT(char(4), datepart(YEAR, getdate()) + 1) ' +
        --                                       ' when   DATEPART(YEAR, T.fecha_antiguedad) = DATEPART(YEAR, GETDATE()) then ' +
        --                                       ' CONVERT(char(4), datepart(YEAR, getdate()) ) + CONVERT(char(4), datepart(YEAR, getdate())+1) ' +
        --                                       '   ELSE CONVERT(char(4), datepart(YEAR, getdate()) - 1) + CONVERT(char(4), datepart(YEAR, getdate())) ' +
        --                                     '   END AS ciclo_toca     from Adam.dbo.trabajadores_grales T   where sit_trabajador = 1 ' +
        --                                     '   and trabajador not in (select trabajador from Adam.dbo.saldos_vacaciones where compania = T.compania) '

set @msg = ''
set @asunto = ''

set @asunto = 'Punto F.1: Listado de trabajadores que no tienen ciclos creados.'

set @msg = ' Le adjuntamos un listado de los trabajadores que no tienen ningun ciclo creado ' +
                        ' , por favor revisar.  '


      select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }   </head>' +
        N'<body><H1 style="font-family: ''Calibri''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">'+ @saludos + '</H1>' +
        N'</b> ' +
        N'<p> ' +   @msg  +  '</p> ' +
        N'<br/><div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=6" target="_blank">Ver Informe</a></p>
	     <br><label>Atentamente,</label><br><br><label><strong>Departamento de N뿯½mina</strong></label></div>' +
        ' </body>'   ;

exec msdb.dbo.Sp_send_dbmail
            @profile_name = 'Informacion_Nomina',
        @Subject = @asunto,
        @recipients = @correo	,
        @body_format= 'html',
        @body = @html   ,
        -- @query = @query1 ,
        @copy_recipients = @correoCC;
        -- @query_attachment_filename = 'Listado_trabajadores_FaltaCiclos.csv',
        -- @attach_query_result_as_file = 1 ;


------------ Count Punto F.1
SELECT @totalRegistros_F1 = COUNT(*)
FROM Adam.dbo.trabajadores_grales T
WHERE sit_trabajador = 1
  AND trabajador NOT IN (SELECT trabajador FROM Adam.dbo.saldos_vacaciones WHERE compania = T.compania)

------------ Variables Punto F.1
SET @descripcion_F1 = 'Punto F.1: Sin ciclos creados'
SET @estado_F1 = CASE WHEN @totalRegistros_F1 > 0 THEN 'A' ELSE 'I' END

------------ HTML NC Punto F.1
set @html_nc_F1 =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto F.1: Trabajadores sin ciclos creados</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros_F1 as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=6" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas Punto F.1
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado_F1, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Listado_FaltaCiclos',
     'Punto F.1: Trabajadores sin ciclos creados',
     @html_nc_F1, @totalRegistros_F1, @correo, @correoCC,
     NULL, NULL, @descripcion_F1, 'Alta', 'VACACIONES', NULL)


    END TRY
    BEGIN CATCH
        --Insert en notificaciones consolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Listado_FaltaCiclos',
             'Error en proceso de avisos vacaciones Listado Falta Ciclos',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Alta', 'VACACIONES', ERROR_MESSAGE())
    END CATCH
End

