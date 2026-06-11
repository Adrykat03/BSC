USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[sp_fpv_aviso_vacaciones_Listado_topesDiasVac]        Script Date: 8/6/2026 10:51:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Author: Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas

ALTER   procedure [dbo].[sp_fpv_aviso_vacaciones_Listado_topesDiasVac]
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
@b smallint=0,
@totalRegistros INT,
@descripcion    VARCHAR(50),
@estado         CHAR(1),
@html_nc        VARCHAR(MAX)
Begin

    BEGIN TRY

select   @tope= Valor_Numeric FROM   dbo.FPV_Parametros   WHERE   Parametro = 'Dias_maxV '

--- armamos el correo
--  select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'
-- select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'


---- Asignamos el correo

select @i= count(*) from FPV_Parametros where Parametro ='Mail_AvVac'

    if @i> 1
      begin

          select @correo = dbo.fn_correosVariosRemitentes('Mail_AvVac')
      end


    else
      begin
        select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'

      end


  select @b= count(*) from FPV_Parametros where Parametro = 'Mail_VacCC'

  if @b> 1
      begin

          select   @correoCC   = dbo.fn_correosVariosRemitentes('Mail_VacCC')
      end


    else
      begin
        select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'

      end

  -----------------------------------------------------------------------------------------




set @asunto = 'Punto H: Listado de trabajadores que sobrepasan el tope de dias maximos de vacaciones pendientes'

set @msg = ' Le adjuntamos un listado de los trabajadores que poseen dias de vacaciones pendientes por encima del tope configurado ' +
                    '  el cual es de '+ CONVERT(varchar(4), @tope) +  ' dias. Por favor entrar al utilitario en la seccion de errores vacaciones y generar los ' +
                      '  PDFs para el envio a los diferentes departamentos.'

-- set @saludos = 'Buenos dias'

-- 	    select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }  </style>
--                 </head><body><H1  style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' +@saludos+ '</H1>' +
--         N'<b></b> ' +
--         N'<p> ' +   @msg  + '</p> ' +
--         N'<br/><br /><br/><br/><br/>  <br/><br/><br/>' +
--         '  </body>'   ;

	     select @html =   N'<head> <title></title><style type="text/css">.style10 { width: 153px; text-align: center;} .style12 { color: #800000;text-decoration: underline;   } </style>
                                        </head><body><H1 style="font-family: ''Calibri''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">Buenos D&iacute;as</H1>
                                        <div> <p>   Le adjuntamos un listado de los trabajadores que poseen d&iacute;as de vacaciones pendientes por encima del tope configurado el cual es de 4 d&iacute;as.</p>
                                      <p> Por favor entrar al utilitario en la secci&oacute;n de errores vacaciones y generar los   PDFs para el env&iacute;o a los diferentes departamentos.</p> </p>
                                      <br/><div> <p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=3" target="_blank">Ver Informe</a>   </p>
                                      <br>   <label>Atentamente,</label>   <br>  <br>    <label><strong>Departamento de N&oacute;mina</strong></label></div></body>'   ;

  -- select @query1   = 'Select compania, clase_nomina, cco, trabajador, mail, dias_pendientes from Adam.dbo.VW_FPV_Vacaciones_avisos_MaximosVac order by CCO '

SELECT @totalRegistros = COUNT(*) FROM VW_FPV_Vacaciones_avisos_MaximosVac
set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

        exec msdb.dbo.Sp_send_dbmail
          @profile_name = 'Informacion_Nomina',
        @Subject = @asunto,
        @recipients = @correo	,
        @body_format= 'html',
        @body = @html   ,
        @copy_recipients = @correoCC ;



set @html_nc =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto H: Trabajadores que sobrepasan el tope de dias maximos de vacaciones</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=3" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Listado_topesDiasVac',
     'Punto H: Trabajadores que sobrepasan el tope de dias maximos de vacaciones pendientes',
     @html_nc, @totalRegistros, @correo, @correoCC,
     NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)

    END TRY
    BEGIN CATCH
        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Listado_topesDiasVac',
             'Punto H: Trabajadores que sobrepasan el tope de dias maximos de vacaciones pendientes',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Media', 'VACACIONES', ERROR_MESSAGE())
    END CATCH

End

