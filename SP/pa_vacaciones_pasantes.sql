
/*

=============================================
  
Author: Steven Quispe
Create date: 15-12-2023
Description: Alerta para identificar colaboradores (con relación laboral P) que tienen creado un ciclo de vacaciones

=============================================
Editor: Steven Quispe
Edition date: 11-01-2024
Description: Se modifica el filtro de fechas para comparar los ingresos con el valor de la creación del colaborador en la base de datos

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_vacaciones_pasantes]
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
		@destinatarios varchar(max)

	-- CONFIGURACION DE PARAMETROS DEL CORREO 

	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AlrVacPas'

	/* VARIABLES PARA CREACION DE CSV */
	DECLARE @consulta varchar(max), @archivo varchar(max);


	/*		CREACION DE TABLAS TEMPORALES */
	IF Object_id(N'tempdb..#tmp_alerta_vacaciones_pasantes', N'U') IS NOT NULL
			DROP TABLE #tmp_alerta_vacaciones_pasantes

	IF Object_id(N'tempdb..#tmp_alerta_vacaciones_registradas_pasantes', N'U') IS NOT NULL
			DROP TABLE #tmp_alerta_vacaciones_registradas_pasantes

	IF Object_id(N'tempdb..##tmp_csv_alerta_vacaciones_pasantes', N'U') IS NOT NULL
			DROP TABLE ##tmp_csv_alerta_vacaciones_pasantes

	CREATE TABLE #tmp_alerta_vacaciones_pasantes
		  (
			 Codigo			char(26),
			 Trabajador		char(10), 
			 Nombre			varchar(650), 
			 Compania		char(4),
			 Compania_Desc	varchar(450),
			 CCO			varchar(12), 
			 Desc_CCO		varchar(150),
			 Fecha_Ingreso	smalldatetime,
			 Fecha_baja		smalldatetime
		  ) 

	CREATE TABLE #tmp_alerta_vacaciones_registradas_pasantes
		  (
			 Trabajador		char(10), 
		  ) 

	CREATE TABLE ##tmp_csv_alerta_vacaciones_pasantes
		  (
			 Codigo			char(26),
			 Trabajador		char(10), 
			 Nombre			varchar(650), 
			 Compania		char(4),
			 Compania_Desc	varchar(450),
			 CCO			varchar(12), 
			 Desc_CCO		varchar(150),
			 Fecha_Ingreso	smalldatetime,
			 Fecha_baja		smalldatetime
		  ) 

 	-- Obtención de CI de trabajadores con tipo de contrato P (QUE SE INGRESARON EL DÍA ANTERIOR) 
	INSERT INTO #tmp_alerta_vacaciones_pasantes
		SELECT Codigo, Trabajador, Nombre, Compania, Compania_Desc, CCO, Desc_CCO, Fecha_Ingreso, Fecha_baja from RRHH.vw_datosTrabajadores
		WHERE Tipo_Contrato = 'P'
		AND (
				Trabajador IN (
					-- Consulta de CI de colaboradores ingresados el día anterior a la base de datos
							SELECT cedula_dni 
							FROM RRHH.Personas
							WHERE CONVERT(varchar(12), fecha_creacion, 103) = CONVERT(varchar(12), DATEADD(DAY, -1, GETDATE()), 103)
						)
				OR 
					-- En caso de que la fecha de creación este mal registrada
					CONVERT(varchar(12), Fecha_Ingreso, 103) = CONVERT(varchar(12), DATEADD(DAY, -1, GETDATE()), 103)
			)
		AND Situacion =  'Activo'


	-- VERIFICACION DSE PASANTES CON CABECERA DE VACACIONES REGISTRADAS
	INSERT INTO #tmp_alerta_vacaciones_registradas_pasantes
		SELECT Trabajador FROM Adam.dbo.saldos_vacaciones
		WHERE trabajador IN (
			-- Obtención de CI de trabajadores con tipo de contrato P e ingreso en el rango de fechas especificado
			SELECT Trabajador FROM #tmp_alerta_vacaciones_pasantes
		)

	-- Creacion tabla de alerta
	INSERT INTO ##tmp_csv_alerta_vacaciones_pasantes
		SELECT * FROM #tmp_alerta_vacaciones_pasantes
		WHERE Trabajador IN (SELECT Trabajador FROM #tmp_alerta_vacaciones_registradas_pasantes)

	/*	ENVIO DE CORREO ELECTRONICO  */
	IF (SELECT COUNT(Trabajador) FROM ##tmp_csv_alerta_vacaciones_pasantes) > 1
			
				-- SI SE ENCUENTRAN REGISTROS
				BEGIN TRY  

				 -- ENVIO DE RESULTADOS POR CORREO 
							SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR PASANTES CON CICLO DE VACACIONES CREADO</h3>'
								+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
								+N'<h5><font color="SteelBlue">Se adjuntan los colaboradores con relación laboral P (Pasante) que tienen un ciclo de vacaciones creado.</h5>'
								+N'<br/><br />'
								+N' </body>' 
			
							SET @consulta = N'SELECT '''''''' + CONVERT(varchar(26), Codigo) as Codigo_empl, '''''''' + CONVERT(varchar(26), Trabajador) as trabajador, Nombre, 
												'''''''' + CONVERT(varchar(26), Compania) AS compania, Compania_Desc AS descripcion_compania,
												CCO, Desc_CCO AS Datos_CCO, CONVERT(varchar(12),Fecha_Ingreso, 103) AS Fecha_ingreso
											  FROM ##tmp_csv_alerta_vacaciones_pasantes
											  ORDER BY Nombre';

							SET @archivo = N''+ convert(varchar(12),GETDATE(), 105) + ' - VacacionesPasantes.csv';
							-- SET @archivo = N'VacacionesPasantes.csv';


							--/*		ENVIO DE CORREO GENERAL		*/
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
							VALUES ('A', 'Vacaciones', 'pa_vacaciones_pasantes', @asunto, @HTML, @destinatarios);
							EXEC msdb.dbo.sp_send_dbmail 
							@profile_name='Informacion_Nomina',
							@recipients= @destinatarios, 		
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
				-- EN CASO DE QUE NO HAYA REGISTROS
				BEGIN 
					SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR PASANTES CON CICLO DE VACACIONES CREADO</h3>'
								+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
								+N'<h5><font color="SteelBlue">No se encontraron ciclos de vacaciones creados para colaboradores con relación laboral P (Pasante) que se ingresaron el día de ayer.</h5>'
								+N'<br/><br />'
								+N' </body>' 
			
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
							VALUES ('A', 'Vacaciones', 'pa_vacaciones_pasantes', @asunto, @HTML, @destinatarios);
							EXEC msdb.dbo.sp_send_dbmail 
								@profile_name='Informacion_Nomina',
								@recipients= @destinatarios, 
								@subject = @asunto,
								@body = @HTML,
								@body_format = 'HTML' ;  
				END


		/*		ELIMINACION TABLAS TEMPORALES */
		IF Object_id(N'tempdb..#tmp_alerta_vacaciones_pasantes', N'U') IS NOT NULL
			DROP TABLE #tmp_alerta_vacaciones_pasantes

		IF Object_id(N'tempdb..#tmp_alerta_vacaciones_registradas_pasantes', N'U') IS NOT NULL
				DROP TABLE #tmp_alerta_vacaciones_registradas_pasantes

		IF Object_id(N'tempdb..##tmp_csv_alerta_vacaciones_pasantes', N'U') IS NOT NULL
				DROP TABLE ##tmp_csv_alerta_vacaciones_pasantes

END