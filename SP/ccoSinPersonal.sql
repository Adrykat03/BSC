-- =============================================
-- Author:		Mateo Alvear
-- Create date: 2022/12/19
-- Description:	Se revisan los CCO que no tengan trabajadores asignados y se los notifica por correo
-- =============================================
-- =============================================
-- Editor:		 Steven Quispe
-- Edition date: 2024/03/11
-- Description:	 Se agrega la comprobación de la exitencia de resultados para notificar si existen casos de alerta o si no se tiene novedades.
-- =============================================
CREATE PROCEDURE [Avisos].[ccoSinPersonal]
AS
BEGIN
	IF OBJECT_ID(N'tempdb..#dp', N'U') IS NOT NULL
		DROP TABLE #dp
	IF OBJECT_ID(N'tempdb..#tmpCCOt', N'U') IS NOT NULL
		DROP TABLE #tmpCCOt

	SELECT coo CCO, CCO_DESCRIPCION descripcion, dp.referencia_09 dp 
	INTO #dp 
	FROM Adam.dbo.fpv_agr_com_clase dp 
	WHERE dp.status = 'ABIERTO' 
	AND dp.referencia_09 IN ('DP01', 'DP02') 
	AND referencia_20 = 'SI'

	SELECT dt.cco, COUNT(1) NTrab INTO #tmpCCOt FROM RRHH.vw_datosTrabajadores dt
	INNER JOIN  #dp dp ON dp.cco = dt.CCO
	WHERE dt.Situacion = 'Activo' AND dt.Fecha_baja IS NULL AND dt.Fecha_bajaIndice IS NULL
	GROUP BY dt.cco
	
	-- Parametros para envio por correo
	DECLARE @html varchar(MAX), @asunto varchar(50), @destinatarios varchar(350)

	SELECT @html = referencia_06, @asunto = descripcion, @destinatarios = valor FROM Configuracion.parametros WHERE parametro = 'AL_CCO_Sin_Trab'

	-- Comprobación de alertas
	IF(SELECT COUNT(DISTINCT CCO) FROM #dp dp WHERE dp.CCO NOT IN(SELECT cco FROM #tmpCCOt c)) > 0
		BEGIN 

			SELECT @html = REPLACE(@html, '@fecha', CONVERT(VARCHAR, GETDATE(), 103))
			SELECT @html = REPLACE(@html, '@tabla', CAST(
										(SELECT
												td = cco, '',
												td = descripcion, '',
												td = (CASE WHEN dp.dp = 'DP01' THEN 'LOCALES'  WHEN dp.dp = 'DP02' THEN 'PLANTA' END), ''
											FROM #dp dp WHERE dp.CCO NOT IN(SELECT cco FROM #tmpCCOt c)
											ORDER BY dp.dp, LEN(dp.descripcion)
											FOR XML PATH('tr'), TYPE) AS varchar(max)))
	
	
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
			VALUES ('A', 'Estructura', 'ccoSinPersonal', @asunto, @HTML, @destinatarios);
			EXEC msdb.dbo.Sp_send_dbmail
				@profile_name = 'Informacion_Nomina',
				@Subject = @asunto,
				@recipients = @destinatarios,
				@body_format= 'html',
				@body = @HTML
		END
	ELSE 
		BEGIN 

			SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA CCO ABIERTOS SIN PERSONAL</h3>'
									+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
									+N'<h5><font color="SteelBlue">No se encontraron centros de costos abiertos sin personal activo asignado.</h5>'
									+N'<br/><br />'
									+N' </body>' 
			
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
			VALUES ('A', 'Estructura', 'ccoSinPersonal', @asunto, @HTML, @destinatarios);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina',
				@recipients= @destinatarios, 
				@subject = @asunto,
				@body = @HTML,
				@body_format = 'HTML' ;  
		END
END
