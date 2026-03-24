
/*

=============================================
  
Author:			Jimmy Cazaro
Create date:	25-12-2024
Description:	Alerta para identificar las 
				cargas familiares legalizadas 
				de asociados que declaren el 
				impuesto a la renta

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_cargafamiliarimpuestoalarenta]
(
	@Trabajador		varchar(10),
	@Nombre			varchar(250),
	@empresa		varchar(250),
	@Sueldo			decimal(12, 2)
)
AS
BEGIN
	SET NOCOUNT ON;
	SET LANGUAGE 'Spanish';
	DECLARE  
		@body varchar(MAX),	
		@Dirigido varchar(300) = 'info.nomina@kfc.com.ec',
		@asunto varchar(300),
		@Aux_fecha_hora DATETIME = GETDATE();
			   
			   
	DECLARE @TransactionName VARCHAR(30) = 'CargaFamiliarIR', @errorMensaje VARCHAR(1000), @referencia_02 VARCHAR(1000) ; 
	SELECT @referencia_02 = 'Cédula: ' + @Trabajador + ', Nombre: ' + @Nombre + ', Empresa: ' + @empresa + ', variable Sueldo: ' + CONVERT(VARCHAR(20), @Sueldo);

	BEGIN TRANSACTION @TransactionName;

	BEGIN TRY
		SELECT @asunto = descripcion, @Dirigido = valor, @body = referencia_06 FROM Configuracion.parametros WITH (NOLOCK) WHERE parametro = 'CARFAM_IR_MAIL';
 
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(VARCHAR, @Aux_fecha_hora, 9)) ;
		SELECT @body = REPLACE (@body, '@aux_trabajador', @Trabajador)
		SELECT @body = REPLACE (@body, '@aux_nombre', @Nombre)
		SELECT @body = REPLACE (@body, '@aux_empresa_nombre', @empresa)
		SELECT @body = REPLACE (@body, '@aux_variable_sueldo', CONVERT(VARCHAR(20), @Sueldo))		

		INSERT DB_NOMKFC.Logs.log_envio_correo (fecha, correo, html, modulo, referencia_02, referencia_01)
		SELECT GETDATE(), @Dirigido, @body, 'Carga Familiar, Impuesto a la Renta', SUBSTRING(@referencia_02, 1, 499), SUBSTRING(@asunto, 1, 149); 

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
		VALUES ('A', 'Cargas Familiares', 'pa_cargafamiliarimpuestoalarenta', @asunto, @body, @Dirigido);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @Dirigido, 
		@importance = 'High',
		@body_format= 'html',
		@body = @body; 
		COMMIT TRANSACTION @TransactionName;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION @TransactionName;

		SELECT @errorMensaje = SUBSTRING(ERROR_PROCEDURE() + ' - ' + ERROR_MESSAGE() + ' - profiler: Informacion_Nomina', 0, 999);

		INSERT DB_NOMKFC.Logs.log_envio_correo (fecha, correo, html, modulo, referencia_02, referencia_06, referencia_01)
		SELECT GETDATE(), @Dirigido, @body, 'Carga Familiar, Impuesto a la Renta ERROR', SUBSTRING(@referencia_02, 1, 499), @errorMensaje, SUBSTRING(@asunto, 1, 149);
	END CATCH
	SET NOCOUNT OFF;
END
