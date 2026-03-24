CREATE PROCEDURE [Avisos].[pa_diferencias_he_a_hea] (
      @fechaIni DATE
    , @fechaFin DATE
	,@tipoConsulta tinyint
    )
AS
 --set nocount on
BEGIN
  --  DECLARE @tableMarcajes AS TABLE (
  --        Desc_Clase_Nomina VARCHAR(500)
  --      , cco VARCHAR(10)
  --      , CCO_Desc VARCHAR(350)
  --      , trabajador CHAR(20)
  --      , nombre VARCHAR(280)
		--, contrato varchar(15)
  --      , fecha VARCHAR(30) 
  --      , marcaje_just VARCHAR(80)
  --      , marcaje_aprob VARCHAR(80) 
  --      , minutos_trabajados  int
  --      , horario VARCHAR(80)
  --      , heA int
  --      , he  int
  --      , tipoHe VARCHAR(15)
		--, tipoHeN  int --1 =25,2= 50,3=100,4 =fer
  --      , tipo SMALLINT
		--, marcaje varchar(30)
		--, accion varchar(250)
		--, usuario varchar(350)
  --      ) --tipo 1= hea >he 2= he>hea

		truncate table  tableMarcajes

		declare @Apruebausuario as table (usuarionombre varchar(400),codigo  char(20), fechamarcaje date, fechaaccion date, accion varchar(350)) 

		declare @tablaTrabajadores as table (codigo char(20), nombre varchar(200), Desc_Clase_Nomina varchar(320), trabajador char(10))

		insert into @tablaTrabajadores
		select codigo , nombre , Desc_Clase_Nomina, trabajador from RRHH.vw_datosTrabajadores
		where fecha_baja >=dateadd(day,-2,@fechaIni)

		
		--insert into @tablaTrabajadores
		--select codigo , nombre , Desc_Clase_Nomina, trabajador from RRHH.vw_datosTrabajadores
		--where situacion = 'Activo'
		 

		truncate table trabajadoresDatosDiarioTempReporte
		truncate table marcajesTempReporte
		truncate table horariostempReporte

		insert into trabajadoresDatosDiarioTempReporte
		select *  from RRHH.trabajadoresDatosDiario
		where fecha  between @fechaIni and @fechaFin
		  
		 insert into  marcajesTempReporte(id_marcajes,codigo_emp_equipo, fecha , hora1_just ,hora2_just , hora3_just,hora4_just,
          hora1_justA ,hora2_justA , hora3_justA,hora4_justA,
         he25A  ,he50A,he100A,hefA,he25  ,he50,he100,hef,  aux07, estatus, horas_trabajadasA,  hora1 ,hora2,hora3,hora4, fecha_real , fecha_creacion) 
		 select id_marcajes,codigo_emp_equipo, fecha , hora1_just ,hora2_just , hora3_just,hora4_just,
		 hora1_justA ,hora2_justA , hora3_justA,hora4_justA,
		 he25A  ,he50A,he100A,hefA,he25  ,he50,he100,hef,
		 aux07, estatus,case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end ,
		 hora1 ,hora2,hora3,hora4,fecha_real, fecha_creacion
		 from asistencia.marcajes m
		 where fecha between @fechaIni and @fechaFin
		  
		 insert into horariostempReporte
		 select * from  Asistencia.rel_trab_horarios 
		  where fecha between @fechaIni and @fechaFin


		if @tipoConsulta =1
		begin
		 insert into @Apruebausuario
		 select usuarionombre , codigo , fechamarcaje, fechaaccion, accion
		 from asistencia.Auditoria_justificacion_marcajes i
         where  fechamarcaje between dateadd(day,-2,@fechaIni) and dateadd(day, 2,@fechaFin)
	     order by fechaaccion desc 
		  
		end

		 
    -------------------------------------------------------------------------------------------------------------------------------------
    -------Tipo 2 le subieron las he
    -------------------------------------------------------------------------------------------------------------------------------------
  
  -----------------He25
   INSERT INTO  tableMarcajes (
          Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
		, contrato  
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT ''
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
        ,  ta.codigo 
        ,'' as nombre
		, ta.contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
         , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
         ,  case when isnull(hora4_justA ,'') in ('', '0') then   isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end
 
        , CASE 
            WHEN  j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN  j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN  h.id_jornada_definicion = 9
                THEN h.notas
            END
        , he25A
        , he25
        , 'HE25',1
        , 1
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	   , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM  marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) > 0
        AND he25A > he25
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
         AND m.estatus in (4,3)
    ORDER BY m.fecha
        , m.codigo_emp_equipo
 
 -------------------He50
   INSERT INTO tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
	    , contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT ''  
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
        ,  ta.codigo 
        , '' as nombre
		, contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
        , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
        ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end
 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN h.id_jornada_definicion = 9
                THEN h.notas
            END
        , he50A
        , he50
        , 'HE50',2
        , 1
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	   , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) > 0
        AND he50A > he50
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
         AND m.estatus in (4,3)
    ORDER BY  m.fecha
        , m.codigo_emp_equipo

 
		-- -------------------He100
   
   INSERT INTO  tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
	    , contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT '' 
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
        , ta.codigo 
        , '' as nombre
        , contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
        , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
        ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end
 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN h.id_jornada_definicion = 9
                THEN h.notas
            END
        , he100A
        , he100
        , 'HE100'
        , 3
        , 1
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	  , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) > 0
        AND he100A > he100
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
        AND m.estatus in (4,3)
    ORDER BY  m.fecha
        , m.codigo_emp_equipo

 
		 -------------------HeF
  
   INSERT INTO  tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
	    , contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT ''
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
         , ta.codigo
        ,'' as  nombre
        , contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
       , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
       ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN h.id_jornada_definicion = 9
                THEN h.notas
            END
        , hefa
        , hef
        , 'HEFE'
        ,4
        , 1
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	  , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) > 0
        AND hefa > hef
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
         AND m.estatus in (4,3)
    ORDER BY  m.fecha
        , m.codigo_emp_equipo

  
    -------------------------------------------------------------------------------------------------------------------------------------
    -------Tipo 2 le bajaron las he
    -------------------------------------------------------------------------------------------------------------------------------------
    
	-----------------------He 25
	INSERT INTO  tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
		, contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT ''
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
         , ta.codigo
        , '' as nombre
        , contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
        , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
        ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN h.id_jornada_definicion = 9
                THEN h.notas
            END
        , he25A
        , he25
        , 'HE25',1
        , 2
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	  , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0)>= 0
        AND he25A < he25
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
        AND m.estatus in (4,3)
    ORDER BY   m.fecha
        , m.codigo_emp_equipo

  
   -------------------He50
   INSERT INTO  tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
	    , contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT '' 
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
         , ta.codigo
        , '' as nombre
        , contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
        , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
         ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN  h.id_jornada_definicion =9
                THEN h.notas
            END
        , he50A
        , he50
        , 'HE50'
        , 2
        , 2
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	   , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) >= 0
        AND he50A < he50
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
        AND m.estatus in (4,3)
    ORDER BY   m.fecha
        , m.codigo_emp_equipo
  
 -------------------He100
   INSERT INTO  tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
	    , contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT ''
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
        , ta.codigo
        , '' as nombre
        , contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
        , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
        ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN  h.id_jornada_definicion  = 9
                THEN h.notas
            END
        , he100A
        , he100
        , 'HE100'
        , 3
        , 2
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	  , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) >= 0
        AND he100A < he100
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
        AND m.estatus in (4,3)
    ORDER BY  m.fecha
        , m.codigo_emp_equipo
 
		 -------------------HeF
   
   INSERT INTO tableMarcajes (
        Desc_Clase_Nomina
        , cco
        , CCO_Desc
        , trabajador
        , nombre
		, contrato 
        , fecha
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados
        , horario
        , heA
        , he
        , tipoHe
		, tipoHeN
        , tipo
		, marcaje  
		, accion 
		, usuario
        )
    SELECT ''
        , ta.cco
        , (
            SELECT descripcion
            FROM Catalogos.centro_costos c
            WHERE c.cco = ta.cco
            ) AS CCO_Desc
         , ta.codigo
        , '' as nombre
        , contrato
        , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
        , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
         , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
    ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end
 
        , CASE 
            WHEN j.id_descanso NOT IN (6, 3)
                THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
            WHEN j.id_descanso IN (6, 3)
                AND j.id_jornada_definicion NOT IN (0, 9)
                THEN j.horadesde + ' a las ' + j.horahasta
            WHEN  h.id_jornada_definicion  = 9
                THEN h.notas
            END
        , hefa
        , hef
        , 'HEFE',4
        , 2
		,case when hora1 = '00' then '' 
              when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	         else hora1 +'-'+hora4 end as marcajes 
	   ,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	  , ( select top 1 i.usuarionombre from @Apruebausuario i
           where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha  and i.accion = 'Confirma horas extra'  
	       order by fechaaccion desc)
    FROM marcajesTempReporte m
    INNER JOIN horariostempReporte H
        ON h.codigo = m.codigo_emp_equipo
            AND h.fecha = m.fecha
    INNER JOIN Asistencia.jornadas_definicion j
        ON j.id_jornada_definicion = h.id_jornada_definicion 
    INNER JOIN trabajadoresDatosDiarioTempReporte ta
        ON ta.codigo = m.codigo_emp_equipo
            AND ta.fecha = m.fecha
    WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) >= 0
        AND hefa < hef
        AND m.fecha BETWEEN @fechaIni AND @fechaFin
        AND hora4_justA IS NOT NULL
        AND hora1_justA <> '0'
        AND hora1_justA <> ''
        AND m.estatus in (4,3)
    ORDER BY   m.fecha
        , m.codigo_emp_equipo
		 

		-----------------------------------------------------------
		----Poblacion sin problemas con HE
		----------------------------------------------------------
	INSERT INTO  tableMarcajes (
    Desc_Clase_Nomina
    , cco
    , CCO_Desc
    , trabajador
    , nombre
	, contrato 
    , fecha
    , marcaje_just
    , marcaje_aprob
    , minutos_trabajados
    , horario
    , heA
    , he
    , tipoHe
	, tipoHeN
    , tipo
	, marcaje  
	, accion 
	, usuario
    )
SELECT  ''
    , ta.cco
    , (
        SELECT descripcion
        FROM Catalogos.centro_costos c
        WHERE c.cco = ta.cco
        ) AS CCO_Desc
   ,  ta.codigo 
    , '' as nombre
    , contrato
    , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
    , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
    , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
    , case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end 
    , CASE 
        WHEN j.id_descanso NOT IN (6, 3)
            THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
        WHEN j.id_descanso IN (6, 3)
            AND j.id_jornada_definicion NOT IN (0, 9)
            THEN j.horadesde + ' a las ' + j.horahasta
        WHEN  h.id_jornada_definicion  = 9
            THEN h.notas
        END
    , hefa
    , hef
    , 'SPCH'
    , 4
    , 3
	, case when hora1 = '00' then '' 
            when hora2 <> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	        else hora1 +'-'+hora4 end as marcajes 
	, (select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	, ( select top 1 i.usuarionombre from @Apruebausuario i
        where  codigo =m.codigo_emp_equipo  and convert(date,fechamarcaje) =convert(date,m.fecha )
	    order by fechaaccion desc)
FROM marcajesTempReporte m
INNER JOIN horariostempReporte H
    ON h.codigo = m.codigo_emp_equipo
        AND h.fecha = m.fecha
INNER JOIN Asistencia.jornadas_definicion j
    ON j.id_jornada_definicion = h.id_jornada_definicion 
INNER JOIN trabajadoresDatosDiarioTempReporte ta
    ON ta.codigo = m.codigo_emp_equipo
        AND ta.fecha = m.fecha
WHERE ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) > 0
    AND ISNULL(he25, 0) + ISNULL(he50, 0) + ISNULL(he100, 0) + ISNULL(hef, 0) = ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0)
    AND m.fecha BETWEEN @fechaIni AND @fechaFin
	---- and ta.codigo like '%17245851102013042206%'
    AND m.estatus in (4,3) 
ORDER BY   m.fecha
    , m.codigo_emp_equipo

--    -----------------------------------------------------------
--	----Poblacion sin problemas sin HE
--	----------------------------------------------------------
  INSERT INTO  tableMarcajes (
    Desc_Clase_Nomina
    , cco
    , CCO_Desc
    , trabajador
    , nombre
	, contrato 
    , fecha
    , marcaje_just
    , marcaje_aprob
    , minutos_trabajados
    , horario
    , heA
    , he
    , tipoHe
	, tipoHeN
    , tipo
	, marcaje  
	, accion 
	, usuario
    )
SELECT '' 
    , ta.cco
    , (
        SELECT descripcion
        FROM Catalogos.centro_costos c
        WHERE c.cco = ta.cco
        ) AS CCO_Desc
    , ta.codigo
    , '' as nombre
    , contrato
    , FORMAT(m.fecha, 'dd/MM/yyyy') AS fecha
    , hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just
    , case when isnull(hora4_justA ,'') in ('', '0') then  hora1_just + '-' + hora2_just + '/' + hora3_just + '-' + hora4_just else hora1_justA + '-' + hora2_justA + '/' + hora3_justA + '-' + hora4_justA end
    ,  case when isnull(hora4_justA ,'') in ('', '0') then  isnull(m.aux03,horas_trabajadasA) else  isnull(horas_trabajadasA,m.aux03) end
    , CASE 
        WHEN j.id_descanso NOT IN (6, 3)
            THEN j.horadesde + '-' + j.horadesdedescanso + ' a las ' + j.horadeshadescanso + '-' + j.horahasta
        WHEN j.id_descanso IN (6, 3)
            AND j.id_jornada_definicion NOT IN (0, 9)
            THEN j.horadesde + ' a las ' + j.horahasta
        WHEN  h.id_jornada_definicion  = 9
            THEN h.notas
        END
    , hefa
    , hef
    , 'SHE'
    , 4
    , 4
	,case when hora1 = '00' then '' 
            when hora2<> '' then hora1 +'-'+hora2+' a '+hora3+'-'+hora4 
	        else hora1 +'-'+hora4 end as marcajes 
	,(select descripcion from  Asistencia.marcajes_acciones where codigo_accion =aux07)
	, ( select top 1 i.usuarionombre from @Apruebausuario i
        where  codigo =m.codigo_emp_equipo and fechamarcaje =m.fecha 
	    order by fechaaccion desc)
FROM marcajesTempReporte m
INNER JOIN horariostempReporte H
    ON h.codigo = m.codigo_emp_equipo
        AND h.fecha = m.fecha
INNER JOIN Asistencia.jornadas_definicion j
    ON j.id_jornada_definicion = h.id_jornada_definicion 
INNER JOIN trabajadoresDatosDiarioTempReporte ta
    ON ta.codigo = m.codigo_emp_equipo
        AND ta.fecha = m.fecha
WHERE   ISNULL(he25, 0) + ISNULL(he50, 0) + ISNULL(he100, 0) + ISNULL(hef, 0) = 0
    AND ISNULL(he25A, 0) + ISNULL(he50A, 0) + ISNULL(he100A, 0) + ISNULL(hefA, 0) = 0
    AND m.fecha BETWEEN @fechaIni AND @fechaFin 
    AND m.estatus in (4,3)  ---and ta.codigo like '%17245851102013042206%'
ORDER BY m.fecha,m.codigo_emp_equipo
		 

  if @tipoConsulta = 1 ---detalle
  begin
     Select  c.Cadena
        , t.cco
        , CCO_Desc
        , trabajador
        , '' as nombre
	    , (select descripcion from catalogos.relaciones_laborales where relacion_laboral =t.contrato) as contrato 
        , fecha
		, upper(horario) as horario
		, marcaje 
		, accion 
        , marcaje_just
        , marcaje_aprob
        , minutos_trabajados  
        , he
		, heA
		, (he- heA ) as diferencia 
        , tipoHe
        , case when t.tipo = 1 then 'Sube las HE' 
		       when t.tipo =2  then 'Baja las HE'
			   when t.tipo =3  then 'Sin Problemas Con HE'
			   when t.tipo =4  then 'Sin Problemas Sin HE'  end as tipo 
		,usuario
		from  tableMarcajes t left JOIN Catalogos.VW_CCO c on t.cco = c.cco 
		order by  Cadena,tipo, tipoHe, CCO_Desc,fecha, trabajador
  end 
  else if @tipoConsulta =2 ---consolidado
   begin
     Select  
	      tipoHe 
	     ,c.Cadena
         ,CCO_Desc 
		 , (select descripcion from catalogos.relaciones_laborales where relacion_laboral =t.contrato)  as contrato
         ,CAST(SUM(he) / 60 AS VARCHAR) + ':' + RIGHT('0' + CAST(SUM(he) % 60 AS VARCHAR), 2)   AS HE
         ,CAST(SUM(heA) / 60 AS VARCHAR) + ':' + RIGHT('0' + CAST(SUM(heA) % 60 AS VARCHAR), 2)   AS HEA  
		 ,CAST((SUM(he) - SUM(heA)) / 60 AS VARCHAR) AS diferenciaHoras
		 ,RIGHT('0' + CAST((SUM(he) - SUM(heA)) % 60 AS VARCHAR), 2)   AS diferenciaMin  
		 , case when t.tipo = 1 then 'Sube las HE' 
		       when t.tipo =2  then 'Baja las HE'
			   when t.tipo =3  then 'Sin Problemas Con HE'
			   when t.tipo =4  then 'Sin Problemas Sin HE'  end as tipo 
		from  tableMarcajes t inner JOIN Catalogos.VW_CCO c on t.cco = c.cco
		group by Cadena,t.tipo, tipoHe, CCO_Desc, contrato
		order by Cadena,tipo, tipoHe, CCO_Desc
  end
END
