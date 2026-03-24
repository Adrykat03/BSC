-- =============================================
-- Author:		Mateo Alvear
-- Create date: 18-11-2022
-- Description:	Se notifica sobre las ausencias que tengan marcajes distintos a ausencia o marcajes que tengan asuencia sin ausencia
-- =============================================
-- =============================================
-- Author:		Mateo Alvear
-- Edit date:	28-11-2022
-- Description:	A petición de Dennis se revisa unicamente del corte actual en adelante ya que las marcaciones anteriores no pueden cambiarse
-- =============================================
CREATE PROCEDURE [Avisos].[pa_errorAusenciaMarcaje]
AS
BEGIN
	DECLARE @fi date

	SELECT @fi = FechaInicioNomina FROM Utilidades.fn_fechasperiodonomina(GETDATE())

	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
		DROP TABLE #tmp_errores
	IF OBJECT_ID(N'tempdb..#tmp_vacaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias', N'U') IS NOT NULL
		DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_marcaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_marcaciones
	IF OBJECT_ID(N'tempdb..#tmp_cortes', N'U') IS NOT NULL
		DROP TABLE #tmp_cortes

	DECLARE @CTE_tabla_cco AS TABLE(cco VARCHAR(30), descripcion VARCHAR (100), cadena VARCHAR(50))
	INSERT INTO @CTE_tabla_cco (cco, descripcion, cadena)	
	SELECT COO, CCO_DESCRIPCION, DESCRIPCION_CLASE 
	FROM Adam.[dbo].[FPV_AGR_COM_CLASE]
	WHERE REFERENCIA_20 = 'SI'
	AND [STATUS] = 'ABIERTO' AND referencia_09 in ('DP02','DP01')

	SELECT A.codigo, Fecha_Ini_Incapacidad, Fecha_Fin_Incapacidad, estado, fecha_fallecimientoCFoTR
	INTO #tmp_ausencias FROM Ausencias.Accidentes a WITH(NOLOCK)
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = a.Codigo 
	INNER JOIN @CTE_tabla_cco dp ON dt.CCO = dp.cco
	WHERE Fecha_Ini_Incapacidad > @fi

	
	INSERT INTO #tmp_ausencias(codigo, Fecha_Ini_Incapacidad, Fecha_Fin_Incapacidad, estado, fecha_fallecimientoCFoTR) 
	SELECT DISTINCT v.codigo, v.Fecha_Ini_Incapacidad, v.Fecha_Fin_Incapacidad, v.estado, v.fecha_fallecimientoCFoTR
	FROM Ausencias.Accidentes v WITH(NOLOCK) INNER JOIN #tmp_ausencias v2 ON v.codigo = v2.codigo
	AND (v.Fecha_Ini_Incapacidad > '20211231' OR v.Fecha_Fin_Incapacidad > '20211231')

	SELECT a.* INTO #tmp_vacaciones FROM Vacacion.Solicitud_vacaciones a WITH(NOLOCK)
	INNER JOIN #tmp_ausencias v ON a.Codigo = v.codigo

	DECLARE @fmin date, @fmax date
	SELECT @fmin = MIN(Fecha_Ini_Incapacidad), @fmax = MAX(Fecha_Fin_Incapacidad) FROM #tmp_ausencias
	SELECT FechaInicioNomina, FechaFinNomina INTO #tmp_cortes FROM Utilidades.fn_fechasperiodonomina(@fmin)
	WHILE @fmin < @fmax
	BEGIN
		SELECT @fmin = DATEADD(DAY, 1, MAX(FechaFinNomina)) FROM #tmp_cortes
		INSERT INTO #tmp_cortes
		SELECT FechaInicioNomina, FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(@fmin)
	END

	SELECT m.* INTO #tmp_marcaciones FROM Asistencia.marcajes m WITH(nolock)
	INNER JOIN #tmp_ausencias v ON v.codigo = m.codigo_emp_equipo 
	AND m.fecha BETWEEN (SELECT FechaInicioNomina FROM #tmp_cortes c WHERE v.Fecha_Ini_Incapacidad BETWEEN c.FechaInicioNomina AND c.FechaFinNomina)
	AND (SELECT FechaFinNomina FROM #tmp_cortes c WHERE v.Fecha_Fin_Incapacidad BETWEEN c.FechaInicioNomina AND c.FechaFinNomina)

	SELECT DISTINCT m.codigo_emp_equipo, MIN(m.fecha) Desde, MAX(m.fecha) Hasta,
	CONVERT(VARCHAR, m.Fecha_Ini_Incapacidad, 103) [Fecha Inicio Ausencia], CONVERT(VARCHAR, m.Fecha_Fin_Incapacidad, 103) [Fecha Fin Ausencia], 'AUSENCIA SIN MARCACION' Error
	INTO #tmp_errores
	FROM (SELECT m.*, v.Fecha_Ini_Incapacidad, v.Fecha_Fin_Incapacidad, v.fecha_fallecimientoCFoTR FROM #tmp_marcaciones m
	INNER JOIN #tmp_ausencias v ON m.fecha BETWEEN v.Fecha_Ini_Incapacidad AND v.Fecha_Fin_Incapacidad AND m.codigo_emp_equipo = v.codigo) m
	WHERE m.comentario <> 'AUSENCIA' 
	AND (SELECT COUNT(1) FROM #tmp_vacaciones a WHERE a.Codigo = m.codigo_emp_equipo AND m.fecha BETWEEN a.fecha_inicio AND a.fecha_fin ) = 0
	AND m.fecha_fallecimientoCFoTR IS NULL
	AND m.fecha > '20211231'
	GROUP BY m.codigo_emp_equipo, m.Fecha_Ini_Incapacidad, m.Fecha_Fin_Incapacidad

	INSERT INTO #tmp_errores
	SELECT DISTINCT m.codigo_emp_equipo, MIN(m.fecha) Desde, MAX(m.fecha) Hasta, '--', '--', 'MARCACION SIN AUSENCIA'  FROM #tmp_marcaciones m
	WHERE codigo_emp_equipo = (SELECT DISTINCT codigo FROM #tmp_ausencias v WHERE m.codigo_emp_equipo = v.codigo)
	AND (SELECT COUNT(1) FROM #tmp_ausencias v WHERE m.codigo_emp_equipo = v.codigo AND m.fecha BETWEEN v.Fecha_Ini_Incapacidad AND v.Fecha_Fin_Incapacidad) = 0
	AND m.comentario LIKE '%AUSENCIA%'
	AND m.fecha > '20211231'
	GROUP BY m.codigo_emp_equipo
	ORDER BY m.codigo_emp_equipo

	DELETE FROM #tmp_errores WHERE Desde < @fi OR Hasta < @fi

	DECLARE @destinatarios varchar(500), @asunto varchar(300)

	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_Aus_Marcaje'

	DECLARE @HTML varchar(MAX)
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
							N'<H3><font color="SteelBlue">ERROR EN AUSENCIAS - MARCAJES</H3>' +
							N'<H3><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H3>'+
							N'<H3><font color="SteelBlue">Trabajadores con marcajes erroneos en fechas de ausencia o marcajes de ausencia fuera de fechas de ausencia.</H3>'+
							N'<table id="box-table" >' +
							N'<tr><font color="Green">
							<th>CÓDIGO</th>
							<th>NOMBRE</th>
							<th>CCO</th>
							<th>DESC CCO</th>
							<th>MARCAJE DESDE</th>
							<th>MARCAJE HASTA</th>
							<th>AUSENCIA DESDE</th>
							<th>AUSENCIA HASTA</th>
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
										td = a.[Fecha Inicio Ausencia],'', 
										td = a.[Fecha Fin Ausencia],'', 
										td = a.Error,''
									FROM #tmp_errores a 
									INNER JOIN RRHH.vw_datosTrabajadores dt ON a.codigo_emp_equipo = dt.Codigo
									ORDER BY a.Error
									FOR XML PATH('tr'), TYPE) AS varchar(max)) +
							N'</table>' +
							N'<br/><br/>' +
							N'</body>' 

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio)
		VALUES ('A', 'Marcajes', 'pa_errorAusenciaMarcaje', @asunto, @HTML, @destinatarios, @fi);
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
							N'<H3><font color="SteelBlue">ERROR EN AUSENCIAS - MARCAJES</H3>' +
							N'<H3><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H3>'+
							N'<H3><font color="SteelBlue">No se encontraron trabajadores con marcajes erroneos en fechas de ausencia o marcajes de ausencia fuera de fechas de ausencia.</H3>'
							
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio)
		VALUES ('A', 'Marcajes', 'pa_errorAusenciaMarcaje', @asunto, @HTML, @destinatarios, @fi);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML									
	END
	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
		DROP TABLE #tmp_errores
	IF OBJECT_ID(N'tempdb..#tmp_vacaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_vacaciones
	IF OBJECT_ID(N'tempdb..#tmp_ausencias', N'U') IS NOT NULL
		DROP TABLE #tmp_ausencias
	IF OBJECT_ID(N'tempdb..#tmp_marcaciones', N'U') IS NOT NULL
		DROP TABLE #tmp_marcaciones
	IF OBJECT_ID(N'tempdb..#tmp_cortes', N'U') IS NOT NULL
		DROP TABLE #tmp_cortes
END
