
CREATE procedure [Avisos].[pa_avisos_biometricosDiel]
( @tipo smallint =0) 
As
Begin
  
	if @tipo = 1------- CCO con equipos biométricos asignados, que no sean de las provincias de Guayas y Pichincha, que no tengan asignado usuario con rol de Administrador
	begin

	   Declare @tableCCOBiometricosNoPichincha as table(compania char(2),nombre_cia varchar(200), clase_nomina char(2), cadena  varchar(200),provincia varchar(50), cantones varchar(50) , cco char(8), 
	   descripcion varchar(250),tieneAdministrador char(2), Biometrico varchar(20))


	   insert into @tableCCOBiometricosNoPichincha(compania   ,nombre_cia , clase_nomina  , cadena ,provincia , cantones  , cco , descripcion  ,tieneAdministrador,Biometrico)
	   Select compania ,nombre_cia  , clase_nomina , cadena as Cadena,provincia , cantones , cco , 
	   descripcion  , case when ( Select count(*)   from [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]  em  
	   where   Administrator = 1  and  isnull(id_biometrico, '') =  [DEVICE_ID] collate SQL_Latin1_General_CP1_CI_AS) > 1 then 'Si' else 'No' end  , id_biometrico
	   from catalogos.vw_cco   where tieneBimetrico = 1  and provincia not in ('PICHINCHA', 'GUAYAS')  order by compania,cadena, descripcion  
       
	   Select compania as [Compañia],nombre_cia as Empresa, clase_nomina as [Clase Nómina], cadena as Cadena,provincia as Provincia, cantones as [Cantón], cco as CCO, 
	   descripcion as Descripción, tieneAdministrador  [Tiene Administrador], Biometrico as [Biométrico]
	   from @tableCCOBiometricosNoPichincha   where  tieneAdministrador = 'No'
	   order by compania,cadena, descripcion  
      

	end
	else if @tipo = 2------- CCO a nivel nacional con equipo biométrico asignado, que no tienen relacionado rol de Administrador 601 O 0601
	begin

	   Declare @tableCCOBiometricosNo601 as table(compania char(2),nombre_cia varchar(200), clase_nomina char(2), cadena  varchar(200),provincia varchar(50),  cantones varchar(50) , cco char(8), 
	   descripcion varchar(250),tiene601 char(2))

	   insert into @tableCCOBiometricosNo601(compania   ,nombre_cia , clase_nomina  , cadena ,  cantones  , cco , descripcion  ,tiene601, provincia)
	   Select compania,nombre_cia , clase_nomina  , cadena  , cantones , cco , descripcion ,
	   case when ( Select   count([DEVICE_ID])  from[srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]  em 
       where [USER_ID] IN ('0601', '601') and isnull(id_biometrico,'')=  [DEVICE_ID] collate SQL_Latin1_General_CP1_CI_AS)> 0 then 'Si' else 'No' end ,provincia 
	   from catalogos.vw_cco where tieneBimetrico = 1 order by  compania,cadena, descripcion 

	  Select compania,nombre_cia as Empresa, clase_nomina as  [Clase Nómina], cadena as Cadena,provincia as Provincia, cantones as Cantón, cco as CCO, descripcion as Descripción, tiene601  as Tiene601 
	  from @tableCCOBiometricosNo601 where tiene601 = 'No' 
	  order by nombre_cia,cadena,  descripcion


	end
	else if @tipo = 3------ CCO con equipos biométricos asignados, que sean de las provincias de Guayas y Pichincha, y que tengan asignado un usuario con rol de Administrador diferente a los usuarios 601 o 0601
	begin

	   Declare @tableCCOBiometricosNo601A as table(compania char(2),nombre_cia varchar(200), clase_nomina char(2), cadena  varchar(200),provincia varchar(50),  cantones varchar(50) , cco char(8), 
	   descripcion varchar(250),AdministradorNo601 char(2), biometrico varchar(20))

	    insert into @tableCCOBiometricosNo601A(compania   ,nombre_cia , clase_nomina  , cadena, provincia ,  cantones  , cco , descripcion  ,AdministradorNo601, biometrico )
	    Select compania as Compañia,nombre_cia as Empresa, clase_nomina as [Clase Nómina], cadena as Cadena,provincia, cantones  as Cantón, 
		cco as CCO, descripcion as Descripción, case when(Select count(Administrator) from[srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]  em 
		where isnull(id_biometrico, '') = [DEVICE_ID] collate SQL_Latin1_General_CP1_CI_AS  and[USER_ID] not IN ('0601', '601') and Administrator = 1) > 0 then 'Si' else 'No' end as AdministradorNo601
		, isnull(id_biometrico, '') from catalogos.vw_cco  where tieneBimetrico = 1  and provincia in ('PICHINCHA', 'GUAYAS')  order by compania,cadena, descripcion 
       
	  Select compania,nombre_cia as Empresa, clase_nomina as  [Clase Nómina], cadena as Cadena,provincia as Provincia, cantones as Cantón, cco as CCO, descripcion as Descripción,
	  AdministradorNo601 , biometrico as [Biométrico] 
	  from  @tableCCOBiometricosNo601A where AdministradorNo601 <> 'No'  order by  compania,cadena, descripcion  
	end
	else if @tipo = 4------Base de personal por CCO con equipos biométricos asignados, que en la información LAST_TEMPLATE = “0”
	begin

	   Declare @tableCCOBiometricosTemplate0 as table(compania char(2),nombre_cia varchar(200), clase_nomina char(2), cadena  varchar(200),provincia varchar(50),cco char(8), 
	   descripcion varchar(250),userId varchar(25), nombre varchar(200),documentid varchar(15))

	   Insert into @tableCCOBiometricosTemplate0(compania  ,nombre_cia,clase_nomina,cadena,provincia,cco,descripcion ,userId,nombre,documentid )
	   select t.compania ,t.compania_Desc , clase_nomina , desc_clase_nomina ,provincia , 
	   cco as CCO, desc_cco  as Descripción ,  em.[USER_ID], nombre as Nombre, em.[DOCUMENT_ID]  
	   from  integracion.Diel_Tbl_Realtime_Enroll_Data em inner join rrhh.vw_datosTrabajadores t on em.[USER_ID] = t.trabajador 
	   where em.[LAST_TEMPLATE] = 0 AND em.[USER_ID] NOT IN  ('0601', '601') and situacion = 'Activo' 
         and Fecha_bajaIndice is null  
    
      select compania as Compañia,nombre_cia as Empresa, clase_nomina as  [Clase Nómina], cadena as Cadena,provincia as Provincia,  cco as CCO, descripcion as Descripción,
	  userId as [User_ID] , nombre as Nombre  ,documentid as  Document_Id from @tableCCOBiometricosTemplate0 
	  order by nombre_cia,cadena,  descripcion, nombre

	end   
	else if @tipo = 5------ Biometricos Apagados
	begin

	  DECLARE @tableCCoApagados AS TABLE (compania char(2),nombre_cia varchar(200), clase_nomina char(2), cadena  varchar(200),provincia varchar(50),
			  cco VARCHAR(10) , descripcion VARCHAR(250), biometrico varchar(20))
  
		SELECT cn.compania as Compañia,cn.nombre_cia as Empresa, clase_nomina as [Clase Nómina], cn.Cadena,provincia as Provincia, 
	    cco as CCO, descripcion  as Descripción ,isnull(id_biometrico, '') as [Biomótrico]
		FROM DB_NOMKFC.catalogos.vw_cco cn
		INNER JOIN [srvv-biomdb].BiometricosDIEL.dbo.TBL_LOCATIONS c
			ON cn.cco_padre = c.code collate SQL_Latin1_General_CP1_CI_AS
		INNER JOIN [srvv-biomdb].BiometricosDIEL.dbo.TBL_FKDEVICE_STATUS b
			ON c.id = b.location_id
		WHERE isnull(CONNECTED, 0) = 0
		ORDER BY descripcion

		 
	end
	else if @tipo = 6------ Personas con el document id vacio, deben cumplir con las condiciones de ser un trabajador, no ser 601 debe estar en los de contratacion
	begin

	 Select em.[USER_ID], em.[LAST_NAME], em.[FIRST_NAME], em.[DOCUMENT_ID]
	  from   [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]  em  
	  inner join [srvv-biomdb].BiometricosDIEL.dbo.TBL_FKDEVICE_STATUS d on d.[DEVICE_ID] = em.[DEVICE_ID]
	  inner join adam.dbo.trabajadores_grales t on t.trabajador =  isnull(em.[USER_ID],'')  collate SQL_Latin1_General_CP1_CI_AS
	  inner join catalogos.centro_costos c on c.id_biometrico = em.[DEVICE_ID]  collate SQL_Latin1_General_CP1_CI_AS 
	  where    [USER_ID] NOT IN  ('0601', '601')  
	   and  isnull(em.[USER_ID],'') != isnull(em.[DOCUMENT_ID],'')  
	  AND em.[LAST_TEMPLATE] = 1 and sit_trabajador  = 1
	  and [Device_name] not like '%Contrata%'
	  And   T.Trabajador + CONVERT(varchar(12),  T.Fecha_Ingreso, 112) + LTRIM(RTRIM( T.Compania)) not in (select codigo from rrhh.prebajas_prt where codigo like '%'+t.trabajador+'%')
	  order by [USER_ID] 
		 
	end
	else if @tipo = 7------ Enrolados que no pertenecen a la empresa
	begin

	 Select em.[USER_ID], em.[LAST_NAME], em.[FIRST_NAME], em.[DOCUMENT_ID],[Device_name]
	  from   [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]  em  
	  inner join [srvv-biomdb].BiometricosDIEL.dbo.TBL_FKDEVICE_STATUS d on d.[DEVICE_ID] = em.[DEVICE_ID]
	  where    [USER_ID] NOT IN  ('0601', '601')   
	  and [USER_ID]  collate SQL_Latin1_General_CP1_CI_AS  not in (select distinct trabajador from adam.dbo.trabajadores)
	  order by [USER_ID] 
		 
	end
	else if @tipo = 8------ Personas duplicadas
	begin
	declare @tableDuplicados as table (cedula varchar(15), cantidad smallint)
	declare @tableDuplicadosDetalles as table (cedula varchar(15), biometrico varchar(20), last_template tinyint)

	 insert into @tableDuplicados
	 Select  [USER_ID], count([USER_ID])
     from   [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]  em   
     inner join adam.dbo.trabajadores_grales t on t.trabajador =  isnull(em.[USER_ID],'')  collate SQL_Latin1_General_CP1_CI_AS 
     where    [USER_ID] NOT IN  ('0601', '601')  and sit_trabajador=1
	 and  [LAST_TEMPLATE] =1
     group by [USER_ID]
     having  count([USER_ID])>1

	 insert into @tableDuplicadosDetalles
	 select [USER_ID], [DEVICE_ID], [LAST_TEMPLATE]
	 from [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA] b inner join @tableDuplicados t on b.[USER_ID]  collate SQL_Latin1_General_CP1_CI_AS = t.cedula
	 
	 Select t.compania as Compañia, t.compania_Desc as Empresa, t.Clase_Nomina as [Clase Nómina], t.Desc_Clase_Nomina as Cadena, t.CCO,t.Desc_CCO   as [Descripción CCO],
	 t.trabajador as Trabajador, t.nombre as Nombre , d.biometrico as Serial,v.[description] as [Biometrico Local]  , last_template as [Last Template]
	 from @tableDuplicadosDetalles d inner join rrhh.vw_datosTrabajadores t on t.trabajador = d.cedula  collate SQL_Latin1_General_CP1_CI_AS 
	 inner join integracion.vw_biometricos_Diel v on v.[DEVICE_ID]  collate SQL_Latin1_General_CP1_CI_AS =d.biometrico
	 where t.situacion = 'Activo'  and Fecha_bajaIndice is null  
	 order by trabajador
		 
	end
	else if @tipo = 9------ digitalizada Arreglar es personal que no esta en Diel
	begin
	
	 
	Select  compania,t.compania_desc , clase_nomina  , desc_clase_nomina  , cantones , t.cco , descripcion, trabajador, nombre , fecha_ingreso, cargo
	from   RRHH.vw_datosTrabajadores t inner join catalogos.centro_costos c
	on t.cco = c.cco 
	where c.tieneBimetrico =1
	and situacion = 'Activo'  and Fecha_bajaIndice is null  
	and trabajador not in (Select  [USER_ID] collate SQL_Latin1_General_CP1_CI_AS  from [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA])
	order by compania,clase_nomina

   --   Select   d.[DEVICE_ID] as [Biometrico],v.[description] as [Biometrico Local]  ,[USER_ID] as Trabajador,
	  --(select top 1 nombre from RRHH.vw_datosTrabajadores where trabajador =[USER_ID]  collate SQL_Latin1_General_CP1_CI_AS) as Nombre
   --   from   [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA] d  inner join
	  --integracion.vw_biometricos_Diel v on v.[DEVICE_ID]  collate SQL_Latin1_General_CP1_CI_AS =d. [DEVICE_ID] collate SQL_Latin1_General_CP1_CI_AS
   --   where    [USER_ID] NOT IN  ('0601', '601')  
   --   and [user_data] is null
		 
	end
	else if @tipo = 10------ Personas que no tienen los datos completos Nombres y cedula y esten con template 1
	begin 
     
	 Select   em.[USER_ID] as Trabajador, em.[LAST_NAME] as Apellidos, em.[FIRST_NAME] as Nombres, em.[DOCUMENT_ID] as Cedula
     from   [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA] em
      WHERE (ISNULL(em.[LAST_NAME], '') = ''
	 OR ISNULL(em.[FIRST_NAME], '') = '' 
	 OR ISNULL(em.[DOCUMENT_ID], '') = '')
	 and [USER_ID] NOT IN  ('0601', '601') 
	 and [USER_ID]  collate SQL_Latin1_General_CP1_CI_AS  in (select distinct trabajador from adam.dbo.trabajadores)
	 and [last_template] = 1
		 
	end
	else if @tipo = 11----- Personas que vienen de un cco que no tenia biometrico a uno que si tiene
	begin 
     
	SELECT 
		tHoy.codigo, nombre,
		tHoy.cco AS cco_hoy, 
		ccoHoy.descripcion AS descripcion_hoy,
		tAyer.cco AS cco_ayer,
		ccoAyer.descripcion AS descripcion_ayer
	FROM RRHH.trabajadoresDatosDiario tHoy
	JOIN RRHH.trabajadoresDatosDiario tAyer 
		ON tHoy.codigo = tAyer.codigo
		AND tHoy.fecha = CAST(GETDATE() AS DATE)
		AND tAyer.fecha = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
	JOIN Catalogos.VW_CCO ccoHoy
		ON tHoy.cco = ccoHoy.cco
	JOIN Catalogos.VW_CCO ccoAyer
		ON tAyer.cco = ccoAyer.cco
		inner join rrhh.vw_datostrabajadoresbasico ta on ta.codigo =  tHoy.codigo
	WHERE 
		tHoy.cco <> tAyer.cco
		AND ccoHoy.tieneBimetrico = 1
		AND ccoAyer.tieneBimetrico <> 1
		 
	end
	else if @tipo = 12----- Personas que vienen de un cco que  tenia biometrico a uno que no tiene
	begin 
     
	SELECT 
		tHoy.codigo, nombre,
		tHoy.cco AS cco_hoy, 
		ccoHoy.descripcion AS descripcion_hoy,
		tAyer.cco AS cco_ayer,
		ccoAyer.descripcion AS descripcion_ayer
	FROM RRHH.trabajadoresDatosDiario tHoy
	JOIN RRHH.trabajadoresDatosDiario tAyer 
		ON tHoy.codigo = tAyer.codigo
		AND tHoy.fecha = CAST(GETDATE() AS DATE)
		AND tAyer.fecha = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
	JOIN Catalogos.VW_CCO ccoHoy
		ON tHoy.cco = ccoHoy.cco
	JOIN Catalogos.VW_CCO ccoAyer
		ON tAyer.cco = ccoAyer.cco
		inner join rrhh.vw_datostrabajadoresbasico ta on ta.codigo =  tHoy.codigo
	WHERE 
		tHoy.cco <> tAyer.cco
		AND ccoHoy.tieneBimetrico <> 1
		AND ccoAyer.tieneBimetrico= 1
		 
	end

End	 
 

   
