
-- =============================================
-- Edit:		Jimmy Cazaro
-- Edit date:	02-11-2022
-- Description: Sirve para alertar sobre los FALTANTES DE CAJA 
--				que se registren es decir se importen en nominas 
--				cerradas
-- =============================================

CREATE PROCEDURE [Avisos].[pa_faltantecaja]
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE  
	@Body varchar(MAX),	
	@Dirigido varchar(300),
 	@CopiaOculta varchar(300) = (SELECT valor FROM Configuracion.parametros WHERE parametro = 'AL_Falt_Caja'),
 	@Asunto varchar(300) = 'Advertencia - Faltantes de Caja en Nómina Cerrada',
	@Aux_fecha_hora DATETIME = GETDATE(),
	@var_Analista VARCHAR(500), @consulta varchar(max), @tab char(1) = CHAR(9);

	SET @Dirigido = @CopiaOculta;

	DECLARE @fecha VARCHAR(10) = CONVERT(VARCHAR(10), @Aux_fecha_hora, 112)
	DECLARE @fecha_inicio_busqueda VARCHAR(10) = '20221015'; /* nomina de noviembre 2022 */
	--DECLARE @fi DATE = @fecha_inicio_busqueda, @ff DATE = '20221031';
	--DECLARE @fi DATE = '20221027', @ff DATE = '20221031';

	/* 
	tabla: descuentos.descuento_ws_temp, donde se importan los descuentos 
	*/
	IF OBJECT_ID(N'tempdb..#tmp_tbl_descuento_ws', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_descuento_ws

	SELECT w.cedula, w.cajero, w.monto, w.fecha, w.tienda, w.cco, w.fechaTraida, w.codigo, w.estado, w.observaciones, w.descripcionTienda
	, v.clase_nomina, v.descripcion
	INTO #tmp_tbl_descuento_ws
	FROM descuentos.descuento_ws_temp AS w WITH (NOLOCK)
	INNER JOIN Catalogos.VW_CCO AS v ON w.cco = v.cco
	WHERE w.estado = 1
		AND ISNULL(w.cedula, '') = ''
		AND CONVERT(DATE, w.fechaTraida) = CONVERT(DATE, @fecha)
	--	--AND w.fecha >= @fecha_inicio_busqueda
	--	----AND (w.fecha BETWEEN @fi AND @ff)
	----ORDER BY w.fecha DESC
	GROUP BY w.cedula, w.cajero, w.monto, w.fecha, w.tienda, w.cco, w.fechaTraida, w.codigo, w.estado, w.observaciones, w.descripcionTienda
	, v.clase_nomina, v.descripcion;

	/*
	separamos segun la clase de nomina a que analista o analistas de nomina va dirigida la alerta
	*/
	IF OBJECT_ID(N'tempdb..#tmp_tbl_contactodescuento_ws', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_contactodescuento_ws

	SELECT clase_nomina,
	contacto = [Configuracion].[fn_correosVariosRemitentesContactoTiendas] (clase_nomina)
	INTO #tmp_tbl_contactodescuento_ws
	FROM #tmp_tbl_descuento_ws
	GROUP BY clase_nomina;

	/*
	Analisis de fechas cuando es una nomina legalizada
	*/
	IF OBJECT_ID(N'tempdb..#tmp_tbl_nomyperiodo', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_nomyperiodo

	SELECT w.fecha, 
	nomina = Nomina.fn_consulta_estado_periodoNomina(w.fecha) /* el estado de la nomina, estados es cerrada y abierta; 1 nomina abierta, 2 nomina cerrada*/
	, IniNomina = (SELECT FechaInicioNomina FROM Utilidades.fn_fechasperiodonomina(w.fecha))
	, FinNomina = (SELECT FechaFinNomina FROM Utilidades.fn_fechasperiodonomina(w.fecha))
	, Mes = (SELECT Mes FROM Utilidades.fn_fechasperiodonomina(w.fecha))
	, CASE (SELECT Mes FROM Utilidades.fn_fechasperiodonomina(w.fecha))
		WHEN '01' THEN 'Ene'
		WHEN '02' THEN 'Feb'
		WHEN '03' THEN 'Mar'
		WHEN '04' THEN 'Abr'
		WHEN '05' THEN 'May'
		WHEN '06' THEN 'Jun'
		WHEN '07' THEN 'Jul'
		WHEN '08' THEN 'Ago'
		WHEN '09' THEN 'Sep'
		WHEN '10' THEN 'Oct'
		WHEN '11' THEN 'Nov'
		WHEN '12' THEN 'Dic'
		ELSE ''
	END AS MesLetras
	, Anio = (SELECT Anio FROM Utilidades.fn_fechasperiodonomina(w.fecha))
	INTO #tmp_tbl_nomyperiodo
	FROM #tmp_tbl_descuento_ws AS w
	GROUP BY w.fecha;

	/*
	Realizamos la consulta de la respectiva alerta
	*/
	IF OBJECT_ID(N'tempdb..##tmp_tbl_consolidadodescuento', N'U') IS NOT NULL 
		DROP TABLE ##tmp_tbl_consolidadodescuento

	SELECT ws.cajero, ws.monto, ws.fecha, ws.cco, ws.tienda 
	, ws.descripcionTienda, ws.observaciones 
	, cws.contacto AS analista
	, ws.fechaTraida
	--, CONVERT(VARCHAR(21), ws.fechaTraida, 20) AS fechaTraida
	, nomina = (MesLetras + ' ' + Anio + ', (Del ' + CONVERT(VARCHAR(10), CONVERT(DATE, per.IniNomina) , 105) + ' al ' + CONVERT(VARCHAR(10), CONVERT(DATE, per.FinNomina) , 105) + ')')
	INTO ##tmp_tbl_consolidadodescuento
	FROM #tmp_tbl_nomyperiodo AS per
	INNER JOIN #tmp_tbl_descuento_ws AS ws ON per.fecha = ws.fecha
	INNER JOIN #tmp_tbl_contactodescuento_ws AS cws ON ws.clase_nomina = cws.clase_nomina
	WHERE per.nomina = 2
	ORDER BY ws.fechaTraida DESC, ws.tienda, ws.cajero;

	IF (SELECT COUNT(cajero) FROM ##tmp_tbl_consolidadodescuento) > 0
	BEGIN
		SELECT @consulta = 'SELECT cajero, monto, CONVERT(VARCHAR(10), fecha, 23) AS fecha_CxC, ''''+cco AS cco_codigo, tienda AS centro_costo, descripcionTienda AS cco_descripcion, observaciones, CONVERT(VARCHAR(21), fechaTraida, 20) AS fecha_creacion, corte_nomina FROM ##tmp_tbl_consolidadodescuento ORDER BY fechaTraida DESC, fecha DESC, cajero'

		 
		SELECT @Body =	(SELECT referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_Falt_Caja')
	
		SELECT @Body = REPLACE (@Body, '@fecha_hora', CONVERT(VARCHAR, @Aux_fecha_hora, 9)) ;
		
		SELECT @Asunto = @Asunto + ', en la fecha: ' + CONVERT(varchar(10), CONVERT(DATE, @Fecha), 105) 

		/*guardamos log*/
		DECLARE @referencia_02 VARCHAR(1000), @solo_fecha VARCHAR(12) = CONVERT(varchar(10), CONVERT(DATE, @Fecha), 105), @nombre_archivo VARCHAR(100); 
		SELECT @referencia_02 = 'Se ejecutó el proceso de la alerta que revisa el ingreso de faltantes de caja con fechas de nóminas cerradas, en la fecha: ' + @solo_fecha  
		INSERT Logs.log_envio_correo (fecha, correo, html, modulo, referencia_02)
		SELECT @Aux_fecha_hora, @Dirigido, @body, 'Advertencia - Faltantes de Caja en Nóminas Cerradas', SUBSTRING(@referencia_02, 1, 499)

		SET @nombre_archivo = 'cuentas_x_cobrar_' + @solo_fecha +'.csv'

		DECLARE @TransactionName VARCHAR(30), @errorMensaje VARCHAR(510); 
		SELECT @TransactionName = 'AlertaFaltantesCaja';  
		BEGIN TRAN @TransactionName;  
		BEGIN TRY
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, destinatariosCc, periodoInicio, periodoFin)
			VALUES ('A', 'Créditos Tienda', 'pa_faltantecaja', @Asunto, @Body, @Dirigido, @CopiaOculta, @fi, @ff);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @Asunto,
			@recipients = @Dirigido,
			--@blind_copy_recipients = @CopiaOculta,
			@importance = 'High', 
			@body_format = 'html',
			@query = @consulta,
			@attach_query_result_as_file = 1,
			@query_attachment_filename = @nombre_archivo,
			--@query_result_separator = @tab,
			@query_result_separator = '	',
			@query_result_no_padding = 1,
			@body = @Body; 
			/* Confirmamos la transaccion*/
			COMMIT TRANSACTION  @TransactionName;
		END TRY
		BEGIN CATCH

			/* Ocurrió un error, deshacemos los cambios*/ 
			ROLLBACK TRANSACTION @TransactionName;

			SELECT @errorMensaje = ERROR_MESSAGE();

			INSERT INTO db_nomkfc.logs.log_usuarios (id_usuario, fecha, descripcion, notas, operacion, ip, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06)

			 select SYSTEM_USER, @Aux_fecha_hora,'Error al enviar el correo: ' + SUBSTRING(@errorMensaje, 1, 250) + ', al reportar la Advertencia - Faltantes de Caja: ' + @referencia_02, 
			  '',1,'','', 'Procedimiento Almacenado: descuentos.pa_traer_descuentos_ws',0,0,@Aux_fecha_hora, '';
		END CATCH		
	END
	
	IF OBJECT_ID(N'tempdb..#tmp_tbl_descuento_ws', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_descuento_ws
	IF OBJECT_ID(N'tempdb..#tmp_tbl_contactodescuento_ws', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_contactodescuento_ws
	IF OBJECT_ID(N'tempdb..#tmp_tbl_nomyperiodo', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_nomyperiodo
	IF OBJECT_ID(N'tempdb..##tmp_tbl_consolidadodescuento', N'U') IS NOT NULL 
		DROP TABLE ##tmp_tbl_consolidadodescuento
	SET NOCOUNT OFF;
END