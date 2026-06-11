USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[sp_fpv_aviso_vacaciones_TrabajadoresMAsUnaEmpresa]        Script Date: 8/6/2026 10:52:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----- Creado Dennis Suarez
----- Fecha 14/08/2017
---- Version 1.0
---- Busca los trabajadores que estan activos en mas de una empresa y manda sus saldosde vacaciones
---- Es el punto I
-- Author: Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas
ALTER procedure [dbo].[sp_fpv_aviso_vacaciones_TrabajadoresMAsUnaEmpresa]
AS
declare
@trabajador char(10),
@compania char(4),
@fecha_ingreso smalldatetime,
@fecha_antiguedad smalldatetime,
@fecha_iniVacaciones smalldatetime,
@ciclo varchar(10),
@mensaje varchar(3000),
@empresa varchar(100),
@asunto varchar(250),
@nombreTrab varchar(100),
@html varchar(4000),
@saludos varchar(100),
@correo varchar(1000),
@x smallint = 0,
@fecha datetime,
@dia smallint,
@mes smallint,
@anio smallint,
@i smallint=0,
@b smallint=0,
@query1 varchar(max),
@comilla char(1),
@correoCC varchar(1000),
@totalRegistros INT,
@descripcion    VARCHAR(50),
@estado         CHAR(1),
@html_nc        VARCHAR(MAX)

Begin

    BEGIN TRY

--- vemos que el mes sea diferente entre la fecha de antiguedad y la fecha de inicio de la vacion
  set @comilla = CHAR(39)
  set @fecha= GETDATE()
set @dia = datepart(day,@fecha)
set @mes = datepart(month,@fecha)
set @anio = datepart(year,@fecha)


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

  select @x =   Count(*) from VW_AvisoVacI4

SELECT @totalRegistros = COUNT(*) FROM VW_AvisoVacI4
set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end


    set @mensaje =   ' Le adjuntamos un listado de saldos vacaciones de todos los trabajadores que se encuentran activos en mas de una empresa, en el sistema de n&oacute;mina. ' +
                                    ', por favor revisar. '


set @asunto = 'Punto I.4: Listado de vacaciones de trabajadores que estan activos en mas de una empresa.   '

set @saludos = 'Buenos Dias'

select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }  </head>' +
        N'<body><H1   style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' +@saludos+ '</H1>' +
        N'<b></b> ' +
        N'<p> ' + @mensaje +  '</p> ' +
        N'<br/><div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=12" target="_blank">Ver Informe</a></p>
            <br><label>Atentamente,</label><br><br><label><strong>Departamento de N&oacute;mina</strong></label></div>' +
        '  </body>'   ;


	 -- select @query1   = '  Select codigo, convert(varchar(60),nombre) as nombre, trabajador, cco, clase_nomina, fecha_antiguedad, fecha_ingreso, ciclo_laboral,   diasPtes     From   Adam.dbo.VW_AvisoVacI4 '

    exec msdb.dbo.Sp_send_dbmail
        @profile_name = 'Informacion_Nomina',
        @Subject = @asunto,
        @recipients =       @correo	,
        @body_format= 'html',
        @body = @html   ,
        -- @query = @query1 ,
        -- @query_result_width = 32767,
        -- @query_result_separator= ',' ,
        @copy_recipients = @correoCC;
        -- @query_attachment_filename = 'ListadoTrabMAsdeUnaEmpresaAdam.csv',
      --  @attach_query_result_as_file = 1 ;


        if @x = 0
          Begin
            exec msdb.dbo.Sp_send_dbmail
            @Subject = 'Punto I3: Listado de vacaciones detrabajadores que estan activos en mas de una empresa.   ',
            @recipients = @correo,
            @body_format= 'html',
            @copy_recipients = @correoCC,
            @body = 'No Existen trabajadores con saldos de vacaciones que trabajen en mas de una empresa';

    end


set @html_nc =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto I.4: Trabajadores activos en mas de una empresa</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=12" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_TrabajadoresMAsUnaEmpresa',
     'Punto I.4: Trabajadores activos en mas de una empresa',
     @html_nc, @totalRegistros, @correo, @correoCC,
     NULL, NULL, @descripcion, 'Baja', 'VACACIONES', NULL)

    END TRY
    BEGIN CATCH
        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_TrabajadoresMAsUnaEmpresa',
             'Punto I.4: Trabajadores activos en mas de una empresa',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Baja', 'VACACIONES', ERROR_MESSAGE())
    END CATCH

End
