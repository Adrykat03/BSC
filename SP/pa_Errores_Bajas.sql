-- =============================================
-- Create:		Mateo Alvear
-- Edit date:	08-09-2022
-- Description:  
--				
-- =============================================
CREATE PROCEDURE [Avisos].[pa_Errores_Bajas]
AS
BEGIN
	DECLARE @fi date, @ff date, @f date, @fecha date = DATEADD(DAY, -1, CONVERT(date, GETDATE()))

	SELECT @f = FechaInicioNomina, @ff = FechaFinNomina FROM [Utilidades].[fn_fechasperiodonomina](@fecha)
	SELECT @fi = FechaInicioNomina FROM [Utilidades].[fn_fechasperiodonomina](DATEADD(day, -1, @f))

	DECLARE @CTE_tabla_cco AS TABLE(cco VARCHAR(30), descripcion VARCHAR (100), cadena VARCHAR(50))
		INSERT INTO @CTE_tabla_cco 
			SELECT COO, CCO_DESCRIPCION, DESCRIPCION_CLASE 
				FROM Adam.[dbo].[FPV_AGR_COM_CLASE] WITH (NOLOCK)
				WHERE REFERENCIA_20 = 'SI' AND [STATUS] = 'ABIERTO' AND referencia_09 in ('DP02','DP01')
	--SELECT @fi AS fi, @ff AS ff, @f AS f
	--------------------------------------------------- CREACION DE LAS TABLAS TEMPORALES ----------------------------------------------------------

	IF OBJECT_ID(N'tempdb..#tmp_bajasda', N'U') IS NOT NULL
					DROP TABLE #tmp_bajasda

	SELECT dt.CCO, b.Compania, dt.Codigo, dt.Nombre, dt.Compania_Desc,
	dt.Clase_Nomina, dt.Desc_Clase_Nomina, dt.Desc_CCO, b.Trabajador, dt.Fecha_bajaIndice, dt.Cargo, dt.Fecha_Ingreso, dt.Fecha_Induccion, 
	CASE WHEN DATEPART(YEAR, p.fecha_creacion) = 1900 THEN p.lastUpdate ELSE p.fecha_creacion END fecha_creacion
		INTO #tmp_bajasda
			FROM adam.dbo.Indices_FPV_BajasCalculo b WITH(NOLOCK) 
			INNER JOIN RRHH.vw_datosTrabajadores dt ON LEFT(dt.Codigo,10) = b.Trabajador
			INNER JOIN RRHH.Personas p ON p.cedula_dni = b.Trabajador
			WHERE dt.Fecha_bajaIndice between @f AND @ff and b.Fecha_Ingreso = dt.Fecha_Ingreso AND b.causa_baja <> 08
			

	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
					DROP TABLE #tmp_errores

	CREATE TABLE #tmp_errores(
		[Fecha Baja] smalldatetime,
		CCO char(20),
		Compania char(50),
		codigo varchar(50),
		nombre varchar(150),
		Compania_Desc varchar(150),
		Clase_Nomina varchar(100),
		Desc_Clase_Nomina varchar(50),
		Desc_CCO varchar(150),
		Trabajador varchar(10),
		fecha_bajaindice smalldatetime,
		cargo varchar(50),
		observacion varchar(150),
		fecha_ingreso date,
		fecha_induccion date
	)

	IF OBJECT_ID(N'tempdb..#tmp_marcajes', N'U') IS NOT NULL
					DROP TABLE #tmp_marcajes
	IF OBJECT_ID(N'tempdb..#tmp_horarios', N'U') IS NOT NULL
					DROP TABLE #tmp_horarios
	IF OBJECT_ID(N'tempdb..#tmp_vacaciones', N'U') IS NOT NULL
					DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias', N'U') IS NOT NULL
					DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_calendario', N'U') IS NOT NULL
					DROP TABLE #tmp_calendario

	CREATE TABLE #tmp_calendario(
		fecha date
	);

	SELECT m.codigo_emp_equipo, m.fecha, m.estatus, m.cco_trab
	INTO #tmp_marcajes FROM Asistencia.marcajes m WITH(NOLOCK) INNER JOIN #tmp_bajasda b ON b.Codigo = m.codigo_emp_equipo
	WHERE m.fecha between @fi and b.Fecha_bajaIndice or m.fecha > b.Fecha_bajaIndice

	SELECT rth.codigo, rth.fecha
	INTO #tmp_horarios FROM Asistencia.rel_trab_horarios rth WITH(NOLOCK) INNER JOIN #tmp_bajasda b ON b.Codigo = rth.codigo
	WHERE rth.fecha between @fi and b.Fecha_bajaIndice or rth.fecha > b.Fecha_bajaIndice

	SELECT sv.codigo, sv.fecha_inicio, sv.fecha_fin
	INTO #tmp_vacaciones FROM Vacacion.Solicitud_vacaciones sv WITH(NOLOCK) INNER JOIN #tmp_bajasda b ON b.Codigo = sv.codigo
	WHERE (((fecha_inicio between @fi and b.Fecha_bajaIndice or fecha_inicio < @fi) AND fecha_fin > b.Fecha_bajaIndice) OR fecha_inicio > b.Fecha_bajaIndice)

	SELECT a.Codigo, a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.id_tipoAusencia
	INTO #tmp_ausencias FROM Ausencias.Accidentes a WITH(NOLOCK) INNER JOIN #tmp_bajasda b ON b.Codigo = a.Codigo
	WHERE ((a.Fecha_Ini_Incapacidad between @fi and b.Fecha_bajaIndice or a.Fecha_Ini_Incapacidad < @fi) AND a.Fecha_Fin_Incapacidad > b.Fecha_bajaIndice)
	AND a.id_tipoAusencia IN ('01', '02', '04', '09')

	DECLARE @fini date = @fi, @ffin date = @ff
	WHILE @fini < @ffin
	BEGIN
		INSERT INTO #tmp_calendario VALUES(@fini)
		SET @fini = DATEADD(day, 1, @fini)
	END
	--------------------------------------------------- FIN CREACION DE LAS TABLAS TEMPORALES ----------------------------------------------------------

	--------------------------------------------------- MARCAJES ----------------------------------------------------------

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'FALTAN MARCAJES ANTERIORES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_calendario c 
	INNER JOIN #tmp_bajasda b ON c.fecha between @fi and b.Fecha_bajaIndice
	INNER JOIN @CTE_tabla_cco cc ON cc.cco = b.CCO 
	WHERE NOT EXISTS(SELECT 1 FROM #tmp_marcajes m WHERE m.fecha = c.fecha and m.codigo_emp_equipo = b.Codigo) AND (c.fecha BETWEEN @fi and b.Fecha_bajaIndice AND c.fecha > b.Fecha_Ingreso)
	AND NOT((CONVERT(DATE, fecha_creacion) <> CONVERT(DATE, b.Fecha_Ingreso)) AND (fecha_creacion > @f AND b.Fecha_Ingreso < @f))

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'MARCAJES ANTERIORES PENDIENTES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b INNER JOIN @CTE_tabla_cco tc ON tc.cco = b.CCO 
	WHERE EXISTS(SELECT 1 FROM #tmp_marcajes m WHERE b.Codigo = m.codigo_emp_equipo and m.fecha between @fi and b.Fecha_bajaIndice AND m.estatus = '0')
	AND NOT((CONVERT(DATE, fecha_creacion) <> CONVERT(DATE, b.Fecha_Ingreso)) AND (fecha_creacion > @f AND b.Fecha_Ingreso < @f))

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'MARCAJES ANTERIORES SJ O PA', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b INNER JOIN @CTE_tabla_cco tc ON tc.cco = b.CCO 
	WHERE EXISTS(SELECT 1 FROM #tmp_marcajes m WHERE b.Codigo = m.codigo_emp_equipo and m.fecha between @fi and b.Fecha_bajaIndice AND m.estatus = '1')
	AND NOT((CONVERT(DATE, fecha_creacion) <> CONVERT(DATE, b.Fecha_Ingreso)) AND (fecha_creacion > @f AND b.Fecha_Ingreso < @f))

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'MARCAJES ANTERIORES APROBADOS', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b INNER JOIN @CTE_tabla_cco tc ON tc.cco = b.CCO 
	WHERE EXISTS(SELECT 1 FROM #tmp_marcajes m WHERE b.Codigo = m.codigo_emp_equipo and m.fecha between @fi and b.Fecha_bajaIndice AND m.estatus = '2')
	AND NOT((CONVERT(DATE, fecha_creacion) <> CONVERT(DATE, b.Fecha_Ingreso)) AND (fecha_creacion > @f AND b.Fecha_Ingreso < @f))

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'EXISTEN MARCAJES POSTERIORES !!', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b INNER JOIN @CTE_tabla_cco tc ON tc.cco = b.CCO 
	WHERE EXISTS(SELECT 1 FROM #tmp_marcajes m WHERE m.codigo_emp_equipo = b.Codigo and m.fecha > b.Fecha_bajaIndice AND m.estatus IN (1,2,3,4))

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'EXISTEN MARCAJES POSTERIORES EN CERO', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b INNER JOIN @CTE_tabla_cco tc ON tc.cco = b.CCO 
	WHERE EXISTS(SELECT 1 FROM #tmp_marcajes m WHERE m.codigo_emp_equipo = b.Codigo and m.fecha > b.Fecha_bajaIndice AND m.estatus NOT IN (1,2,3,4))


	--------------------------------------------------- FIN MARCAJES ----------------------------------------------------------


	--------------------------------------------------- HORARIOS ----------------------------------------------------------


	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'FALTAN HORARIOS ANTERIORES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_calendario c 
	INNER JOIN #tmp_bajasda b ON c.fecha between @fi and b.Fecha_bajaIndice
	INNER JOIN @CTE_tabla_cco cc ON cc.cco = b.CCO 
	WHERE NOT EXISTS(SELECT 1 FROM #tmp_horarios rth WHERE rth.codigo = b.Codigo and rth.fecha = c.fecha) AND (c.fecha BETWEEN @fi and b.Fecha_bajaIndice AND c.fecha > b.Fecha_Ingreso)
	AND NOT((CONVERT(DATE, fecha_creacion) <> CONVERT(DATE, b.Fecha_Ingreso)) AND (fecha_creacion > @f AND b.Fecha_Ingreso < @f))

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'EXISTEN HORARIOS POSTERIORES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b INNER JOIN @CTE_tabla_cco tc ON tc.cco = b.CCO 
	WHERE EXISTS(SELECT 1 FROM #tmp_horarios rth WHERE rth.codigo = b.Codigo and rth.fecha > b.Fecha_bajaIndice)

	--------------------------------------------------- FIN HORARIOS ----------------------------------------------------------


	--------------------------------------------------- VACACIONES ----------------------------------------------------------

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'VACACIONES VIGENTES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE EXISTS(SELECT 1 FROM #tmp_vacaciones v WHERE v.codigo = b.Codigo
	AND (fecha_inicio between @fi and b.Fecha_bajaIndice or fecha_inicio < @fi) AND fecha_fin > b.Fecha_bajaIndice)


	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'VACACIONES POSTERIORES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE EXISTS(SELECT 1 FROM #tmp_vacaciones v WHERE v.codigo = b.Codigo AND v.fecha_inicio > b.Fecha_bajaIndice)

	--------------------------------------------------- FIN VACACIONES ----------------------------------------------------------

	--------------------------------------------------- AUSENCIAS ----------------------------------------------------------

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'ENFERMEDAD GENERAL VIGENTE', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE EXISTS(SELECT 1 FROM #tmp_ausencias a WHERE a.Codigo = b.Codigo AND
	(a.Fecha_Ini_Incapacidad between @fi and b.Fecha_bajaIndice or a.Fecha_Ini_Incapacidad < @fi) AND a.Fecha_Fin_Incapacidad > b.Fecha_bajaIndice AND a.id_tipoAusencia = '02')

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'MATERNIDAD VIGENTE', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE EXISTS(SELECT 1 FROM #tmp_ausencias a WHERE a.Codigo = b.Codigo AND
	(a.Fecha_Ini_Incapacidad between @fi and b.Fecha_bajaIndice or a.Fecha_Ini_Incapacidad < @fi) AND a.Fecha_Fin_Incapacidad > b.Fecha_bajaIndice AND a.id_tipoAusencia = '01')

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'PATERNIDAD VIGENTE', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE EXISTS(SELECT 1 FROM #tmp_ausencias a WHERE a.Codigo = b.Codigo AND
	(a.Fecha_Ini_Incapacidad between @fi and b.Fecha_bajaIndice or a.Fecha_Ini_Incapacidad < @fi) AND a.Fecha_Fin_Incapacidad > b.Fecha_bajaIndice AND a.id_tipoAusencia = '04')

	INSERT INTO #tmp_errores
	SELECT DISTINCT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'MATERNIDAD POR REEMPLAZO VIGENTE', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE EXISTS(SELECT 1 FROM #tmp_ausencias a WHERE a.Codigo = b.Codigo AND
	(a.Fecha_Ini_Incapacidad between @fi and b.Fecha_bajaIndice or a.Fecha_Ini_Incapacidad < @fi) AND a.Fecha_Fin_Incapacidad > b.Fecha_bajaIndice AND a.id_tipoAusencia = '09')

	--------------------------------------------------- FIN AUSENCIAS ----------------------------------------------------------

	INSERT INTO #tmp_errores SELECT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'COSTO HORARIO CALCULADO POSTERIORES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE (SELECT COUNT(1) FROM Asistencia.calculosHorarios ch WHERE ch.codigo = b.Codigo AND ch.fecha > b.Fecha_bajaIndice) > 0

	INSERT INTO #tmp_errores SELECT b.Fecha_bajaIndice, b.CCO,  b.Compania, b.Codigo, b.Nombre, b.Compania_Desc,
	b.Clase_Nomina, b.Desc_Clase_Nomina, b.Desc_CCO, b.Trabajador, b.Fecha_bajaIndice, b.Cargo, 'COSTO MARCAJE CALCULADO POSTERIORES', b.Fecha_Ingreso, b.Fecha_Induccion
	FROM #tmp_bajasda b WHERE (SELECT COUNT(1) FROM Asistencia.costos_marcaciones ch WHERE ch.codigo = b.Codigo AND ch.fecha > b.Fecha_bajaIndice) > 0



	DECLARE @tiene int = 0
	declare @html varchar(max)='',
		@asunto varchar (400),
		@saludos varchar(500)='',
		@msg varchar (500)='',
		@destinatarios varchar(max) = (SELECT valor FROM Configuracion.parametros WHERE parametro = 'AL_Error_Baja')
	SELECT DISTINCT @tiene = COUNT(1) FROM #tmp_errores
	IF (@tiene <> 0)
	BEGIN
		select @asunto=descripcion , @saludos=valor, @msg=referencia_06  from configuracion.parametros where parametro='MailPrebAviso'

		select @html=N' <style type="text/css">
								.box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
								.box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
								.box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } 
						</style>'+
						N'<body>'+
							N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
							N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> Mediante el presente ponemos en su conocimiento,
							el listado de trabajadores que fue generada la baja en el periodo de nomina ' + CONVERT(varchar(10), @f) + ' al ' + CONVERT(varchar(10), @ff) + '. Por favor agradecemos realizar los procesos correspondientes en sus respectivas áreas.</p> '+
							N'<br/>'+
							N'<h3>Descripción observaciones</h3>'+
							N'<table class="box-table" >' +
							N'<tr>'+   
							N'<th align="left">Observación</th>'+
							N'<th align="left">Descripción</th>'+
							N'</tr>'+
							N'<tr><td>FALTAN HORARIOS ANTERIORES</td><td>Faltan horarios desde la fecha de corte hasta la fecha de baja.</td></tr>'+
							N'<tr><td>EXISTEN HORARIOS POSTERIORES</td><td>Existen horarios posteriores a la fecha de baja.</td></tr>'+
							N'<tr><td>FALTAN MARCAJES ANTERIORES</td><td>Faltan marcajes desde la fecha de corte hasta la fecha de baja.</td></tr>'+
							N'<tr><td>EXISTEN MARCAJES POSTERIORES</td><td>Trabajador tiene registrados marcajes posteriores a la fecha de baja.</td></tr>'+
							N'<tr><td>MARCAJES ANTERIORES PENDIENTES</td><td>Trabajador tiene registrados marcajes con estado "PENDIENTE" anterior a la fecha de baja.</td></tr>'+
							N'<tr><td>MARCAJES ANTERIORES SJ O PA</td><td>Trabajador tiene registrados marcajes con estado "HE SIN JUST" o "POR ASENTAR" anterior a la fecha de baja.</td></tr>'+
							N'<tr><td>MARCAJES ANTERIORES APROBADOS</td><td>Trabajador tiene registrados marcajes con estado "APROBADO" anterior a la fecha de baja.</td></tr>'+
							N'<tr><td>VACACIONES VIGENTES</td><td>Trabajador tiene vacaciones durante la fecha de baja.</td></tr>'+
							N'<tr><td>VACACIONES POSTERIORES</td><td>Trabajador tiene vacaciones programadas posteriores a la fecha de baja.</td></tr>'+
							N'<tr><td>ENFERMEDAD GENERAL VIGENTE</td><td>Trabajador tiene ausencias por enfermedad general durante la fecha de baja.</td></tr>'+
							N'<tr><td>MATERNIDAD VIGENTE</td><td>Trabajador tiene ausencias por maternidad durante la fecha de baja.</td></tr>'+
							N'<tr><td>PATERNIDAD VIGENTE</td><td>Trabajador tiene ausencias por paternidad durante la fecha de baja.</td></tr>'+
							N'<tr><td>MATERNIDAD POR REEMPLAZO VIGENTE</td><td>Trabajador tiene ausencias por maternidad por reemplazo durante la fecha de baja.</td></tr>'+
							N'<tr><td>COSTO HORARIO CALCULADO POSTERIORES</td><td>Trabajador tiene cálulos de costo horario en fechas posteriores a la baja.</td></tr>'+
							N'<tr><td>COSTO MARCAJE CALCULADO POSTERIORES</td><td>Trabajador tiene cálulos de costo horario en fechas posteriores a la baja.</td></tr>'+
							N'<tr><td>EXISTEN MARCAJES POSTERIORES EN CERO</td><td>Trabajador tiene marcajes posteriores a la fecha de baja con estado 0.</td></tr>'+
							N'</table>'+

							N' <br/>'+
							N'<h3>Observaciones</h3>'+
							N'<table class="box-table" >' +
							N' <tr>'+
							N' <th style="text-align:center"> Cod Compañía</th>'+
							N' <th style="text-align:left"> Compañía</th>'+
							N' <th style="text-align:center"> Cod Cadena</th>'+
							N' <th style="text-align:left"> Cadena</th>'+
  							N' <th style="text-align:left"> Cod CCO</th>'+
							N' <th style="text-align:left"> CCO</th>'+
							N' <th style="text-align:left"> Cédula</th>'+
							N' <th style="text-align:center"> Nombre</th>'+
							N' <th style="text-align:left"> Fecha Baja</th>'+
							N' <th style="text-align:center"> Cargo</th>'+
							N' <th style="text-align:center"> Fecha Ingreso</th>'+
							N' <th style="text-align:center"> Observación</th>'+
							N' <th style="text-align:center"> Ingreso Tarde</th>'+
							cast( (select   distinct 
										td= e.Compania, '',
										td= e.Compania_Desc, '',
										td= e.Clase_Nomina, '',
										td= e.Desc_Clase_Nomina, '',
										td= e.CCO, '',
										td= e.Desc_CCO, '',
										td= e.Trabajador, '',
										td= e.Nombre, '',			  
										td= ISNULL(CONVERT(VARCHAR(12), e.fecha_bajaindice, 103), ' '), '',
										td= ISNULL(e.cargo, ' '), '',
										td= ISNULL(CONVERT(VARCHAR(12), e.fecha_ingreso, 103), ' '), '',
										td= e.observacion, '',
										td= CASE WHEN (ISNULL((SELECT Asistencia.fn_verificarContratacionPosteriorLegalizado(e.fecha_ingreso, e.codigo, e.cco,'A')), '') = 'NO') THEN 'NO' ELSE 'SI' END, ''
										FROM #tmp_errores e
							  order by e.Compania, e.Clase_Nomina, e.Nombre
							FOR XML PATH('tr'),TYPE
							) as varchar(max))+
								N'</table>'+
								N' <br/></body>'  ;


								if @html is not null
								begin
									 -- INSERT notificación consolidada
									 INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
									 VALUES ('A', 'Bajas', 'pa_Errores_Bajas', 'Notificación de Pre-Bajas con error', @html, @tiene, @destinatarios, @fi, @ff);
									 exec msdb.dbo.Sp_send_dbmail
									 @profile_name = 'Informacion_Nomina',  
									 @Subject = 'Notificación de Pre-Bajas con error',
									 @recipients = @destinatarios,
									 @body_format= 'html',
									 @body = @html 
								end

	END
	ELSE
	BEGIN
		select @asunto=descripcion , @saludos=valor, @msg=referencia_06  from configuracion.parametros where parametro='MailPrebAviso'
		set @msg=replace(@msg,'@fecha',convert(varchar(12),@fecha,103))

		select @html=N' <style type="text/css">
							.box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
							.box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
							.box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } 
						</style>'+
						N'<body>'+
							N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
							N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> Mediante el presente ponemos en su conocimiento,
						el listado de trabajadores que fue generada la baja en el periodo de nomina ' + CONVERT(varchar(10), @f) + ' al ' + CONVERT(varchar(10), @ff) + '. Por favor agradecemos realizar los procesos correspondientes en sus respectivas áreas.</p> '+
							N'<br/>'+
							N'<h2>Observaciones</h2>'+
							N'<h3>No se encontraron errores con las bajas entre ' + CONVERT(varchar(10), @f) + ' al ' + CONVERT(varchar(10), @ff) + '</h3></br>'+
						N' <br/><br/><br/><br/>  </body>';

						if @html is not null
						begin
						-- INSERT notificación consolidada
						INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
						VALUES ('A', 'Bajas', 'pa_Errores_Bajas', 'Notificación de Pre-Bajas con error', @html, @tiene, @destinatarios, @fi, @ff);
						exec msdb.dbo.Sp_send_dbmail
							@profile_name = 'Informacion_Nomina', 
							@Subject = 'Notificación de Pre-Bajas con error',
							@recipients = @destinatarios,
							@body_format= 'html',
							@body = @html
						end
	END
	IF OBJECT_ID(N'tempdb..#tmp_marcajes', N'U') IS NOT NULL
					DROP TABLE #tmp_marcajes
	IF OBJECT_ID(N'tempdb..#tmp_horarios', N'U') IS NOT NULL
					DROP TABLE #tmp_horarios
	IF OBJECT_ID(N'tempdb..#tmp_vacaciones', N'U') IS NOT NULL
					DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias', N'U') IS NOT NULL
					DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_calendario', N'U') IS NOT NULL
					DROP TABLE #tmp_calendario
END