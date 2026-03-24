CREATE PROCEDURE [Avisos].[pa_trabajadoresHorariosCostoHorario]

AS
BEGIN
	SET NOCOUNT ON;
	SET LANGUAGE 'Spanish';
	DECLARE @HTML Nvarchar(MAX);


	DECLARE @fecha DATE = CONVERT(DATE, GETDATE());
	DECLARE @fecha_ini DATE, @fecha_fin DATE = GETDATE();
	DECLARE @tbl_cortenomina AS TABLE (FechaIni DATE, FechaFin DATE, Mes VARCHAR(2), Anio VARCHAR(4));
	INSERT INTO @tbl_cortenomina (FechaIni, FechaFin, Mes, Anio)
	SELECT FechaInicioNomina, FechaFinNomina, Mes, Anio FROM [Utilidades].[fn_fechasperiodonomina] (@fecha);
 
	SELECT @fecha_ini = FechaIni, @fecha_fin = FechaFin FROM @tbl_cortenomina;
	DECLARE @fecha_Dia_Primero_Mes VARCHAR(10) = '';
	SELECT @fecha_Dia_Primero_Mes = CONVERT(VARCHAR(4), YEAR(@fecha_fin)) + '' + CASE WHEN LEN(CONVERT(VARCHAR(2), MONTH(@fecha_fin))) = 1 THEN '0'+CONVERT(VARCHAR(2), MONTH(@fecha_fin)) ELSE CONVERT(VARCHAR(2), MONTH(@fecha_fin)) END + '01';
	SELECT @fecha_fin = DATEADD(DAY, -1, @fecha);
	

	DECLARE @consulta varchar(max), @archivo varchar(max);
	DECLARE @fecha_recorre DATE;

	BEGIN TRY
 
		IF OBJECT_ID(N'tempdb..#tmp_tbl_centro_costos', N'U') IS NOT NULL 
			DROP TABLE #tmp_tbl_centro_costos
		CREATE TABLE #tmp_tbl_centro_costos
		(
				[cco]              [VARCHAR](50), 
				[valor]            [VARCHAR](50) NULL, 
				[descripcion]		[VARCHAR](200) NULL,
				[cadena]			[VARCHAR](300) NULL
		)
		CREATE CLUSTERED INDEX idx_tmp_tbl_centro_costos ON #tmp_tbl_centro_costos ([cco]);

		INSERT INTO #tmp_tbl_centro_costos (cco, valor, descripcion, cadena)

		SELECT COO
		, [Configuracion].[fn_cadenasProductivasTiendas](COO) AS HorariosMarcacionPayRoll
		, CCO_DESCRIPCION
		, DESCRIPCION_CLASE
		FROM Adam.[dbo].[FPV_AGR_COM_CLASE] WITH (NOLOCK)
		WHERE REFERENCIA_20 = 'SI'
			AND [STATUS] = 'ABIERTO' AND referencia_09 in ('DP02','DP01')
		ORDER BY REGION DESC, COMPANIA, EMPRESA, CCO_DESCRIPCION;
 
 
		IF OBJECT_ID(N'tempdb..#tmp_tbl_cco_fecha_horario', N'U') IS NOT NULL 
			DROP TABLE #tmp_tbl_cco_fecha_horario
		CREATE TABLE #tmp_tbl_cco_fecha_horario
		(
				[cco]								[VARCHAR](50) NULL, 
				[fecha]							[DATE] NULL 
		)

		CREATE CLUSTERED INDEX idx_tmp_tbl_cco_fecha_horario ON #tmp_tbl_cco_fecha_horario ([cco],[fecha]);

		DECLARE @aux_cco VARCHAR(10), @aux_descripcion VARCHAR(200), @aux_cant_asociados SMALLINT = 0, @aux_cant_horarios SMALLINT = 0, @aux_cant_costohorario SMALLINT = 0;
		DECLARE cursor_ccofechor CURSOR LOCAL FOR
			SELECT cco, descripcion FROM #tmp_tbl_centro_costos WHERE valor = 'SI' GROUP BY cco, descripcion ORDER BY descripcion
		OPEN cursor_ccofechor
		FETCH NEXT FROM cursor_ccofechor INTO @aux_cco, @aux_descripcion

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @fecha_recorre = @fecha_ini;
			WHILE @fecha_recorre <= @fecha_fin
			BEGIN
				INSERT #tmp_tbl_cco_fecha_horario (cco, fecha)
				SELECT @aux_cco, @fecha_recorre; 

				SELECT @fecha_recorre = DATEADD(DAY, 1, @fecha_recorre); 
			END

			FETCH NEXT FROM cursor_ccofechor into @aux_cco, @aux_descripcion
		END            
		CLOSE cursor_ccofechor
		DEALLOCATE cursor_ccofechor

--SELECT * FROM #tmp_tbl_cco_fecha_horario
--SELECT TOP 10 * FROM Asistencia.rel_trab_horarios
--RETURN

		IF OBJECT_ID(N'tempdb..##tmp_tbl_RESUMEN', N'U') IS NOT NULL 
			DROP TABLE ##tmp_tbl_RESUMEN
		CREATE TABLE ##tmp_tbl_RESUMEN
		(
				[cadena]						[VARCHAR](300) NULL,
				[descripcion]					[VARCHAR](200) NULL,
				[cco]							[VARCHAR](10) NULL, 
				[fecha]							[DATE] NULL, 
				[cant_asociados]				[SMALLINT] NULL,
				[cant_horarios]					[SMALLINT] NULL,
				[cant_calculosHorarios]			[SMALLINT] NULL
		)

		; WITH CTE_rel_trab_horarios AS (
			SELECT h.cco, h.fecha, h.codigo
			FROM Asistencia.rel_trab_horarios AS h WITH (NOLOCK)
			INNER JOIN #tmp_tbl_cco_fecha_horario AS tcfh ON h.cco = tcfh.cco AND h.fecha = tcfh.fecha
			GROUP BY h.cco, h.fecha, h.codigo
		), CTE_calculosHorarios AS (
			SELECT ch.cco, ch.fecha, ch.codigo
			FROM Asistencia.calculosHorarios AS ch WITH (NOLOCK)
			INNER JOIN #tmp_tbl_cco_fecha_horario AS tcfh ON ch.cco = tcfh.cco AND ch.fecha = tcfh.fecha
			GROUP BY ch.cco, ch.fecha, ch.codigo
		), CTE_DatosHorario (cco, fecha, cant_horarios, cant_calculohorarios)
		AS
		(
			SELECT tcfh.cco, tcfh.fecha
			, (SELECT COUNT(codigo) FROM CTE_rel_trab_horarios WHERE cco = tcfh.cco AND fecha = tcfh.fecha) AS Cant_Horarios
			, (SELECT COUNT(codigo) FROM CTE_calculosHorarios WHERE cco = tcfh.cco AND fecha = tcfh.fecha) AS Cant_CalculoHorarios
			--, (SELECT COUNT(1) FROM Asistencia.rel_trab_horarios WHERE cco = tcfh.cco AND fecha = tcfh.fecha) AS Cant_Horarios
			--, (SELECT COUNT(1) FROM Asistencia.calculosHorarios WHERE cco = tcfh.cco AND fecha = tcfh.fecha) AS Cant_CalculoHorarios
			FROM #tmp_tbl_cco_fecha_horario AS tcfh
			GROUP BY tcfh.cco, tcfh.fecha
		)

		INSERT ##tmp_tbl_RESUMEN (cadena, descripcion, cco, fecha, cant_asociados, cant_horarios, cant_calculosHorarios) 


		SELECT LTRIM(RTRIM(cc.cadena)), LTRIM(RTRIM(cc.descripcion)), LTRIM(RTRIM(c.cco)), LTRIM(RTRIM(c.fecha))
		, (SELECT COUNT(codigo) FROM Asistencia.fc_Trabajadores_Activos_CCO(c.fecha, c.cco)) AS cant_asociados
		, LTRIM(RTRIM(c.cant_horarios)), LTRIM(RTRIM(c.cant_calculohorarios))
		FROM CTE_DatosHorario AS c
		INNER JOIN #tmp_tbl_centro_costos AS cc ON c.cco = cc.cco
		GROUP BY cc.cadena, cc.descripcion, c.cco, c.fecha
		, c.cant_horarios, c.cant_calculohorarios;
		 
		IF ((SELECT COUNT(cadena) FROM ##tmp_tbl_RESUMEN WHERE cant_asociados <> cant_horarios OR cant_asociados <> cant_calculosHorarios) > 0)
		BEGIN
			SET @consulta = N'SELECT cadena, cco, descripcion, fecha, cant_asociados AS Num_Asociados, cant_horarios, cant_calculosHorarios
					FROM ##tmp_tbl_RESUMEN 
					WHERE cant_asociados <> cant_horarios
						OR cant_asociados <> cant_calculosHorarios
					GROUP BY cadena, cco, descripcion, fecha, cant_asociados, cant_horarios, cant_calculosHorarios
					ORDER BY cadena, descripcion, fecha';
			
			SET @archivo = N''+CONVERT(varchar(10),@fecha_fin,105)+' - AsociadosHorarioCostoHorario.csv';
 
			select @HTML = N'<style type="text/css">
			#box-table
			{
				font-family: "Calibri";
				font-size: 11px;
				text-align: center;
				border-collapse: collapse;
				border-top: 7px solid #9baff1;
				border-bottom: 7px solid #9baff1;
			}
			#box-table th
			{
				font-size: 12px;
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
				color: #669;
			}
			tr:nth-child(odd) { background-color:#eee; }
			tr:nth-child(even) { background-color:#fff; } 
			</style>'+ 
			N'<H3><font color="SteelBlue">ALERTA CENTROS DE COSTO A REVISAR HORARIOS O COSTO HORARIO</H3>' +
			N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),105)+'</H4>'+
			N'<H4><font color="SteelBlue">Alerta - revisar los horarios o costo horario </H4>' +
			--N'<table id="box-table" >' +
			--N'<tr><font color="Green">
			--<th>CCO</th>
			--<th>CCO DESCRIPCIÓN</th>
			--<th>FECHA</th>
			--<th>No. ASOCIADOS</th>
			--<th>No. HORARIOS</th>
			--</tr>' +
 
			--CAST(( SELECT
			--td = cco, '', 
			--td = descripcion, '', 
			--td = fecha, '', 
			--td = cant_asociados, '', 
			--td = cant_horarios
			--FROM ##tmp_tbl_RESUMEN
			--WHERE cant_asociados <> cant_horarios
			--	OR cant_asociados <> cant_calculosHorarios
			--ORDER BY cadena, descripcion, fecha
                    
			--FOR XML PATH('tr'), TYPE 
			--) AS varchar(max)) +
			--N'</table>' +
			N'<br/><br />'+
			N' </body>'  
 
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Horarios', 'pa_trabajadoresHorariosCostoHorario', 'Alerta - asociados, horarios y costo de horario', @HTML, 'sabrina.chinchin@kfc.com.ec', @fecha_ini, @fecha_fin);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina', 
				@recipients= 'sabrina.chinchin@kfc.com.ec', 
				@subject = 'Alerta - asociados, horarios y costo de horario',
				@body = @HTML,

				@query = @consulta,
		@attach_query_result_as_file = 1,
		@query_attachment_filename = @archivo,
		@importance = 'High',
		@query_result_separator = '	',
		@query_result_header = 1,
		@query_result_no_padding = 1,
		@exclude_query_output = 1,
				@body_format = 'HTML' ;   

		END
		ELSE
		BEGIN
 
			select @HTML = N'<style type="text/css">
			#box-table
			{
				font-family: "Calibri";
				font-size: 9px;
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
				color: #669;
			}
			tr:nth-child(odd) { background-color:#eee; }
			tr:nth-child(even) { background-color:#fff; } 
			</style>'+ 
			N'<H3><font color="SteelBlue">ALERTA CENTROS DE COSTO A REVISAR HORARIOS O COSTO HORARIO</H3>' +
			N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),105)+'</H4>'+
			N'<H4><font color="SteelBlue">Alerta - revisar los horarios o costo horario </H4>' +
			N'<H4><font color="SteelBlue">NO EXISTE HORARIOS SIN EL COSTO HORARIO, PROCESO SATISFACTORIO</H4>' +
			N'<br/><br />'+
			N' </body>'  
 
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Horarios', 'pa_trabajadoresHorariosCostoHorario', 'Alerta - asociados, horarios y costo de horario', @HTML, 'sabrina.chinchin@kfc.com.ec;', @fecha_ini, @fecha_fin);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina', 
				@recipients= 'sabrina.chinchin@kfc.com.ec;', 
				@subject = 'Alerta - asociados, horarios y costo de horario',
				@body = @HTML,
				@body_format = 'HTML' ;			
		END
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage VARCHAR(MAX) = ERROR_MESSAGE();

        DECLARE @Mensaje VARCHAR(150) = 'Error en la alerta Trabajadores: Horarios vs CostoHorario que se genera en DB_NOMKFC ([Avisos].[pa_trabajadoresHorariosCostoHorario])',
            @FechaLog SMALLDATETIME = GETDATE();
   
        EXEC [Logs].[pa_insertarErroresenLogs] 'Error al insertar al trabajador', @FechaLog, @Mensaje, @ErrorMessage

		SELECT @HTML = 
			N'<p style="color: #000000;    font-family: ''Trebuchet MS''; font-size: 14px"><strong>' + @Mensaje + '</strong></p>'+
			N'<H1  style="  color: #000000;    font-family:''Trebuchet MS'';    font-size: 12px;">ALERTA CENTROS DE COSTO A REVISAR HORARIOS O COSTO HORARIO</H1>' +
			N'<p  style="  color: #000000;    font-family:''Trebuchet MS'';    font-size: 8px;">&nbsp;</p>' +
			N'<p  style="  color: #000000;    font-family:''Trebuchet MS'';    font-size: 12px;">Fecha: '+convert(varchar(12),GETDATE(),105)+'</p>' +
			N'<p  style="  color: #000000;    font-family:''Trebuchet MS'';    font-size: 12px;">Mensaje: '+@ErrorMessage+'</p>' +
			N'<br>'

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Horarios', 'pa_trabajadoresHorariosCostoHorario', 'ERROR en Alerta - asociados, horarios y costo de horario', @HTML, 'pasante.nominadosec@kfc.com.ec', @fecha_ini, @fecha_fin);
		EXEC msdb.dbo.sp_send_dbmail 
			@profile_name='Informacion_Nomina',
			--@recipients= 'pasante.nominadosec@kfc.com.ec', 
			@recipients= 'sabrina.chinchin@kfc.com.ec', 
			@subject = 'ERROR en Alerta - asociados, horarios y costo de horario',
			@body = @HTML,
			@body_format = 'HTML' ;	
	
        RAISERROR (@ErrorMessage, 16, 1)		
	END CATCH

	IF OBJECT_ID(N'tempdb..##tmp_tbl_RESUMEN', N'U') IS NOT NULL 
		DROP TABLE ##tmp_tbl_RESUMEN
	IF OBJECT_ID(N'tempdb..#tmp_tbl_cco_fecha_horario', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_cco_fecha_horario
	IF OBJECT_ID(N'tempdb..#tmp_tbl_centro_costos', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_centro_costos
	SET NOCOUNT OFF;
END
