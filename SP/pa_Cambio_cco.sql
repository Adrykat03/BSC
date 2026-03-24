
-- =============================================
-- Edit:		Andrés Gómez
-- Edit date:	14-06-2022
-- Description: Se envía un correo con la información 
--				del empleado cambiado
-- =============================================
-- =============================================
-- Edit:		Jimmy Cazaro
-- Edit date:	09-08-2022
-- Description: Se realiza una mejora al proceso 
--				ya que envia sin informacion
-- =============================================

CREATE PROCEDURE [Avisos].[pa_Cambio_cco]
@trabajador varchar(20),
@fecha_ini DATE,
@fecha_fin DATE,
@cco_nuevo char(10) = null,
@CCOAnterior char(10) = null

AS
DECLARE  
	@body varchar(MAX),	
	@Dirigido varchar(300),
	@asunto varchar(300),
	@Aux_fecha_hora DATETIME = GETDATE(),
	@nombre varchar (100),
	@desc_cco_ant VARCHAR(100),
	@desc_cco_actual VARCHAR(100),
	@cont_reg int = 0,
	@fecha_Ingreso VARCHAR(10);

BEGIN

	SELECT @nombre = Nombre, @fecha_Ingreso = CONVERT(VARCHAR(10), CONVERT(DATE, Fecha_Ingreso), 105)
	FROM RRHH.vw_datosTrabajadores
	WHERE Trabajador = @trabajador

	DECLARE @tmp_cco AS TABLE(cco varchar(20), descripcion varchar(200))
	INSERT INTO @tmp_cco
	SELECT cco, descripcion FROM Catalogos.VW_CCO WHERE cco IN (@CCOAnterior, @cco_nuevo)

	SELECT @asunto = descripcion, @Dirigido = valor, @body = referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_Cambio';

	SELECT @desc_cco_actual = descripcion FROM @tmp_cco WHERE cco = @cco_nuevo
	SELECT @desc_cco_ant = descripcion FROM @tmp_cco WHERE cco = @CCOAnterior
	
	SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(VARCHAR, @Aux_fecha_hora, 9)) ;
	SELECT @body = REPLACE (@body, '@trabajador', @trabajador)
	SELECT @body = REPLACE (@body, '@nombre', @nombre)
	SELECT @body = REPLACE (@body, '@fecha_ingreso', @fecha_Ingreso)
	SELECT @body = REPLACE (@body, '@desc_cco_ant', @desc_cco_ant)
	SELECT @body = REPLACE (@body, '@cco_ant', @CCOAnterior)
	SELECT @body = REPLACE (@body, '@desc_cco_actual', @desc_cco_actual)
	SELECT @body = REPLACE (@body, '@cco_actual', @cco_nuevo)

	DECLARE @referencia_02 VARCHAR(1000) 
	SELECT @referencia_02 = 'Cédula: ' + @trabajador + ', Nombre: ' + @nombre + ', fecha ingreso: ' + @fecha_Ingreso + ', cco actual: ' + @cco_nuevo + ', descripcion: ' + @desc_cco_actual + ', cco anterior: ' + @CCOAnterior + ', descripcion: ' + @desc_cco_ant
	INSERT Logs.log_envio_correo (fecha, correo, html, modulo, referencia_02)
	SELECT GETDATE(), @Dirigido, @body, 'Cambio de CCO', SUBSTRING(@referencia_02, 1, 499)

	DECLARE @TransactionName VARCHAR(30), @errorMensaje VARCHAR(510); 
	SELECT @TransactionName = 'CambioCCOAsociado';  
	BEGIN TRAN @TransactionName;  
	BEGIN TRY
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Cambios', 'pa_Cambio_cco', @asunto, @body, @Dirigido, @fecha_ini, @fecha_fin);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @Dirigido,
		@body_format= 'html',
		@body = @body; 
		COMMIT TRANSACTION  @TransactionName;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION @TransactionName;

		SELECT @errorMensaje = ERROR_MESSAGE();

		INSERT INTO db_nomkfc.logs.log_usuarios (id_usuario, fecha, descripcion, notas, operacion, ip, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06)

			SELECT SYSTEM_USER, getdate(),'Error al enviar el correo: ' + SUBSTRING(@errorMensaje, 1, 250) + ', al reportar el Cambio de CCO: ' + @referencia_02, 
			'',1,'','', 'Procedimiento Almacenado: RRHH.pa_cambio_centro_costo2',0,0,getdate(), '';
	END CATCH	


	IF OBJECT_ID(N'tempdb..#tmp_trabajador_nomina', N'U') IS NOT NULL 
		DROP TABLE #tmp_trabajador_nomina
END