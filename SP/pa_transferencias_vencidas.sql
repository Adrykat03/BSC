-- =============================================
-- Author:		Mateo Alvear
-- Create date: 17/11/2022
-- Description:	Se alerta sobre los trabajadores que tuvieron una transferencia vencida y no hicieron otra.

-- Modifica:	Jimmy Cazaro
-- Create date: 23/08/2023
-- Description:	Se depura la informacion a notificar cuando tienen fechas de solicitud iguales
-- =============================================
CREATE PROCEDURE [Avisos].[pa_transferencias_vencidas]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @ff date, @fi date, @p int, @html varchar(max), @w int

	SELECT @fi = FechaInicioNomina, @ff = FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(GETDATE())

	SELECT @p = CONVERT(INT, valor) FROM Configuracion.parametros WHERE parametro = 'tranf_vence'


	IF OBJECT_ID(N'tempdb..#transf', N'U') IS NOT NULL
			DROP TABLE #transf
	IF OBJECT_ID(N'tempdb..#transf_vencidas', N'U') IS NOT NULL
			DROP TABLE #transf_vencidas
	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
			DROP TABLE #tmp_errores
	 
	; WITH CTE_Transferencia As (
		SELECT ROW_NUMBER() OVER(PARTITION BY t.codigo ORDER BY t.id_transferencia DESC) row_num
		, t.id_transferencia, t.id_motivo, t.tipo_solicitud, t.tipo_transferencia, t.codigo, t.cco_origen, t.cco_destino, t.fecha_inicio, t.fecha_fin, t.fecha_modificacion
		, t.fecha_solicita, t.fecha_aprueba, t.usuario_solicita, t.usuario_aprueba, t.estatus
		, t.referencia_01, t.referencia_02, t.referencia_03, t.referencia_04, t.referencia_05, t.referencia_06
		, dt.Nombre, dt.clase_nomina, dt.CCO /*INTO #transf*/ 
		FROM Asistencia.transferencias t 
		INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = t.codigo 
		WHERE estatus IN (1,3) AND t.codigo <> '-1' AND t.fecha_solicita BETWEEN @fi AND @ff  
		AND dt.Situacion = 'Activo' AND (t.codigo NOT IN (SELECT codigo FROM RRHH.Prebajas) OR t.codigo NOT IN (SELECT codigo FROM RRHH.Prebajas_PRT))
	)

	SELECT id_transferencia, id_motivo, tipo_solicitud, tipo_transferencia, codigo, cco_origen, cco_destino, fecha_inicio, fecha_fin, fecha_modificacion
	, fecha_solicita, fecha_aprueba, usuario_solicita, usuario_aprueba, estatus
	, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06
	, Nombre, Clase_Nomina, CCO
	INTO #transf
	FROM CTE_Transferencia
	WHERE row_num = 1

	SELECT * INTO #transf_vencidas FROM #transf WHERE estatus = 1 AND fecha_aprueba IS NULL AND fecha_solicita < DATEADD(MINUTE, @p, fecha_solicita)

	SELECT * INTO #tmp_errores FROM #transf_vencidas tv WHERE 
	NOT EXISTS(SELECT 1 FROM #transf t 
				WHERE t.codigo = tv.codigo AND t.cco_origen = tv.cco_origen  AND ((t.fecha_solicita > tv.fecha_solicita AND t.estatus = 3) 
				OR (t.estatus = 1 AND DATEDIFF(minute, t.fecha_solicita, GETDATE()) < @p)))

	SELECT * FROM #tmp_errores

	DECLARE @Correo_Clase_Nomina AS TABLE (clase_nomina VARCHAR(6), analista VARCHAR(1000))

	INSERT INTO @Correo_Clase_Nomina (clase_nomina, analista) SELECT CV.clase_nomina, Configuracion.fn_correosVariosRemitentesContactoTiendas (CV.clase_nomina)
	FROM Asistencia.transferencias t WITH (NOLOCK) 
	INNER JOIN RRHH.vw_datosTrabajadores dt ON t.codigo = dt.Codigo
	INNER JOIN Catalogos.VW_CCO cv ON t.cco_origen = cv.cco and cv.clase_nomina = dt.Clase_Nomina
	GROUP BY CV.clase_nomina

	DECLARE @destinatarios varchar(MAX), @asunto varchar(300)
	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WITH (NOLOCK) WHERE parametro = 'AL_Tran_Venc'
	IF (SELECT COUNT(1) FROM #tmp_errores) > 0
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
				N'<h3><font color="SteelBlue">TRANSFERENCIAS VENCIDAS, SIN EJECUTAR</h3>' +
					N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</h4>'+
					N'<h4><font color="SteelBlue">Trabajadores con transferencias vencidas que no se volvieron a realizar</h4>'+
					N'<table id="box-table" >' +
					N'<tr><font color="Green">
						<th>TIPO</th>
						<th>FECHA INICIO</th>
						<th>FECHA FIN</th>
						<th>FECHA SOLICITA</th>
						<th>CÓDIGO</th>
						<th>NOMBRE</th>
						<th>CCO ORIGEN</th>
						<th>DESCRIPCION CCO ORIGEN</th>
						<th>CCO DESTINO</th>
						<th>DESCRIPCION CCO DESTINO</th>
						<th>CCO ACTUAL</th>
						<th>DESCRIPCION CCO ACTUAL</th>
					</tr>' +
						CAST(( 
						SELECT 
						td = CASE WHEN e.tipo_transferencia = 1 THEN 'TEMPORAL' ELSE 'DEFINITIVA' END, '',
						td = CONVERT(VARCHAR(20),e.fecha_inicio, 105),'',
						td = ISNULL(CONVERT(VARCHAR(20),e.fecha_fin, 105), '-'),'',
						td = CONVERT(VARCHAR(20),e.fecha_solicita, 105),'',
						td = e.codigo,'',
						td = e.Nombre, '',
						td = e.cco_origen,'',
						td = ccoo.descripcion,'',
						td = e.cco_destino,'',
						td = ccod.descripcion,'',
						td = e.CCO,'',
						td = ccoa.descripcion,''
						FROM #tmp_errores e 
						INNER JOIN Catalogos.VW_CCO ccoo ON e.cco_origen = ccoo.cco
						INNER JOIN Catalogos.VW_CCO ccod ON ccod.cco = e.cco_destino 
						INNER JOIN Catalogos.VW_CCO ccoa ON ccoa.cco = e.CCO
						FOR XML PATH('tr'), TYPE) AS varchar(max)) +
					N'</table>' + 
					N'<br/><br />'+
					N' </body>'
									
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Transferencias', 'pa_transferencias_vencidas', @asunto, @html, @destinatarios, @fi, @ff);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		 @body_format= 'html',
		@body = @html

		DECLARE @clase_nomina VARCHAR(6), @ANALISTA VARCHAR(1000)
		DECLARE CURSOR4 CURSOR LOCAL
		FOR 
		SELECT clase_nomina, analista FROM @Correo_Clase_Nomina ORDER BY clase_nomina
							
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
					N'<h3><font color="SteelBlue">TRANSFERENCIAS VENCIDAS, SIN EJECUTAR</h3>' +
					N'<h4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</h4>'+
					N'<h4><font color="SteelBlue">Trabajadores con transferencias vencidas que no se volvieron a realizar</h4>'+
					N'<table id="box-table" >' +
					N'<tr><font color="Green">
						<th>TIPO</th>
						<th>FECHA INICIO</th>
						<th>FECHA FIN</th>
						<th>FECHA SOLICITA</th>
						<th>CÓDIGO</th>
						<th>NOMBRE</th>
						<th>CCO ORIGEN</th>
						<th>DESCRIPCION CCO ORIGEN</th>
						<th>CCO DESTINO</th>
						<th>DESCRIPCION CCO DESTINO</th>
						<th>CCO ACTUAL</th>
						<th>DESCRIPCION CCO ACTUAL</th>
					</tr>' +
						CAST(( 
						SELECT 
						td = CASE WHEN e.tipo_transferencia = 1 THEN 'TEMPORAL' ELSE 'DEFINITIVA' END, '',
						td = CONVERT(VARCHAR(20),e.fecha_inicio, 105),'',
						td = ISNULL(CONVERT(VARCHAR(20),e.fecha_fin, 105), '-'),'',
						td = CONVERT(VARCHAR(20),e.fecha_solicita, 105),'',
						td = e.codigo,'',
						td = e.Nombre, '',
						td = e.cco_origen,'',
						td = ccoo.descripcion,'',
						td = e.cco_destino,'',
						td = ccod.descripcion,'',
						td = e.CCO,'',
						td = ccoa.descripcion,''
						FROM #tmp_errores e 
						INNER JOIN @Correo_Clase_Nomina cn ON cn.clase_nomina = e.clase_nomina
						INNER JOIN Catalogos.VW_CCO ccoo ON e.cco_origen = ccoo.cco 
						INNER JOIN Catalogos.VW_CCO ccod ON ccod.cco = e.cco_destino
						INNER JOIN Catalogos.VW_CCO ccoa ON ccoa.cco = e.CCO
						WHERE e.clase_nomina = @clase_nomina 
						FOR XML PATH('tr'), TYPE) AS varchar(max)) +
					N'</table>' + 
					N'<br/><br />'+
					N' </body>'
					-- INSERT notificación consolidada
					INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
					VALUES ('A', 'Transferencias', 'pa_transferencias_vencidas', @asunto, @html, @w, @ANALISTA, @fi, @ff);
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

END
