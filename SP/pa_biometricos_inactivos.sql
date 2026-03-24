
/*

=============================================
  
Author: Steven Quispe
Create date: 17-04-2024
Description: Alerta para notificar novedades en los biometricos (nombres de dispositivos repetidos, no trae informacion de DIEL, apagados con marcajes, activados sin datos, no relacionados)

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_biometricos_inactivos]
	-- Parametro para llenar tablas o ejecutar consultas 
	@tipo int
AS 
BEGIN
	/************************** LLENAR DATOS EN LAS TABLAS **************************************/
	-- @tipo = 1
	IF(@tipo = 1)
		BEGIN
			-- Creacion de tablas 
			--CREATE TABLE integracion.Diel_Tbl_Locations			
			--(
			--	[DIEL_ID_LOCATIONS]	UNIQUEIDENTIFIER,
			--	 [ID]					INT,
			--	 [DESCRIPTION]			VARCHAR(255),
			--	 --REGION_ID,
			--	 [ENABLE]				BIT,
			--	 -- CREATED_BY			,
			--	 --CREATED_DATE,
			--	 --LAST_MODIFIED_BY,
			--	 --LAST_MODIFIED_DATE,
			--	 [CODE]					VARCHAR(10),
			--	 [CODE_AUX]				VARCHAR(10)
			--) 

			--CREATE TABLE integracion.Diel_Tbl_FKdevice_Status
			--(
			--	 [DIEL_DEVICE_LOCATIONS]	UNIQUEIDENTIFIER,
			--	 [DEVICE_ID]			VARCHAR(24),
			--	 [CONNECTED]			INT,
			--	 --[DEVICE_INFO]			
			--	 [DEVICE_NAME]			VARCHAR(24),
			--	 [DEVICE_IP]			VARCHAR(20),
			--	 --[LAST_UPDATE_FK_TIME]	
			--	 --[LAST_UPDATE_TIME]
			--	 [LOCATION_ID]			INT
			--	 --[LOCATION_ASIGNED]
			--	 --[ENROLL_DEVICE]
			--) 

			-- Borrado de datos anteriores
			TRUNCATE TABLE integracion.Diel_Tbl_Locations

			TRUNCATE TABLE integracion.Diel_Tbl_FKdevice_Status

			-- Llenado de datos desde la base de la consola DIEL
			INSERT INTO integracion.Diel_Tbl_Locations
			SELECT 
				NEWID(),
				[ID],
				[DESCRIPTION],
				[ENABLE],
				[CODE],
				[CODE_AUX]
			FROM [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_LOCATIONS]

			INSERT INTO integracion.Diel_Tbl_FKdevice_Status
			SELECT 
				NEWID(),
				[DEVICE_ID],
				[CONNECTED],
				[DEVICE_NAME],
				[DEVICE_IP],
				[LOCATION_ID]
			FROM [srvv-biomdb].[BiometricosDIEL].[dbo].[TBL_FKDEVICE_STATUS]

			
		END

	/**************************   EJECUTAR LAS CONSULTAS   **************************************/
	-- @tipo = 2
	IF(@tipo = 2) 
		BEGIN 
			IF OBJECT_ID(N'tempdb..#BiometricosRepetidos', N'U') IS NOT NULL
				DROP TABLE #BiometricosRepetidos

			IF OBJECT_ID(N'tempdb..#BiometricosNoTraeDiel', N'U') IS NOT NULL
					DROP TABLE #BiometricosNoTraeDiel

			IF OBJECT_ID(N'tempdb..#BiometricosDesactivadosConMarcajes', N'U') IS NOT NULL
					DROP TABLE #BiometricosDesactivadosConMarcajes

			IF OBJECT_ID(N'tempdb..#CCOActivoSinBiometrico', N'U') IS NOT NULL
					DROP TABLE #CCOActivoSinBiometrico

			IF OBJECT_ID(N'tempdb..#BiometricosActivadosSinInformacion', N'U') IS NOT NULL
					DROP TABLE #BiometricosActivadosSinInformacion

			IF OBJECT_ID(N'tempdb..#BiometricosNoRelacionados', N'U') IS NOT NULL
					DROP TABLE #BiometricosNoRelacionados

			IF OBJECT_ID(N'tempdb..#TieneMarcajes', N'U') IS NOT NULL
					DROP TABLE #TieneMarcajes

			SET DATEFORMAT ymd

			-- 1: Biometricos con nombres repetidos
			;WITH CTE_biometricoRepetido
			AS(
				SELECT Count(1) AS 'Cantidad', DEVICE_NAME
				FROM integracion.Diel_Tbl_FKdevice_Status
				GROUP BY DEVICE_NAME
			)
			SELECT * 
			INTO #BiometricosRepetidos
			FROM CTE_biometricoRepetido
			WHERE Cantidad > 1

			--SELECT * FROM #BiometricosRepetidos

			-- 2: Comprobacion de que CCO con biometrico no se trae de la consola DIEL
			--SELECT id_cco, cco, descripcion, cco_padre, id_claseNomina, estatus, codigoLocal, tieneBimetrico, id_biometrico, ip_biometrico
			--INTO #BiometricosNoTraeDiel
			--FROM Catalogos.centro_costos
			--WHERE tieneBimetrico = 1  -- CCO con biométrico
			--AND estatus = 1		      -- CCO Activo
			--AND cco NOT IN (
			--			-- Que cco vienen de la consola DIEL 
			--				SELECT CCO FROM integracion.biometricos
			--			)
			--AND codigoLocal NOT IN(SELECT LTRIM(RTRIM(deviceName)) from #BiometricosRepetidos)

			--SELECT * FROM #BiometricosNoTraeDiel

			-- 3: Comprobacion CCO con biometrico DESACTIVADO que tiene marcaciones en los ultimos 3 meses
			DECLARE 
				@fecha_actual DATE = GETDATE(),
				@mes tinyint = 3, 
				@texto_mensaje varchar(30) = '';

			SELECT @texto_mensaje = CASE WHEN @mes = 1 THEN 'el último mes' ELSE 'los últimos ' + CONVERT(VARCHAR(2), @mes) + ' meses' END

			SELECT COUNT(1) AS 'Cantidad_marcajes', LocationCode
			INTO #TieneMarcajes
			FROM TMP_Marcaje_WS_Competencia
			WHERE (CONVERT(DATE, IoTime) BETWEEN DATEADD(MONTH, -@mes, @fecha_actual) AND @fecha_actual)
			GROUP BY LocationCode

			;WITH CTE_BiometricosDesactivadosConMarcajes
			AS(
				SELECT cc.id_cco, cc.cco, cc.descripcion, cc.cco_padre, cc.id_claseNomina, cc.estatus, cc.codigoLocal, cc.tieneBimetrico, cc.id_biometrico, cc.ip_biometrico
				, ISNULL((SELECT Cantidad_marcajes FROM #TieneMarcajes WHERE LocationCode = cc.cco), 0) AS NumMarcajes, id.[CONNECTED]
				FROM Catalogos.centro_costos AS cc
				INNER JOIN integracion.Diel_Tbl_FKdevice_Status AS id ON cc.codigoLocal = id.DEVICE_NAME
				INNER JOIN integracion.Diel_Tbl_Locations AS il ON RTRIM(LTRIM(id.[LOCATION_ID])) = RTRIM(LTRIM(il.[ID]))
				--INNER JOIN integracion.Diel_Tbl_Locations AS il ON RTRIM(LTRIM(cc.cco)) = RTRIM(LTRIM(il.CODE))
				WHERE id.CONNECTED = 0  -- CCO con biométrico APAGADO
				AND cc.estatus = 1			-- CCO Activo
				AND codigoLocal NOT IN(SELECT LTRIM(RTRIM(DEVICE_NAME)) from #BiometricosRepetidos)
			)
			SELECT * 
			into #BiometricosDesactivadosConMarcajes
			FROM CTE_BiometricosDesactivadosConMarcajes
			WHERE NumMarcajes > 0

			--SELECT * FROM #BiometricosDesactivadosConMarcajes


			-- 4: Comprobacion de CCO activos sin biométrico (Excluyendo planta)
			SELECT id_cco, cco, descripcion, cco_padre, id_claseNomina, estatus, codigoLocal, tieneBimetrico, id_biometrico, ip_biometrico
			INTO #CCOActivoSinBiometrico
			FROM DB_NOMKFC.catalogos.centro_costos
			WHERE tieneBimetrico = 0
			AND id_claseNomina not in (39,18,52,42,61,62,37,23)
			AND esLocal = 'S' and isnull(codigoLocal,'')<> '' 
			AND estatus =1 and descripcion not like '%Entrenamiento%' and descripcion not like '%anfitrion%' 
			ORDER BY id_claseNomina, descripcion

			--SELECT * FROM #CCOActivoSinBiometrico

			-- 5: Comprobacion de CCO con biometrico ACTIVADO sin informacion de id e ip 
			SELECT id_cco, cco, descripcion, cco_padre, id_claseNomina, estatus, codigoLocal, tieneBimetrico, id_biometrico, ip_biometrico, SubAgrCCO
			INTO #BiometricosActivadosSinInformacion
			FROM Catalogos.centro_costos
			WHERE tieneBimetrico = 1
			AND (ISNULL(id_biometrico, '') = ''
					AND ISNULL(ip_biometrico, '') = ''
				)
			--AND SubAgrCCO != 'HELADERIA' 
			AND codigoLocal NOT IN(SELECT LTRIM(RTRIM(DEVICE_NAME)) from #BiometricosRepetidos)  -- Se excluye los que tienen 2 biometricos

			--SELECT * FROM #BiometricosActivadosSinInformacion


			-- 6: Biometricos no relacionados: Cuando cco es NULL, no trae marcaciones 
			SELECT * 
			INTO #BiometricosNoRelacionados
			FROM integracion.Diel_Tbl_FKdevice_Status
			WHERE ISNULL(LOCATION_ID, '') = ''
			AND DEVICE_NAME NOT IN(SELECT LTRIM(RTRIM(DEVICE_NAME)) from #BiometricosRepetidos)  -- Se excluye los que tienen 2 biometricos
			AND DEVICE_NAME IN (
								SELECT codigoLocal FROM Catalogos.centro_costos
								)
			ORDER BY DEVICE_NAME

			--SELECT * FROM #BiometricosNoRelacionados

			-- CORREO ALERTA

					DECLARE @tiene1 int = 0, @tiene2 int = 0, @tiene3 int = 0, @tiene4 int = 0, @tiene5 int = 0, @tiene6 int = 0
					DECLARE @htmlE varchar(max)='', @html1 varchar(max)='', @html2 varchar(max)='', @html3 varchar(max)='',@html4 varchar(max)='', @html5 varchar(max)='',  @html6 varchar(max)='',
					@asunto varchar (400), @saludos varchar(500)='', @destinatarios varchar(max); 
	
					SELECT @destinatarios= valor, @asunto=descripcion FROM [DB_NOMKFC].[Configuracion].[parametros] WHERE parametro = 'AltNovBio'
					--SELECT @destinatarios= 'pasante.nominadosec@kfc.com.ec', @asunto='B3 - Novedades en los biométricos'
					SELECT DISTINCT @tiene1 = COUNT(DEVICE_NAME) FROM  #BiometricosRepetidos 
					--SELECT DISTINCT @tiene2 = COUNT(id_cco) FROM  #BiometricosNoTraeDiel 
					SELECT DISTINCT @tiene3 = COUNT(id_cco) FROM  #BiometricosDesactivadosConMarcajes 
					SELECT DISTINCT @tiene4 = COUNT(id_cco) FROM  #CCOActivoSinBiometrico 
					SELECT DISTINCT @tiene5 = COUNT(id_cco) FROM  #BiometricosActivadosSinInformacion 
					SELECT DISTINCT @tiene6 = COUNT(DEVICE_NAME) FROM  #BiometricosNoRelacionados 
		
					IF (@tiene1 = 0 or @tiene2 = 0 or @tiene3 <> 0 or @tiene4 <> 0 or @tiene5 <> 0)
					BEGIN
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
							N' <h4 style="font-family: Calibri; color:black;"> 
												Informe de biométricos ' +CONVERT(VARCHAR, GETDATE(), 103)+ '. </h4>'
	
						IF (@tiene1 <> 0)
							BEGIN
							select @html1= 	
											N'<body>'+								
												N' <br/>'+
												N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
												Listado de biométricos con nombre de dispositivo duplicado (Posible daño en el biométrico original y se instaló uno nuevo): '+
												N' <br>'+
												N' <table class="box-table" >' +
												N' <tr>'+
												N' <th style="text-align:center"> Cantidad</th>'+
												N' <th style="text-align:center"> Descripción del local</th>'+
	
												cast( (select 
															td = ISNULL(e.Cantidad,''),'',
															td = ISNULL(e.DEVICE_NAME,''),''
															FROM #BiometricosRepetidos e
												FOR XML PATH('tr'),TYPE
												) as varchar(max))+
													N'</table>'+
													N' <br/></body>' 
							END
							else
							BEGIN
							select @html1=N'<body>'+
									N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
												Listado de biométricos con nombre de dispositivo duplicado (Posible daño en el biométrico original y se instaló uno nuevo):'+
										N' <table class="box-table">' +N' <tr>' +
											N' <th style="text-align:center" > Notificación</th>'+
										N' </tr>'+
										N' <tr>'+
											N' <td >
											No se encontraron biométricos con el mismo nombre de dispositivo.</td>'+N' </tr>'+
									N'</table>'+
													N'</body>';
						
							END
						--IF (@tiene2 <> 0)
						--	BEGIN
						--		select @html2= 	
						--					N'<body>'+
						--						N' <h1 style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
						--						Listado de centros de costo con biométrico activo en PayRoll [Catalogos.centro_costos] que no constan en los 
						--						datos obtenidos desde la consola DIEL [integracion.biometricos]: </h1>'+
						--						N' <br/>'+
						--						N' <table class="box-table" >' +
						--						N' <tr>'+
						--						N' <th style="text-align:center"> id_cco</th>'+
						--						N' <th style="text-align:center"> cco</th>'+
						--						N' <th style="text-align:center"> descripcion</th>'+
						--						N' <th style="text-align:center"> cco_padre</th>'+
						--						N' <th style="text-align:center"> id_claseNomina</th>'+
						--						N' <th style="text-align:center"> codigoLocal</th>'+
						--						N' <th style="text-align:center"> Tiene Biometrico</th>'+
						--						N' <th style="text-align:center"> Id Biométrico</th>'+
						--						N' <th style="text-align:center"> IP Biométrico</th>'+
	 
						--						cast( (select 
						--									td = ISNULL(e.id_cco,''),'', 
						--									td = ISNULL(e.cco,''),'',
						--									td = ISNULL(e.descripcion,''),'',
						--									td = ISNULL(e.cco_padre,''),'',
						--									td=  ISNULL(e.id_claseNomina,''),'',
						--									td = ISNULL(e.codigoLocal,''),'',
						--									td = ISNULL(e.tieneBimetrico,''),'',
						--									td=  ISNULL(e.id_biometrico,''),'',
						--									td=  ISNULL(e.ip_biometrico, ''),''
						--									FROM #BiometricosNoTraeDiel e
						--									ORDER BY e.id_claseNomina, e.cco
								 
						--						FOR XML PATH('tr'),TYPE
						--						) as varchar(max))+
						--							N' </table>'+
						--							N'<br>'+
						--							N' </body>' 
									
						--	END
						--	 ELSE
						--		BEGIN
						--		SELECT @html2=N'<body>'+
						--						N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
						--						Listado de centros de costo con biométrico activo en PayRoll [Catalogos.centro_costos] que no constan en los 
						--						datos obtenidos desde la consola DIEL [integracion.biometricos]:'+
						--						N' <table class="box-table">' +
						--						N' <tr>'+
						--						N' <th style="text-align:center"> Notificación</th>'+N' </tr>'+N' <tr>'+
						--						N' <td >
						--						No se encontraron centros de costo con biométrico activo que no se traen desde la consola DIEL</td>'+N' </tr>'+
						--				N'</table>'+
						--								N' </body>';	
						--		END

							IF (@tiene3 <> 0)
							BEGIN
								select @html3= 	
											N' <body>'+
												N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
												Listado de centros de costos con biométrico DESACTIVADO que registran marcajes en ' + @texto_mensaje + ':'+
											N' <br>'+
											N' <table class="table1" >'+ 
											N' <th style="font-weight: normal;   ">'+
											N' <table class="box-table" >' +
											N' <th style="text-align:center"> id_cco</th>'+
											N' <th style="text-align:center"> cco</th>'+
											N' <th style="text-align:center"> descripcion</th>'+
											N' <th style="text-align:center"> cco_padre</th>'+
											N' <th style="text-align:center"> codigoLocal</th>'+
											N' <th style="text-align:center"> Tiene Biometrico</th>'+
											N' <th style="text-align:center"> Id Biométrico</th>'+
											N' <th style="text-align:center"> Conectado</th>'+
   
											cast( (select 
													td = ISNULL(a.id_cco,''),'', 
													td = ISNULL(a.cco,''),'',
													td = ISNULL(a.descripcion,''),'',
													td = ISNULL(a.cco_padre,''),'',
													td = ISNULL(a.codigoLocal,''),'',
													td = ISNULL(a.tieneBimetrico,''),'',
													td=  ISNULL(a.id_biometrico,''),'',
													td=  ISNULL(a.CONNECTED,''),''
														FROM #BiometricosDesactivadosConMarcajes a
													ORDER BY a.id_claseNomina, a.cco_padre, a.codigoLocal
											FOR XML PATH('tr'),TYPE
											) as varchar(max))+
													N' </table>'+
													N' </body>'

							END
								ELSE
									BEGIN
									SELECT @html3=N'<body>'+
													N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
													Listado de centros de costos con biométrico DESACTIVADO que registran marcajes en ' + @texto_mensaje + ':'+
													N' <table class="box-table">' +
													N' <tr>'+
													N' <th style="text-align:center"> Notificación</th>'+N' </tr>'+N' <tr>'+
													N' <td >
													No se encontraron novedades</td>'+N' </tr>'+
											N'</table>'+
															N' </body>';	
								END

							IF (@tiene4 <> 0)
								BEGIN
									select @html4=
												N' <body>'+
												N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
												Listado de centros de costos sin biométricos en [Catalogos.centro_costos]:'+
											N' <br>'+
											N' <table class="table1" >'+ 
											N' <th style="font-weight: normal;   ">'+
											N' <table class="box-table" >' +
											N' <th style="text-align:center"> Id_cco</th>'+
											N' <th style="text-align:center"> Cco</th>'+
											N' <th style="text-align:center"> Descripcion</th>'+
											N' <th style="text-align:center"> Cco_padre</th>'+
											N' <th style="text-align:center"> CodigoLocal</th>'+
											N' <th style="text-align:center"> Tiene Biometrico</th>'+
											N' <th style="text-align:center"> Id Biométrico</th>'+
											N' <th style="text-align:center"> IP Biométrico</th>'+
   
											cast( (select 
													td = ISNULL(d.id_cco,''),'', 
													td = ISNULL(d.cco,''),'',
													td = ISNULL(d.descripcion,''),'',
													td = ISNULL(d.cco_padre,''),'',
													td = ISNULL(d.codigoLocal,''),'',
													td = ISNULL(d.tieneBimetrico,''),'',
													td=  ISNULL(d.id_biometrico,''),'',
													td=  ISNULL(d.ip_biometrico, ''),''
														FROM #CCOActivoSinBiometrico d
													ORDER BY d.id_claseNomina, d.cco
											FOR XML PATH('tr'),TYPE
											) as varchar(max))+
													N' </table>'+
													N' </body>'
							END
								ELSE
									BEGIN
									SELECT @html4=N'<body>'+
													N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
													Listado de centros de costos sin biométricos en [Catalogos.centro_costos]:'+
													N' <table class="box-table">' +
													N' <tr>'+
													N' <th style="text-align:center"> Notificación</th>'+N' </tr>'+N' <tr>'+
													N' <td >
													No se encontraron novedades</td>'+N' </tr>'+
											N'</table>'+
															N' </body>';	
								END

							IF (@tiene5 <> 0)
								BEGIN
									select @html5=
												N' <body>'+
													N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
													Listado de centros de costos con biométrico ACTIVADO sin información de id e ip del dispositivo en PayRoll [Catalogos.centro_costos]:'+
												N' <br>'+
												N' <table class="table1" >'+ 
												N' <th style="font-weight: normal;   ">'+
												N' <table class="box-table" >' +
												N' <tr>'+
												N' <th style="text-align:center"> id_cco</th>'+
												N' <th style="text-align:center"> cco</th>'+
												N' <th style="text-align:center"> descripcion</th>'+
												N' <th style="text-align:center"> cco_padre</th>'+
												N' <th style="text-align:center"> id_claseNomina</th>'+
												N' <th style="text-align:center"> codigoLocal</th>'+
												N' <th style="text-align:center"> Tiene Biometrico</th>'+
												N' <th style="text-align:center"> Id Biométrico</th>'+
								

												cast( (select 
															td = ISNULL(f.id_cco,''),'', 
															td = ISNULL(f.cco,''),'',
															td = ISNULL(f.descripcion,''),'',
															td = ISNULL(f.cco_padre,''),'',
															td=  ISNULL(f.id_claseNomina,''),'',
															td = ISNULL(f.codigoLocal,''),'',
															td = ISNULL(f.tieneBimetrico,''),'',
															td=  ISNULL(f.id_biometrico,''),''
															FROM #BiometricosActivadosSinInformacion f
															ORDER BY f.id_claseNomina, f.cco
												FOR XML PATH('tr'),TYPE
												) as varchar(max))+
													N' </table>'+
													N' </body>'		
								END
									ELSE
										BEGIN
										SELECT @html5=N'<body>'+
														N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
														Listado de centros de costos con biométrico ACTIVADO sin información de id e ip del dispositivo en PayRoll [Catalogos.centro_costos]:'+
														N' <table class="box-table">' +
														N' <tr>'+
														N' <th style="text-align:center"> Notificación</th>'+N' </tr>'+N' <tr>'+
														N' <td >
														No se encontraron novedades</td>'+N' </tr>'+
												N'</table>'+
																N' </body>';	
									END
							IF (@tiene6 <> 0)
								BEGIN
									select @html6=
												N' <body>'+
													N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
													Listado de biométricos que no tienen asignado ubicación en la consola DIEL, motivo por el cual no se descargaría los marcajes en el sistema PayRoll:'+
												N' <br>'+
												N' <table class="table1" >'+ 
												N' <th style="font-weight: normal;   ">'+
												N' <table class="box-table" >' +
												N' <tr>'+
												N' <th style="text-align:center"> Dispositivo</th>'+
												N' <th style="text-align:center"> Conectado</th>'+
												N' <th style="text-align:center"> Nombre del dispositivo</th>'+
												N' <th style="text-align:center"> CCO</th>'+
							
												cast( (select 
															td = ISNULL(g.DEVICE_ID,''),'', 
															td = ISNULL(g.CONNECTED,''),'',
															td = ISNULL(g.DEVICE_NAME,''),'',
															td=  ISNULL(g.LOCATION_ID,''),''
															FROM #BiometricosNoRelacionados g
															ORDER BY g.CONNECTED, g.DEVICE_NAME
												FOR XML PATH('tr'),TYPE
												) as varchar(max))+
													N' </table>'+
													N' <br/></body>'	
								END
									ELSE
											BEGIN
											SELECT @html6=N'<body>'+
															N' <p style="text-align:start; font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: blod; line-height: auto;"> 
															Listado de biométricos que no tienen asignado ubicación en la consola DIEL, motivo por el cual no se descargaría los marcajes en el sistema PayRoll:'+
															N' <table class="box-table">' +
															N' <tr>'+
															N' <th style="text-align:center"> Notificación</th>'+N' </tr>'+N' <tr>'+
															N' <td >
															No se encontraron novedades</td>'+N' </tr>'+
													N'</table>'+
																	N' </body>';	
										END

								if @html1 is not null or @html2 is not null or @html3 is not null or @html4 is not null or @html5 is not null or @html6 is not null 
									declare @html varchar(max)= @htmlE + ' ' +@html1 + ' ' + @html2 + ' ' + @html3 + ' ' + @html4 + ' ' + @html5 + ' ' + @html6
									SELECT @html AS '-'
									begin
											-- INSERT notificación consolidada
											INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
											VALUES ('A', 'Biométricos', 'pa_biometricos_inactivos', @asunto, @html, @tiene6, @destinatarios);
											exec msdb.dbo.Sp_send_dbmail
											@profile_name = 'Informacion_Nomina',  
											@Subject = @asunto,
											@recipients = @destinatarios,
											--- @recipients = 'pasante.nominadosec@kfc.com.ec;',
											@body_format= 'html',
											@body = @html
									end
					END
						ELSE
							BEGIN
										select @html1=N'<body>'+
											N' <h4 style="text-align:start; font-family: Calibri; text-align:center">ALERTA BIOMÉTRICOS</h4>'+ 
							
											N' <p style="border: 2px solid #d8d8d8; background: #white; font-weight:normal; padding: 100px; 
											border-left: solid rgb(0, 103, 198);  font-family: Calibri;">Fecha: '+CONVERT(VARCHAR, GETDATE(), 103)+' <br/>
											No se encontraron novedades con los biométricos.</br>'+
											N' <br/></body>';

										if @html1 is not null 
										begin
											-- INSERT notificación consolidada
											INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
											VALUES ('A', 'Biométricos', 'pa_biometricos_inactivos', @asunto, @html1, @tiene6, @destinatarios);
											exec msdb.dbo.Sp_send_dbmail
												@profile_name = 'Informacion_Nomina', 
												@Subject = @asunto,
												@recipients = @destinatarios,
												-- @recipients = 'pasante.nominadosec@kfc.com.ec;',
												@body_format= 'html',
												@body = @html1
										end
							END


			IF OBJECT_ID(N'tempdb..#BiometricosRepetidos', N'U') IS NOT NULL
					DROP TABLE #BiometricosRepetidos

			IF OBJECT_ID(N'tempdb..#BiometricosNoTraeDiel', N'U') IS NOT NULL
					DROP TABLE #BiometricosNoTraeDiel

			IF OBJECT_ID(N'tempdb..#BiometricosDesactivadosConMarcajes', N'U') IS NOT NULL
					DROP TABLE #BiometricosDesactivadosConMarcajes

			IF OBJECT_ID(N'tempdb..#CCOActivoSinBiometrico', N'U') IS NOT NULL
					DROP TABLE #CCOActivoSinBiometrico

			IF OBJECT_ID(N'tempdb..#BiometricosActivadosSinInformacion', N'U') IS NOT NULL
					DROP TABLE #BiometricosActivadosSinInformacion

			IF OBJECT_ID(N'tempdb..#BiometricosNoRelacionados', N'U') IS NOT NULL
					DROP TABLE #BiometricosNoRelacionados

			IF OBJECT_ID(N'tempdb..#TieneMarcajes', N'U') IS NOT NULL
					DROP TABLE #TieneMarcajes
		
		END
	
END