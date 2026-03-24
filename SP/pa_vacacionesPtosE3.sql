
create procedure avisos.pa_vacacionesPtosE3
AS
declare
@trabajador char(10),
@compania char(2),
@ciclo varchar(8),
@p int =0 ,
@y int =0 ,
@i int =0 ,
@b int  = 0,
@tableHTML2 varchar(max),
@cuerpo varchar(max),
@vac_por_ciclo smallint=0,
@vac_disfrutadas smallint = 0,
@vac_programadas smallint = 0,
@correo varchar(800),
@correoCC varchar(800)
 Begin

  declare @tablaVac as table(compania char(2), trabajador char(10), cant int, dias int, ciclo varchar(10), vac_por_ciclo int, saldoDisfrutada int, saldoProgramada int)

  Declare C1 Cursor local For                          
   select T.Trabajador, V.compania, ciclo_laboral, vac_disfrutadas, vac_programadas, vac_por_ciclo
   from adam.dbo.saldos_vacaciones V inner join DB_NOMKFC.rrhh.vw_datosTrabajadores T on
   V.trabajador = T.trabajador and V.compania = T.Compania
   and Situacion = 'Activo' and ciclo_laboral >= '20172018'
   and (V.vac_disfrutadas> 0 or V.vac_programadas>0) 
   

   Open C1                          
                          
	 While @@Fetch_Status < 1                          
	  Begin                          
		 Fetch C1 Into @trabajador, @compania , @ciclo, @vac_disfrutadas, @vac_programadas, @vac_por_ciclo                
                          
		 If @@Fetch_Status <> 0                           
			Begin                          
			   Break                          
			End                          
              
         set @i = 0
		 set @p = 0
		 set @y = 0

         set @i = @vac_disfrutadas+@vac_programadas  
		 
		 select @y= count(*) from Adam.dbo.programacion_vacaciones
		 where compania = @compania and trabajador = @trabajador
		 and ciclo_laboral = @ciclo

		  select @p=  sum(tiempo_prog_vac) from Adam.dbo.programacion_vacaciones
		 where compania = @compania and trabajador = @trabajador
		 and ciclo_laboral = @ciclo
	  
	     insert into @tablaVac
		 select @compania, @trabajador, isnull(@y,0), isnull(@p,0), @ciclo, @vac_por_ciclo, @vac_disfrutadas, @vac_programadas
	  
	  end                          
	  Close      C1                          
	  Deallocate C1 


	
  select  compania , trabajador ,    cant ,  dias , ciclo , vac_por_ciclo , saldoDisfrutada ,saldoProgramada   
  from @tablaVac  where (saldoDisfrutada + saldoProgramada) <> dias 
	
 End 
	 
  