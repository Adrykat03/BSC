
/*

=============================================
  
Author: Steven Quispe
Create date: 05-01-2024
Description: Esta alerta identifica los siguientes casos
		1.- Colaboradores que en su historial de reingreso tengan un motivo de salida 'Expatriado' (y esten activos)
		2.- Colaboradores que esten saliendo con motivo de baja 'Expatriado'

=============================================
  
Editor: Steven Quispe
Edition date: 31-01-2024
Description: Se motificó la tabla de consulta para los expatriados con prebaja.
		Antes: RRHH.vw_datosTrabajadores
		Ahora: RRHH.PreBajas && RRHH.PreBajas_PRT

=============================================


*/

CREATE PROCEDURE [Avisos].[pa_colaboradores_expatriados]
AS
BEGIN

	-- Declaracion de variables 
	DECLARE
		@Dirigido varchar(300),
		@asunto varchar(300),
		@body varchar(5000),
		@HTML Nvarchar(MAX),
		@tab char(1) = CHAR(9),
		@error varchar(10),
		@destinatarios varchar(max),
		@fecha_Actual DATE = GETDATE(),
		@resultadoCaso1 varchar(150) = '° En el mes en curso no se encontraron alertas por colaboradores activos que tengan en su historial un motivo de salida de tipo EXPATRIADO.',
		@resultadoCaso2 varchar(150) = '° No se encontraron colaboradores Expatriados – Con pre_baja en este mes.'

	-- CONFIGURACION DE PARAMETROS DEL CORREO 

	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AlrExpAct'

	/* VARIABLES PARA CREACION DE CSV */
	DECLARE @consulta varchar(max), @archivo varchar(max), @archivo2 varchar(max);

	-- Creacion de tablas temporales
	IF Object_id(N'tempdb..##tmp_reingresos_rango_fechas_especificado', N'U') IS NOT NULL
			DROP TABLE ##tmp_reingresos_rango_fechas_especificado

	IF Object_id(N'tempdb..##tmp_comprobacion_reingresos_expatriados', N'U') IS NOT NULL
			DROP TABLE ##tmp_comprobacion_reingresos_expatriados

	IF Object_id(N'tempdb..##tmp_trabajadores_expatriados_activos', N'U') IS NOT NULL
			DROP TABLE ##tmp_trabajadores_expatriados_activos

	IF Object_id(N'tempdb..##tmp_alerta_expatriados_activos', N'U') IS NOT NULL
			DROP TABLE ##tmp_alerta_expatriados_activos

	IF Object_id(N'tempdb..##tmp_salidas_rango_fechas_especificado', N'U') IS NOT NULL
			DROP TABLE ##tmp_salidas_rango_fechas_especificado

	IF Object_id(N'tempdb..##tmp_alerta_salidas_expatriados', N'U') IS NOT NULL
			DROP TABLE ##tmp_alerta_salidas_expatriados


		/*		TABLAS PARA EL PRIMER CASO	*/
		CREATE TABLE ##tmp_trabajadores_expatriados_activos
		  (
			 repeticiones TINYINT,
			 CI			  CHAR(10)			
		  ) 

		CREATE TABLE ##tmp_reingresos_rango_fechas_especificado
		  (
			 CI			  CHAR(10)			
		  ) 

		CREATE TABLE ##tmp_comprobacion_reingresos_expatriados
		  (
			 CI			  CHAR(10)			
		  ) 

		CREATE TABLE ##tmp_alerta_expatriados_activos
		  (
			 trabajador				char(10),
			 nombre					varchar(650), 
			 Compania				char(4), 
			 Compania_Desc			varchar(450),
			 CCO					char(12),
			 Desc_CCO				varchar(150), 
			 Fecha_Antiguedad		date,
			 Fecha_ingreso			date,
			 Fecha_baja				date,
			 Descripcion_CausaBaja	varchar(350),
			 Nota_Baja				varchar(1800),
			 Motivo_Salida			varchar(250)
		  ) 

		  /*		TABLAS PARA EL SEGUNDO CASO			*/
		 CREATE TABLE ##tmp_salidas_rango_fechas_especificado
		  (
			 CI						CHAR(10),		
			 Fecha_baja				date,
			 Descripcion_CausaBaja	varchar(350),
			 Nota_Baja				varchar(1800),
			 Motivo_Salida			varchar(250)
		  ) 

		CREATE TABLE ##tmp_alerta_salidas_expatriados
		  (
			 trabajador				char(10),
			 nombre					varchar(650), 
			 Compania				char(4), 
			 Compania_Desc			varchar(450),
			 CCO					char(12),
			 Desc_CCO				varchar(150), 
			 Fecha_Antiguedad		date,
			 Fecha_ingreso			date,
			 Fecha_baja				date,
			 Descripcion_CausaBaja	varchar(350),
			 Nota_Baja				varchar(1800),
			 Motivo_Salida			varchar(250)
		  ) 

		/*			COMPROBACION DE ALERTAS PARA EL PRIMER CASO	 (EXPATRIADOS ACTIVOS)					*/
		-- Obtención de CI de trabajadores con fecha de ingreso en el rango de fecha especificado
		INSERT INTO ##tmp_reingresos_rango_fechas_especificado
			SELECT trabajador
			from RRHH.vw_datosTrabajadores Dt
				JOIN RRHH.Personas Rp
				ON Dt.Trabajador = Rp.cedula_dni
				-- La alerta debe tomar datos de los EXPATRIADOS ACTIVOS de ese mes
				WHERE (
						Dt.Fecha_Ingreso BETWEEN DATEADD(DAY, 1, EOMONTH(@fecha_Actual, -1)) AND @fecha_Actual	-- RANGO DE FECHAS ESPECIFICADO 
					OR
						Rp.fecha_creacion  BETWEEN DATEADD(DAY, 1, EOMONTH(@fecha_Actual, -1)) AND @fecha_Actual	-- RANGO DE FECHAS ESPECIFICADO 
					)
				AND Dt.Situacion =  'Activo'


		-- Obtención de CI de trabajadores expatriados
		INSERT INTO ##tmp_comprobacion_reingresos_expatriados
			SELECT trabajador from RRHH.vw_datosTrabajadores
				WHERE Motivo_Salida LIKE '%EXPATRIADO%'

		-- Obtención de CI de trabajadores de reingresos de la tabla general de trabajadores
		INSERT INTO ##tmp_trabajadores_expatriados_activos
			SELECT COUNT(1) AS n, Trabajador
			FROM  RRHH.vw_datosTrabajadores
			WHERE trabajador IN (Select CI FROM ##tmp_reingresos_rango_fechas_especificado) 
			GROUP BY Trabajador
			HAVING COUNT(1) > 1
			ORDER BY 1

		-- OBTENCION DE LOS DATOS 
		INSERT INTO ##tmp_alerta_expatriados_activos
			SELECT 
				 Trabajador,
				 Nombre, 
				 Compania, 
				 Compania_Desc,
				 CCO,
				 Desc_CCO, 
				 Fecha_Antiguedad,
				 Fecha_Ingreso,
				 Fecha_baja,
				 ISNULL(Descripcion_CausaBaja,'---'),
				 ISNULL(Notas_Baja,'---'),
				 ISNULL(Motivo_Salida,'---')
			FROM RRHH.vw_datosTrabajadores G
			WHERE G.trabajador in (SELECT DISTINCT T.CI FROM ##tmp_reingresos_rango_fechas_especificado T
									INNER JOIN ##tmp_comprobacion_reingresos_expatriados R
									ON T.CI = R.CI)
			ORDER BY G.trabajador, G.Fecha_Ingreso


		/*			COMPROBACION DE ALERTAS PARA EL SEGUNDO CASO	 (EXPATRIADOS CON PRE_BAJA)					*/
		-- Obtencion de CI de colaboradores
		INSERT INTO ##tmp_salidas_rango_fechas_especificado
				-- Seleccion CI colaboradores con Fecha de baja dentro del mes en curso Y causa de baja de tipo Expatriado
				SELECT Trabajador, Fecha_Baja, Cb.descripcion, Notas, Cm.descripcion
				FROM RRHH.PreBajas_PRT	PRT
					JOIN catalogos.motivosBaja Cm
						ON PRT.Cod_Motivo = Cm.motivo
					JOIN catalogos.causasBaja Cb
						ON PRT.Causa_Baja = Cb.causa_baja
					WHERE Fecha_baja BETWEEN DATEADD(DAY, 1, EOMONTH(@fecha_Actual, -1)) AND @fecha_Actual
					-- AND Cod_Motivo IN ('EXA','EXE','EXH','EXPA')
					AND Cod_Motivo LIKE '%EX%'
				UNION  
				SELECT Trabajador, Fecha_Baja, Cb.descripcion, Notas, Cm.descripcion
				FROM RRHH.PreBajas  Pb
					JOIN catalogos.motivosBaja Cm
						ON Pb.Cod_Motivo = Cm.motivo
					JOIN catalogos.causasBaja Cb
						ON Pb.Causa_Baja = Cb.causa_baja
					WHERE Fecha_baja BETWEEN DATEADD(DAY, 1, EOMONTH(@fecha_Actual, -1)) AND @fecha_Actual
					-- AND Cod_Motivo IN ('EXA','EXE','EXH','EXPA')
					AND Cod_Motivo LIKE '%EX%'

		-- OBTENCION DE LOS DATOS 
		INSERT INTO ##tmp_alerta_salidas_expatriados
			SELECT 
				 G.Trabajador,
				 G.Nombre, 
				 G.Compania, 
				 G.Compania_Desc,
				 G.CCO,
				 G.Desc_CCO, 
				 G.Fecha_Antiguedad,
				 G.Fecha_Ingreso,
				 S.Fecha_baja,
				 ISNULL(S.Descripcion_CausaBaja,'---'),
				 ISNULL(S.Nota_Baja,'---'),
				 ISNULL(S.Motivo_Salida,'---')
			FROM RRHH.vw_datosTrabajadores  G
			JOIN ##tmp_salidas_rango_fechas_especificado S
			ON G.Trabajador = S.CI
			WHERE G.trabajador in (SELECT DISTINCT T.CI FROM ##tmp_salidas_rango_fechas_especificado T)															
			AND G.trabajador NOT IN (SELECT V.Trabajador FROM ##tmp_alerta_expatriados_activos V)			-- Validacion que no sea parte del primer caso de la alerta
			AND Fecha_bajaIndice BETWEEN DATEADD(DAY, 1, EOMONTH(@fecha_Actual, -1)) AND @fecha_Actual
			ORDER BY G.trabajador, G.Fecha_baja

		-- VERIFICACION DE CASOS PARA ENVIO POR CORREO 
			IF (((SELECT COUNT(trabajador) FROM ##tmp_alerta_expatriados_activos) > 1) OR ((SELECT COUNT(trabajador) FROM ##tmp_alerta_salidas_expatriados) > 1))
			
				-- SI SE ENCUENTRAN REGISTROS
				BEGIN TRY  
			
				SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA EXPATRIADOS</h3>'
								+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
								+N' </body>' 

				/*			COMPROBACIÓN CASO 2			*/
				IF((SELECT COUNT(trabajador) FROM ##tmp_alerta_salidas_expatriados) = 0) -- No Hay registros
					BEGIN 
						SELECT @HTML = CONCAT(@HTML,  N'<h4><font color="SteelBlue">'+ @resultadoCaso2+ '</h4>'
								+N' </body>') 
					END
				ELSE -- Si hay registros
					BEGIN 
						SET @resultadoCaso2 = '° A continuación, se muestran los colaboradores correspondientes a expatriados con pre_baja de este mes:'
					

						/*			Tabulación de datos para envio por correo		*/
						SELECT @HTML = CONCAT(@HTML, N'<style type="text/css">
							#box-table
							{
								font-family: "Calibri";
								font-size: 11px;
								text-align: center;
								border-collapse: collapse;
								border-top: 7px solid #9baff1;
								border-bottom: 7px solid #9baff1;
								table-layout:fixed;
							}
							#box-table th
							{
								font-size: 10px;
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
								padding-top: 2px;
								padding-bottom: 2px;
								padding-left: 4px;
								padding-right: 4px;
								color: #669;
							}
							tr:nth-child(odd)	{ background-color:#eee; }
							tr:nth-child(even)	{ background-color:#fff; }	
						</style>'
						+	
						N'<H4><font color="SteelBlue">'+ @resultadoCaso2+ '</H4>'+
						N'<table id="box-table">'+
						N'<th>Trabajador</th>'+
						N'<th>Nombre</th>'+
						N'<th>Compania</th>'+
						N'<th>Descripcion_compania</th>'+
						N'<th>CCO</th>'+
						N'<th>Datos_CCO</th>'+
						N'<th>Fecha_Antiguedad</th>'+
						N'<th>Fecha_ingreso</th>'+
						N'<th>Fecha_baja</th>'+
						N'<th>Descripcion_CausaBaja</th>'+
						N'<th>Nota_Baja</th>'+
						N'<th>Motivo_Salida</th>'+
						N'</tr>'+
						CAST(
							(SELECT 
								td = e.Trabajador, '',
								td = e.Nombre, '',
								td = e.Compania, '',
								td = e.Compania_Desc, '',
								td = e.CCO, '',
								td = e.Desc_CCO, '',
								td = ISNULL(CONVERT(VARCHAR(20),e.Fecha_Antiguedad, 103),'-'), '',
								td = ISNULL(CONVERT(VARCHAR(20),e.Fecha_Ingreso, 103), '-'), '',
								td = ISNULL(CONVERT(VARCHAR(20),e.Fecha_baja, 103), '-'), '',
								td = ISNULL(e.Descripcion_CausaBaja,'---'), '',
								td = ISNULL(e.Nota_Baja,'---'), '',
								td = ISNULL(e.Motivo_Salida,'---'), ''			 
							FROM ##tmp_alerta_salidas_expatriados e ORDER BY convert(date, e.Fecha_baja) 
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>' +
						N'<br/>')
					END 

				/*			COMPROBACIÓN CASO 1			*/
				IF((SELECT COUNT(trabajador) FROM ##tmp_alerta_expatriados_activos) = 0)	-- Si no hay registros
					BEGIN 
						SELECT @HTML = CONCAT(@HTML,  N'<h4><font color="SteelBlue">'+ @resultadoCaso1+ '</h4>'
								+N'<br/>'
								+N' </body>') 

						/*		ENVIO DE CORREO GENERAL		*/
						-- INSERT notificación consolidada
						INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
						VALUES ('A', 'Trabajadores', 'pa_colaboradores_expatriados', @asunto, @HTML, @destinatarios);
						EXEC msdb.dbo.sp_send_dbmail 
							@profile_name='Informacion_Nomina',
							@recipients= @destinatarios, 		
						 	@subject = @asunto,
							@body = @HTML,
							@body_format = 'HTML' ; 

					END
				ELSE
					BEGIN 
						SET @resultadoCaso1 = '° A continuación, se  muestran los colaboradores activos que tienen en su historial un motivo de baja de tipo EXPATRIADO: '
						-- ENVIO DE RESULTADOS POR CORREO 
							/*			Tabulación de datos para envio por correo		*/
							SELECT @HTML = CONCAT(@HTML, N'<style type="text/css">
								#box-table
								{
									font-family: "Calibri";
									font-size: 11px;
									text-align: center;
									border-collapse: collapse;
									border-top: 7px solid #9baff1;
									border-bottom: 7px solid #9baff1;
									table-layout:fixed;
								}
								#box-table th
								{
									font-size: 10px;
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
									padding-top: 2px;
									padding-bottom: 2px;
									padding-left: 4px;
									padding-right: 4px;
									color: #669;
								}
								tr:nth-child(odd)	{ background-color:#eee; }
								tr:nth-child(even)	{ background-color:#fff; }	
							</style>'
							+	
							N'<H4><font color="SteelBlue">'+ @resultadoCaso1 + '</H4>'+
							N'<table id="box-table">'+
							N'<th>Trabajador</th>'+
							N'<th>Nombre</th>'+
							N'<th>Compania</th>'+
							N'<th>Descripcion_compania</th>'+
							N'<th>CCO</th>'+
							N'<th>Datos_CCO</th>'+
							N'<th>Fecha_Antiguedad</th>'+
							N'<th>Fecha_ingreso</th>'+
							N'<th>Fecha_baja</th>'+
							N'<th>Descripcion_CausaBaja</th>'+
							N'<th>Nota_Baja</th>'+
							N'<th>Motivo_Salida</th>'+
							N'</tr>'+
							CAST(
								(SELECT 
									td = e.Trabajador, '',
									td = e.Nombre, '',
									td = e.Compania, '',
									td = e.Compania_Desc, '',
									td = e.CCO, '',
									td = e.Desc_CCO, '',
									td = ISNULL(CONVERT(VARCHAR(20),e.Fecha_Antiguedad, 103),'-'), '',
									td = ISNULL(CONVERT(VARCHAR(20),e.Fecha_Ingreso, 103), '-'), '',
									td = ISNULL(CONVERT(VARCHAR(20),e.Fecha_baja, 103), '-'), '',
									td = ISNULL(e.Descripcion_CausaBaja,'---'), '',
									td = ISNULL(e.Nota_Baja,'---'), '',
									td = ISNULL(e.Motivo_Salida,'---'), ''			 
								FROM ##tmp_alerta_expatriados_activos e ORDER BY nombre, convert(date, e.Fecha_ingreso) DESC
								FOR XML PATH('tr'), TYPE) AS varchar(max)) +
							N'</table>' +
							N'<br/>') 
							+N' </body>' 

							/*		ENVIO DE CORREO GENERAL		*/
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
							VALUES ('A', 'Trabajadores', 'pa_colaboradores_expatriados', @asunto, @HTML, @destinatarios);
							EXEC msdb.dbo.sp_send_dbmail 
								@profile_name='Informacion_Nomina',
								@recipients= @destinatarios, 		
							 	@subject = @asunto,
								@body = @HTML,
								@body_format = 'HTML' ; 

					END

				END TRY 
				BEGIN CATCH
					INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec; info.nomina@kfc.com.ec' , NULL, @HTML, @asunto, 'Error al envíar correo')
				END CATCH
			ELSE
				-- EN CASO DE QUE NO HAYA REGISTROS
				BEGIN 
					SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR EXPATRIADOS </h3>'
								+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
								+N'<h5><font color="SteelBlue">'+ @resultadoCaso1+ '</h5>'
								+N'<h5><font color="SteelBlue">'+ @resultadoCaso2+ '</h5>'
								+N'<br/><br />'
								+N' </body>' 
			
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
							VALUES ('A', 'Trabajadores', 'pa_colaboradores_expatriados', @asunto, @HTML, @destinatarios);
							EXEC msdb.dbo.sp_send_dbmail 
								@profile_name='Informacion_Nomina',
							 	@recipients= @destinatarios, 
								@subject = @asunto,
								@body = @HTML,
								@body_format = 'HTML' ;  
				END

	-- Eliminación de tablas temporales
	IF Object_id(N'tempdb..##tmp_reingresos_rango_fechas_especificado', N'U') IS NOT NULL
			DROP TABLE ##tmp_reingresos_rango_fechas_especificado

	IF Object_id(N'tempdb..##tmp_comprobacion_reingresos_expatriados', N'U') IS NOT NULL
			DROP TABLE ##tmp_comprobacion_reingresos_expatriados

	IF Object_id(N'tempdb..##tmp_trabajadores_expatriados_activos', N'U') IS NOT NULL
			DROP TABLE ##tmp_trabajadores_expatriados_activos

	IF Object_id(N'tempdb..##tmp_alerta_expatriados_activos', N'U') IS NOT NULL
			DROP TABLE ##tmp_alerta_expatriados_activos

	IF Object_id(N'tempdb..##tmp_salidas_rango_fechas_especificado', N'U') IS NOT NULL
			DROP TABLE ##tmp_salidas_rango_fechas_especificado

	IF Object_id(N'tempdb..##tmp_alerta_salidas_expatriados', N'U') IS NOT NULL
			DROP TABLE ##tmp_alerta_salidas_expatriados

END