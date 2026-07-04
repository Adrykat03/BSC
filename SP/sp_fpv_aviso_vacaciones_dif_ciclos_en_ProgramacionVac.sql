USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[sp_fpv_aviso_vacaciones_dif_ciclos_en_ProgramacionVac]        Script Date: 8/6/2026 10:49:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
---- Creado Dennis Suarez
----- Fecha 20/07/2016
---- Version 1.2
  -- g) 	 f) 	 Aviso de ciclos no creados por trabajador (con el mes de ingreso) Ejemplo: ingreso en abril de 2016,
  -- al finalizar la nomina de abril se debe crear el ciclo 2016-2017. Ejemplo. Ingreso en mayo 2010, al finalizar
  -- la nomina de abril, solo debe tener el periodo 2015-2016.

 --- se modifico el 18-08-2016 para que sea dinamico el correo copia
-- Author: Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas

ALTER procedure [dbo].[sp_fpv_aviso_vacaciones_dif_ciclos_en_ProgramacionVac]
AS
declare
@compania char(4),
@trabajador char(10),
@ciclo varchar(10),
@x smallint = 0,
@w smallint=0,
@y smallint = 0,
@t smallint = 0,
@a smallint= 0,
@r smallint = 0,
@q smallint = 0,
@empresa varchar(100),
@query1 varchar(max),
@mensaje varchar(2000),
@asunto varchar(250),
@nombreTrab varchar(100),
@html varchar(4000),
@correoCC varchar(1000),
@saludos varchar(100),
@correo varchar(1000) ,
@msg varchar(500),
@fechaIngreso smalldatetime,
@anio smallint,
@i smallint=0,
@b smallint=0

Begin --- comienzo del proceso
    BEGIN TRY



  -- select @correo = Valor from FPV_Parametros where Parametro ='Mail_AvVac'
  -- select @correoCC = Valor from FPV_Parametros where Parametro ='Mail_VacCC'


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


---- limpiamos la tabla temporal
delete fpv_avisos_dif_ciclos_temp


--- armamos el correo
set @asunto = 'Punto G: Diferencias entre los ciclos en la programacion , para los reingresos en otras empresas (causa baja 08)'
set @msg = ' Le adjuntamos un listado de los problemas que existen con los datos de la tabla detalle de vacaciones, para los trabajadores que son reingresos'
set @saludos = 'Buenos dias'

      --  select @html = '<head> <title></title> <style type="text/css">.style10 { width: 153px; text-align: center;   } .style12 { color: #800000;text-decoration: underline;   }  </style></head>' +
      --  N'<body><H1   style="font-family: ''Trebuchet MS''; font-size: medium; font-weight: bold; font-style: normal; color: #993300">' +@saludos+ '</H1>' +
      --  N'<b></b> ' +
      --  N'<p> ' +   @msg  + '</p> ' +
      --  N' <br/><div> <p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=4" target="_blank">Ver Informe</a>   </p>
      -- <br>   <label>Atentamente,</label>   <br>  <br>    <label><strong>Departamento de N&oacute;mina</strong></label></div></body>' ;



-------- Comenzamos con el bicle de busqueda de errores

  Declare C_BuscarTrabReDet Cursor For
SELECT         Trabajador, COUNT(distinct Compania) AS companias
FROM               dbo.FPV_Datos_Trabajador_Nomina
where trabajador in (select Trabajador from trabajadores_grales where sit_trabajador = 1)
GROUP BY Trabajador
HAVING        (COUNT(distinct Compania) > 1)

Open C_BuscarTrabReDet

  While @@Fetch_Status < 1
    Begin
          Fetch C_BuscarTrabReDet Into @trabajador , @x

          If @@Fetch_Status <> 0
                Begin
                      Break
                End

      select @nombreTrab = replace(nombre, '/', ' ') from trabajadores where trabajador = @trabajador

      select @empresa = ltrim(rtrim(nombre_cia)) from companias where compania = (select top(1) compania from trabajadores_grales
      where trabajador =@trabajador and sit_trabajador = 1)

      select @fechaIngreso = fecha_ingreso
      from trabajadores_grales
      where sit_trabajador = 1 and trabajador =  @trabajador

    set @anio =   DATEPART(year, @fechaIngreso )

----- preguntamos si estan las empresas en saldos vacaciones primero

    Select @w = COUNT(distinct compania) from programacion_vacaciones
    where trabajador = @trabajador


  if @w <> @X
    Begin


          select @mensaje =   'No estan en el detalle de vacaciones los ciclos de todas las empresas donde trabajo el empleado con cedula: ' + @trabajador

    end
  Else
  -------------- me quede aca ojo debe ser mas o menos lo mismo

  ----- Buscamos si ya tienen las dos empresas si tienen la misma cantidad de ciclo
        Begin

                select @t =   COUNT(trabajador) from   dbo.fn_TB_count_dif_prog_Ciclos_vac(@trabajador, @fechaIngreso)
                if @t > 1
                  Begin

                    select @mensaje =   'No tiene la misma cantidad de ciclos creados en todas las empresas donde trabajo el empleado con cedula: '   + @trabajador + ', en la programacion de vacaciones'

                      INSERT INTO   fpv_avisos_dif_ciclos_temp
                      (tipo ,compania ,empresa ,trabajador ,nombre,ciclo ,mensaje,fecha)
                    VALUES ('Error_Cant_ciclos_Pro', @compania, @empresa,@trabajador,@nombreTrab,null,@mensaje,GETDATE() )

                  end --- fin problemas ciclos
                else
                  Begin
                ----- Buscamos ahora si no es un problama de ciclos buscar si estan bien asignados bien los dias de vacaciones

                    select   @r = COUNT(trabajador) from dbo.fn_TB_count_dif_prog_vac(@trabajador, @fechaIngreso)
                      if @r > 1
                      begin

                          select @mensaje =   'No tiene la misma cantidad de dias asignados, en todos los ciclos de las empresas donde trabajo el empleado con cedula: '   + @trabajador + ', en la programacion de vacaciones'

                          INSERT INTO   fpv_avisos_dif_ciclos_temp
                          (tipo ,compania ,empresa ,trabajador ,nombre,ciclo ,mensaje,fecha)
                          VALUES ('Error_dias_asignados_Pro', @compania, @empresa,@trabajador,@nombreTrab,null,@mensaje,GETDATE() )


                      end --- fin problemas dias vac asignados

                End --- fin de todas las diferencias (tipos ) de ciclos y dias
          end


end
    Close       C_BuscarTrabReDet
    Deallocate   C_BuscarTrabReDet

  -- select @query1   = '  SELECT tipo,compania,empresa ,trabajador,nombre , mensaje ,fecha FROM Adam.dbo.fpv_avisos_dif_ciclos_temp order by tipo '

  select @html = '<head><title></title><style type="text/css">.style10{width:153px;text-align:center}.style12{color:maroon;text-decoration:underline}</style></head><body><h1 style="font-family:''Calibri'';font-size:medium;font-weight:700;font-style:normal;color:#930">Buenos D&iacute;as</h1><b></b><p>Le adjuntamos un listado de los problemas que existen con los datos de la tabla detalle de vacaciones, para los trabajadores que son reingresos</p><br><div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=4" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de N&oacute;mina</strong></label></div></body>' ;

    if (select count(*) from fpv_avisos_dif_ciclos_temp where tipo ='Error_dias_asignados_Pro') = 0
    begin
            set @html = '<p>No existen problemas de Diferencias entre los ciclos en la programacion , para los reingresos en otras empresas (causa baja 08)</p>'
	      exec msdb.dbo.Sp_send_dbmail
        @profile_name='Mail_Sql_Adam',
        @Subject = @asunto,
        @recipients = @correo	,
        @body_format= 'html',
        @body = @html   ,
	@blind_copy_recipients = 'dennis.suarez@gmail.com',
        @copy_recipients = @correoCC ;
    end
    else
    begin
      exec msdb.dbo.Sp_send_dbmail
        @profile_name='Mail_Sql_Adam',
        @Subject = @asunto,
        @recipients = @correo	,
        @body_format= 'html',
        @body = @html   ,
	@blind_copy_recipients = 'dennis.suarez@gmail.com',
        @copy_recipients = @correoCC ;

    end

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'C_BuscarTrabReDet') >= 0
            CLOSE C_BuscarTrabReDet
        IF CURSOR_STATUS('global', 'C_BuscarTrabReDet') > -2
            DEALLOCATE C_BuscarTrabReDet
        ;THROW;
    END CATCH
End --- fin del proceso

