USE [ADAM]
GO
/****** Object:  StoredProcedure [dbo].[sp_fpv_aviso_vacaciones_Fecha_ini_fecha_ant_iguales]        Script Date: 8/6/2026 10:42:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----Creado Dennis Suarez
------Fecha 14/07/2016
----Version 1.2
-- d) 	En el caso de que la fecha de ingreso y la de antig뿯½edad de un trabajador sean iguales y en vacaciones
--   hay una fecha diferente al aniversario, se debe enviar un aviso.

--- se modifico el 18-08-2016 para que sea dinamico el correo copia
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 08/06/2026
-- Description:	Se inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER   procedure [dbo].[sp_fpv_aviso_vacaciones_Fecha_ini_fecha_ant_iguales]
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
@correoCC varchar(1000),
@x smallint = 0,
@id varchar(6),
@desc varchar(30),
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

----- Seccion D Trabajadores  con igual fecha de antiguedad y fecha ingreso con error en la fecha asignada para el comienzo de vacaciones

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


SELECT @totalRegistros = COUNT(*)
FROM (
    select T.compania, T.trabajador, T.fecha_antiguedad, T.fecha_ingreso, V.fecha_ini_prog_vac, V.ciclo_laboral
    from saldos_vacaciones V inner join trabajadores_grales T
    on v.trabajador = T.trabajador and V.compania = T.compania
    where     T.sit_trabajador = 1
    and fecha_antiguedad = fecha_ingreso
    and DATEPART(month,fecha_ingreso)<>DATEPART(month,fecha_ini_prog_vac)
    UNION ALL
    select T.compania, T.trabajador, T.fecha_antiguedad, T.fecha_ingreso, V.fecha_ini_prog_vac, V.ciclo_laboral
    from saldos_vacaciones V inner join trabajadores_grales T
    on v.trabajador = T.trabajador and V.compania = T.compania
    where     T.sit_trabajador = 1
    and fecha_antiguedad = fecha_ingreso
    and DATEPART(day,fecha_ingreso)<>DATEPART(day,fecha_ini_prog_vac)
) AS sub

set @descripcion = case when @totalRegistros > 0 then 'Con novedad' else 'Sin novedad' end
set @estado      = case when @totalRegistros > 0 then 'A'           else 'C'           end

Declare C_SBDescuadre Cursor For
  select 'Mes' as Tipo,  T.compania,  T.trabajador,T.fecha_antiguedad,  T.fecha_ingreso  ,V.fecha_ini_prog_vac,  V.ciclo_laboral
  from saldos_vacaciones V inner join trabajadores_grales T
on v.trabajador = T.trabajador and V.compania = T.compania
where     T.sit_trabajador = 1
and fecha_antiguedad = fecha_ingreso
and DATEPART(month,fecha_ingreso)<>DATEPART(month,fecha_ini_prog_vac)
union
  select 'Dias' as Tipo,  T.compania,  T.trabajador,T.fecha_antiguedad,  T.fecha_ingreso  ,V.fecha_ini_prog_vac,  V.ciclo_laboral
  from saldos_vacaciones V inner join trabajadores_grales T
on v.trabajador = T.trabajador and V.compania = T.compania
where     T.sit_trabajador = 1
and fecha_antiguedad = fecha_ingreso
and DATEPART(day,fecha_ingreso)<>DATEPART(day,fecha_ini_prog_vac)



Open C_SBDescuadre

  While @@Fetch_Status < 1
    Begin
          Fetch C_SBDescuadre Into @id ,  @compania, @trabajador,  @fecha_antiguedad   , @fecha_ingreso, @fecha_iniVacaciones  , @ciclo

          If @@Fetch_Status <> 0
                Begin
                      Break
                End

  set @x = @x+1

select @nombreTrab = replace(nombre,  '/', '  ') from trabajadores where trabajador = @trabajador
select @empresa = ltrim(rtrim(nombre_cia)) from companias where compania = @compania


	 if @id = 'Mes'
	 	 Begin
	 	 	 set @mensaje = '  El presente correo tiene como fin, informale que el trabajador de nombre: '+ @nombreTrab +
                              ', con cedula : '  + @trabajador +  ', que se encuentra activo(a) en la empresa: '  + @empresa + ', y tiene como fecha de antiguedad : '+
                              CONVERT(varchar(15),  @fecha_antiguedad,103) + ' y fecha de ingreso : '  +   CONVERT(varchar(15),  @fecha_antiguedad,103) +
                              ', tiene un error en la fecha de asignacion de comienzo de vacaciones ( tiene un error en el mes) , la fecha colocada es : ' +CONVERT(varchar(15),@fecha_iniVacaciones,103)

	 	 end
	 else if @id= 'Dias'
	 	 Begin
	 	 	 set @mensaje = '  El presente correo tiene como fin, informale que el trabajador de nombre: '+ @nombreTrab +
                              ', con cedula : '  + @trabajador +  ', que se encuentra activo(a) en la empresa: '  + @empresa + ', y tiene como fecha de antiguedad : '+
                              CONVERT(varchar(15),  @fecha_antiguedad,103) + ' y fecha de ingreso : '  +   CONVERT(varchar(15),  @fecha_antiguedad,103) +
                              ', tiene un error en la fecha de asignacion de comienzo de vacaciones ( tiene un error en el dia) , la fecha colocada es : ' +CONVERT(varchar(15),@fecha_iniVacaciones,103)

          End



set @asunto = 'Punto D: Error en la fecha asignada para el comienzo de vacaciones de un ciclo. Con el trabajador: '  + @nombreTrab

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
Exec sp_fpv_inserta_avisos_vacaciones 'PTO_D_ErrorDias', @mensaje,  @ciclo,  @dia,@mes,@anio,  @trabajador,@fecha,  null,null,null,@correo


      end
    Close             C_SBDescuadre
    Deallocate C_SBDescuadre

        if @x =  0
    Begin
    exec msdb.dbo.Sp_send_dbmail
        @profile_name = 'Informacion_Nomina',
        @Subject = 'Punto D: No hay trabajadores con error en la fecha asignada para el comienzo de vacaciones de un ciclo',
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
        '<tr><td style="padding:4px;">&nbsp;Punto D: Fecha de inicio de vacaciones igual a fecha de antiguedad</td>' +
        '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros as varchar(10)) + '</td>' +
        '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=40" target="_blank">Ver Informe</a></td>' +
        '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Fecha_ini_fecha_ant_iguales',
     'Punto D: Fecha de inicio de vacaciones igual a fecha de antiguedad',
     @html_nc, @totalRegistros, @correo, @correoCC,
     NULL, NULL, @descripcion, 'Media', 'VACACIONES', NULL)

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'C_SBDescuadre') >= 0
            CLOSE C_SBDescuadre
        IF CURSOR_STATUS('global', 'C_SBDescuadre') > -2
            DEALLOCATE C_SBDescuadre
        --Insert en notificaciones consolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Fecha_ini_fecha_ant_iguales',
             'Punto D: Fecha de inicio de vacaciones igual a fecha de antiguedad',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Media', 'VACACIONES', ERROR_MESSAGE())
    END CATCH
END ---fin

