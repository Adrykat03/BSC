-- =============================================
-- Author:		Mateo Alvear
-- Create date: 09-11-2022
-- Description:	Se revisan las faltas no justificadas en los marcajes, si hay algún llamado de atención 5 días antes o 5 días después de esta para verificar que no sea una doble sanción
-- =============================================
-- =============================================
-- Author:		Mateo Alvear
-- Create date: 15-12-2022
-- Description: Se agrega el correo de notificacion cuando no se encontraron errores.
-- =============================================
-- =============================================
-- Author:		Mateo Alvear
-- Create date: 15-12-2022
-- Description: Se quitan trabajadores con baja
-- =============================================
CREATE PROCEDURE [Avisos].[pa_fnjMarcaje]
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @fi date, @ff date, @asunto varchar(250), @destinatarios varchar(max)

	SELECT @fi = FechaInicioNomina, @ff = FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(GETDATE())

	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
			DROP TABLE #tmp_errores

	SELECT m.codigo_emp_equipo, m.fecha, m.aux07, CONVERT(VARCHAR(25),m.comentario) COMENTARIO,
	CONVERT(VARCHAR(max),s.amonestacion) AMONESTACION, s.fecha_emision, s.fecha_legalización, s.estado, s.tipo_sancion,
	dt.Clase_Nomina
	INTO #tmp_errores
	FROM Asistencia.marcajes m WITH(NOLOCK)
  --INNER JOIN Sanciones.sanciones_trab s WITH(NOLOCK) ON m.codigo_emp_equipo = s.codigo AND m.fecha BETWEEN DATEADD(DAY, -4, s.fecha_emision) AND DATEADD(DAY, 4, s.fecha_emision)
    INNER JOIN Sanciones.sanciones_trab s WITH(NOLOCK) ON m.codigo_emp_equipo = s.codigo AND m.fecha = s.fecha_emision
	INNER JOIN RRHH.vw_datosTrabajadores dt ON m.codigo_emp_equipo = dt.Codigo AND dt.Situacion = 'Activo' AND dt.Fecha_bajaIndice IS NULL
	WHERE ((m.aux07 = 'FNJ' OR m.comentario LIKE '%Falta%')	AND s.tipo_sancion = 'Pecunaria' AND s.estado IN(1,3)) 
	AND m.fecha BETWEEN @fi AND @ff
	ORDER BY m.codigo_emp_equipo,m.fecha

	INSERT INTO #tmp_errores
	SELECT m.codigo_emp_equipo, m.fecha, m.aux07, CONVERT(VARCHAR(25),m.comentario) COMENTARIO,
	CONVERT(VARCHAR(max),s.amonestacion) AMONESTACION, s.fecha_emision, s.fecha_legalización, s.estado, s.tipo_sancion,
	dt.Clase_Nomina
	FROM Asistencia.marcajes m WITH(NOLOCK)
	INNER JOIN Sanciones.sanciones_trab s WITH(NOLOCK) ON m.codigo_emp_equipo = s.codigo AND m.fecha = s.fecha_emision
	INNER JOIN RRHH.vw_datosTrabajadores dt ON m.codigo_emp_equipo = dt.Codigo AND dt.Situacion = 'Activo' AND dt.Fecha_bajaIndice IS NULL
	WHERE ((m.comentario IN('Ausencia','Vacaciones','Vacacion')) AND s.tipo_sancion = 'Pecunaria' AND s.estado IN(1,3)) 
	AND m.fecha BETWEEN @fi AND @ff
	ORDER BY m.codigo_emp_equipo,m.fecha

	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_FNJ_LLAT'
			
	DECLARE @html varchar(max)
	IF (SELECT COUNT(1) FROM #tmp_errores) > 0
	BEGIN
		SELECT @HTML = N'<style type="text/css">
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
						.motivo {
							width: 350px;
							min-width: 350px;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
					</style>'
					+	
					N'<body><H4><font color="SteelBlue">VALIDAR LLAMADOS DE ATENCIÓN</H4>' +
					N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
					N'<H4><font color="SteelBlue">Trabajadores con llamados de atención en fechas con falta no justificada vacación o ausencia.</H4>'+
					N'<br/><br/>'+
					N'<table id="box-table">'+
					N'<th>CÓDIGO</th>'+
					N'<th>NOMBRE</th>'+
					N'<th>COMPAÑIA</th>'+
					N'<th>CCO</th>'+
					N'<th>DESC. CCO</th>'+
					N'<th>FECHA LLAT</th>'+
					N'<th class="motivo">MOTIVO LLAT</th>'+
					N'<th>FECHA LEGALIZACIÓN</th>'+
					N'<th>TIPO SANCIÓN</th>'+
					N'<th>FECHA MARCAJE</th>'+
					N'<th>MOTIVO JUSTIF MARCAJE</th>'+
					N'</tr>'+
					CAST(
						(SELECT DISTINCT
							td = e.codigo_emp_equipo, '',
							td = dt.Nombre, '',
							td = dt.Compania, '',
							td = dt.CCO, '',
							td = dt.Desc_CCO, '',
							td = ISNULL(CONVERT(VARCHAR(20),e.fecha_emision, 105),'-'), '',
							td = e.amonestacion, '',
							td = ISNULL(CONVERT(VARCHAR(20),e.fecha_legalización, 105), '-'), '',
							td = e.tipo_sancion, '',
							td = ISNULL(CONVERT(VARCHAR(20),e.fecha, 105), '-'), '',
							td = e.COMENTARIO, ''
						FROM #tmp_errores e INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo_emp_equipo ORDER BY e.codigo_emp_equipo
						FOR XML PATH('tr'), TYPE) AS varchar(max)) +
					N'</table>' +
					N'<br/><br /></body>'
	END
	IF (SELECT COUNT(1) FROM #tmp_errores) = 0
	BEGIN
		SELECT @HTML = N'<style type="text/css">
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
						.motivo {
							width: 350px;
							min-width: 350px;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
					</style>'
					+	
					N'<body><H4><font color="SteelBlue">VALIDAR LLAMADOS DE ATENCIÓN</H4>' +
					N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
					N'<H4><font color="SteelBlue">Trabajadores con llamados de atención en fechas con falta no justificada vacación o ausencia.</H4>'+
					N'<br/><br/> <h3>No se encontraron llamados de atención con FNJ</h3>'+
					N'<br/><br /></body>'
	END
	SELECT @html
	-- INSERT notificación consolidada
	INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
	VALUES ('A', 'Marcajes', 'pa_fnjMarcaje', @asunto, @HTML, @destinatarios, @fi, @ff);
	EXEC msdb.dbo.Sp_send_dbmail
	@profile_name = 'Informacion_Nomina',
	@Subject = @asunto,
	@recipients = @destinatarios,
	@body_format= 'html',
	@body = @HTML

	DECLARE @Correo_Clase_Nomina AS TABLE (clase_nomina VARCHAR(6), analista VARCHAR(1000))

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
		INNER JOIN #tmp_errores t1 ON cn.clase_nomina = t1.clase_nomina
		WHERE cn.clase_nomina = @clase_nomina
		and cn.clase_nomina = t1.clase_nomina
		IF @w > 0
		BEGIN
			SELECT @HTML = N'<style type="text/css">
					#box-table
					{
						font-family: "Calibri";
						font-size: 10px;
						text-align: center;
						border-collapse: collapse;
						border-top: 7px solid #9baff1;
						border-bottom: 7px solid #9baff1;
					}
					#box-table th
					{
						font-size: 11px;
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
						/*padding: 15px;*/
									padding-top: 2px;
									padding-bottom: 2px;
									padding-left: 4px;
									padding-right: 4px;
						color: #669;
					}
					tr:nth-child(odd)	{ background-color:#eee; }
					tr:nth-child(even)	{ background-color:#fff; }	
				</style>'+		
				N'<body><H4><font color="SteelBlue">VALIDAR LLAMADOS DE ATENCIÓN</H4>' +
				N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
				N'<H4><font color="SteelBlue">Trabajadores con llamados de atención en fechas con falta no justificada vacación o ausencia.</H4>'+
				N'<br/><br/>'+
				N'<table id="box-table">'+
				N'<th>CÓDIGO</th>'+
				N'<th>NOMBRE</th>'+
				N'<th>COMPAÑIA</th>'+
				N'<th>CCO</th>'+
				N'<th>DESC. CCO</th>'+
				N'<th>FECHA LLAT</th>'+
				N'<th class="motivo">MOTIVO LLAT</th>'+
				N'<th>FECHA LEGALIZACIÓN</th>'+
				N'<th>TIPO SANCIÓN</th>'+
				N'<th>FECHA MARCAJE</th>'+
				N'<th>MOTIVO JUSTIF MARCAJE</th>'+
				N'</tr>'+
				CAST(
					(SELECT 
						td = e.codigo_emp_equipo, '',
						td = dt.Nombre, '',
						td = dt.Compania, '',
						td = dt.CCO, '',
						td = dt.Desc_CCO, '',
						td = ISNULL(CONVERT(VARCHAR(20),e.fecha_emision, 105),'-'), '',
						td = e.amonestacion, '',
						td = ISNULL(CONVERT(VARCHAR(20),e.fecha_legalización, 105), '-'), '',
						td = e.tipo_sancion, '',
						td = ISNULL(CONVERT(VARCHAR(20),e.fecha, 105), '-'), '',
						td = e.COMENTARIO, ''
					FROM #tmp_errores e 
					INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo_emp_equipo
					INNER JOIN @Correo_Clase_Nomina cn ON cn.clase_nomina = e.clase_nomina
					WHERE e.clase_nomina = @clase_nomina 
					ORDER BY e.codigo_emp_equipo
					FOR XML PATH('tr'), TYPE) AS varchar(max)) +
				N'</table>' + 
				N'<br/><br />'+
				N' </body>'
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Marcajes', 'pa_fnjMarcaje', @asunto, @html, @w, @ANALISTA, @fi, @ff);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @asunto,
			@recipients = @ANALISTA,
			@body_format= 'html',
			@body = @html
		END
		FETCH CURSOR4 INTO @clase_nomina, @ANALISTA
	END
	CLOSE CURSOR4
	DEALLOCATE CURSOR4
END
