
/*

=============================================
  
Author: Steven Quispe
Create date: 17-04-2024
Description: Alerta para notificar novedades en los biometricos: Usuarios distintos a documentId
=============================================

*/

CREATE PROCEDURE [Avisos].[pa_diferencias_usuarios_documentId]
	-- Parametro para llenar tablas o ejecutar consultas 
	@tipo int
AS 
BEGIN
	/************************** LLENAR DATOS EN LAS TABLAS **************************************/
	-- @tipo = 1
	IF(@tipo = 1)
		BEGIN 
			 
			-- Borrado de datos anteriores
			TRUNCATE TABLE integracion.Diel_Tbl_Realtime_Enroll_Data	

			-- Llenado de datos desde la base de la consola DIEL
			INSERT INTO integracion.Diel_Tbl_Realtime_Enroll_Data	
			SELECT 
				NEWID(),
				[ID], 
				[DEVICE_ID],
				[UPDATE_TIME],
				[USER_ID],
				[USER_DATA],
				[LAST_NAME],
				[FIRST_NAME],
				[DOCUMENT_ID],
				[ADMINISTRATOR],
				[LAST_TEMPLATE],
				[ACTIVE]
			FROM [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_REALTIME_ENROLL_DATA]

			--SELECT * FROM integracion.Diel_Tbl_Realtime_Enroll_Data	

		END

	/**************************   EJECUTAR LAS CONSULTAS   **************************************/
	-- @tipo = 2
	IF(@tipo = 2) 
		BEGIN 
			IF OBJECT_ID(N'tempdb..#NovedadesUsuarioDocument', N'U') IS NOT NULL
					DROP TABLE #NovedadesUsuarioDocument

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
			--SELECT @destinatarios = 'pasante.nominadosec@kfc.com.ec', @asunto = 'B4 - Diferencias entre Usuario y DocumentId'
			SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'DifUserDocId'

			SET DATEFORMAT ymd;

			SELECT em.[USER_ID], em.[LAST_NAME], em.[FIRST_NAME], em.[DOCUMENT_ID], 
				CASE WHEN em.[ACTIVE] = 1 THEN 'Activo' ELSE 'Inactivo' END AS 'Estado',
				em.[DEVICE_ID], ib.deviceName, ib.cco, em.[UPDATE_TIME]
			INTO #NovedadesUsuarioDocument
			FROM integracion.Diel_Tbl_Realtime_Enroll_Data AS em
			INNER JOIN integracion.biometricos ib ON em.[DEVICE_ID] = ib.device
			WHERE em.[USER_ID] != em.[DOCUMENT_ID]
			AND em.[LAST_TEMPLATE] = 1
			AND em.[USER_ID] NOT IN  ('0601', '601')  -- Codigos Tecnicos DIEL
			ORDER BY deviceName

			-- SELECT * FROM #NovedadesUsuarioDocument

			-- VERIFICACIÓN DE EXISTENCIA DE ALERTAS ENCONTRADAS
				IF (SELECT COUNT([USER_ID]) FROM #NovedadesUsuarioDocument) > 0 
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
												Informe personal con diferencias entre Usuario y DocumentId: ' +CONVERT(VARCHAR, GETDATE(), 103)+ '. </h1>'

						/*								 ENVIO DE CORREO GENERAL													*/
						SELECT @htmlGeneral= 	
											N'<body>'+								
												N' <br/>'+
												N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
												Listado de novedades encontradas:'+
												N' <br>'+
												N' <table class="box-table" >' +
												N' <tr>'+
												N' <th style="text-align:center"> Usuario</th>'+
												N' <th style="text-align:center"> Apellidos</th>'+
												N' <th style="text-align:center"> Nombres</th>'+
												N' <th style="text-align:center"> DocumenId</th>'+
												N' <th style="text-align:center"> Estado</th>'+
												N' <th style="text-align:center"> Dispositivo</th>'+
												N' <th style="text-align:center"> Código Local</th>'+
												N' <th style="text-align:center"> CCO</th>'+
												N' <th style="text-align:center"> Fecha Actualización</th>'+
	
												cast( (select 
															td = ISNULL(e.[USER_ID],''),'',
															td = ISNULL(e.[LAST_NAME],''),'',
															td = ISNULL(e.[FIRST_NAME],''),'',
															td = ISNULL(e.[DOCUMENT_ID],''),'',
															td = ISNULL(e.Estado,''),'',
															td = ISNULL(e.[DEVICE_ID],''),'',
															td = ISNULL(e.deviceName,''),'',
															td = ISNULL(e.cco,''),'',
															td = ISNULL(CONVERT(VARCHAR, e.[UPDATE_TIME], 103),''),''
															FROM #NovedadesUsuarioDocument e 
															ORDER BY e.deviceName, e.[LAST_NAME]
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
												VALUES ('A', 'Trabajadores', 'pa_diferencias_usuarios_documentId', @asunto, @HTML, @destinatarios, @fi, @ff);
												EXEC msdb.dbo.sp_send_dbmail 
													@profile_name='Informacion_Nomina',
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
							+N'<h5><font color="SteelBlue">No se encontraron personas con diferencias entre Usuario y DocumentId.</h5>'
							+N'<br/><br />'
							+N' </body>' 

							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
							VALUES ('A', 'Trabajadores', 'pa_diferencias_usuarios_documentId', @asunto, @HTML, @destinatarios, @fi, @ff);
							EXEC msdb.dbo.sp_send_dbmail 
							@profile_name='Informacion_Nomina',
						 	@recipients= @destinatarios, 
							@subject = @asunto,
							@body = @HTML,
							@body_format = 'HTML' ;  
					END

			IF OBJECT_ID(N'tempdb..#NovedadesUsuarioDocument', N'U') IS NOT NULL
					DROP TABLE #NovedadesUsuarioDocument
		END
	
END