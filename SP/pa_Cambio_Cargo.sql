-- =============================================
-- Author:		Andrés Gómez
-- Create date: 15/06/2022
-- Description:	Se envía un correo informando los 
--				colaboradrores que tienen un cambio
--				de cargo.
-- =============================================
-- =============================================
-- Author:		Mateo Alvear
-- Create date: 16/09/2022
-- Description:	Se realiza una limpieza en el codigo
-- =============================================
CREATE   PROCEDURE [Avisos].[pa_Cambio_Cargo]
@trabajador VARCHAR(15),
@nombre varchar(200),
@desc_actual varchar(250),
@desc_ant varchar(250),
@cco varchar(20),
@desc_cco varchar(250),
@fecha_antiguedad date,
@genero varchar(10),
@fecha_baja date

AS
DECLARE
@body varchar(MAX),	
@Dirigido varchar(300),
@asunto varchar(300)

BEGIN
	SELECT @Dirigido = valor, @asunto = descripcion, @body = referencia_06  FROM Configuracion.parametros WHERE parametro = 'AL_Cambio_Cargo';

	IF @desc_ant <> @desc_actual
	BEGIN
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, GETDATE(),9) )
		SELECT @body = REPLACE (@body, '@saludo',(CASE WHEN @genero = 'Femenino'  THEN 'La asociada' ELSE 'El asociado' END))
		SELECT @body = REPLACE (@body, '@trabajador', @nombre)
		SELECT @body = REPLACE (@body, '@cedula', @trabajador)
		SELECT @body = REPLACE (@body, '@cco', @cco)
		SELECT @body = REPLACE (@body, '@desc_cco', @desc_cco)
		SELECT @body = REPLACE (@body, '@fecha_anti', CONVERT(varchar(10), @fecha_antiguedad, 105))
		SELECT @body = REPLACE (@body, '@cargo_ant', ISNULL(@desc_ant, ''))
		SELECT @body = REPLACE (@body, '@cargo_actual', @desc_actual)
		SELECT @body = REPLACE (@body, '@fbaja', ISNULL(CONVERT(varchar(22), @fecha_baja, 105),'No tiene fecha de baja'))
		BEGIN TRY
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
			VALUES ('A', 'Cambios', 'pa_Cambio_Cargo', @asunto, @body, @Dirigido);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @asunto,
			@recipients = @Dirigido,
			@body_format= 'html',
			@body = @body; 
		END TRY
		BEGIN CATCH
			INSERT INTO db_nomkfc.logs.log_usuarios 
			(id_usuario, fecha, descripcion, notas, operacion, ip, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06)
			select 'Adam', getdate(),'Error al enviar el correo cuando se realizó el cambio de cargo en el trabajador: '
			+ isnull(@trabajador,'sin Trab') + ' ' +isnull(@nombre,'Sin nombre') + 'con fecha de antigüedad' + ISNULL(CONVERT(varchar(10),@fecha_antiguedad, 105), 'sin antigüedad') + ' y fecha de baja ' 
			+ ISNULL(CONVERT(varchar(20), @fecha_baja, 105),'No tiene fecha de baja')
			, '',1,'','', 'pa_Cambio_Cargo',0,0,getdate(), '';
		END CATCH
	END
END
