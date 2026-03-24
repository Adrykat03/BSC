
/*

=============================================
  
Author: Steven Quispe
Create date: 28-11-2023
Description: Alerta para identificar (3 o más) permisos - dias libres consecutivos reportados en el marcaje

=============================================

*/
CREATE PROCEDURE [Avisos].[pa_permisosconsecutivos]
AS
BEGIN
	
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
	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'PrmDiaLib'

	SELECT @fi = FechaInicioNomina, @ff = FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(GETDATE())

	/* VARIABLES PARA CREACION DE CSV */
	DECLARE @consulta varchar(max), @archivo varchar(max);
	
	/* CREACION DE TABLAS TEMPORALES AUXILIARES */
	IF Object_id(N'tempdb..#tmp_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE #tmp_alerta_permisos_consecutivos

	IF Object_id(N'tempdb..##tmp_resultado_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE ##tmp_resultado_alerta_permisos_consecutivos 

	IF Object_id(N'tempdb..##tmp_mensaje_correo_permisos_consecutivos ', N'U') IS NOT NULL
		DROP TABLE ##tmp_mensaje_correo_permisos_consecutivos 

	IF Object_id(N'tempdb..##tmp_tabla_csv_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE ##tmp_tabla_csv_alerta_permisos_consecutivos

	IF Object_id(N'tempdb..##tmp_final_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE ##tmp_final_alerta_permisos_consecutivos

	IF Object_id(N'tempdb..##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista', N'U') IS NOT NULL
		DROP TABLE ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista

	CREATE TABLE #tmp_alerta_permisos_consecutivos
	  (
		 codigo          VARCHAR(26),
		 nombre          VARCHAR(650),
		 cco             VARCHAR(12),
		 tipo_contrato	 VARCHAR (50),
		 comentario      VARCHAR(250),
		 descripcion_cco	VARCHAR(250),
		 referencia_06   VARCHAR(max),
		 fecha				DATE,
		 fecha_anterior		DATE,
		 fecha_anterior_2	DATE,
		 fecha_siguiente	DATE,
		 fecha_siguiente_2	DATE,
		 id_periodoOpeDet smallint, -- Para agrupar dias libres
		 consecutividad  TINYINT,
		 clase_nomina		VARCHAR(6)
	  ) 

    CREATE TABLE ##tmp_resultado_alerta_permisos_consecutivos 
        (
           codigo_empleado VARCHAR(26),
           nombre          VARCHAR(650),
           cco             VARCHAR(12),
		   descripcion_cco	VARCHAR(250),
           tipo_contrato   VARCHAR(50),
           comentario	   VARCHAR(250),
		   referencia_06   VARCHAR(max),
           fecha           DATE, 
		   id_periodoOpeDet smallint, 
		   verificador_Parciales char(7),
		   clase_nomina		VARCHAR(6)
        )

	CREATE TABLE ##tmp_mensaje_correo_permisos_consecutivos 
        (
           codigo_empleado VARCHAR(26),
           nombre          VARCHAR(650),
           cco             VARCHAR(12),
		   descripcion_cco VARCHAR(250),
           tipo_contrato   VARCHAR(50),
           comentario	   VARCHAR(250),
		   referencia_06   VARCHAR(max),
		   fecha_inicial   DATE, 
		   fecha_final     DATE, 
		   id_periodoOpeDet smallint, 
		   verificador_Parciales char(7),
		   clase_nomina		VARCHAR(6)
        )

	CREATE TABLE ##tmp_tabla_csv_alerta_permisos_consecutivos
        (
           codigo_empleado VARCHAR(26),
           nombre          VARCHAR(650),
           cco             VARCHAR(12),
		   descripcion_cco	VARCHAR(250),
           tipo_contrato   VARCHAR(50),
           comentario	   VARCHAR(250),
		   referencia_06   VARCHAR(max),
		   fecha_inicial   DATE, 
		   fecha_final     DATE, 
		   verificador_Parciales char(7),
		   clase_nomina		VARCHAR(6)
        )

	CREATE TABLE ##tmp_final_alerta_permisos_consecutivos
        (
           codigo_empleado VARCHAR(26),
           nombre          VARCHAR(650),
           cco             VARCHAR(12),
		   descripcion_cco	VARCHAR(250),
           tipo_contrato   VARCHAR(50),
           comentario	   VARCHAR(250),
		   referencia_06   VARCHAR(max),
		   fecha_inicial   DATE, 
		   fecha_final     DATE, 
		   verificador_Parciales char(7),
		   clase_nomina		VARCHAR(6)
        )

	CREATE TABLE ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista
        (
           codigo_empleado VARCHAR(26),
           nombre          VARCHAR(650),
           cco             VARCHAR(12),
		   descripcion_cco	VARCHAR(250),
           tipo_contrato   VARCHAR(50),
           comentario	   VARCHAR(250),
		   referencia_06   VARCHAR(max),
		   fecha_inicial   DATE, 
		   fecha_final     DATE, 
		   verificador_Parciales char(7),
		   clase_nomina		VARCHAR(6),
		   clase_nomina_conf		VARCHAR(6),
		   analista			VARCHAR(1000),
        )

    /* -------------------------------------------------- */
    --- Seleccion de datos desde el marcaje (Permisos y días libres):
	;
	WITH cte_asociados (codigo, nombre,  desc_tipo_contrato)
           AS (SELECT codigo,
                      nombre,
                      desc_tipo_contrato 
               FROM rrhh.vw_datostrabajadores ),
           cte
           AS (SELECT 
                      a.codigo_emp_equipo,
                      a.comentario,
					  b.descripcion,
					  a.referencia_06,
                      a.fecha,
                      a.id_periodoOpeDet AS id_periodoOpeDet,
					  aso.nombre, 
					  aso.desc_tipo_contrato,
					  COALESCE(a.cco_trab, a.cco_marcaje) as cco,
					  LAG(a.fecha, 1) OVER (PARTITION BY a.codigo_emp_equipo ORDER BY a.fecha) AS fecha_anterior,
					  LAG(a.fecha, 2) OVER (PARTITION BY a.codigo_emp_equipo ORDER BY a.fecha) AS fecha_anterior_2,
					  LEAD(a.fecha, 1) OVER (PARTITION BY a.codigo_emp_equipo ORDER BY a.fecha) AS fecha_siguiente,
					  LEAD(a.fecha, 2) OVER (PARTITION BY a.codigo_emp_equipo ORDER BY a.fecha) AS fecha_siguiente_2,
					  b.clase_nomina
               FROM   asistencia.marcajes AS a WITH(NOLOCK)--- Tabla real (Producción)
                      INNER JOIN cte_asociados AS aso
                              ON a.codigo_emp_equipo = aso.codigo
                      JOIN catalogos.vw_cco b
                        ON COALESCE(a.cco_trab, a.cco_marcaje) = b.cco
						WHERE b.tipo != 'DP03'
						-- AND a.fecha BETWEEN '2023-10-15' AND  getdate()
						-- AND a.fecha BETWEEN @fi AND @ff
						AND a.fecha BETWEEN DATEADD(DAY,-7,@fi) AND  @ff  -- Se verifica hasta 7 días antes al corte actual
						AND comentario IN ('Dia Libre Confirmado', 'Día Libre Confirmado', 'PERMISO-DESDE HOSPITALIZACION-67780', 'Permiso')
              )

      INSERT INTO #tmp_alerta_permisos_consecutivos 
		SELECT 
			a.codigo_emp_equipo, 
			a.nombre, 
			a.cco,
			a.desc_tipo_contrato,
			a.comentario,
			a.descripcion,
			a.referencia_06,
			a.fecha,
			fecha_anterior,
			fecha_anterior_2, 
			fecha_siguiente,
			fecha_siguiente_2,
			a.id_periodoOpeDet,
			0,
			a.clase_nomina
		FROM cte a
		ORDER BY a.nombre ASC, a.fecha ASC;
		;

	/* COMPROBACION DE EXISTENCIA DE REGISTROS */
	IF( (SELECT Count(1)
			   FROM #tmp_alerta_permisos_consecutivos) > 0 )
			BEGIN

				-- ACTUALIZACIÓN DEL CAMPO CONSECUTIVIDAD A 1 CUANDO SE TIENEN REGISTROS EN DIAS CONTINUOS
				UPDATE #tmp_alerta_permisos_consecutivos
				SET    consecutividad = 1
				FROM   #tmp_alerta_permisos_consecutivos 
				WHERE ( fecha_siguiente = Dateadd(day, 1, fecha)				-- Si es un día intermedio
							AND fecha_anterior = Dateadd(day, -1, fecha)
					   )OR
					   ( fecha_siguiente = Dateadd(day, 1, fecha)				 -- Si es el primer día
							AND fecha_siguiente_2 = Dateadd(day, 2, fecha)
					   )OR 
					   ( fecha_anterior = Dateadd(day, -1, fecha)				 -- Si es el último día
							AND fecha_anterior_2 = Dateadd(day, -2, fecha) 
					   )

				-- SELECCIÓN DE RESULTADOS (3 O MÁS DIAS DE ENFERMEDAD - 3 O MÁS DÍAS LIBRES CONSECUTIVOS)
				;
				WITH PartitionedData AS (
				  SELECT
					*,
					ROW_NUMBER() OVER (PARTITION BY codigo ORDER BY fecha)  -
					ROW_NUMBER() OVER (PARTITION BY codigo, consecutividad ORDER BY fecha) AS grp
				  FROM #tmp_alerta_permisos_consecutivos
				)

				INSERT INTO ##tmp_resultado_alerta_permisos_consecutivos (codigo_empleado, nombre, cco, descripcion_cco,tipo_contrato, comentario, referencia_06, fecha, id_periodoOpeDet, verificador_Parciales, clase_nomina)
				SELECT
				  codigo,
				  nombre,
				  cco,
				  descripcion_cco,
				  tipo_contrato,
				  comentario,
				  referencia_06,
				  fecha, 
				  id_periodoOpeDet,
				  ' ',
				  clase_nomina
				FROM (
				  SELECT
					*,
					COUNT(*) OVER (PARTITION BY codigo, grp) AS consecutive_ones_count
				  FROM PartitionedData
				  WHERE consecutividad = 1
				) AS Subquery
				WHERE consecutive_ones_count > 3  
				;

				-- Campo agregado para contratos parciales
				UPDATE ##tmp_resultado_alerta_permisos_consecutivos
				SET   verificador_Parciales = 'Parcial'
				WHERE tipo_contrato IN (
					'TIEMPO PARCIAL PASANTE',
					'TIEMPO PARCIAL A PRUEBA 30',
					'TIEMPO PARCIAL A PRUEBA',
					'PARCIAL JUVENIL A PRUEBA',
					'PARCIAL', 
					'TIEMPO PARCIAL INDEFINIDO', 
					'TIEMPO PARCIAL INDEFINIDO 30', 
					'TIEMPO PARCIAL FIJO', 
					'TIEMPO PARCIAL EVENTUAL',
					'TIEMPO PARCIAL'
				) 

				-- INSERCIÓN DE DATOS PARA ENVIO POR CORREO
				-- 1.- Días libres agrupados por fechas 
				INSERT INTO ##tmp_mensaje_correo_permisos_consecutivos      
					SELECT
						codigo_empleado,
						nombre,
						cco,
						descripcion_cco,
						tipo_contrato,
						comentario,
						referencia_06,
						fecha,
						fecha,
						id_periodoOpeDet,
						verificador_Parciales,
						clase_nomina
					FROM  ##tmp_resultado_alerta_permisos_consecutivos
					WHERE comentario IN ('Dia Libre Confirmado', 'Día Libre Confirmado', 'PERMISO-DESDE HOSPITALIZACION-67780', 'Permiso')

				-- Agrupacion por dias consecutivos e igual comentario 
					;
					WITH CommentGroups AS (
						SELECT *,
							   ROW_NUMBER() OVER (PARTITION BY codigo_empleado ORDER BY fecha_inicial) -
							   ROW_NUMBER() OVER (PARTITION BY codigo_empleado, comentario ORDER BY fecha_inicial) AS grp
						FROM ##tmp_mensaje_correo_permisos_consecutivos
					),
					GroupedDates AS (
						SELECT codigo_empleado,
							   nombre,
							   cco,
							   descripcion_cco,
							   tipo_contrato,
							   comentario,
							   referencia_06,
							   MIN(fecha_inicial) AS fecha_inicial,
							   MAX(fecha_final) AS fecha_final,
							   verificador_Parciales,
							   clase_nomina
						FROM CommentGroups
						GROUP BY codigo_empleado, nombre, cco, descripcion_cco, tipo_contrato, comentario, referencia_06, grp, verificador_Parciales, clase_nomina
					)
					INSERT INTO ##tmp_tabla_csv_alerta_permisos_consecutivos
						SELECT codigo_empleado, nombre, cco, descripcion_cco, tipo_contrato, comentario, referencia_06, fecha_inicial, fecha_final, verificador_Parciales, clase_nomina
						FROM GroupedDates
						ORDER BY nombre, fecha_inicial;
					;

					-- TABLA DE ALERTAS ENCONTRADAS
					INSERT INTO ##tmp_final_alerta_permisos_consecutivos
						SELECT *
						FROM ##tmp_tabla_csv_alerta_permisos_consecutivos 
										  WHERE  nombre IN (
													SELECT DISTINCT nombre
														FROM ##tmp_tabla_csv_alerta_permisos_consecutivos
														WHERE comentario IN ('Dia Libre Confirmado', 'Día Libre Confirmado', 'PERMISO-DESDE HOSPITALIZACION-67780', 'Permiso')
												)
												AND codigo_empleado IN (
													SELECT codigo_empleado
														FROM ##tmp_tabla_csv_alerta_permisos_consecutivos
														GROUP BY codigo_empleado
														HAVING COUNT(*) > 2
												)
											ORDER BY nombre ASC, fecha_inicial ASC;

				-- VERIFICACIÓN DE EXISTENCIA DE ALERTAS ENCONTRADAS
				IF (SELECT COUNT(1) FROM ##tmp_final_alerta_permisos_consecutivos) > 0 
					BEGIN TRY
/*table {
  width: 100%;
  border-collapse: collapse; /* Para evitar espacio entre celdas */
}

td {
  padding-left: 10px; /* Espacio mínimo a la izquierda */
  padding-right: 10px; /* Espacio mínimo a la derecha */
  padding-top: 5px; /* Espacio en la parte superior */
  padding-bottom: 5px; /* Espacio en la parte inferior */
  border: 1px solid #ccc; /* Bordes de las celdas */
}*/
						-- ENVIO DE RESULTADOS POR CORREO 
						SELECT @HTML = N'<style type="text/css">
												.box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
												.box-table th { font-size: 11px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
												.box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; padding-left: 5px; padding-right: 5px; padding-top: 2px; padding-bottom: 2px; } 
										</style>'+
							N'<body><h3><font color="SteelBlue">ALERTA POR AUSENTISMO</h3>'
							+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<h5><font color="SteelBlue">Se adjuntan las alertas encontradas por permisos - días libres consecutivos reportados en el marcaje.</h5>'
							--+N'<br/><br />'
							+N'<br/>'
							
			/*
						SET @consulta = N'SELECT '''''''' + CONVERT(varchar(26), codigo_empleado) as codigo_empleado, nombre, '''''''' + CONVERT(varchar(26), cco) AS cco, descripcion_cco AS descripcion_local,
											tipo_contrato, comentario AS Tipo_Ausencia, CONVERT(varchar(12),fecha_inicial, 103) AS fecha_inicio, 
											CONVERT(varchar(12),fecha_final, 103) AS fecha_fin, verificador_Parciales
										  FROM ##tmp_final_alerta_permisos_consecutivos
										  ORDER BY nombre, fecha_inicial';
*/
/*										SELECT '''''''' + CONVERT(varchar(26), codigo_empleado) as codigo_empleado, nombre, '''''''' + CONVERT(varchar(26), cco) AS cco, descripcion_cco AS descripcion_local,
											tipo_contrato, comentario AS Tipo_Ausencia, CONVERT(varchar(12),fecha_inicial, 103) AS fecha_inicio, 
											CONVERT(varchar(12),fecha_final, 103) AS fecha_fin, verificador_Parciales
										  FROM ##tmp_final_alerta_permisos_consecutivos
										  ORDER BY nombre, fecha_inicial
*/	

							+N'<table class="box-table" >' 
							+N' <tr>'
							+N' <th style="text-align:center"> Cod Empleado</th>'
							+N' <th style="text-align:center"> Nombre</th>'
							+N' <th style="text-align:center"> CCO</th>'
							+N' <th style="text-align:center"> Descripción Local</th>'
  							+N' <th style="text-align:center"> Tipo Contrato</th>'
							+N' <th style="text-align:center"> Tipo Ausencia</th>'
							+N' <th style="text-align:center"> Fecha Inicio</th>'
							+N' <th style="text-align:center"> Fecha Fin</th>'
							+N' <th style="text-align:center"> Verificado Parciales</th>'
							+cast( (SELECT	td = CONVERT(varchar(26), codigo_empleado), '', 
											td = nombre, '', 
											td = CONVERT(varchar(26), cco), '', 
											td = descripcion_cco, '',
											td = tipo_contrato, '', 
											td = comentario, '', 
											td = CONVERT(varchar(12),fecha_inicial, 103), '', 
											td = CONVERT(varchar(12),fecha_final, 103), '', 
											td = verificador_Parciales, ''
										  FROM ##tmp_final_alerta_permisos_consecutivos
										  ORDER BY nombre, fecha_inicial
							FOR XML PATH('tr'),TYPE
							) as varchar(max))+
								N'</table>'+
								--N' <br/></body>'  ;
							+N'<br/>'
							+N' </body>'; 

						--SET @archivo = N''+ convert(varchar(12),GETDATE(), 105) + ' - PermisosDiasLibresConsecutivos.csv';
						---- SET @archivo = N'PermisosDiasLibres.csv';


						--/*		ENVIO DE CORREO GENERAL		*/
						-- INSERT notificación consolidada
						INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
						VALUES ('A', 'Ausencias', 'pa_permisosconsecutivos', @asunto, @HTML, @destinatarios, @fi, @ff);
						EXEC msdb.dbo.sp_send_dbmail 
						@profile_name='Informacion_Nomina',
						@recipients= @destinatarios, 		
					 	@subject = @asunto,
						@body = @HTML,
						--@query = @consulta,
						--@attach_query_result_as_file = 1,
						--@query_attachment_filename = @archivo,
						----@importance = 'High',
						@query_result_separator = @tab,
						@query_result_header = 1,
						@query_result_no_padding = 1,
						@exclude_query_output = 1,
						@body_format = 'HTML' ; 

						/*		 CURSOR PARA ENVIO DE CORREOS PARA CADA ANALISTA DE NOMINA SEGÚN EL CAMPO CLASE_NOMINA				*/
						DECLARE @Correo_Clase_Nomina AS TABLE (clase_nomina VARCHAR(6), analista VARCHAR(1000))

						-- Creacion tabla auxiliar para verificar el correo de cada analista de nomina
						INSERT INTO @Correo_Clase_Nomina (clase_nomina, analista) SELECT CV.clase_nomina, Configuracion.fn_correosVariosRemitentesContactoTiendas (CV.clase_nomina)
						FROM Asistencia.transferencias t 
						INNER JOIN RRHH.vw_datosTrabajadores dt ON t.codigo = dt.Codigo
						INNER JOIN Catalogos.VW_CCO cv ON t.cco_origen = cv.cco and cv.clase_nomina = dt.Clase_Nomina
						GROUP BY CV.clase_nomina
						
						DECLARE @clase_nomina VARCHAR(6), @ANALISTA VARCHAR(1000), @w int

						DECLARE CURSOR4 CURSOR LOCAL FOR SELECT clase_nomina, analista FROM @Correo_Clase_Nomina ORDER BY clase_nomina
							
						OPEN CURSOR4
						FETCH CURSOR4 INTO  @clase_nomina, @ANALISTA
							WHILE(@@FETCH_STATUS=0)
							BEGIN
								SELECT @w = COUNT(1)
								FROM @Correo_Clase_Nomina cn
								INNER JOIN ##tmp_final_alerta_permisos_consecutivos t1 
									ON cn.clase_nomina = t1.clase_nomina

								IF @w > 0
									BEGIN TRY
										-- Insercion de datos en una tabla temporal para cada analista
										INSERT INTO ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista 
											SELECT *
											FROM ##tmp_final_alerta_permisos_consecutivos e 
												INNER JOIN @Correo_Clase_Nomina cn ON cn.clase_nomina = e.clase_nomina
												WHERE e.clase_nomina = @clase_nomina 
												ORDER BY nombre, fecha_inicial

										-- Comprobación de existencia de datos
										IF (SELECT COUNT(codigo_empleado) FROM ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista) > 1
											BEGIN
												--  ENVIO DE RESULTADOS POR CORREO 
												SELECT @HTML = N'<style type="text/css">
																	.box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
																	.box-table th { font-size: 11px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
																	.box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; padding-left: 5px; padding-right: 5px; padding-top: 2px; padding-bottom: 2px; } 
															</style>'+
													N'<body><h3><font color="SteelBlue">ALERTA POR AUSENTISMO</h3>'
													+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
													+N'<h5><font color="SteelBlue">Se adjuntan las alertas encontradas por permisos - días libres consecutivos reportados en el marcaje.</h5>'
													--+N'<br/><br />'
													+N'<br/>'
													 
/*			
												SET @consulta = N'SELECT '''''''' + CONVERT(varchar(26), codigo_empleado) as codigo_empleado, nombre, '''''''' + CONVERT(varchar(26), cco) AS cco, descripcion_cco AS descripcion_local,
																	tipo_contrato, comentario AS Tipo_Ausencia, CONVERT(varchar(12),fecha_inicial, 103) AS fecha_inicio, 
																	CONVERT(varchar(12),fecha_final, 103) AS fecha_fin, verificador_Parciales
																	FROM ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista
																	ORDER BY nombre, fecha_inicial';		
*/

												+N'<table class="box-table" >' 
												+N' <tr>'
												+N' <th style="text-align:center"> Cod Empleado</th>'
												+N' <th style="text-align:center"> Nombre</th>'
												+N' <th style="text-align:center"> CCO</th>'
												+N' <th style="text-align:center"> Descripción Local</th>'
  												+N' <th style="text-align:center"> Tipo Contrato</th>'
												+N' <th style="text-align:center"> Tipo Ausencia</th>'
												+N' <th style="text-align:center"> Fecha Inicio</th>'
												+N' <th style="text-align:center"> Fecha Fin</th>'
												+N' <th style="text-align:center"> Verificado Parciales</th>'
												+cast( (SELECT	td = CONVERT(varchar(26), codigo_empleado), '', 
																td = nombre, '', 
																td = CONVERT(varchar(26), cco), '', 
																td = descripcion_cco, '',
																td = tipo_contrato, '', 
																td = comentario, '', 
																td = CONVERT(varchar(12),fecha_inicial, 103), '', 
																td = CONVERT(varchar(12),fecha_final, 103), '', 
																td = verificador_Parciales, ''
															  FROM ##tmp_final_alerta_permisos_consecutivos
															  ORDER BY nombre, fecha_inicial
												FOR XML PATH('tr'),TYPE
												) as varchar(max))+
													N'</table>'+
													--N' <br/></body>'  ;
												+N'<br/>'
												+N' </body>'; 


												--SET @archivo = N''+ convert(varchar(12),GETDATE(), 105) + ' - PermisosDiasLibresConsecutivos.csv';
												---- SET @archivo = N'PermisosDiasLibres.csv';

												-- INSERT notificación consolidada
												INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
												VALUES ('A', 'Ausencias', 'pa_permisosconsecutivos', @asunto, @HTML, @w, @ANALISTA, @fi, @ff);
												EXEC msdb.dbo.sp_send_dbmail 
												@profile_name='Informacion_Nomina',
												 @recipients = @ANALISTA,
												@subject = @asunto,
												@body = @HTML,
												--@query = @consulta,
												--@attach_query_result_as_file = 1,
												--@query_attachment_filename = @archivo,
												----@importance = 'High',
												@query_result_separator = @tab,
												@query_result_header = 1,
												@query_result_no_padding = 1,
												@exclude_query_output = 1,
												@body_format = 'HTML' ; 

												-- Se borra el contenido de la tabla para el anterior analista
												DELETE FROM ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista
											END
										ELSE
											BEGIN 
												-- Se borra el contenido de la tabla para el anterior analista
												DELETE FROM ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista
											END
									END TRY 
									BEGIN CATCH
										INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec;' , NULL, @html, 'Alerta - Permisos, días libres consecutivos', 'Error al envíar correo a analistas')
									END CATCH
								FETCH CURSOR4 INTO @clase_nomina, @ANALISTA
							END
						CLOSE CURSOR4
						DEALLOCATE CURSOR4

					END TRY 
					BEGIN CATCH
						INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec;' , NULL, @html, 'Alerta - Permisos, días libres consecutivos', 'Error al envíar correo')
					END CATCH
				ELSE
					BEGIN 
						SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR AUSENTISMO</h3>'
							+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<h5><font color="SteelBlue">No se encontraron alertas por permisos - días libres consecutivos reportados en el marcaje.</h5>'
							+N'<br/><br />'
							+N' </body>' 

							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
							VALUES ('A', 'Ausencias', 'pa_permisosconsecutivos', @asunto, @HTML, @w, @destinatarios, @fi, @ff);
							EXEC msdb.dbo.sp_send_dbmail 
							@profile_name='Informacion_Nomina',
						 	@recipients= @destinatarios, 
							@subject = @asunto,
							@body = @HTML,
							@body_format = 'HTML' ;  
					END
		END 
	ELSE
		BEGIN
			-- Si no se encontró nada en el marcaje
			SELECT @HTML = N'<body><h3><font color="SteelBlue">ALERTA POR AUSENTISMO</h3>'
							+N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<h5><font color="SteelBlue">No se encontraron alertas por permisos - días libres consecutivos reportados en el marcaje.</h5>'
							+N'<br/><br />'
							+N' </body>' 

						-- INSERT notificación consolidada
						INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
						VALUES ('A', 'Ausencias', 'pa_permisosconsecutivos', @asunto, @HTML, @w, 'pasante.nominadosec@kfc.com.ec', @fi, @ff);
						EXEC msdb.dbo.sp_send_dbmail 
							@profile_name='Informacion_Nomina',
							-- @recipients= 'pasante.nominadosec@kfc.com.ec', 	
							@recipients= @destinatarios, 
							@subject = @asunto,
							@body = @HTML,
							@body_format = 'HTML' ;  
		END
			
	-- Eliminacion tablas temporales
	IF Object_id(N'tempdb..#tmp_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE #tmp_alerta_permisos_consecutivos

	IF Object_id(N'tempdb..##tmp_resultado_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE ##tmp_resultado_alerta_permisos_consecutivos 

	IF Object_id(N'tempdb..##tmp_mensaje_correo_permisos_consecutivos ', N'U') IS NOT NULL
		DROP TABLE ##tmp_mensaje_correo_permisos_consecutivos 

	IF Object_id(N'tempdb..##tmp_tabla_csv_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE ##tmp_tabla_csv_alerta_permisos_consecutivos

	IF Object_id(N'tempdb..##tmp_final_alerta_permisos_consecutivos', N'U') IS NOT NULL
		DROP TABLE ##tmp_final_alerta_permisos_consecutivos

	IF Object_id(N'tempdb..##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista', N'U') IS NOT NULL
		DROP TABLE ##tmp_tabla_csv_alerta_permisos_consecutivos_por_analista

END