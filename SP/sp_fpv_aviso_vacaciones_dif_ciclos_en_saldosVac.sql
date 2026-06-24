USE [ADAM]
GO
/****** Object:  Stored Procedure [dbo].[sp_fpv_aviso_vacaciones_dif_ciclos_en_saldosVac]        Script Date: 8/6/2026 10:48:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
---- Creado Dennis Suarez
----- Fecha 14/07/2016
---- Version 1.2
  -- g) 	 Aviso cuando se genere transferencia de personal, donde
  -- detalle que diferencias hay de vacaciones, tanto en detalle como en saldos de la empresa anterior, con la actual.


 --- se modifico el 18-08-2016 para que sea dinamico el correo copia
-- Author: Katerin Carrillo
-- Create date: 08/06/2026
-- Description: Se inserta los datos en la tabla notificacionesConsolidadas

ALTER procedure  [dbo].[sp_fpv_aviso_vacaciones_dif_ciclos_en_saldosVac]
AS
declare
@compania char(4),
@companiaACT char(4),
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
@correoCC varchar(100),
@html varchar(4000),
@saludos varchar(100),
@correo varchar(1000) ,
@fecha_ingreso smalldatetime,
@msg varchar(500),
@i smallint=0,
@b smallint=0,
@z smallint = 0

Begin --- comienzo del proceso
    BEGIN TRY

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

---- limpiamos la tabla temporal
delete fpv_avisos_dif_ciclos_saldos_temp
--- armamos el correo
set @asunto = 'Punto G: Diferencias entre los ciclos para los reingresos en otras empresas (causa baja 08)'
set @msg = ' Le adjuntamos un listado de los problemas que existen con los datos de la tabla maestro de vacaciones, para los trabajadores que son reingresos'
set @saludos = 'Buenos dias'

      select @html = '<head><title></title><style type="text/css">.style10{width:153px;text-align:center}.style12{color:maroon;text-decoration:underline}</style></head><body><h1 style="font-family:''Calibri'';font-size:medium;font-weight:700;font-style:normal;color:#930">Buenos D&iacute;as</h1><b></b><p>Le adjuntamos un listado de los problemas que existen con los datos de la tabla maestro de vacaciones, para los trabajadores que son reingresos</p><div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=5" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de N&oacute;mina</strong></label></div></body>'    ;
-------- Comenzamos con el bicle de busqueda de errores

  Declare C_BuscarTrabRe Cursor local For
SELECT         Trabajador, COUNT(distinct Compania) AS companias
FROM      dbo.FPV_Datos_Trabajador_Nomina
where     trabajador in (select Trabajador from trabajadores_grales where sit_trabajador = 1)
GROUP BY Trabajador
HAVING        (COUNT(distinct Compania) > 1)

Open C_BuscarTrabRe

  While @@Fetch_Status < 1
    Begin
          Fetch C_BuscarTrabRe Into @trabajador , @x

          If @@Fetch_Status <> 0
                Begin
                      Break
                End

    select @empresa = ltrim(rtrim(nombre_cia)), @compania = compania from companias where compania = (select top(1) compania from trabajadores_grales
      where trabajador =@trabajador and sit_trabajador = 1)


   ---- si la empresa esta dentro de las que estas activo ok pasa
    if @compania  in (select compania from trabajadores_grales where sit_trabajador = 1 and trabajador = @trabajador )

    begin

      select @nombreTrab = replace(nombre, '/', ' ') from trabajadores where trabajador = @trabajador


    select @fecha_ingreso = fecha_ingreso from trabajadores_grales
    where sit_trabajador = 1 and trabajador = @trabajador
----- preguntamos si estan las empresas en saldos vacaciones primero

      Select @w = COUNT(distinct compania) from saldos_vacaciones S
      where trabajador = @trabajador   and fecha_ini_prog_vac >=(select top 1 fecha_antiguedad from trabajadores_grales where trabajador =S.trabajador and sit_trabajador = 1 )

  if @w <> @X
    Begin


    select @mensaje =   'No estan en el encabezado de vacaciones los ciclos de todas las empresas donde trabajo el empleado con cedula: ' + @trabajador

    end
  Else
  ----- Buscamos si ya tienen las dos empresas si tienen la misma cantidad de ciclo
        Begin
                set @t = 0

                --- select @t=   COUNT(trabajador) from   dbo.fn_TB_count_dif_saldos_vac(@trabajador,@fecha_ingreso)
	 	  select @t= dbo.fn_DifSaldosTransferencias(@compania,@trabajador,@fecha_ingreso)

	 	if @t > 0
                  Begin

                    select @mensaje =   'No tiene la misma cantidad de ciclos creados en todas las empresas donde trabajo el empleado con cedula: '   + @trabajador

                      INSERT INTO   fpv_avisos_dif_ciclos_saldos_temp
                      (tipo ,compania ,empresa ,trabajador ,nombre,ciclo ,mensaje,fecha)
                      VALUES ('Error_Cant_ciclos', @compania, @empresa,@trabajador,@nombreTrab,null,@mensaje,GETDATE() )

                  end --- fin problemas ciclos
                else
                  Begin
                ----- Buscamos ahora si no es un problama de ciclos buscar si estan bien asignados los dias de vacaciones

                    select   @r =   COUNT(trabajador) from dbo.fn_TB_count_dif_dias_vac_por_ciclo(@trabajador,@fecha_ingreso)

                      if @r > 1
                      begin

	 	 	      select @z =   dbo.fn_dias_difVacAviso(@trabajador,@fecha_ingreso)
	 	 	      if @z>1
	 	 	      Begin
	 	 	            select @mensaje =   'No tiene la misma cantidad de dias asignados, en todos los ciclos de las empresas donde trabajo el empleado con cedula: '   + @trabajador

	 	 	          INSERT INTO   fpv_avisos_dif_ciclos_saldos_temp
                                  (tipo ,compania ,empresa ,trabajador ,nombre,ciclo ,mensaje,fecha)
                                  VALUES ('Error_dias_asignados', @compania, @empresa,@trabajador,@nombreTrab,null,@mensaje,GETDATE() )

	 	 	      end


                      end --- fin problemas dias vac asignados
                      else
                          Begin ----  si estan bien los dias asignados buscamos en los disfrutados a ver si hay problemas
                              select @a =COUNT(trabajador) from   dbo.fn_TB_count_dif_diasDisfrutados_por_ciclo(@trabajador,@fecha_ingreso)
                                if @a > 1
                                  begin
                                    print @a -- de existir porblemas en dias lo da vacaciones programadas es decir el aviso de programadas

                                    -- select @mensaje =   'No tiene la misma cantidad de dias disfrutados, en todos los ciclos de las empresas  ' +
                                    --           'donde trabajo el empleado con cedula: '   + @trabajador

                                    --                 INSERT INTO   fpv_avisos_dif_ciclos_saldos_temp
                                    --               (tipo ,compania ,empresa ,trabajador ,nombre,ciclo ,mensaje,fecha)
                                    --                   VALUES ('Error_dias_disfrutados', @compania, @empresa,@trabajador,@nombreTrab,null,@mensaje,GETDATE() )

                                  end --- fin problemas dias disfrutados
                                  else
                                    Begin

                                        select @q = COUNT(trabajador) from fn_TB_count_dif_diasProgramadas_por_ciclo(@trabajador)
                                          if @q > 1
                                      begin

                                        -- set @y = @y+1
                                          print @y --- esto me lo da el evento de programadas
                                          -- select @mensaje =   'No tiene la misma cantidad de dias programados, en todos los ciclos de las empresas  ' +
                                          --         'donde trabajo el empleado con cedula: '   + @trabajador

                                          --         INSERT INTO   fpv_avisos_dif_ciclos_saldos_temp
                                          --           (tipo ,compania ,empresa ,trabajador ,nombre,ciclo ,mensaje,fecha)
                                          --           VALUES ('Error_dias_programados', @compania, @empresa,@trabajador,@nombreTrab,null,@mensaje,GETDATE() )
                                        end
                                    End --- fin problemas dias programados
                        end

                End --- fin de todas las diferencias (tipos ) de ciclos y dias
          end

	   end

end
    Close       C_BuscarTrabRe
    Deallocate   C_BuscarTrabRe

      -- select @query1   = 'SELECT tipo,compania,empresa ,trabajador,nombre , mensaje ,fecha FROM Adam.dbo.fpv_avisos_dif_ciclos_saldos_temp order by tipo '
      exec msdb.dbo.Sp_send_dbmail
              @profile_name = 'Informacion_Nomina',
          @Subject = @asunto,
          @recipients =  @correo	,
          @body_format= 'html',
          @body = @html   ,
	  @blind_copy_recipients = 'dennis.suarez@gmail.com',
	  @copy_recipients = @correoCC;
        -- @query = @query1 ,
        -- @query_result_width = 1800,
        -- @query_result_separator= ',' ,

      --  @query_attachment_filename = 'Errores_ciclos_reingresos.csv',
        -- @attach_query_result_as_file = 1 ;

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'C_BuscarTrabRe') >= 0
            CLOSE C_BuscarTrabRe
        IF CURSOR_STATUS('global', 'C_BuscarTrabRe') > -2
            DEALLOCATE C_BuscarTrabRe
        ;THROW;
    END CATCH
End --- fin del proceso

