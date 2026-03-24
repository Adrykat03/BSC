
/*

=============================================
  
Author: Steven Quispe
Create date: 26-12-2023
Description: Alerta para notificar los datos registrados de los centros de costos CCO

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_enviarDatosCCO]
AS 
BEGIN

	/*	VARIABLES PARA ENVIO DE CORREO	*/
	DECLARE 
	@Dirigido		varchar(300),
	@asunto			varchar(300),
	@body			varchar(5000),
	@HTML			Nvarchar(MAX),
	@tab			char(1) = char(9),
	@error			varchar(10),
	@destinatarios	varchar(max),
	@fi date,	@ff date;

 	SET @asunto = 'DATOS CCO'
	SET @destinatarios = 'pasante.nominadosec@kfc.com.ec'

	/*		VARIABLES PARA CREACION EL CSV (ADJUNTO DEL CORREO)		*/
	DECLARE @consulta varchar(MAX), @archivo varchar(MAX)

	/*		CREACION DE TABLAS TEMPORALES AUXILIARES				*/
	IF Object_id(N'tempdb..##tmp_datos_envio_alerta_cco', N'U') IS NOT NULL
		DROP TABLE ##tmp_datos_envio_alerta_cco

	CREATE TABLE ##tmp_datos_envio_alerta_cco
		(
			id_cco			int,
			cco				varchar(10),
			descripcion		varchar(250),
			id_claseNomina	smallint,
			cadena			varchar(250),
			fecha_inicio	date,
			fecha_fin		date
		)

	INSERT INTO ##tmp_datos_envio_alerta_cco
		SELECT cc.id_cco, cc.cco, cc.descripcion, cc.id_claseNomina, vw.cadena, cc.fecha_inicio, cc.fecha_fin
		FROM Catalogos.centro_costos cc
		INNER JOIN Catalogos.VW_CCO vw
		ON cc.descripcion = vw.descripcion

	/*		ENVIO DE DATOS POR CORREO		*/
	-- Comprobación de errores 
	IF ((SELECT COUNT(id_cco) FROM ##tmp_datos_envio_alerta_cco) > 0)
			-- Si no hay errores
		BEGIN TRY 
			SELECT @HTML = N'<body><h3><font color="SteelBlue">DATOS CCO</h3>'
							+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<h5><font color="SteelBlue">Se adjuntan los datos de los centros de costo.</h5>'
							+N'<br/><br />'
							+N' </body>' 

			SET @consulta = N'SELECT '''''''' + CONVERT(varchar(26), id_cco) AS id_cco, '''''''' + CONVERT(varchar(26), cco) as cco, 
								descripcion AS descripcion_local, id_claseNomina AS clase_nomina, cadena, ISNULL(CONVERT(varchar(12),
								fecha_inicio, 103), ''---'') AS fecha_inicio, ISNULL(CONVERT(varchar(12),fecha_fin, 103),''---'') AS fecha_fin
										  FROM ##tmp_datos_envio_alerta_cco
										  ORDER BY cadena, descripcion';

			SET @archivo = N''+ convert(varchar(12),GETDATE(), 105) + ' - DatosCCO.csv';
						-- SET @archivo = N'DatosCCO.csv';

			/*		ENVIO DE CORREO			*/
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Estructura', 'pa_enviarDatosCCO', @asunto, @HTML, @destinatarios, @fi, @ff);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina',
				@recipients= @destinatarios, 		
			 	@subject = @asunto,
				@body = @HTML,
				@query = @consulta,
				@attach_query_result_as_file = 1,
				@query_attachment_filename = @archivo,
			 	@query_result_separator = @tab,
				@query_result_header = 1,
				@query_result_no_padding = 1,
				@exclude_query_output = 1,
				@body_format = 'HTML' ; 

		END TRY
		BEGIN CATCH
				INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec' , NULL, @html, @asunto, 'Error al envíar correo')
		END CATCH
	ELSE
		-- Si existió algún error durante la toma de datos
		BEGIN 
						SELECT @HTML = N'<body><h3><font color="SteelBlue">DATOS CCO</h3>'
							+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<h5><font color="SteelBlue">ERROR al consultar los datos de los centros de costo.</h5>'
							+N'<br/><br />'
							+N' </body>' 


			/*		ENVIO DE CORREO			*/
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Estructura', 'pa_enviarDatosCCO', @asunto, @HTML, @destinatarios, @fi, @ff);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina',
				@recipients= @destinatarios, 		
			 	@subject = @asunto,
				@body = @HTML,
				@body_format = 'HTML' ;
		
		END

	/*		ELIMINACIÓN DE TABLAS TEMPORALES AUXILIARES				*/
	IF Object_id(N'tempdb..##tmp_datos_envio_alerta_cco', N'U') IS NOT NULL
		DROP TABLE ##tmp_datos_envio_alerta_cco

END
