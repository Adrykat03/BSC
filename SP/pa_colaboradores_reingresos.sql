
/*

=============================================
  
Author: Steven Quispe
Create date: 11-01-2024
Description: Alerta para notificar los reingresos segun las siguientes especificaciones:
	- Lunes: Reingresos de todo el mes.
	- Resto de días: Reingresos del día anterior a la ejecución.

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_colaboradores_reingresos]
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
		@dia_Actual Nvarchar(10) = (CASE DATENAME(dw, GETDATE())
									 when 'Monday' then 'LUNES'
									 when 'Tuesday' then 'MARTES'
									 when 'Wednesday' then 'MIERCOLES'
									 when 'Thursday' then 'JUEVES'
									 when 'Friday' then 'VIERNES'
									 when 'Saturday' then 'SABADO'
									 when 'Sunday' then 'DOMINGO'
								END),
		@descripcionAlerta varchar(150) = 'No se encontraron colaboradores correspondientes a reingresos registrados el día de ayer.'
	


	-- CONFIGURACION DE PARAMETROS DEL CORREO 

	SELECT @destinatarios = valor, @asunto = descripcion 
	FROM Configuracion.parametros 
	WHERE parametro = 'AlrClbRein'

	/* VARIABLES PARA CREACION DE CSV */
	DECLARE @consulta varchar(max), @archivo varchar(max);

	-- Creacion de tablas temporales
	IF Object_id(N'tempdb..##tmp_reingresos_diarios_rango_fechas', N'U') IS NOT NULL
			DROP TABLE ##tmp_reingresos_diarios_rango_fechas

	IF Object_id(N'tempdb..##tmp_trabajadores_reingresos_diario', N'U') IS NOT NULL
			DROP TABLE ##tmp_trabajadores_reingresos_diario

	IF Object_id(N'tempdb..##tmp_alerta_reingresos_diario', N'U') IS NOT NULL
			DROP TABLE ##tmp_alerta_reingresos_diario

		CREATE TABLE ##tmp_trabajadores_reingresos_diario
		  (
			 repeticiones TINYINT,
			 CI			  CHAR(10)			
		  ) 

		CREATE TABLE ##tmp_reingresos_diarios_rango_fechas
		  (
			 CI			  CHAR(10)			
		  ) 

		CREATE TABLE ##tmp_alerta_reingresos_diario
		  (
			 trabajador				char(10),
			 nombre					varchar(650), 
			 Compania				char(4), 
			 Compania_Desc			varchar(450),
			 CCO					varchar(12),
			 Desc_CCO				varchar(150), 
			 Fecha_Antiguedad		date,
			 Fecha_ingreso			date,
			 Fecha_baja				date,
			 Descripcion_CausaBaja	varchar(350),
			 Nota_Baja				varchar(1800),
			 Motivo_Salida			varchar(250)
		  ) 

	-- Obtención de CI de trabajadores con fecha de ingreso o creacion en la base de datos el día anterior teniendo en consideración que alerta se debe envíar por día
	IF(@dia_Actual = 'LUNES')
		BEGIN
		-- La alerta verifica los reingresos de todo el mes 
			INSERT INTO ##tmp_reingresos_diarios_rango_fechas
			SELECT trabajador from RRHH.vw_datosTrabajadores
				-- La alerta debe tomar datos de los reingresos de ese mes
				WHERE Fecha_Ingreso BETWEEN DATEADD(DAY, 1, EOMONTH(@fecha_Actual, -1)) AND @fecha_Actual	-- RANGO DE FECHAS ESPECIFICADO 
		END
	ELSE
		-- La alerta verifica los reingresos del día anterior
		BEGIN 
			INSERT INTO ##tmp_reingresos_diarios_rango_fechas
				SELECT trabajador from RRHH.vw_datosTrabajadores
					WHERE (
						Trabajador IN (
							-- Consulta de CI de colaboradores creados el día anterior en la base de datos
									SELECT cedula_dni 
									FROM RRHH.Personas
									WHERE CONVERT(varchar(12), fecha_creacion, 103) = CONVERT(varchar(12), DATEADD(DAY, -1, GETDATE()), 103)
								)
						OR 
							-- En caso de que la fecha de creación este mal registrada, se toma la fecha de ingreso
							CONVERT(varchar(12), Fecha_Ingreso, 103) = CONVERT(varchar(12), DATEADD(DAY, -1, GETDATE()), 103)
					)
		END

	-- Obtención de CI de trabajadores de reingresos de la tabla general de trabajadores
	INSERT INTO ##tmp_trabajadores_reingresos_diario
		SELECT COUNT(1) AS n, Trabajador
		FROM  RRHH.vw_datosTrabajadores
		WHERE trabajador IN (Select CI FROM ##tmp_reingresos_diarios_rango_fechas) 
		GROUP BY Trabajador
		HAVING COUNT(1) > 1
		ORDER BY 1

	-- OBTENCION DE LOS DATOS 
	INSERT INTO ##tmp_alerta_reingresos_diario
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
		where G.trabajador in (Select CI from ##tmp_trabajadores_reingresos_diario)
			ORDER BY G.trabajador, G.Fecha_Ingreso DESC


	-- VERIFICACION DE CASOS PARA ENVIO POR CORREO 
			IF (SELECT COUNT(trabajador) FROM ##tmp_alerta_reingresos_diario) > 1
				-- SI SE ENCUENTRAN REGISTROS
					BEGIN TRY  

				-- Comprobacion para envio de mensaje de descripcion segun el día
					IF(@dia_Actual = 'LUNES')
						BEGIN
							SET @descripcionAlerta = 'Se adjuntan los colaboradores correspondientes a reingresos en este mes.'
						END
					ELSE
						BEGIN
							SET @descripcionAlerta = 'Se adjuntan los colaboradores correspondientes a reingresos de ayer.'
						END

				 -- ENVIO DE RESULTADOS POR CORREO 
							SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR REINGRESOS</h3>'
								+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
								+N'<h5><font color="SteelBlue">'+ @descripcionAlerta + '</h5>'
								+N'<br/><br />'
								+N' </body>' 
			
							SET @consulta = N'SELECT '''''''' + CONVERT(varchar(26), trabajador) as trabajador, nombre, '''''''' + CONVERT(varchar(26), compania) AS compania, 
												Compania_Desc AS descripcion_compania, '''''''' + CONVERT(varchar(26), CCO) AS CCO, Desc_CCO AS Datos_CCO, 
												CONVERT(varchar(12),Fecha_Antiguedad, 103) AS Fecha_Antiguedad, CONVERT(varchar(12),Fecha_ingreso, 103) AS Fecha_ingreso, 
												ISNULL(CONVERT(varchar(12),Fecha_baja, 103),''---'') AS Fecha_baja, 
												Descripcion_CausaBaja, Nota_Baja, Motivo_Salida
											  FROM ##tmp_alerta_reingresos_diario
											  ORDER BY nombre, convert(date, Fecha_ingreso) DESC';

							SET @archivo = N''+ convert(varchar(12),GETDATE(), 105) + ' - Reingresos.csv';
							-- SET @archivo = N'Reingresos.csv';

							/*		ENVIO DE CORREO GENERAL		*/
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
							VALUES ('A', 'Trabajadores', 'pa_colaboradores_reingresos', @asunto, @HTML, @destinatarios);
							EXEC msdb.dbo.sp_send_dbmail 
							@profile_name='Informacion_Nomina',
							@recipients= @destinatarios, 		
							-- @recipients= 'pasante.nominadosec@kfc.com.ec', 		 
							@subject = @asunto,
							@body = @HTML,
							@query = @consulta,
							@attach_query_result_as_file = 1,
							@query_attachment_filename = @archivo,
							--@importance = 'High',
							@query_result_separator = @tab,
							@query_result_header = 1,
							@query_result_no_padding = 1,
							@exclude_query_output = 1,
							@body_format = 'HTML' ; 
	 
				END TRY 
				BEGIN CATCH
					INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec' , NULL, @HTML, @asunto, 'Error al envíar correo')
				END CATCH
			ELSE
				BEGIN 
					-- EN CASO DE QUE NO HAYA REGISTROS
					-- Comprobacion para envio de mensaje de descripcion segun el día
						IF(@dia_Actual = 'LUNES')
							BEGIN
								SET @descripcionAlerta = 'No se encontraron colaboradores correspondientes a reingresos.'
							END
						ELSE
							BEGIN
								SET @descripcionAlerta = 'No se encontraron colaboradores correspondientes a reingresos registrados el día de ayer.'
							END

					SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR REINGRESOS</h3>'
								+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
								+N'<h5><font color="SteelBlue">'+ @descripcionAlerta + '</h5>'
								+N'<br/><br />'
								+N' </body>' 
			
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
							VALUES ('A', 'Trabajadores', 'pa_colaboradores_reingresos', @asunto, @HTML, 'pasante.nominadosec@kfc.com.ec');
							EXEC msdb.dbo.sp_send_dbmail 
								@profile_name='Informacion_Nomina',
								-- @recipients= 'pasante.nominadosec@kfc.com.ec', 	
								@recipients= @destinatarios, 
								@subject = @asunto,
								@body = @HTML,
								@body_format = 'HTML' ;  
				END


	-- Eliminación de tablas temporales
	IF Object_id(N'tempdb..##tmp_reingresos_diarios_rango_fechas', N'U') IS NOT NULL
			DROP TABLE ##tmp_reingresos_diarios_rango_fechas

	IF Object_id(N'tempdb..##tmp_trabajadores_reingresos_diario', N'U') IS NOT NULL
			DROP TABLE ##tmp_trabajadores_reingresos_diario

	IF Object_id(N'tempdb..##tmp_alerta_reingresos_diario', N'U') IS NOT NULL
			DROP TABLE ##tmp_alerta_reingresos_diario

END