
/*

=============================================
  
Author: Steven Quispe
Create date: 10-04-2024
Description: Alerta para notificar los usuarios enrolados sin datos del colaborador en los biometricos

=============================================
=============================================
  
Editor: Steven Quispe
Edition date: 17-04-2024
Description: Se cambia la fuente de datos para obtener los usuarios desde el servidor vinculado de la consola DIEL

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_usuarios_sin_datos]
AS 
BEGIN
	
	IF OBJECT_ID(N'tempdb..#NovedadesUsuarioSinDts', N'U') IS NOT NULL
			DROP TABLE #NovedadesUsuarioSinDts

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
	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'EnrSinDts'
 
	SET DATEFORMAT ymd;

	--- BASE ULTIMO REGISTRO TRABAJADORES
	IF OBJECT_ID(N'tempdb..#BaseTrabajadores', N'U') IS NOT NULL
				DROP TABLE #BaseTrabajadores

	; WITH CTE_BASE (numero, Codigo, Trabajador, Nombre, Cadena, CCO, codigoLocal, Desc_CCO, Cargo, Cargo_Homologado, Fecha_Antiguedad, Fecha_Ingreso, Fecha_bajaIndice, Fecha_baja, situacion)	
	AS (
		SELECT ROW_NUMBER() OVER(PARTITION by vd.Trabajador ORDER BY vd.Codigo DESC) AS numero, vd.Codigo, vd.Trabajador, vd.Nombre, vd.Desc_Clase_Nomina AS 'Cadena', vd.CCO, cl.codigoLocal,
		vd.Desc_CCO, vd.Cargo, vd.Cargo_Homologado, vd.Fecha_Antiguedad, vd.Fecha_Ingreso, vd.Fecha_bajaIndice, vd.Fecha_baja, vd.situacion
		FROM RRHH.vw_datostrabajadores AS vd
		INNER JOIN Catalogos.centro_costos AS cl ON vd.cco = cl.cco
		WHERE vd.trabajador IN (
			SELECT documentid FROM integracion.empleadosBiometricos
			UNION
			SELECT usuario FROM integracion.empleadosBiometricos	
		)
	)
	SELECT *
	INTO #BaseTrabajadores
	FROM CTE_BASE
	WHERE numero = 1

	-- Seleccion de novedades para la alerta
	SELECT em.[USER_ID], em.[LAST_NAME], em.[FIRST_NAME], em.[DOCUMENT_ID], 
		CASE WHEN em.[ACTIVE] = 1 THEN 'Activo' ELSE 'Inactivo' END AS 'Estado',
		em.[DEVICE_ID], bt.Nombre, bt.Cadena, ib.cco, bt.Cargo, bt.Cargo_Homologado, ib.deviceName, em.[UPDATE_TIME]
	INTO #NovedadesUsuarioSinDts
	FROM integracion.Diel_Tbl_Realtime_Enroll_Data AS em
	INNER JOIN integracion.biometricos ib ON em.[DEVICE_ID] = ib.device
	INNER JOIN #BaseTrabajadores bt ON em.[USER_ID] = bt.trabajador
	WHERE ISNULL(em.[LAST_NAME], '') = ''
	OR ISNULL(em.[FIRST_NAME], '') = '' 
	OR ISNULL(em.[DOCUMENT_ID], '') = ''

	--SELECT * FROM #NovedadesUsuarioSinDts
	--ORDER BY Cadena


	-- VERIFICACIÓN DE EXISTENCIA DE ALERTAS ENCONTRADAS
		IF (SELECT COUNT([USER_ID]) FROM #NovedadesUsuarioSinDts) > 0
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
										Informe personal enrolado sin datos del colaborador : ' +CONVERT(VARCHAR, GETDATE(), 103)+ '. </h1>'

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
										N' <th style="text-align:center"> Nombre</th>'+
										N' <th style="text-align:center"> Cadena</th>'+
										N' <th style="text-align:center"> CCO</th>'+
										N' <th style="text-align:center"> Código Local</th>'+
										N' <th style="text-align:center"> Cargo</th>'+
										N' <th style="text-align:center"> Cargo homologado</th>'+
										N' <th style="text-align:center"> Fecha actualización</th>'+
	
										cast( (select 
													td = ISNULL(e.[USER_ID],''),'',
													td = ISNULL(e.[LAST_NAME],''),'',
													td = ISNULL(e.[FIRST_NAME],''),'',
													td = ISNULL(e.[DOCUMENT_ID],''),'',
													td = ISNULL(e.Estado,''),'',
													td = ISNULL(e.[DEVICE_ID],''),'',
													td = ISNULL(e.Nombre,''),'',
													td = ISNULL(e.Cadena,''),'',
													td = ISNULL(e.cco,''),'',
													td = ISNULL(e.deviceName,''),'',
													td = ISNULL(e.Cargo,''),'',
													td = ISNULL(e.Cargo_Homologado,''),'',
													td = ISNULL(CONVERT(VARCHAR, e.[UPDATE_TIME], 103),''),''
													FROM #NovedadesUsuarioSinDts e 
													ORDER BY e.Cadena, e.[USER_ID]
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
										VALUES ('A', 'Trabajadores', 'pa_usuarios_sin_datos', @asunto, @HTML, @destinatarios, @fi, @ff);
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
					+N'<h5><font color="SteelBlue">No se encontraron personas enroladas sin datos del colaborador.</h5>'
					+N'<br/><br />'
					+N' </body>' 

					-- INSERT notificación consolidada
					INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
					VALUES ('A', 'Trabajadores', 'pa_usuarios_sin_datos', @asunto, @HTML, 'pasante.nominadosec@kfc.com.ec', @fi, @ff);
					EXEC msdb.dbo.sp_send_dbmail 
					@profile_name='Informacion_Nomina',
					--@recipients= 'pasante.nominadosec@kfc.com.ec', 	
					@recipients= @destinatarios, 
					@subject = @asunto,
					@body = @HTML,
					@body_format = 'HTML' ;  
			END
	
	IF OBJECT_ID(N'tempdb..#NovedadesUsuarioSinDts', N'U') IS NOT NULL
			DROP TABLE #NovedadesUsuarioSinDts

	IF OBJECT_ID(N'tempdb..#BaseTrabajadores', N'U') IS NOT NULL
				DROP TABLE #BaseTrabajadores
	
END