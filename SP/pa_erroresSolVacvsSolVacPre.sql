
-- =============================================
-- Author:		Jimmy Cazaro
-- Create date: 15-02-2023
-- Description:	Se envia una notificacion en el caso que se tenga registro en la solicitud de vacación 
--				vs solicitud de vacación preprogramación tiene que tener igual informacion
-- =============================================

CREATE PROCEDURE [Avisos].[pa_erroresSolVacvsSolVacPre]
AS
BEGIN
	IF OBJECT_ID(N'tempdb..#tmp_valida_vacacionsol', N'U') IS NOT NULL
		DROP TABLE #tmp_valida_vacacionsol

	DECLARE @fi DATE = '20230101';

	WITH CTE_Sol_Pre (id, codigo, trabajador, fecha_ini, fecha_fin, estado, dia, procedencia, trabajador_pre, dias_pre, fecha_ini_pre, fecha_fin_pre)
	AS (
		SELECT sv.id, sv.codigo, LEFT(sv.codigo, 10) AS trabajador_sv, sv.fecha_inicio, sv.fecha_fin, sv.estado, sv.dias, sv.procedencia 
		, svp.trabajador, svp.tiempo_prog_vac, svp.fecha_ini_per_vac, svp.fecha_fin_per_vac
		FROM Vacacion.Solicitud_vacaciones AS sv WITH (NOLOCK)
		LEFT JOIN (
			SELECT svp.id, SUM(svp.tiempo_prog_vac) AS tiempo_prog_vac, svp.trabajador, MIN(CONVERT(DATE, svp.fecha_ini_per_vac)) AS fecha_ini_per_vac, MAX(CONVERT(DATE, svp.fecha_fin_per_vac)) AS fecha_fin_per_vac
			FROM Vacacion.Solicitud_Vacaciones_Preprogramacion AS svp WITH (NOLOCK)
			WHERE svp.fecha_ini_per_vac >= @fi
			GROUP BY svp.id, svp.trabajador
		) 
		AS svp ON sv.id = svp.id
			AND LEFT(sv.codigo, 10) = svp.trabajador
			AND sv.dias = svp.tiempo_prog_vac
				AND sv.fecha_inicio = svp.fecha_ini_per_vac
				AND sv.fecha_fin = svp.fecha_fin_per_vac
		WHERE /*sv.estado = 1
			AND*/ sv.fecha_inicio >= @fi
		GROUP BY sv.id, sv.codigo, sv.fecha_inicio, sv.fecha_fin, sv.estado, sv.dias, sv.procedencia
		, svp.trabajador, svp.tiempo_prog_vac, svp.fecha_ini_per_vac, svp.fecha_fin_per_vac
	), CTE_Respuesta (id, codigo, trabajador, fecha_ini, fecha_fin, estado, dia, procedencia, dias_pre, observacion, fecha_ini_pre, fecha_fin_Pre)
	AS
	(
		SELECT id, codigo, trabajador, fecha_ini, fecha_fin, estado, dia, procedencia
		, dias_pre
		, CASE
			WHEN (ISNULL(dias_pre, 0) > 0 AND ISNULL(dias_pre, 0) = dia) THEN 'Correcto'
			WHEN (ISNULL(dias_pre, 0) > 0 AND ISNULL(dias_pre, 0) < dia) THEN 'Falta información en la tabla: Solicitud_Vacaciones_Preprogramacion'
			WHEN (ISNULL(dias_pre, 0) > 0 AND ISNULL(dias_pre, 0) > dia) THEN 'Validar información de las tablas: Solicitud_vacaciones vs Solicitud_Vacaciones_Preprogramacion'
			ELSE
				'No existe el o los registros de las tablas: Solicitud_vacaciones vs Solicitud_Vacaciones_Preprogramacion'
		END AS observacion
		, fecha_ini_pre, fecha_fin_pre
		FROM CTE_Sol_Pre
	)

	SELECT c.id, c.codigo, c.trabajador, v.Nombre, 
	CONVERT(VARCHAR(10), c.fecha_ini, 105) AS fecha_ini, 
	CONVERT(VARCHAR(10), c.fecha_fin, 105) AS fecha_fin, 
	c.estado, c.dia, c.procedencia, 
	c.observacion, 
	ISNULL(c.dias_pre, 0) AS dias_pre, 
	ISNULL(CONVERT(VARCHAR(10), c.fecha_ini_pre, 105), '') AS fecha_ini_pre, 
	ISNULL(CONVERT(VARCHAR(10), c.fecha_fin_Pre, 105), '') AS fecha_fin_pre
	INTO #tmp_valida_vacacionsol
	FROM CTE_Respuesta AS c
	INNER JOIN RRHH.vw_datosTrabajadores AS v ON c.codigo = v.Codigo
	WHERE v.Situacion = 'Activo'
		AND c.observacion != 'Correcto'
	--ORDER BY c.fecha_ini, v.Nombre
	;

	--SELECT * FROM #tmp_valida_vacacionsol
	--RETURN

	DECLARE @destinatarios varchar(500), @asunto varchar(300), @HTML VARCHAR(MAX)

	SELECT @destinatarios = valor, @asunto = descripcion, @HTML = referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_VacSolProPre'

	IF (SELECT COUNT(id) FROM #tmp_valida_vacacionsol ) > 0
	BEGIN 
		SELECT @HTML = REPLACE(@HTML, '@fecha', convert(varchar(12),GETDATE(),103))
		SELECT @HTML = REPLACE(@html, '@tabla',
				CAST((SELECT td = id,'', 
						td = codigo,'', 
						td = trabajador,'', 
						td = Nombre,'', 
						td = fecha_ini,'', 
						td = fecha_fin,'', 
						td = estado,'', 
						td = dia,'', 
						td = procedencia,'', 
						td = observacion,'', 
						td = dias_pre,'', 
						td = fecha_ini_pre,'', 
						td = fecha_fin_pre,''
						FROM #tmp_valida_vacacionsol
						FOR XML PATH('tr'), TYPE) AS varchar(max)))
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio)
		VALUES ('A', 'Vacaciones', 'pa_erroresSolVacvsSolVacPre', @asunto, @HTML, @destinatarios, @fi);
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
						  </style>' +
							N'<div style="font-size: 22px; text-align: center; color: black;"><strong>No se encontro error en Vacaciones</strong></div>' +
							N'<br>' +
							N'<div style="font-size: 16px; color: black;">Se compara la información que existe en la tabla: <strong>Solicitud_Vacaciones</strong> vs <strong>Solicitud_Vacaciones_Preprogramacion</strong>.</div>' +
							N'<br>' +
							N'<div style="font-size: 16px; color: black;">Fecha: ' + convert(varchar(12),GETDATE(),103) + '</div>' 
							
					
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio)
		VALUES ('A', 'Vacaciones', 'pa_erroresSolVacvsSolVacPre', @asunto, @HTML, @destinatarios, @fi);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML
	END
	IF OBJECT_ID(N'tempdb..#tmp_valida_vacacionsol', N'U') IS NOT NULL
		DROP TABLE #tmp_valida_vacacionsol
END
