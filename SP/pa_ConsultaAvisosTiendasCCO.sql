
 CREATE procedure [Avisos].[pa_ConsultaAvisosTiendasCCO]
   @cco  varchar(15) 
 AS
Declare
 @id numeric(28, 0), 
 @trabajador char(10),
 @codigo varchar(20),
 @nombreCarga varchar(300),
 @nombre varchar(300),
 @mensajeCorto varchar(200),
 @asunto varchar(100),
 @tipoCarga varchar(25),
 @mensajeLargo varchar(max),
 @fecha_aviso smalldatetime,
 @fecha_aviso2 smalldatetime,
 @estado dbo.estatus,
 @regla_tarea varchar(max),
 @tipo smallint ,
 @fechaAnt varchar(15),
 @fechaIng varchar(15)

 Begin
     declare @tablaCargas as table(asunto varchar(50), regla varchar(max), cco varchar(15), 
                             mensajeCorte varchar(200), mensajeLargo varchar(2000), 
							 fechaAviso smalldatetime, tipoAviso smallint, trabajador char(10))

    declare @tablaTrabajadores as table(cco varchar(8), compania char(2), clase_nomina char(2),
	                                     codigo varchar(20), nombre varchar(200),fecha_ingreso date, 
										 fecha_antiguedad date, trabajador char(10), Situacion varchar(15),
										 Fecha_bajaIndice date, fecha_baja date, Tipo_Contrato char(5), Fecha_Vencimiento date,
										 Causa_Baja char(2), Fecha_Nacimiento date, secuenciaContratacion smallint)

		declare @lactancia as table(codigo char(20), cco varchar(8), clase_nomina char(2), compania char(2), puesto varchar(8),fecha_ini_incapacidad date, 
	fecha_fin_incapacidad date, f_fin_lactancia date, f_inicio_lactancia date,bisiesto smallint, nombre varchar(100))

	insert into @lactancia 
    select codigo, cco, clase_nomina, compania, puesto,fecha_ini_incapacidad, 
     fecha_fin_incapacidad, f_fin_lactancia, f_inicio_lactancia,bisiesto, nombre from rrhh.vw_personal_lactancia

	insert into @tablaTrabajadores
	select cco, compania, clase_nomina, codigo , nombre, fecha_ingreso,fecha_antiguedad,trabajador, Situacion,
	Fecha_bajaIndice, fecha_baja,Tipo_Contrato,Fecha_Vencimiento, Causa_Baja,Fecha_Nacimiento,secuenciaContratacion
	from rrhh.vw_datosTrabajadores   where cco = @cco

----Aviso cargas por aprobar
	Declare C_cargarsApro Cursor local For  
	
	Select C.cedula,T.Nombre, 
	  CA.Descripcion  as tipo_carga ,
	  C.nombre +' '+ c.apellido as nombreCarga, CCO
	  from Cargas.familiares_personas C inner join @tablaTrabajadores T 
	  on C.cedula = T.Trabajador
	   inner join Cargas.Tipo_CargasFamiliares CA on  CA.id_TipoCarga = C.id_TipoCarga
	  where estado = 0 and Situacion = 'Activo' and Fecha_bajaIndice is null
	  and cco  =@cco
	  --Select C.cedula,T.Nombre, 
	  --(select Descripcion from Cargas.Tipo_CargasFamiliares CA where CA.id_TipoCarga = C.id_TipoCarga) as tipo_carga ,
	  --C.nombre +' '+ c.apellido as nombreCarga, CCO
	  --from Cargas.familiares_personas C inner join @tablaTrabajadores T
	  --on C.cedula = T.Trabajador 
	  --where estado = 0 and Situacion = 'Activo' and Fecha_bajaIndice is null
	  --and cco  = @cco
Open C_cargarsApro                          
                          
 While @@Fetch_Status < 1                          
  Begin                          
     Fetch C_cargarsApro Into @trabajador,@nombre,@tipoCarga,@nombreCarga,@cco                   
                          
     If @@Fetch_Status <> 0                           
        Begin                          
           Break                          
        End                          
      
	  set @regla_tarea = 'Dar lectura del módulo de cargas familiares con estado "Por aprobar". Esta alerta debe generarse todos los días lunes. La tarea desaparece cuando el estado de CF cambie a legalizado. (Nombre/tipo de carga/nombre carga)'
	  set @asunto = 'Cargas pendientes por aprobar'
	  set @mensajeCorto = 'Trabajador:' +@nombre +' Carga: ' +@nombreCarga  + ' Tipo Carga: ' + @tipoCarga

	  set @mensajeLargo = 'El trabajador '+@nombre +' con cédula: ' + @trabajador + ' tiene una carga pendiente por aprobar, con nombre ' + @nombreCarga + '('+@tipoCarga+').' + 
	                       ' Por favor entrar al módulo de Cargas Familiares o comunicarse con el departamento de Nómina.'
	  
	  
	  
	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	  select @cco, @mensajeCorto, @asunto,@mensajeLargo,getdate(),  @regla_tarea,1,@trabajador

                       
end                          
  Close      C_cargarsApro                          
  Deallocate C_cargarsApro


--  "* De acuerdo a la contratación, una vez que se actualiza un nuevo colaborador y es un reingreso (no necesariamente en la misma empresa) , genere un alerta
--* Esta alerta debe generarse todos los días lunes
--* La tarea debe quedar visible tres días y se desactivará automáticamente al siguiente día."
--select codigo, nombre, cco, fecha_ingreso, fecha_antiguedad
--from @tablaTrabajadores
--where fecha_ingreso between dateadd(day,3,DATEADD(wk,DATEDIFF(wk,7,GETDATE()),0))  and DATEADD(wk,DATEDIFF(wk,7,GETDATE()),6) 
--and secuenciaContratacion>1
  Declare C_cargarsApro Cursor local For                          
  select codigo, nombre, cco, fecha_ingreso, fecha_antiguedad
    from @tablaTrabajadores T
    where isnull((select referencia_03 from adam.dbo.TB_RRHH_Reclutamiento where Cedula = T.Trabajador and fecha_ingreso in (select max(fecha_ingreso) from
	  adam.dbo.TB_RRHH_Reclutamiento where Cedula = T.Trabajador)),fecha_ingreso) between dateadd(day,3,DATEADD(wk,DATEDIFF(wk,7,GETDATE()),0))  and DATEADD(wk,DATEDIFF(wk,7,GETDATE()),6) 
    and secuenciaContratacion>1  and cco  = @cco

Open C_cargarsApro                          
                          
 While @@Fetch_Status < 1                          
  Begin                          
     Fetch C_cargarsApro Into @trabajador,@nombre,@tipoCarga,@fechaIng,@fechaAnt                   
                          
     If @@Fetch_Status <> 0                           
        Begin                          
           Break                          
        End                          
      
	  set @regla_tarea = '* De acuerdo a la contratación, una vez que se actualiza un nuevo colaborador y es un reingreso (no necesariamente en la misma empresa) , genere un alerta
                           * Esta alerta debe generarse todos los días lunes * La tarea debe quedar visible tres días y se desactivará automáticamente al siguiente día.'
	  
	  set @asunto = 'Reingresos de la semana anterior'
	  set @mensajeCorto = 'Tienes un nuevo reingreso, valida que la información de Cargas Familiares este completa. Trabajador:' +@nombre +' Carga: ' +@nombreCarga   

	  set @mensajeLargo = 'El trabajador '+@nombre +' con cédula: ' + @trabajador + ' es un reingreso de la semana pasada, con fecha ' + @fechaIng+'. Tienes un nuevo reingreso, valida que la información de Cargas Familiares este completa.'
	    if (DATENAME(DW,getdate()) in ('Tuesday','Monday','Wednesday'))
		begin

		 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	     select @cco, @mensajeCorto, @asunto,@mensajeLargo,getdate(),  @regla_tarea,1,@trabajador

		end
	  
                       
end                          
  Close      C_cargarsApro                          
  Deallocate C_cargarsApro


  -----------------------------------------------------------------------------------------------
  ----Creditos diferencias
  -----------------------------------------------------------------------------------------------
   insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso )
	 Exec avisos.pa_creditosPrtvsSinCupon @cco


 
  -----------------------------------------------------------------------------------------------
  ----fin Creditos diferencias
  -----------------------------------------------------------------------------------------------
   
   
  -----------------------------------------------------------------------------------------------
  ----Contratos
  -----------------------------------------------------------------------------------------------

--  "Filtrar el tipo de contrato: A, E, M, V, B, P, P, C, K, Y, Q
--Genere dos alertas; La primera con 15 días antes del vencimiento y  la segunda a los 5 días del vencimiento
--La alerta debe quedar visible tres días y se desactivará automáticamente al siguiente día."

    insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso , trabajador)
    select CCO,'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121) , 'Vencimiento Contrato',
	'Al trabajador de ' + Nombre + ' se le vence el contrato el día  '+ convert(varchar(10),Fecha_Vencimiento,121)+' ',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-15,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	 
	 
	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select CCO,'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121) , 'Vencimiento Contrato',
		'Al trabajador de ' + Nombre + ' se le vence el contrato el día  '+ convert(varchar(10),Fecha_Vencimiento,121)+' ',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores T
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-14,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Contrato')

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select CCO,'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121) , 'Vencimiento Contrato',
		'Al trabajador de ' + Nombre + ' se le vence el contrato el día  '+ convert(varchar(10),Fecha_Vencimiento,121)+' ',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-13,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	and  trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Contrato')

     insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select CCO,'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121) , 'Vencimiento Contrato',
		'Al trabajador de ' + Nombre + ' se le vence el contrato el día  '+ convert(varchar(10),Fecha_Vencimiento,121)+' ',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-5,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	and  trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Contrato')

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select CCO,'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121) , 'Vencimiento Contrato',
	'Al trabajador de ' + Nombre + ' se le vence el contrato el día  '+ convert(varchar(10),Fecha_Vencimiento,121)+' ',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-4,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	and trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Contrato')

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select CCO,'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121) , 'Vencimiento Contrato',
	'Al trabajador de ' + Nombre + ' se le vence el contrato el día  '+ convert(varchar(10),Fecha_Vencimiento,121)+' ',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-3,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	and  trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Contrato')

  -----------------------------------------------------------------------------------------------
  ----fin contratos
  -----------------------------------------------------------------------------------------------
   

    -----------------------------------------------------------------------------------------------
  ---- Terminación licencia sin remuneración  
  -----------------------------------------------------------------------------------------------
--  "* Se tiene que notificar con 15 y 5 días de anticipación al reintegro a las labores
--* La fecha fin se lee del índice f_licencia
--* La alerta debe quedar visible tres días y se desactivará automáticamente al siguiente día."
    insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion <> 'Activo' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-15,dato_22) and dato_22 and Causa_Baja = '22'
	and cco = @cco
	 
	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion  <>'Activo'  and Causa_Baja = '22' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-14,dato_22) and dato_22
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Licencia R')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion  <> 'Activo'  and Causa_Baja = '22' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-13,dato_22) and dato_22
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Licencia R')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador  ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion  <> 'Activo'  and Causa_Baja = '22' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-10,dato_22) and dato_22
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Licencia R')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador  ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion <>'Activo'  and Causa_Baja = '22' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-5,dato_22) and dato_22
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Licencia R')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador  ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion <> 'Activo'  and Causa_Baja = '22' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-4,dato_22) and dato_22
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Licencia R')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	select  distinct CCO,'Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121) , 'Vencimiento Licencia R',
	'Al trabajador  ' + Nombre + ' se le vence la licencia por remuneración dentro de '+convert(varchar(2),datediff(day,getdate(),dato_22))+' días ('+ convert(varchar(10),dato_22,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @tablaTrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion  <>'Activo'  and Causa_Baja = '22' and I.indice_inf_soc = 'F_LICENCIA'
	and getdate() between dateadd(day,-3,dato_22) and dato_22
	and cco = @cco
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Licencia R')

	 

   -----------------------------------------------------------------------------------------------
  ----fin licencia sin remuneracion
  -----------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------------------
  ----Maternidad
  -----------------------------------------------------------------------------------------------
  --  "* Se tiene que notificar con 15, 10 y 5 días de anticipación de reintegro a las labores 
  --* La fecha fin se lee del módulo de ausencias
  --* La alerta debe quedar visible tres días y se desactivará automáticamente al siguiente día."
   
   insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
  	Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-15,fecha_fin_incapacidad)  AND fecha_fin_incapacidad

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-14,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-13,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-10,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-9,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-8,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-5,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-4,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Maternidad de la Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Maternidad',
	'A la trabajadora de nombre:' + Nombre + ' se vence la maternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '01' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-3,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Maternidad')



    -----------------------------------------------------------------------------------------------
  ----fin  maternidad
  -----------------------------------------------------------------------------------------------


   -----------------------------------------------------------------------------------------------
  ----Paternidad
  -----------------------------------------------------------------------------------------------
  --  "* Se tiene que notificar con 15, 10 y 5 días de anticipación de reintegro a las labores 
  --* La fecha fin se lee del módulo de ausencias
  --* La alerta debe quedar visible tres días y se desactivará automáticamente al siguiente día."
   
   insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
  	Select  T.CCO,'Vencimiento Paternidad del Trabajadora: '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	 AND GETDATE() BETWEEN   dateadd(day,-15,fecha_fin_incapacidad)  AND fecha_fin_incapacidad

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) ,'Vencimiento Paternidad',
	'Al trabajador  de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-14,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador  de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-13,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) ,'Vencimiento Paternidad',
	'Al trabajador de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-10,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador  de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-9,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-8,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-5,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-4,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Paternidad')

	insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Paternidad del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121) , 'Vencimiento Paternidad',
	'Al trabajador  de nombre:' + Nombre + ' se vence la paternidad dentro de '+convert(varchar(2),datediff(day,getdate(),fecha_fin_incapacidad))+' días ('+ convert(varchar(10),fecha_fin_incapacidad,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from Ausencias.Accidentes A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  and T.cco = @cco
	AND GETDATE() BETWEEN   dateadd(day,-3,fecha_fin_incapacidad)  AND fecha_fin_incapacidad
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Paternidad')
	 
  -----------------------------------------------------------------------------------------------
  ----fin paternidad
  -----------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------------------
  ----Cumpleaños
  -----------------------------------------------------------------------------------------------

     insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
    select CCO,'Cumpleaños del trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_nacimiento,121) , 'Cumpleaños',
	'Hoy es el cumpleaños del trabajador ' + Nombre + '.',
	convert(date, getdate()), Trabajador,1, trabajador
	from @tablaTrabajadores
	where Situacion = 'Activo' 
	and datepart(MONTH,Fecha_Nacimiento) =  datepart(MONTH,getdate()) 
	and datepart(day,Fecha_Nacimiento) =  datepart(day,getdate()) 
	and cco = @cco
	 

    -----------------------------------------------------------------------------------------------
  ----fin Cumpleaños
  -----------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------------------
  ----Cargos por encargo
  -----------------------------------------------------------------------------------------------
--   "* Enlista los colaboradores que tienen cargo por encargo, dar lectura de proceso de AP con 15, 10 y 5 días de anticipación al vencimiento
--* La alerta debe quedar visible tres días y se desactivará automáticamente al siguiente día."

    insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-15,A.fechaReingreso) and A.fechaReingreso 
	  
	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-14,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')
	 
	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-13,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')

	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-10,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')

	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-9,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')

	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-8,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')
	  
	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-5,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')
	  
	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-4,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')
	  
	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
     Select  CCO,'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) , 'Vencimiento Cargo por Encargo',
	'Al trabajador  de nombre:' + Nombre + ' se vence el Cargo por Encargo dentro de '+convert(varchar(2),datediff(day,getdate(),fechaReingreso))+' días ('+ convert(varchar(10),fechaReingreso,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from adam.dbo.FPV_AP_CargosTemporales A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and getdate() between dateadd(day,-3,A.fechaReingreso) and A.fechaReingreso 
	 and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto ='Vencimiento Cargo por Encargo')
	 
  -----------------------------------------------------------------------------------------------
  ----Fin Cargos por encargo
  -----------------------------------------------------------------------------------------------


   -----------------------------------------------------------------------------------------------
  ----Lactancia
  -----------------------------------------------------------------------------------------------
	--  "* Se tiene que notificar con 15, 5 y el día de vencimiento a la finalización de la lactancia, es decir al cumplimiento del año del hijo/a
	--* La fecha fin de lactancia debe calcular tomando la fecha inicio de maternidad hasta 1 año
	--Ejemplo:
	--MATERNIDAD - Desde el 05-01-2020 al 25-03-2020 (84 días) 
	--LACTANCIA - Desde el 26-03-2020 al 04-01-2021 (1 año del niño)
	--* La alerta debe quedar visible tres días y se desactivará automáticamente al siguiente día."
	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-15,f_fin_lactancia) and f_fin_lactancia
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-14,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-13,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-10,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-9,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-8,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-5,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-4,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and  GETDATE()  between dateadd(day,-3,f_fin_lactancia) and f_fin_lactancia
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo

	 insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso, trabajador )
	 Select  T.CCO,'Vencimiento Lactancia de la Trabajadora : '+A.Nombre + ' el día: '+ convert(varchar(10),f_fin_lactancia,121) , 'Vencimiento Lactancia',
	'A la trabajadora  de nombre:' + A.Nombre + ' se vence el período de lactancia dentro de  '+convert(varchar(2),datediff(day,getdate(),f_fin_lactancia))+' días ('+ convert(varchar(10),f_fin_lactancia,121)+')',
	convert(date, getdate()), T.Trabajador,1, T.Trabajador
	from @lactancia A inner join @tablaTrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
	 and T.cco = @cco
	and convert(date,f_fin_lactancia)  = convert(date,GETDATE()) 
	and T.trabajador not in (select C.trabajador from @tablaCargas C where asunto = 'Vencimiento Lactancia')
	order by T.codigo
   -----------------------------------------------------------------------------------------------
  ----Fin lactancia
  -----------------------------------------------------------------------------------------------



  Select 0 as id_avisoTienda, cco, 'Avisos' as nombre,mensajeCorte as mensajeCorto,asunto as asunto,mensajeLargo as mensajeLargo, 
  fechaAviso as fecha_aviso, getdate() as fecha_aviso2,1 as estado,
  regla as regla_tarea, tipoAviso as tipo
  from  @tablaCargas
    
 End
