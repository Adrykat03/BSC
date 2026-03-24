
-- =============================================
-- Edit:		Jimmy Cazaro
-- Edit date:	20-08-2022
-- Description: Sirve para validar las marcaciones 
--				EXEC Asistencia.pa_validarMArcajes @var_fecha_recorre, @codigo;
-- =============================================

CREATE PROCEDURE [Avisos].[pa_validarMarcajes_correo]
( 
	@Fecha DATE, 
	@Codigo VARCHAR(20)  
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE  
	@Body varchar(MAX),	
	@Dirigido varchar(300),
	@Asunto varchar(300),
	@Aux_fecha_hora DATETIME = GETDATE(),
	@Aux_mensaje VARCHAR(500) = '';

	 	IF OBJECT_ID(N'tempdb..#tmp_tbl_MailValidacion', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_MailValidacion
	CREATE TABLE #tmp_tbl_MailValidacion
	(
		[mensaje]	[VARCHAR](500) NULL, 
		[codigo]	[VARCHAR](20) NULL
	)

	INSERT INTO #tmp_tbl_MailValidacion (mensaje, codigo)
	EXEC Asistencia.pa_validarMArcajes @Fecha, @codigo;

	SELECT @Aux_mensaje = mensaje FROM #tmp_tbl_MailValidacion WHERE codigo = @Codigo;

	IF (@Aux_mensaje != 'OK')
	BEGIN
		DECLARE @var_Trabajador VARCHAR(20), @var_Nombre VARCHAR(250), @var_Clase_Nomina VARCHAR(4), @var_CCO VARCHAR(15), @var_Desc_CCO VARCHAR(250), @var_Analista VARCHAR(500)

		DECLARE @Tbl_DatosTrabajador AS TABLE (
			Trabajador VARCHAR(20), 
			Nombre VARCHAR(250), 
			Clase_Nomina VARCHAR(4), 
			CCO VARCHAR(15), 
			Desc_CCO VARCHAR(250)/*,
			Analista VARCHAR(500)*/
		)

		IF (SELECT COUNT(tdd.codigo)
		FROM RRHH.trabajadoresDatosDiario AS tdd WITH (NOLOCK)
		WHERE tdd.codigo = @Codigo
			AND tdd.fecha = @Fecha
			AND tdd.situacion = 'Activo'
			AND tdd.fecha_baja IS NULL
		) > 0
		BEGIN
			INSERT INTO @Tbl_DatosTrabajador (Trabajador, Nombre, Clase_Nomina, CCO, Desc_CCO)

			SELECT LEFT(tdd.codigo, 10) AS Trabajador, 
				Nombre = RRHH.fn_obtener_nombreMarcajes_trabajador (@codigo, @fecha),
				vc.clase_nomina, 
				vc.cco,
				vc.descripcion
			FROM RRHH.trabajadoresDatosDiario AS tdd WITH (NOLOCK)
			INNER JOIN Catalogos.VW_CCO AS vc ON tdd.cco = vc.cco
			WHERE tdd.codigo = @Codigo
				AND tdd.fecha = @Fecha;
				
			SELECT @var_Trabajador = t.Trabajador, 
				@var_Nombre = t.Nombre, 
				@var_Clase_Nomina = t.Clase_Nomina, 
				@var_CCO = t.CCO, 
				@var_Desc_CCO = t.Desc_CCO, 
				@var_Analista = Configuracion.fn_correosVariosRemitentesContactoTiendas (t.Clase_Nomina)
			FROM @Tbl_DatosTrabajador AS t;
		END
		ELSE
		BEGIN
			INSERT INTO @Tbl_DatosTrabajador (Trabajador, Nombre, Clase_Nomina, CCO, Desc_CCO)

			SELECT Trabajador, 
			--Nombre, 
			RRHH.fn_obtener_nombreMarcajes_trabajador (@codigo, @fecha),
			Clase_Nomina, 
			CCO, 
			Desc_CCO 
			FROM RRHH.vw_datosTrabajadores
			WHERE codigo = @Codigo;

			SELECT @var_Trabajador = t.Trabajador, 
				@var_Nombre = t.Nombre, 
				@var_Clase_Nomina = t.Clase_Nomina, 
				@var_CCO = t.CCO, 
				@var_Desc_CCO = t.Desc_CCO, 
				@var_Analista = Configuracion.fn_correosVariosRemitentesContactoTiendas (t.Clase_Nomina)
			FROM @Tbl_DatosTrabajador AS t;
		END

		/*se retira espacios en blanco*/
		SELECT @var_Analista = REPLACE(@var_Analista, ' ', '');
		SELECT @Dirigido =  @var_Analista;

		SELECT @Body =	(SELECT referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_Marcaje_Admn')
	
		SELECT @Body = REPLACE (@Body, '@fecha_hora', CONVERT(VARCHAR, @Aux_fecha_hora, 9)) ;
		SELECT @Body = REPLACE (@Body, '@trabajador', @var_Trabajador)
		SELECT @Body = REPLACE (@Body, '@nombre', @var_Nombre)
		SELECT @Body = REPLACE (@Body, '@cco', @var_CCO)
		SELECT @Body = REPLACE (@Body, '@descripcion', @var_Desc_CCO)
		SELECT @Body = REPLACE (@Body, '@fecha', CONVERT(varchar(10), @Fecha, 105))
		SELECT @Body = REPLACE (@Body, '@mensaje', @Aux_mensaje)
		
		--select CONVERT(varchar(10), GETDATE(), 105)
		SELECT @Asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_Marcaje_Admn'
		SELECT @Asunto = REPLACE(@Asunto, '@codcco', @var_CCO)
		SELECT @Asunto = REPLACE(@Asunto, '@desccco', @var_Desc_CCO)
		SELECT @Asunto = REPLACE(@Asunto, '@fecha', CONVERT(varchar(10), @Fecha, 105))
		SELECT @Asunto = REPLACE(@Asunto, '@cedula', @var_Trabajador)
		SELECT @Asunto = REPLACE(@Asunto, '@nombre', @var_Nombre)

		/*guardamos log*/
		DECLARE @referencia_02 VARCHAR(1000) 
		SELECT @referencia_02 = 'Cédula: ' + @var_Trabajador + ', Nombre: ' + @var_Nombre + ' del cco: ' + @var_CCO + ' _ ' + @var_Desc_CCO + ', en la fecha: ' + CONVERT(varchar(10), @Fecha, 105) + ', realizar el proceso que emite el sistema: ' + @Aux_mensaje 
		INSERT Logs.log_envio_correo (fecha, correo, html, modulo, referencia_02)
		SELECT @Aux_fecha_hora, @Dirigido, @body, 'Advertencia - Administración de Marcaje', SUBSTRING(@referencia_02, 1, 499)

		DECLARE @TransactionName VARCHAR(30), @errorMensaje VARCHAR(510); 
		SELECT @TransactionName = 'AlertaAdminisMarcaje';  
		BEGIN TRAN @TransactionName;  
		BEGIN TRY
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
			VALUES ('A', 'Marcajes', 'pa_validarMarcajes_correo', @Asunto, @Body, @Dirigido);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @Asunto,
			@recipients =  @Dirigido,
			@importance  = 'High', 
			@body_format= 'html',
			@body = @Body; 
			/* Confirmamos la transaccion*/
			COMMIT TRANSACTION  @TransactionName;
		END TRY
		BEGIN CATCH

			/* Ocurrió un error, deshacemos los cambios*/ 
			ROLLBACK TRANSACTION @TransactionName;

			SELECT @errorMensaje = ERROR_MESSAGE();

			INSERT INTO db_nomkfc.logs.log_usuarios (id_usuario, fecha, descripcion, notas, operacion, ip, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06)

			 select SYSTEM_USER, @Aux_fecha_hora,'Error al enviar el correo: ' + SUBSTRING(@errorMensaje, 1, 250) + ', al reportar la Advertencia - Administración de Marcaje: ' + @referencia_02, 
			  '',1,'','', 'Procedimiento Almacenado: Asistencia.pa_Justificar_Marcajes',0,0,@Aux_fecha_hora, '';
		END CATCH	

	END

	IF OBJECT_ID(N'tempdb..#tmp_tbl_MailValidacion', N'U') IS NOT NULL 
		DROP TABLE #tmp_tbl_MailValidacion
	SET NOCOUNT OFF;
END