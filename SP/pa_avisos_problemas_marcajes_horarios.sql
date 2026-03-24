

 CREATE procedure [Avisos].[pa_avisos_problemas_marcajes_horarios] 
 (@tipo varchar(3))
 AS
 Begin
      Declare @fechaIni date ,@fechaFin date 

	  select @fechaIni =fecha_ini_tiendas, @fechaFin =fecha_fin_tiendas from Nomina.calendario_nominas
	  where getdate() between fecha_ini_tiendas and fecha_fin_tiendas
 
 ----------------------------------------------------------------------------------------------------------------------------------
  ------Marcajes con horas extras y no deberia según relaciún cargos cadenas
  ----------------------------------------------------------------------------------------------------------------------------------  
	   

	  if @tipo = '01'
	  begin
	   Select m.Fecha, t.Codigo, p.primer_nombre +' '+p.segundo_nombre as Nombre , p.primer_apellido +' '+ p.segundo_apellido as Apellido,co.nombre_cia as Empresa, co.Cadena, 
	   t.cco as CCO, co.descripcion as Descripcion_CCO
	   from Asistencia.marcajes m inner join RRHH.trabajadoresDatosDiario t on m.codigo_emp_equipo = t.codigo and m.fecha = t.fecha
	   inner join 	Cargos.rel_claseNomina_cargos cs on cs.id_cargo = convert(int,t.cargo)
	   inner join RRHH.Personas p on left(t.codigo,10) = cedula_dni
	   inner join Catalogos.VW_CCO co on co.cco = t.cco
	   where m.fecha between @fechaIni and @fechaFin
	   and (isnull(m.he100,0) +  isnull(m.he25,0)+ isnull(m.he50,0))>0
	   and cs.excluidos_horas_ext <> 'NO'
	   and m.estatus >= 3
	  end
	else  if @tipo = '01A' --Conteo
	  begin
	   Select count(m.fecha)
	   from Asistencia.marcajes m inner join RRHH.trabajadoresDatosDiario t on m.codigo_emp_equipo = t.codigo and m.fecha = t.fecha
	   inner join 	Cargos.rel_claseNomina_cargos cs on cs.id_cargo = convert(int,t.cargo)
	   inner join RRHH.Personas p on left(t.codigo,10) = cedula_dni
	   inner join Catalogos.VW_CCO co on co.cco = t.cco
	   where m.fecha between @fechaIni and @fechaFin
	   and (isnull(m.he100,0) +  isnull(m.he25,0)+ isnull(m.he50,0))>0
	   and cs.excluidos_horas_ext <> 'NO'
	   and m.estatus >= 3
	  end

 ----------------------------------------------------------------------------------------------------------------------------------
  -----CCO sin asentar días
  ----------------------------------------------------------------------------------------------------------------------------------  
	   
	   else  if @tipo = '02' -- 
	   begin
	   declare @fechaFinTemp date

	   set @fechaFinTemp =  case when @fechaFin>convert(date,getdate()) then dateadd(day,-1,convert(date,getdate())) else @fechaFin end  
	   print @fechaFinTemp
	   Exec Asistencia.pa_consultaEstadosMarcajes @fechaIni   ,@fechaFinTemp
	 --   select distinct  m.fecha, T.cco,co.Cadena, co.descripcion
	 --   from Asistencia.marcajes m inner join RRHH.trabajadoresDatosDiario t on m.codigo_emp_equipo = t.codigo and m.fecha = t.fecha
		--inner join Catalogos.VW_CCO co on co.cco = t.cco
		--where  m.fecha between @fechaIni and (case when @fechaFin>convert(date,getdate()) then dateadd(day,-1,convert(date,getdate())) else @fechaFin end )
		--and m.estatus not in (3,4)
		--order by m.fecha,co.clase_nomina, co.descripcion

	   end
	    else  if @tipo = '02A' --Contero 
	   begin
	    select  count(m.fecha) 
	    from Asistencia.marcajes m inner join RRHH.trabajadoresDatosDiario t on m.codigo_emp_equipo = t.codigo and m.fecha = t.fecha
		inner join Catalogos.VW_CCO co on co.cco = t.cco
		where  m.fecha between @fechaIni and (case when @fechaFin>convert(date,getdate()) then dateadd(day,-1,convert(date,getdate())) else @fechaFin end )
		and m.estatus not in (3,4) 

	   end
	 
	 ----------------------------------------------------------------------------------------------------------------------------------
  -----CCO horarios
  ----------------------------------------------------------------------------------------------------------------------------------  
      else  if @tipo = '03' -- 
	   begin
	     exec asistencia.pa_consulta_horarios_trabajadores @fechaIni, @fechaFin, '', 'F'

	   end

	 else  if @tipo = '04'  
	   begin
	     Select ta.Fecha_Antiguedad, ta.Fecha_Ingreso, ta.Fecha_baja, ta.Situacion,  t.codigo, nombre,co.clase_nomina ,co.Cadena, t.cco, co.descripcion , 
			t.cargo, c.descripcion as puesto, t.fecha ,  t.tiene_he as estaColeccion, case when esConfianza  = 2 then 'NO' else 'SI' end esConfianza,
			case when h.id_jornada_definicion =9 then 'LIBRE' else replace(jd.descripcion,t.cco,'') end as horario ,  case when id_motivos_ausencias ='MO001A' then 'Ausencia'
				 when id_motivos_ausencias ='MO000' then 'Vacaciones'else (select  top 1  descripcion from  Asistencia.marcajes_acciones where codigo_Accion = m.aux07 )  end as justificacion , 
				 isnull(case when id_motivos_ausencias ='MO001A' then 'Ausencia'
				 when id_motivos_ausencias ='MO000' then 'Vacaciones'
  			   when id_motivos_ausencias = 'CDL' then 'Confirma día libre no labora'
  			   when id_motivos_ausencias = 'TH1' then 'Personal Administrativo'
  			   else (select  top 1  descripcion from Asistencia.motivos_ausencias A where A.id_motivos_ausencias  = m.id_motivos_ausencias)  end , id_motivos_ausencias) as motivos,
  			   isnull(he25,0) as he25, isnull(he25A,0) as he25A, isnull(he50,0) as he50, isnull(he50A,0) as he50A, isnull(he100,0) as he100, isnull(he100A,0) as he100A, isnull(hef, 0) as hef ,
  			   isnull(hefa,0) as hefa,m.hora1,m.hora2, m.hora3, m.hora4,M.hora1_just,M.hora2_just,M.hora3_just,M.hora4_just,M.hora1_justA,M.hora2_justA,M.hora3_justA,M.hora4_justA 
			from RRHH.trabajadoresDatosDiario t inner join Cargos.cargos c on cod_cargo = cargo
			inner join Catalogos.VW_CCO co on co.cco = t.cco
			inner join RRHH.vw_datosTrabajadores ta on ta.codigo = t.codigo
			left join Asistencia.rel_trab_horarios h on h.codigo=t.codigo and h.fecha=t.fecha
			inner join Asistencia.jornadas_definicion jd on jd.id_jornada_definicion = h.id_jornada_definicion
			left join asistencia.marcajes M on t.fecha = m.fecha and t.codigo = m.codigo_emp_equipo 
			where  isnull(t.tiene_he,'') = 'S' and t.cargo  in (select cod_cargo from Cargos.cargos where esConfianza = 2)
			--in (select id_cargo from Cargos.rel_claseNomina_cargos where id_clase_nomina = convert(smallint,co.clase_nomina) and excluidos_horas_ext = 'SI')
			and t.fecha  between @fechaIni and @fechaFin 

			 
			 
	   end

End 