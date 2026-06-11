USE [ADAM]
GO
/****** Object:  StoredProcedure [dbo].[sp_fpv_aviso_vacaciones_mayores_20_anios]        Script Date: 8/6/2026 10:41:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----Creado Dennis Suarez
------Fecha 14/07/2016
----Version 1.2
----Recorre la tabla saldo vacaciones y calculamos los anios en la empresa para medir si estan bien asigandos los dias, para aquellos trabajadores.
----que tiene mas de 19 anios

----se modifico el 18-08-2016 para que sea dinamico el correo copia
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 08/06/2026
-- Description:	Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER procedure [dbo].[sp_fpv_aviso_vacaciones_mayores_20_anios]
AS
declare
@trabajador char(10),
@compania char(4),
@fecha_ingreso smalldatetime,
@fecha_antiguedad smalldatetime,
@fecha_iniVacaciones smalldatetime,
@diasToca smallint=0,
@diasDisfrutados smallint=0,
@diasPorCiclo smallint=0,
@aniosTrabajador smallint=0,
@ciclo varchar(10),
@mensaje varchar(3000),
@empresa varchar(100),
@asunto varchar(250),
@nombreTrab varchar(100),
@html varchar(4000),
@saludos varchar(100),
@correo varchar(1000),
@x smallint = 0,
@id char(1),
@desc varchar(30),
@correoCC varchar(1000),
@fecha datetime,
@dia smallint,
@mes smallint,
@anio smallint,
@i smallint=0,
@b smallint=0,
@totalRegistros INT,
@descripcion    VARCHAR(50),
@estado         CHAR(1),
@html_nc        VARCHAR(MAX)
Begin

    BEGIN TRY

----- Seccion C Trabajadores con error en dias asignados si tienen mas de 19 a뿯½os en la empresa.

  set @fecha=  GETDATE()
set @dia   = datepart(day, @fecha)
set @mes   = datepart(month, @fecha)
set @anio  = datepart(year, @fecha)

  -- select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'
  -- select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'



---- Asignamos el correo

select @i=  count(*) from FPV_Parametros where Parametro ='Mail_AvVac'

    if @i>  1
      begin

          select @correo = dbo.fn_correosVariosRemitentes('Mail_AvVac')
      end


    else
      begin
        select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'

      end


  select @b=  count(*) from FPV_Parametros where Parametro =  'Mail_VacCC'

  if @b>  1
      begin

          select   @correoCC   = dbo.fn_correosVariosRemitentes('Mail_VacCC')
      end


    else
      begin
        select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'

      end

  ---------------------------------------------------------------------------------------------------------------------------------------

SELECT @totalRegistros = COUNT(*) FROM VW_FPV_Vacaciones_avisos_error_trabajadores_masde20 WHERE error = 'M'
set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

Declare C_SBDescuadre Cursor For
SELECT     id ,identificador ,compania,trabajador,fecha_antiguedad,fecha_ingreso  ,fecha_ini_prog_vac
            ,ciclo_laboral  ,vac_disfrutadas  ,vac_por_ciclo  ,AniosTrabajados
    FROM VW_FPV_Vacaciones_avisos_error_trabajadores_masde20
    where error = 'M'


Open C_SBDescuadre

  While @@Fetch_Status < 1
    Begin
          Fetch C_SBDescuadre Into @id , @desc ,  @compania, @trabajador,  @fecha_antiguedad   , @fecha_ingreso, @fecha_iniVacaciones  , @ciclo ,  @diasDisfrutados
                                                        , @diasPorCiclo ,  @aniosTrabajador

          If @@Fetch_Status <> 0
                Begin
                      Break
                End

  set @x = @x+1

select @nombreTrab = replace(nombre,  '/', '  ') from trabajadores where trabajador = @trabajador
select @empresa = ltrim(rtrim(nombre_cia)) from companias where compania = @compania


	 if @id = 'a'
	 	 Begin
	 	 	 set @mensaje = '  El presente correo tiene como fin, informale que el trabajador de nombre: '+ @nombreTrab +
                              ', con cedula : '  + @trabajador +  ', que se encuentra activo(a) en la empresa: '  + @empresa + ', y tiene como fecha de antiguedad : '+
                              CONVERT(varchar(15),  @fecha_antiguedad,103) + ' y fecha de ingreso : '  +   CONVERT(varchar(15),  @fecha_antiguedad,103) + ', tiene asignado : ' +
                              CONVERT(varchar(3),  @diasPorCiclo  ) + ' dias en el ciclo ' + @ciclo + ', los cuales no ha disfrutado , pero estan mal asignados '

	 	 end
	 else if @id= 'b'
	 	 Begin
	 	 	 set @mensaje = '  El presente correo tiene como fin, informale que el trabajador de nombre: '+ @nombreTrab +
                              ', con cedula : '  + @trabajador +  ', que se encuentra activo(a) en la empresa: '  + @empresa + ', y tiene como fecha de antiguedad : '+
                              CONVERT(varchar(15),  @fecha_antiguedad,103) + ' y fecha de ingreso : '  +   CONVERT(varchar(15),  @fecha_antiguedad,103) + ', tiene asignado : ' +
                              CONVERT(varchar(3),  @diasPorCiclo  ) + ' dias en el ciclo ' + @ciclo + ', los cuales ha disfrutado: '+ convert(varchar(3),@diasDisfrutados) + ' dias , pero estan mal asignados. '


	 end
	 else if @id= 'c'
	 	 Begin
	 	 	 set @mensaje = '  El presente correo tiene como fin, informale que el trabajador de nombre: '+ @nombreTrab +
                              ', con cedula : '  + @trabajador +  ', que se encuentra activo(a) en la empresa: '  + @empresa + ', y tiene como fecha de antiguedad : '+
                              CONVERT(varchar(15),  @fecha_antiguedad,103) + ' y fecha de ingreso : '  +   CONVERT(varchar(15),  @fecha_antiguedad,103) + ', tiene asignado : ' +
                              CONVERT(varchar(3),  @diasPorCiclo  ) + ' dias en el ciclo ' + @ciclo + ', tiene un error ya que posee mas de 30 dias, lo cual no esta estipulado en ley'


	 end



set @asunto = 'Punto C: Error en la cantidad de dias asignados a trabajadores con mas de 19 a뿯½os en la empresa. Con el trabajador: '  + @nombreTrab

set @saludos = 'Buenos Dias'

select @html = '<head> <title></title> <style type="text/css">.style10 {  width: 153px; text-align: center;   } .style12 {  color: #800000;text-decoration: underline;   }  </head>' +
        N'<body><H1  style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">'+ @saludos+'</H1>' +
        N'<b></b> '+
        N'<p> '+  @mensaje+  '</p> '+
        N'<br/><br /> <br/><br/><br/>  <br/><br/><br/>' +
        ' </body>'  ;

  exec msdb.dbo.Sp_send_dbmail
        @profile_name = 'Informacion_Nomina',
        @Subject = @asunto,
        @recipients =@correo	,
        @body_format=  'html',
        @copy_recipients =  @correoCC,
        @body =  @html ;

        ----insertar registro de envio
Exec sp_fpv_inserta_avisos_vacaciones 'PTO_C_Antg', @mensaje,  @ciclo,  @dia,@mes,@anio,  @trabajador,@fecha,  null,null,null,@correo




      end
    Close             C_SBDescuadre
    Deallocate C_SBDescuadre

        if @x =  0
    Begin
    exec msdb.dbo.Sp_send_dbmail
          @profile_name = 'Informacion_Nomina',
        @Subject = 'Punto C: Aviso Descuadre de dias en vacaciones a trabajadores mayores de 19 a뿯½os en la empresa',
        @recipients =@correo	,
        @body_format=  'html',
        @copy_recipients =  @correoCC,
        @body =  'No Existen descuadres de este tipo en la base';

    end

    set @html_nc =
        '<div style="font-family:Calibri;">' +
        '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
        '<table style="border-collapse:collapse;width:95%;" border="1">' +
        '<tr style="background-color:black;color:white;">' +
        '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
        '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
        '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
        '<tr><td style="padding:4px;">&nbsp;Punto C: Trabajadores con dias asignados mayores a 19 anios</td>' +
        '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
        '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=35" target="_blank">Ver Informe</a></td>' +
        '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_mayores_20_anios',
     'Punto C: Trabajadores con dias asignados mayores a 19 anios',
     @html_nc, @totalRegistros, @correo, @correoCC,
     NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'C_SBDescuadre') >= 0
            CLOSE C_SBDescuadre
        IF CURSOR_STATUS('global', 'C_SBDescuadre') > -2
            DEALLOCATE C_SBDescuadre
        ------------ Insert notificacionesConsolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_mayores_20_anios',
             'Punto C: Error en dias asignados a trabajadores con mas de 19 anios en la empresa',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Media', 'VACACIONES', ERROR_MESSAGE())
    END CATCH

END ---fin
