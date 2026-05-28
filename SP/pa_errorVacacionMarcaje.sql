USE [DB_NOMKFC]
GO
/****** Object:  StoredProcedure [Avisos].[pa_errorVacacionMarcaje]    Script Date: 26/5/2026 8:40:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
-- =============================================
-- Author:		Katerin Carrillo
-- Create date: 26/05/2026
-- Description:	Se refactoriza SP para disminuir tiempo de ejecución e inserta los datos en la tabla notificacionesConsolidadas
-- =============================================
ALTER PROCEDURE [Avisos].[pa_errorVacacionMarcaje]
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @fi date, @ff date

	SELECT @fi = FechaInicioNomina, @ff = FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(GETDATE())

	IF OBJECT_ID(N'tempdb..#tmp_vacaciones',  N'U') IS NOT NULL DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias',   N'U') IS NOT NULL DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_marcaciones', N'U') IS NOT NULL DROP TABLE #tmp_marcaciones
	IF OBJECT_ID(N'tempdb..#tmp_errores',     N'U') IS NOT NULL DROP TABLE #tmp_errores

	DECLARE @CTE_tabla_cco AS TABLE(cco VARCHAR(30), descripcion VARCHAR(100), cadena VARCHAR(50))
	INSERT INTO @CTE_tabla_cco (cco, descripcion, cadena)
	SELECT COO, CCO_DESCRIPCION, DESCRIPCION_CLASE
	FROM Adam.[dbo].[FPV_AGR_COM_CLASE]
	WHERE REFERENCIA_20 = 'SI'
	  AND [STATUS] = 'ABIERTO'
	  AND referencia_09 IN ('DP02','DP01')

	-- Vacaciones del periodo con columnas para rangos de nómina (se llenan después)
	SELECT v.codigo, v.fecha_inicio, v.fecha_fin, v.estado,
		   CAST(NULL AS date) AS fi_nomina,
		   CAST(NULL AS date) AS ff_nomina
	INTO #tmp_vacaciones
	FROM Vacacion.Solicitud_vacaciones v WITH(NOLOCK)
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = v.Codigo
	INNER JOIN @CTE_tabla_cco dp ON dt.CCO = dp.cco
	WHERE v.fecha_inicio BETWEEN @fi AND @ff OR v.fecha_fin BETWEEN @fi AND @ff

	-- Todas las vacaciones de los mismos trabajadores (sin duplicar las ya insertadas)
	INSERT INTO #tmp_vacaciones (codigo, fecha_inicio, fecha_fin, estado, fi_nomina, ff_nomina)
	SELECT DISTINCT v.codigo, v.fecha_inicio, v.fecha_fin, v.estado, NULL, NULL
	FROM Vacacion.Solicitud_vacaciones v WITH(NOLOCK)
	INNER JOIN #tmp_vacaciones v2 ON v.codigo = v2.codigo
	WHERE NOT EXISTS (
		SELECT 1 FROM #tmp_vacaciones e
		WHERE e.codigo = v.codigo AND e.fecha_inicio = v.fecha_inicio AND e.fecha_fin = v.fecha_fin
	)

	-- Pre-calcular rangos de nómina una sola vez por vacación (reemplaza llamadas por fila)
	UPDATE tv
	SET tv.fi_nomina = fp_i.FechaInicioNomina,
		tv.ff_nomina = fp_f.FechaFinNomina
	FROM #tmp_vacaciones tv
	CROSS APPLY Utilidades.fn_fechasperiodonomina(tv.fecha_inicio) fp_i
	CROSS APPLY Utilidades.fn_fechasperiodonomina(tv.fecha_fin)    fp_f

	SELECT a.* INTO #tmp_ausencias
	FROM Ausencias.Accidentes a
	INNER JOIN #tmp_vacaciones v ON a.Codigo = v.codigo

	-- Marcaciones usando rangos pre-calculados (sin llamadas a función por fila)
	SELECT m.* INTO #tmp_marcaciones
	FROM Asistencia.marcajes m WITH(NOLOCK)
	INNER JOIN #tmp_vacaciones v ON v.codigo = m.codigo_emp_equipo
		AND m.fecha BETWEEN v.fi_nomina AND v.ff_nomina

	-- Error 1: Vacación sin marcación correcta
	SELECT m.codigo_emp_equipo, MIN(m.fecha) Desde, MAX(m.fecha) Hasta,
		CONVERT(VARCHAR, m.fecha_inicio, 103) [Fecha Inicio Vacacion],
		CONVERT(VARCHAR, m.fecha_fin, 103) [Fecha Fin Vacacion],
		'VACACION SIN MARCACION' Error
	INTO #tmp_errores
	FROM (
		SELECT m.*, v.fecha_inicio, v.fecha_fin
		FROM #tmp_marcaciones m
		INNER JOIN #tmp_vacaciones v ON m.fecha BETWEEN v.fecha_inicio AND v.fecha_fin
			AND m.codigo_emp_equipo = v.codigo
	) m
	WHERE m.comentario <> 'Vacaciones'
	AND NOT EXISTS (
		SELECT 1 FROM #tmp_ausencias a
		WHERE a.Codigo = m.codigo_emp_equipo
		AND m.fecha BETWEEN a.Fecha_Ini_Incapacidad AND a.Fecha_Fin_Incapacidad
	)
	GROUP BY m.codigo_emp_equipo, m.fecha_inicio, m.fecha_fin

	-- Error 2: Marcación con comentario de vacación sin vacación registrada
	INSERT INTO #tmp_errores
	SELECT m.codigo_emp_equipo, MIN(m.fecha) Desde, MAX(m.fecha) Hasta, '--', '--', 'MARCACION SIN VACACION'
	FROM #tmp_marcaciones m
	WHERE m.comentario LIKE '%Vac%'
	AND m.fecha > '20211231'
	AND NOT EXISTS (
		SELECT 1 FROM #tmp_vacaciones v
		WHERE v.codigo = m.codigo_emp_equipo
		AND m.fecha BETWEEN v.fecha_inicio AND v.fecha_fin
	)
	GROUP BY m.codigo_emp_equipo

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
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
		VALUES ('A', 'AL_Vac_Marcaje', 'pa_errorVacacionMarcaje', @asunto, @HTML, @destinatarios, @fi, @ff, 'Con novedad', 'Baja', 'VACACIONES', NULL);
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
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin, descripcion, prioridad, categoria, mensajeError)
		VALUES ('C', 'AL_Vac_Marcaje', 'pa_errorVacacionMarcaje', @asunto, @HTML, @destinatarios, @fi, @ff, 'Sin novedad', 'Baja', 'VACACIONES', NULL);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML
	END

	IF OBJECT_ID(N'tempdb..#tmp_vacaciones',  N'U') IS NOT NULL DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias',   N'U') IS NOT NULL DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_marcaciones', N'U') IS NOT NULL DROP TABLE #tmp_marcaciones
	IF OBJECT_ID(N'tempdb..#tmp_errores',     N'U') IS NOT NULL DROP TABLE #tmp_errores
END
