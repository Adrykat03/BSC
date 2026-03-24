
CREATE procedure [Avisos].[pa_fechas_calendario]
   @cco char(10)  
  AS
  Begin

  declare @table as table (id bigint IDENTITY(1,1),codigo varchar(20),fechaIni smalldatetime, fechaFin smalldatetime, color varchar(15), descripcion varchar(150))

  ---ingresos
  insert into @table
  select codigo, fecha_ingreso as fechaIni,fecha_ingreso as fechaFin,'#03899C' as color,
  case when fecha_antiguedad<> fecha_ingreso then  'Ingreso (reingreso) del Trabajador: ' + Nombre else  'Ingreso del Trabajador: ' + Nombre end as descripcion
  from rrhh.vw_datostrabajadores
  where   situacion ='Activo'
  and cco = @cco

--bajas
	 insert into @table
	select codigo,fecha_bajaIndice as fechaIni,fecha_bajaIndice as fechaFin,'#6D1203' as color,
	'Bajas del Trabajador: ' + Nombre as descripcion
	from rrhh.vw_datostrabajadores
	where    fecha_bajaIndice is not null
	and cco = @cco

	--vacaciones
	 insert into @table
	select codigo,v.fecha_ini_per_vac as fechaIni,fecha_fin_per_vac as fechaFin,'#0F731B' as color,
	'Vacaciones del Trabajador: ' + Nombre + ' por ' + convert(varchar(4),tiempo_prog_vac) + ' días' as descripcion
	from adam.dbo.programacion_vacaciones v inner join  rrhh.vw_datostrabajadores t on t.trabajador = v.trabajador and t.compania = v.compania
	where  cco = @cco and fecha_ingreso<fecha_ini_per_vac
	and  situacion ='Activo'

---cumpleaños
	 insert into @table
	select codigo,   convert(varchar(4),datepart(year,getdate()))   + substring(convert(varchar(12),fecha_nacimiento,121),6,2)  + substring(convert(varchar(12),fecha_nacimiento,121),9,2) 
	   as fechaIni,
	 convert(varchar(4),datepart(year,getdate()))   + substring(convert(varchar(12),fecha_nacimiento,121),6,2)  + substring(convert(varchar(12),fecha_nacimiento,121),9,2) 
	   as fechaFin,'#6B0B61' as color,
	  'Cumpleaños del Trabajador: ' + Nombre  
	  as descripcion
	from rrhh.vw_datostrabajadores
	where   situacion ='Activo'
	and cco = @cco

----maternidad
    insert into @table
    Select  T.codigo,  f_inicio_lactancia, f_fin_lactancia,'#F77FEA' as color,
	'Maternidad de la trabajador  de nombre:' + A.Nombre + '.' as descripcion 
	from rrhh.vw_personal_lactancia A inner join rrhh.vw_datostrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo' 
    and T.cco = @cco
	and convert(date,f_inicio_lactancia)> convert(date,fecha_ingreso)
	order by T.codigo

---cargo por encargo
 insert into @table
   Select  T.codigo,fechaReingreso,fechaReingreso,'#7C7A7F' as color,
   'Vencimiento Cargo por Encargo del Trabajador : '+Nombre + ' el día: '+ convert(varchar(10),fechaReingreso,121) 
	from adam.dbo.FPV_AP_CargosTemporales A inner join  rrhh.vw_datostrabajadores T on A.Codigo = T.Codigo
	where   Situacion = 'Activo'  and cco = @cco
	and fecha_ingreso< A.fechaReingreso 

	--paternidad
    insert into @table   
    Select  t.codigo,fecha_ini_incapacidad,fecha_fin_incapacidad, '#26D0D6' as color,
      'Paternidad del Trabajador : '+T.Nombre + ' el día: '+ convert(varchar(10),fecha_fin_incapacidad,121)
	from Ausencias.Accidentes A inner join rrhh.vw_datostrabajadores  T on A.Codigo = T.Codigo
	where  id_TipoAusencia = '04' and Situacion = 'Activo'  ---and cco = @cco
	and fecha_ingreso <  fecha_ini_incapacidad
	
	--select * from   rrhh.vw_personal_lactancia

---	licencia sin remuneracion
   insert into @table   
   select  distinct t.codigo,dato_22,dato_22,'#D0F82D' as color,
    'Fecha Vencimiento Licencia por Remuneración del Trabajador: '+Nombre + ' el día: '+ convert(varchar(10),dato_22,121)  
	from rrhh.vw_datostrabajadores T inner join  adam.dbo.inf_soc_trabajador I on T.trabajador = I.trabajador
	where Situacion  <>'Activo'  and Causa_Baja = '22'
	and fecha_ingreso < dato_22
	and cco = @cco

---vencimiento contrato
    insert into @table   
    select Codigo,Fecha_Vencimiento,Fecha_Vencimiento,'#954C4C' as color,
	'Vencimiento Contrato Trabajador: '+Nombre + ' '+ convert(varchar(10),Fecha_Ingreso,121)  
	from rrhh.vw_datostrabajadores  
	where Situacion = 'Activo'
	and Tipo_Contrato in ('A','E','M','V','B','P','C','K','Y','Q')
	and GETDATE() between dateadd(day,-3,Fecha_Vencimiento) and Fecha_Vencimiento
	and cco = @cco
	 
 ---nominas
	  insert into @table 
	  Select 'Nomina' , fecha_fin_tiendas, fecha_fin_tiendas , '#033E1C' as color,
	 case when fecha_fin_tiendas>getdate() then 'Fin de nómina del período. Abierto' else  'Fin de nómina del período. Cerrado' end
	 from Nomina.calendario_nominas
	 where tipo_nomina = 'SQ'
	 and anio between  datepart(year, dateadd(year,-1,getdate())) and DATEPART(YEAR,getdate())

	 --festivos
	 insert into @table 
	   Select 'Fect Canton', convert(date,convert(char(4),datepart(year, getdate())) + right('0'+ convert(varchar(2),mes),2)+ right('0'+ convert(varchar(2),diaAplic),2) ),
	 convert(date,convert(char(4),datepart(year, getdate())) + right('0'+ convert(varchar(2),mes),2)+ right('0'+ convert(varchar(2),diaAplic),2) ),'#6BA703',
	 descripcion
	  from  adam.dbo.fpv_festivos_cantones 
	where anio  = datepart(year, getdate())
	and canton in (select codCantones from catalogos.vw_cco where cco =@cco)
 
	 insert into @table 
	  Select 'Fect Nac', convert(date,convert(char(4),datepart(year, getdate())) + right('0'+ convert(varchar(2),mes),2)+ right('0'+ convert(varchar(2),diaAplic),2) ),
	  convert(date,convert(char(4),datepart(year, getdate())) + right('0'+ convert(varchar(2),mes),2)+ right('0'+ convert(varchar(2),diaAplic),2) ),'#6BA703',
	  descripcion from  adam.dbo.fpv_festivos_cantones 
	  where anio  = datepart(year, getdate())
	  and canton  = 'NACIONAL'

	 

    select id,codigo   ,fechaIni  ,  fechaFin , color  , descripcion   from @table 
	where fechaIni>'20171231'
    order by fechaIni



  End
 
 