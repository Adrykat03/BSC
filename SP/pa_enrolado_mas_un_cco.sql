
/*

=============================================
  
Author: Steven Quispe
Create date: 10-04-2024
Description: Alerta para notificar los usuarios enrolados en mas de un biometrico.

=============================================
=============================================
  
Editor: Steven Quispe
Edition date: 17-04-2024
Description: Se cambia la fuente de datos para obtener los datos de usuarios directos desde el servidor vinculado a la consola DIEL

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_enrolado_mas_un_cco]
AS 
BEGIN
	
	IF OBJECT_ID(N'tempdb..#PersonalMasUnCCO', N'U') IS NOT NULL
			DROP TABLE #PersonalMasUnCCO

	IF OBJECT_ID(N'tempdb..#DatosAlrtMasUnCCO', N'U') IS NOT NULL
			DROP TABLE #DatosAlrtMasUnCCO


	/* VARIABLES PARA ENVIO DE CORREO */
		DECLARE
		@Dirigido varchar(300),
		@asunto varchar(300),
		@body varchar(5000),
		@HTML Nvarchar(MAX),
		@tab char(1) = CHAR(9),
		@error varchar(10),
		@destinatarios varchar(max),
		@fi date, @ff date

	-- Configuración parámetros del correo
	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'EnrMasUnCCO'
	--SELECT @destinatarios = 'pasante.nominadosec@kfc.com.ec', @asunto = 'B2 - Usuarios enrolados en más de un CCO'

	--- PERSONAL ACTIVO EN MAS DE UN CENTRO DE COSTOS
	SELECT COUNT(1) AS 'Cantidad_CCO_Activos', [USER_ID] 
	INTO #PersonalMasUnCCO
	FROM integracion.Diel_Tbl_Realtime_Enroll_Data
	WHERE RTRIM(LTRIM([ACTIVE])) = 1
	AND [LAST_TEMPLATE] = 1
	AND [USER_ID] NOT IN  ('0601', '601')  -- Codigos Tecnicos DIEL
	GROUP BY [USER_ID]  
	HAVING COUNT(1) > 1


	-- DATOS PARA LA ALERTA
	SELECT uc.[DEVICE_ID], uc.[USER_ID] , CASE WHEN UC.[ACTIVE] = 'true' THEN 'Activo' ELSE 'Inactivo' END AS 'Estado', uc.[LAST_NAME], 
	uc.[FIRST_NAME], uc.[DOCUMENT_ID], uc.[UPDATE_TIME], ib.deviceName AS 'CodigoLocal',  ib.cco
	,td.cco AS 'CCO_Real', vc.codigoLocal AS 'CodigoLocal_Real'
	INTO #DatosAlrtMasUnCCO
	FROM integracion.Diel_Tbl_Realtime_Enroll_Data AS uc
	INNER JOIN integracion.biometricos AS ib ON uc.[DEVICE_ID] = ib.device
	INNER JOIN RRHH.trabajadoresDatosDiario td ON uc.[USER_ID] = LEFT(td.codigo, 10)
	INNER JOIN Catalogos.VW_CCO AS vc ON td.cco = vc.cco
	WHERE uc.[USER_ID] IN (SELECT DISTINCT [USER_ID] FROM #PersonalMasUnCCO)
	AND td.Fecha = CONVERT(DATE, GETDATE())
	AND uc.[LAST_TEMPLATE] = 1
	AND uc.[USER_ID] NOT IN  ('0601', '601')  -- Codigos Tecnicos DIEL

	--SELECT * FROM #DatosAlrtMasUnCCO
	--ORDER BY [USER_ID]


	-- VERIFICACIÓN DE EXISTENCIA DE ALERTAS ENCONTRADAS
		IF (SELECT COUNT([USER_ID]) FROM #DatosAlrtMasUnCCO) > 0
			BEGIN TRY
				DECLARE @htmlE varchar(max)='', @html1 varchar(max)='',  @htmlGeneral varchar(max)='', @compania VARCHAR(500);
	
				SELECT @htmlE=
							N' <style type="text/css">
						.box-table { font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
						.box-table th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
						border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
						.box-table td { text-align: center; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }
						.box{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
						.box th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
						border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
						.box td { text-align: right; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }

						.box2{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
						.box2 th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
						border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
						.box2 td { text-align: left; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }

						.aviso{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
						.aviso th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
						border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
						.aviso td { text-align: left; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }

					</style>'+
					N' <h1 style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 500; line-height: auto;"> 
										Informe personal enrolado en más de un centro de costos: ' +CONVERT(VARCHAR, GETDATE(), 103)+ '. </h1>'

				/*								 ENVIO DE CORREO GENERAL													*/
				SELECT @htmlGeneral= 	
									N'<body>'+								
										N' <br/>'+
										N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
										Listado de novedades encontradas:'+
										N' <br>'+
										N' <table class="box-table" >' +
										N' <tr>'+
										N' <th style="text-align:center"> Dispositivo</th>'+
										N' <th style="text-align:center"> CCO</th>'+
										N' <th style="text-align:center"> Código Local</th>'+
										N' <th style="text-align:center"> Usuario</th>'+
										N' <th style="text-align:center"> Apellidos</th>'+
										N' <th style="text-align:center"> Nombres</th>'+
										N' <th style="text-align:center"> DocumenId</th>'+
										N' <th style="text-align:center"> Estado</th>'+
										N' <th style="text-align:center; background:rgb(38, 168, 38)"> CCO Real</th>'+
										N' <th style="text-align:center; background:rgb(38, 168, 38)"> Código Local Real</th>'+
										N' <th style="text-align:center; "> Fecha actualización</th>'+
	
										cast( (select 
													td = ISNULL(e.[DEVICE_ID],''),'',
													td = ISNULL(e.cco,''),'',
													td = ISNULL(e.CodigoLocal,''),'',
													td = ISNULL(e.[USER_ID],''),'',
													td = ISNULL(e.[LAST_NAME],''),'',
													td = ISNULL(e.[FIRST_NAME],''),'',
													td = ISNULL(e.[DOCUMENT_ID],''),'',
													td = ISNULL(e.Estado,''),'',
													td = ISNULL(e.CCO_Real,''),'',
													td = ISNULL(e.CodigoLocal_Real,''),'',
													td = ISNULL(CONVERT(VARCHAR, e.[UPDATE_TIME], 103),''),''
													FROM #DatosAlrtMasUnCCO e 
													ORDER BY e.[USER_ID]
										FOR XML PATH('tr'),TYPE
										) as varchar(max))+
											N'</table>'+
											N'<br>'+
											N' <br/></body>' 

						BEGIN TRY
							IF @htmlGeneral is not null  
								SELECT @HTML = @htmlE + ' ' +@htmlGeneral 
								BEGIN
										-- INSERT notificación consolidada
										INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
										VALUES ('A', 'Biométricos', 'pa_enrolado_mas_un_cco', @asunto, @HTML, 'pasante.nominadosec@kfc.com.ec', @fi, @ff);
										EXEC msdb.dbo.sp_send_dbmail 
											@profile_name='Informacion_Nomina',
											--@recipients= 'pasante.nominadosec@kfc.com.ec', 	
											@recipients= @destinatarios, 
											@subject = @asunto,
											@body = @HTML,
											@body_format = 'HTML' ;  
								END
						END TRY 
						BEGIN CATCH
							INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec' , NULL, @html, @asunto, 'Error al envíar correo general')
						END CATCH

			END TRY 
			BEGIN CATCH
				INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec' , NULL, @html, @asunto, 'Error al envíar correo')
			END CATCH
		ELSE
			BEGIN 
				SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR NOVEDADES EN LOS BIOMÉTRICOS</h3>'
					+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
					+N'<h5><font color="SteelBlue">No se encontraron personas enroladas en más de un centro de costos.</h5>'
					+N'<br/><br />'
					+N' </body>' 

					-- INSERT notificación consolidada
					INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
					VALUES ('A', 'Biométricos', 'pa_enrolado_mas_un_cco', @asunto, @HTML, 'pasante.nominadosec@kfc.com.ec', @fi, @ff);
					EXEC msdb.dbo.sp_send_dbmail 
					@profile_name='Informacion_Nomina',
					--@recipients= 'pasante.nominadosec@kfc.com.ec', 	
					@recipients= @destinatarios, 
					@subject = @asunto,
					@body = @HTML,
					@body_format = 'HTML' ;  
			END
	
	IF OBJECT_ID(N'tempdb..#PersonalMasUnCCO', N'U') IS NOT NULL
			DROP TABLE #PersonalMasUnCCO

	IF OBJECT_ID(N'tempdb..#DatosAlrtMasUnCCO', N'U') IS NOT NULL
			DROP TABLE #DatosAlrtMasUnCCO
	
END