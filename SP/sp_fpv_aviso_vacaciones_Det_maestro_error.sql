USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[sp_fpv_aviso_vacaciones_Det_maestro_error]        Script Date: 8/6/2026 10:43:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

---- Creado Dennis Suarez
----- Fecha 14/09/2016
---- Version 1.2
---- e) 	Aviso de mucha, importancia cuando el estatus del ciclo de vacaciones de un trabajador,
---- tiene en la cabecera una opci�n diferente en el estatus (programada) a lo que tiene el detalle.
---- Se realizo un cambio el dia 17-08-2016 ya que en registrada no teniamos el query correcto para el conteo del valor x.


-- se modifico el 18-08-2016 para que sea dinamico el correo copia

-- Author: Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas

ALTER   procedure [dbo].[sp_fpv_aviso_vacaciones_Det_maestro_error]
As
declare
@asunto varchar(250),
@query1 varchar(max),
@mensaje varchar(300),
@html varchar(4000),
@saludos varchar(100),
@correo varchar(1000),
@correoCC varchar(1000),
@fecha datetime,
@dia smallint,
@mes smallint,
@anio smallint,
@x smallint=0,
@i smallint=0,
@b smallint=0,
@totalRegistros_E1  INT,
@totalRegistros_E2  INT,
@totalRegistros_E4  INT,
@descripcion_E1     VARCHAR(50),
@descripcion_E2     VARCHAR(50),
@descripcion_E4     VARCHAR(50),
@estado_E1          CHAR(1),
@estado_E2          CHAR(1),
@estado_E4          CHAR(1),
@html_nc_E1         VARCHAR(MAX),
@html_nc_E2         VARCHAR(MAX),
@html_nc_E4         VARCHAR(MAX)
Begin
    BEGIN TRY

set @fecha=  GETDATE()
set @dia  =  datepart(day,@fecha)
set @mes  =  datepart(month,@fecha)
set @anio  =  datepart(year,@fecha)
set @asunto = ''
set @query1 = ''
set @mensaje = ''
set @html = ''

----- Seccion E Trabajadores con diferencia entre el detalle y la cabecera

set @saludos =  'Buenos Dias'

  --select @correo =  Valor from FPV_Parametros where Parametro ='Mail_AvVac'
  --select @correoCC =  Valor from FPV_Parametros where Parametro ='Mail_VacCC'


---- Asignamos el correo

select @i=  count(*) from FPV_Parametros where Parametro ='Mail_AvVac'

    if @i>  1
      begin

          select @correo =  dbo.fn_correosVariosRemitentes('Mail_AvVac')
      end


    else
      begin
        select @correo =  Valor from FPV_Parametros where Parametro ='Mail_AvVac'

      end


  select @b=  count(*) from FPV_Parametros where Parametro =  'Mail_VacCC'

  if @b>  1
      begin

          select   @correoCC   =  dbo.fn_correosVariosRemitentes('Mail_VacCC')
      end


    else
      begin
        select @correoCC =  Valor from FPV_Parametros where Parametro ='Mail_VacCC'

      end

  ---------------------------------------------------------------------------------------------------------------------------------------



      exec    pa_aviso_vac_E01

------------ Count E-1
SELECT @totalRegistros_E1 = COUNT(*)
FROM Adam.dbo.programacion_vacaciones
WHERE situacion_programa = 1

SET @descripcion_E1 = 'Punto E-1: Det. registradas y cab. disfrutadas con error'
SET @estado_E1 = CASE WHEN @totalRegistros_E1 > 0 THEN 'A' ELSE 'C' END

------------ NC Insert E-1
set @html_nc_E1 =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto E-1: Det. registradas y cab. disfrutadas con error</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros_E1 as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=13" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado_E1, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Det_maestro_error',
     'Punto E-1: Det. registradas y cab. disfrutadas con error',
     @html_nc_E1, @totalRegistros_E1, @correo, @correoCC,
     NULL, NULL, @descripcion_E1, 'Alta', 'VACACIONES', NULL)

-------------- Fin de registradas

select @x = 0
set @asunto = ''
set @query1 = ''
set @mensaje = ''
set @html = ''

-------------- Confirmadas

  select @x=  count  (*)
    from Adam.dbo.programacion_vacaciones as P inner join Adam.dbo.trabajadores_grales as T
    on P.trabajador = T.trabajador   and P.compania = T.compania
    inner join Adam.dbo.saldos_vacaciones V
    on P.ciclo_laboral = V.ciclo_laboral and P.trabajador = V.trabajador   and P.compania = V.compania
    where situacion_programa   = 2
    and T.sit_trabajador = 1
    and V.vac_disfrutadas > 0

if @x>0
Begin
--select @query1 =   '  select T.compania,T.clase_nomina,  T.trabajador,  T.fecha_antiguedad,T.fecha_ingreso,  ' +
--  '  P.ciclo_Laboral,P.tiempo_prog_vac,  P.situacion_programa,  V.vac_disfrutadas,  V.vac_programadas,  ' +
--  '  V.vac_por_ciclo  ' +
--  '  from Adam.dbo.programacion_vacaciones as P inner join Adam.dbo.trabajadores_grales as T  ' +
--  '  on P.trabajador = T.trabajador   and P.compania = T.compania     ' +
--  '  inner join Adam.dbo.saldos_vacaciones V    ' +
--  '  on P.ciclo_laboral = V.ciclo_laboral and P.trabajador = V.trabajador   and P.compania = V.compania  ' +
--  '  where situacion_programa   = 2  ' +
--  '  and T.sit_trabajador = 1  ' +
--  '  and V.vac_disfrutadas > 0  '

Set @asunto =  'Punto E-4: Trabajadores que tienen en el detalle las vacaciones como confirmadas y en la cabecera sale como disfrutadas'

set @mensaje =  'Se adjunta listado en formato csv de trabajadores con este problema. Pueden abrir con Excel, el separador de columnas es la coma(,).'

select @html =  '<head> <title></title> <style type="text/css">.style10 {  width: 153px; text-align: center;   } .style12 {  color: #800000;text-decoration: underline;   }  </head>' +
        N'<body><H1   style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">'+ @saludos +'</H1>' +
        N'<b></b> '+
        N'<p> '+  @mensaje+  '</p> ' +
        N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=10" target="_blank">Ver Informe</a></p>
            <br><label>Atentamente,</label><br><br><label><strong>Departamento de N&#243;mina</strong></label></div>' +
        '  </body>'   ;


      exec msdb.dbo.Sp_send_dbmail
        @profile_name =  'Informacion_Nomina' ,
        @Subject =  @asunto,
        @recipients =  @correo	 ,
        @body_format=  'html',
        @body =  @html   ,
	@copy_recipients =  @correoCC;
      --  @query =  @query1  ,
        --@query_result_separator=',' ,
        --@query_result_width =  2000,
      --
      --  @query_attachment_filename =  'Confirmadas.csv',
      --  @attach_query_result_as_file =  1 ;

---- insertar registro de envio
Exec sp_fpv_inserta_avisos_vacaciones 'PTO_E_Confirmadas', @mensaje,  '', @dia, @mes, @anio,  '', @fecha,  null,null,null,@correo

End
------- Si no hay registros de confirmadas

else if @x=0
      Begin

    set @asunto=  'Punto E-4: Trabajadores que tienen en el detalle las vacaciones como confirmadas y en la cabecera sale como disfrutadas'

        exec msdb.dbo.Sp_send_dbmail
	   @profile_name =  'Informacion_Nomina' ,
          @Subject =  @asunto,
          @recipients =  @correo	 ,
          @body_format=  'html',
          @body =  'No se encontraron registros con problemas en Confirmadas'    ,
          @query_result_separator=',' ,
          @copy_recipients =  @correoCC ;

    end

------------ Count E-4
SELECT @totalRegistros_E4 = COUNT(*)
FROM Adam.dbo.programacion_vacaciones AS P
INNER JOIN Adam.dbo.trabajadores_grales AS T
    ON P.trabajador = T.trabajador AND P.compania = T.compania
INNER JOIN Adam.dbo.saldos_vacaciones V
    ON P.ciclo_laboral = V.ciclo_laboral AND P.trabajador = V.trabajador AND P.compania = V.compania
WHERE situacion_programa = 2
    AND T.sit_trabajador = 1
    AND V.vac_disfrutadas > 0

SET @descripcion_E4 = 'Punto E-4: Det. confirmadas y cab. disfrutadas con error'
SET @estado_E4 = CASE WHEN @totalRegistros_E4 > 0 THEN 'A' ELSE 'C' END

------------ NC Insert E-4
set @html_nc_E4 =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto E-4: Det. confirmadas y cab. disfrutadas con error</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros_E4 as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=10" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado_E4, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Det_maestro_error',
     'Punto E-4: Det. confirmadas y cab. disfrutadas con error',
     @html_nc_E4, @totalRegistros_E4, @correo, @correoCC,
     NULL, NULL, @descripcion_E4, 'Alta', 'VACACIONES', NULL)

--------------- Fin de confirmadas

select @x   = 0
set @asunto = ''
set @query1 = ''
set @mensaje = ''
set @html = ''

--------- Disfrutadas


select @x  =    COUNT(*)
    from Adam.dbo.programacion_vacaciones as P inner join Adam.dbo.trabajadores_grales as T
    on P.trabajador = T.trabajador   and P.compania = T.compania
    inner join Adam.dbo.saldos_vacaciones V
    on P.ciclo_laboral = V.ciclo_laboral and P.trabajador = V.trabajador     and P.compania = V.compania
    where situacion_programa   = 3
    and T.sit_trabajador = 1
    and V.vac_programadas > 0
    and vac_disfrutadas <> (select SUM(tiempo_prog_vac) from Adam.dbo.programacion_vacaciones where trabajador = T.trabajador
    and compania = T.compania and ciclo_laboral = V.ciclo_laboral and situacion_programa   = 3      )

if @x >  0
  Begin
  --  select @query1 =  'Select T.compania,T.clase_nomina,  T.trabajador,  T.fecha_antiguedad,T.fecha_ingreso,  ' +
  -- '  P.ciclo_Laboral,P.tiempo_prog_vac,  P.situacion_programa,  V.vac_disfrutadas,  V.vac_programadas,  ' +
  -- '  V.vac_por_ciclo  ' +
  -- '  from Adam.dbo.programacion_vacaciones as P inner join Adam.dbo.trabajadores_grales as T  ' +
  -- '  on P.trabajador = T.trabajador   and P.compania = T.compania  ' +
  -- '  inner join Adam.dbo.saldos_vacaciones V    ' +
  -- '  on P.ciclo_laboral = V.ciclo_laboral and P.trabajador = V.trabajador     and P.compania = V.compania    ' +
  -- '  where situacion_programa   = 3  ' +
  -- '  and T.sit_trabajador = 1  ' +
  -- '  and V.vac_programadas > 0  ' +
  -- '  and vac_disfrutadas <> (select SUM(tiempo_prog_vac) from Adam.dbo.programacion_vacaciones where trabajador = T.trabajador  ' +
  -- '  and compania = T.compania and ciclo_laboral = V.ciclo_laboral and situacion_programa   = 3      )' +
  -- '  and P.tiempo_prog_vac = (select SUM(tiempo_prog_vac) from Adam.dbo.programacion_vacaciones where trabajador = T.trabajador    ' +
  -- '  and compania = T.compania and ciclo_laboral = V.ciclo_laboral and situacion_programa   = 3      )  -  vac_disfrutadas  '


Set @asunto =  'Punto E-2: Trabajadores que tienen en el detalle las vacaciones como disfrutadas y en la cabecera sale como programadas'

set @mensaje =  'Se adjunta listado en formato csv de trabajadores con este problema. Pueden abrir con Excel, el separador de columnas es la coma(,).'

select @html =  '<head> <title></title> <style type="text/css">.style10 {  width: 153px; text-align: center;   } .style12 {  color: #800000;text-decoration: underline;   }  </head>' +
        N'<body><H1   style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">'+ @saludos +'</H1>' +
        N'<b></b> '+
        N'<p> '+  @mensaje+  '</p> ' +
        N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=11" target="_blank">Ver Informe</a></p>
            <br><label>Atentamente,</label><br><br><label><strong>Departamento de N&#243;mina</strong></label></div>' +
        '  </body>'   ;


    exec msdb.dbo.Sp_send_dbmail
          @profile_name =  'Informacion_Nomina' ,
        @Subject =  @asunto,
        @recipients =  @correo	 ,
        @body_format=  'html',
        @body =  @html  ;
        --@query =  @query1  ,
        --@query_result_separator=',' ,
        --@copy_recipients =  @correoCC,
      --  @query_attachment_filename =  'Disfrutadas.csv',
        --@attach_query_result_as_file =  1 ;

---- insertar registro de envio
Exec sp_fpv_inserta_avisos_vacaciones 'PTO_E_Disfrutadas', @mensaje,  '', @dia, @mes, @anio,  '', @fecha,  null,null,null,@correo

------ si no se encuentran registros
  end
  else if @x=0
      Begin

    Set @asunto =  'Punto E-2: Trabajadores que tienen en el detalle las vacaciones como disfrutadas y en la cabecera sale como programadas'

        exec msdb.dbo.Sp_send_dbmail
	   @profile_name =  'Informacion_Nomina' ,
          @Subject =  @asunto,
          @recipients =  @correo	 ,
          @body_format=  'html',
          @body =  'No se encontraron registros con problemas en Disfrutadas'    ,
          @query_result_separator=',' ,
          @copy_recipients =  @correoCC ;

      end


------------ Count E-2
SELECT @totalRegistros_E2 = COUNT(*)
FROM Adam.dbo.programacion_vacaciones AS P
INNER JOIN Adam.dbo.trabajadores_grales AS T
    ON P.trabajador = T.trabajador AND P.compania = T.compania
INNER JOIN Adam.dbo.saldos_vacaciones V
    ON P.ciclo_laboral = V.ciclo_laboral AND P.trabajador = V.trabajador AND P.compania = V.compania
WHERE situacion_programa = 3
    AND T.sit_trabajador = 1
    AND V.vac_programadas > 0
    AND vac_disfrutadas <> (SELECT SUM(tiempo_prog_vac) FROM Adam.dbo.programacion_vacaciones
                             WHERE trabajador = T.trabajador
                               AND compania = T.compania
                               AND ciclo_laboral = V.ciclo_laboral
                               AND situacion_programa = 3)

SET @descripcion_E2 = 'Punto E-2: Det. disfrutadas y cab. programadas con error'
SET @estado_E2 = CASE WHEN @totalRegistros_E2 > 0 THEN 'A' ELSE 'C' END

------------ NC Insert E-2
set @html_nc_E2 =
    '<div style="font-family:Calibri;">' +
    '<p>Buenos d&iacute;as estimado(a) analista, se adjunta listado de avisos de vacaciones.</p>' +
    '<table style="border-collapse:collapse;width:95%;" border="1">' +
    '<tr style="background-color:black;color:white;">' +
    '<td style="text-align:center;padding:4px;width:81%;"><strong>Descripci&oacute;n</strong></td>' +
    '<td style="text-align:center;padding:4px;width:11%;"><strong>Registros</strong></td>' +
    '<td style="text-align:center;padding:4px;width:8%;"><strong>Reporte</strong></td></tr>' +
    '<tr><td style="padding:4px;">&nbsp;Punto E-2: Det. disfrutadas y cab. programadas con error</td>' +
    '<td style="text-align:center;padding:4px;">' + CAST(@totalRegistros_E2 as varchar(10)) + '</td>' +
    '<td style="text-align:center;padding:4px;"><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=11" target="_blank">Ver Informe</a></td>' +
    '</tr></table></div>'

------------ Insert notificacionesConsolidadas
INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
    (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
     periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
VALUES
    (@estado_E2, 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Det_maestro_error',
     'Punto E-2: Det. disfrutadas y cab. programadas con error',
     @html_nc_E2, @totalRegistros_E2, @correo, @correoCC,
     NULL, NULL, @descripcion_E2, 'Alta', 'VACACIONES', NULL)

--------- Fin de disfrutadas
select @x   = 0
set @asunto = ''
set @query1 = ''
set @mensaje = ''
set @html = ''

--------- Fin Disfrutadas parcialmente
    END TRY
    BEGIN CATCH
        --Insert en notificaciones consolidadas
        INSERT INTO DB_NOMKFC.Avisos.notificacionesConsolidadas
            (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc,
             periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
        VALUES
            ('E', 'Mail_AvVac', 'sp_fpv_aviso_vacaciones_Det_maestro_error',
             'Error en proceso de avisos vacaciones Det Maestro',
             NULL, NULL, ISNULL(@correo, ''), ISNULL(@correoCC, NULL),
             NULL, NULL, 'Error Proceso', 'Alta', 'VACACIONES', ERROR_MESSAGE())
    END CATCH
END
