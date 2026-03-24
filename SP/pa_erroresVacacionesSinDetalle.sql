-- =============================================
-- Author:		Mateo Alvear
-- Create date: 12-01-2023
-- Description:	Se envia una notificacion si existen trabajadores con programacion sin saldos.
-- =============================================
CREATE PROCEDURE [Avisos].[pa_erroresVacacionesSinDetalle]
AS
BEGIN
	IF OBJECT_ID(N'tempdb..#coso_3', N'U') IS NOT NULL
		DROP TABLE #coso_3

	SELECT sv.ciclo_laboral, sv.trabajador, sv.compania, sv.vac_programadas + sv.vac_disfrutadas VacTotal, 
	CASE WHEN SUM(pv.tiempo_prog_vac) <> sv.vac_programadas + sv.vac_disfrutadas THEN 'SI' ELSE 'NO' END Error, SUM(pv.tiempo_prog_vac) TiempoProgramado,
	CASE WHEN (sv.vac_por_ciclo = sv.vac_disfrutadas AND sv.compania = pv.compania) THEN 'SI' ELSE 'NO' END VacacionesCompletas,
	pv.compania PVCompania
	INTO #coso_3 FROM Adam.dbo.saldos_vacaciones sv
	INNER JOIN Adam.dbo.programacion_vacaciones pv ON sv.ciclo_laboral = pv.ciclo_laboral AND sv.trabajador = pv.trabajador AND sv.compania = pv.compania
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Trabajador = sv.trabajador AND dt.Situacion = 'Activo' AND dt.Compania = sv.compania
	GROUP BY sv.ciclo_laboral, sv.trabajador, sv.compania, pv.ciclo_laboral, pv.trabajador, pv.compania, sv.vac_programadas, sv.vac_disfrutadas, sv.vac_por_ciclo

	DECLARE @destinatarios varchar(500), @asunto varchar(300), @HTML VARCHAR(MAX)

	SELECT @destinatarios = valor, @asunto = descripcion, @HTML = referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_VacSinDet'

	IF (SELECT COUNT(1) FROM #coso_3 WHERE Error = 'SI' AND ciclo_laboral > '20132014') > 0
	BEGIN 
		SELECT @HTML = REPLACE(@HTML, '@fecha', convert(varchar(12),GETDATE(),103))
		SELECT @HTML = REPLACE(@html, '@tabla',
				CAST((SELECT td = dt.Codigo,'', td = dt.Nombre,'', td = dt.Compania,'', td = dt.cco,'', td = dt.Desc_CCO,'', td = a.ciclo_laboral,'', td = a.VacTotal,'', td = a.TiempoProgramado,''
						FROM #coso_3 a 
						INNER JOIN RRHH.vw_datosTrabajadores dt ON a.trabajador = dt.Trabajador AND dt.Compania = a.compania
						WHERE Error = 'SI' AND ciclo_laboral > '20132014'
						FOR XML PATH('tr'), TYPE) AS varchar(max)))
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
		VALUES ('A', 'Vacaciones', 'pa_erroresVacacionesSinDetalle', @asunto, @HTML, @destinatarios);
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
							N'<H3><font color="SteelBlue">NO SE ENCONTRARON ERRORES</H3>' +
							N'<H3><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103) + '</H3>'+
							N'<H3><font color="SteelBlue">No se encontraron trabajadores con vacaciones con saldos sin información en programación.</H3>'
					
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
		VALUES ('A', 'Vacaciones', 'pa_erroresVacacionesSinDetalle', @asunto, @HTML, @destinatarios);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML
	END
	IF OBJECT_ID(N'tempdb..#coso_3', N'U') IS NOT NULL
		DROP TABLE #coso_3
END
