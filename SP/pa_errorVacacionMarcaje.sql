-- =============================================
-- Author:		Mateo Alvear
-- Create date: 18-11-2022
-- Description:	Notifica sobre errores en los marcajes que tengan vacación sin existir esta, o vacaciones que no tengan marcaje
-- =============================================
-- =============================================
-- Author:		Mateo Alvear
-- Edit date:	28-11-2022
-- Description:	A petición de Dennis se revisa unicamente del corte actual en adelante ya que las marcaciones anteriores no pueden cambiarse
-- =============================================
CREATE PROCEDURE [Avisos].[pa_errorVacacionMarcaje]
AS
BEGIN
	DECLARE @f date, @fi date, @ff date = GETDATE()

	SELECT @fi = FechaInicioNomina, @ff = FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(GETDATE())

	IF OBJECT_ID(N'tempdb..#tmp_vacaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias', N'U') IS NOT NULL
		DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_marcaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_marcaciones
	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
		DROP TABLE #tmp_errores

	DECLARE @CTE_tabla_cco AS TABLE(cco VARCHAR(30), descripcion VARCHAR (100), cadena VARCHAR(50))
	INSERT INTO @CTE_tabla_cco (cco, descripcion, cadena)	
	SELECT COO, CCO_DESCRIPCION, DESCRIPCION_CLASE 
	FROM Adam.[dbo].[FPV_AGR_COM_CLASE]
	WHERE REFERENCIA_20 = 'SI'
	AND [STATUS] = 'ABIERTO' AND referencia_09 in ('DP02','DP01')

	SELECT v.codigo, v.fecha_inicio, v.fecha_fin, v.estado INTO #tmp_vacaciones 
	FROM Vacacion.Solicitud_vacaciones v WITH(NOLOCK)
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = v.Codigo 
	INNER JOIN @CTE_tabla_cco dp ON dt.CCO = dp.cco
	WHERE fecha_inicio BETWEEN @fi AND @ff OR fecha_fin BETWEEN @fi AND @ff

	INSERT INTO #tmp_vacaciones(codigo, fecha_inicio, fecha_fin, estado) SELECT DISTINCT v.codigo, v.fecha_inicio, v.fecha_fin, v.estado FROM Vacacion.Solicitud_vacaciones v WITH(NOLOCK) INNER JOIN #tmp_vacaciones v2 ON v.codigo = v2.codigo

	DECLARE @fmin date, @fmax date
	SELECT @fmin = MIN(fecha_inicio), @fmax = MAX(fecha_fin) FROM #tmp_vacaciones

	SELECT a.* INTO #tmp_ausencias FROM Ausencias.Accidentes a
	INNER JOIN #tmp_vacaciones v ON a.Codigo = v.codigo

	SELECT m.* INTO #tmp_marcaciones FROM Asistencia.marcajes m WITH(nolock)
	INNER JOIN #tmp_vacaciones v ON v.codigo = m.codigo_emp_equipo 
	AND m.fecha BETWEEN (SELECT FechaInicioNomina FROM Utilidades.fn_fechasperiodonomina(v.fecha_inicio))
	AND (SELECT FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(v.fecha_fin))

	SELECT DISTINCT m.codigo_emp_equipo, MIN(m.fecha) Desde, MAX(m.fecha) Hasta,
	CONVERT(VARCHAR, m.fecha_inicio, 103) [Fecha Inicio Vacacion], CONVERT(VARCHAR, m.fecha_fin, 103) [Fecha Fin Vacacion], 'VACACION SIN MARCACION' Error
	INTO #tmp_errores
	FROM (SELECT m.*, v.fecha_inicio, v.fecha_fin FROM #tmp_marcaciones m
	INNER JOIN #tmp_vacaciones v ON m.fecha BETWEEN v.fecha_inicio AND v.fecha_fin AND m.codigo_emp_equipo = v.codigo) m
	WHERE m.comentario <> 'Vacaciones' 
	AND (SELECT COUNT(1) FROM #tmp_ausencias a WHERE a.Codigo = m.codigo_emp_equipo AND m.fecha BETWEEN a.Fecha_Ini_Incapacidad AND a.Fecha_Fin_Incapacidad ) = 0
	GROUP BY m.codigo_emp_equipo, m.fecha_inicio, m.fecha_fin

	INSERT INTO #tmp_errores
	SELECT DISTINCT m.codigo_emp_equipo,  MIN(m.fecha) Desde, MAX(m.fecha) Hasta, '--', '--', 'MARCACION SIN VACACION'  FROM #tmp_marcaciones m
	WHERE codigo_emp_equipo = (SELECT DISTINCT codigo FROM #tmp_vacaciones v WHERE m.codigo_emp_equipo = v.codigo)
	AND (SELECT COUNT(1) FROM #tmp_vacaciones v WHERE m.codigo_emp_equipo = v.codigo AND m.fecha BETWEEN v.fecha_inicio AND v.fecha_fin) = 0 
	AND m.comentario LIKE '%Vac%'
	AND m.fecha > '20211231'
	GROUP BY m.codigo_emp_equipo
	ORDER BY m.codigo_emp_equipo

	DELETE FROM #tmp_errores WHERE Desde < @fi OR Hasta < @fi

	DECLARE @destinatarios varchar(500), @asunto varchar(300)

	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_Vac_Marcaje'

	DECLARE
	@HTML varchar(MAX)

	IF (SELECT COUNT(1) FROM #tmp_errores) > 0
	BEGIN 
		SELECT @HTML = N'<style type="text/css">
							#box-table
							{
								font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
								font-size: 12px;
								text-align: center;
								border-collapse: collapse;
								border-top: 7px solid #9baff1;
								border-bottom: 7px solid #9baff1;
							}
							#box-table th
							{
								font-size: 13px;
								font-weight: normal;
								background: #b9c9fe;
								border-right: 2px solid #9baff1;
								border-left: 2px solid #9baff1;
								border-bottom: 2px solid #9baff1;
								color: #039;
							}
							#box-table td
							{
								border-right: 1px solid #aabcfe;
								border-left: 1px solid #aabcfe;
								border-bottom: 1px solid #aabcfe;
								color: #669;
							}
							tr:nth-child(odd)	{ background-color:#eee; }
							tr:nth-child(even)	{ background-color:#fff; }	
						  </style>'+	
							N'<H3><font color="SteelBlue">ERROR EN VACACIONES - MARCAJES</H3>' +
							N'<H3><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H3>'+
							N'<H3><font color="SteelBlue">Trabajadores con marcajes erroneos en fechas de vacación o marcajes de vacación fuera de fechas de vacación.</H3>'+
							N'<table id="box-table" >' +
							N'<tr><font color="Green">
							<th>CÓDIGO</th>
							<th>NOMBRE</th>
							<th>CCO</th>
							<th>DESC CCO</th>
							<th>MARCAJE DESDE</th>
							<th>MARCAJE HASTA</th>
							<th>VACACIÓN DESDE</th>
							<th>VACACIÓN HASTA</th>
							<th>ERROR</th>
							</tr>' +
							CAST(
								(SELECT
										td = a.codigo_emp_equipo,'', 
										td = dt.Nombre,'',
										td = dt.cco,'', 
										td = dt.Desc_CCO,'',
										td = CONVERT(VARCHAR,MAX(a.Desde), 103),'', 
										td = CONVERT(VARCHAR,MAX(a.Hasta), 103),'', 
										td = a.[Fecha Inicio Vacacion],'', 
										td = a.[Fecha Fin Vacacion],'', 
										td = a.Error,''
									FROM #tmp_errores a 
									INNER JOIN RRHH.vw_datosTrabajadores dt ON a.codigo_emp_equipo = dt.Codigo
									ORDER BY a.Error
									FOR XML PATH('tr'), TYPE) AS varchar(max)) +
							N'</table>' +
							N'<br/><br/>' +
							N'</body>' 

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Vacaciones', 'pa_errorVacacionMarcaje', @asunto, @HTML, @destinatarios, @fi, @ff);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML									
	END
	ELSE
	BEGIN 
		SELECT @HTML = N'<style type="text/css">
							#box-table
							{
								font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
								font-size: 12px;
								text-align: center;
								border-collapse: collapse;
								border-top: 7px solid #9baff1;
								border-bottom: 7px solid #9baff1;
							}
							#box-table th
							{
								font-size: 13px;
								font-weight: normal;
								background: #b9c9fe;
								border-right: 2px solid #9baff1;
								border-left: 2px solid #9baff1;
								border-bottom: 2px solid #9baff1;
								color: #039;
							}
							#box-table td
							{
								border-right: 1px solid #aabcfe;
								border-left: 1px solid #aabcfe;
								border-bottom: 1px solid #aabcfe;
								color: #669;
							}
							tr:nth-child(odd)	{ background-color:#eee; }
							tr:nth-child(even)	{ background-color:#fff; }	
						  </style>'+	
							N'<H3><font color="SteelBlue">ERROR EN VACACIONES - MARCAJES</H3>' +
							N'<H3><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H3>'+
							N'<H3><font color="SteelBlue">No se encontraron trabajadores con marcajes erroneos en fechas de vacación o marcajes de vacación fuera de fechas de vacación.</H3>'

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Vacaciones', 'pa_errorVacacionMarcaje', @asunto, @HTML, @destinatarios, @fi, @ff);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML									
	END
	IF OBJECT_ID(N'tempdb..#tmp_vacaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias', N'U') IS NOT NULL
		DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_marcaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_marcaciones
	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
		DROP TABLE #tmp_errores
END
