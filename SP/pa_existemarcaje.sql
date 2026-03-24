CREATE   PROCEDURE [Avisos].[pa_existemarcaje]
@fecha DATE 
AS
declare
@query1 varchar(6000),
@cuerpo NVARCHAR(MAX),
@Dirigido varchar(300),
@asunto varchar(300),
--@copia varchar(100),
@body varchar(5000),
@w int = 0
BEGIN
	SET LANGUAGE 'Spanish';
	DECLARE @Aux_fecha_hora DATETIME = GETDATE();

 	DECLARE @parametro_tabla AS TABLE (parametro CHAR(15), valor VARCHAR(250), descripcion VARCHAR(150), referencia_06 VARCHAR(MAX))
	INSERT @parametro_tabla (parametro, valor, descripcion, referencia_06)
	SELECT parametro, valor, descripcion, referencia_06 FROM Configuracion.parametros WITH (NOLOCK) WHERE parametro IN ('CO_Marcaje','AL_Marcaje','ER_Marcaje');

	SELECT @Dirigido = valor FROM @parametro_tabla WHERE parametro = 'CO_Marcaje';

	DECLARE @tabla AS TABLE (Cod_Restaurante VARCHAR(50), cedula VARCHAR(50), fecha VARCHAR(50), hora VARCHAR(50))

	; WITH CTE_Tabla (Cod_Restaurante, cedula, fecha, hora)
    AS (
		SELECT Cod_Restaurante, cedula, fecha, hora FROM dbo.Tmp_Marcacion_Local_WS WITH (NOLOCK) WHERE CONVERT(DATE, fecha) = @fecha GROUP BY Cod_Restaurante, cedula, fecha, hora
 		UNION
		SELECT Cod_Restaurante, cedula, fecha, hora FROM dbo.Tmp_MarcacionPlanta WITH (NOLOCK) WHERE CONVERT(DATE, fecha) = @fecha GROUP BY Cod_Restaurante, cedula, fecha, hora
		UNION
		SELECT Cod_Restaurante, Cedula, Fecha, Hora FROM dbo.Tmp_Marcacion_Planta WITH (NOLOCK) WHERE Fecha = @fecha GROUP BY Cod_Restaurante, Cedula, Fecha, Hora
		/* MARCAJES LA COMPETENCIA */
		UNION
		SELECT DISTINCT LocationCode, UserId, CONVERT(DATE, IoTime) AS Fecha, SUBSTRING(IoTime, 12, 5) AS Hora FROM dbo.Tmp_Marcaje_WS_Competencia WITH (NOLOCK) WHERE CONVERT(DATE, IoTime) = @fecha
	)

	SELECT @w = COUNT(1) FROM CTE_Tabla;  

	DECLARE @Conteo_marcajes SMALLINT = 0, @Numero_marcajes BIGINT = 0;
	SELECT @Conteo_marcajes = COUNT(1) FROM Avisos.cantidad_marcajes WITH (NOLOCK) WHERE fecha = @fecha;
	IF ((@Conteo_marcajes > 0) AND (@w > 0))
	BEGIN
		SELECT TOP 1 @Numero_marcajes = total_marcaje FROM Avisos.cantidad_marcajes WITH (NOLOCK) WHERE fecha = @fecha ORDER BY fecha DESC, CONVERT(TIME, hora) DESC;
		IF (@w > @Numero_marcajes)
		BEGIN
			SELECT @asunto = descripcion, @body = referencia_06 FROM @parametro_tabla WHERE parametro = 'CO_Marcaje'

			SELECT @body = REPLACE (@body, '@numero_marcaje', CAST(@w AS VARCHAR)) 		
			SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, @Aux_fecha_hora,9) ) 
		END 
		ELSE IF (@w <= @Numero_marcajes)
		BEGIN
			SELECT @asunto = descripcion, @body = referencia_06 FROM @parametro_tabla WHERE parametro = 'AL_Marcaje'

			SELECT @body = REPLACE (@body, '@numero_marcaje', CAST(@w AS VARCHAR)) 		
			SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, @Aux_fecha_hora,9) ) 
		END 
	END
	ELSE IF ((@Conteo_marcajes = 0) AND (@w > 0))
	BEGIN
		SELECT @asunto = descripcion, @body = referencia_06 FROM @parametro_tabla WHERE parametro = 'CO_Marcaje'

		SELECT @body = REPLACE (@body, '@numero_marcaje', CAST(@w AS VARCHAR)) 		
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, @Aux_fecha_hora,9) ) 
	END 
	ELSE IF ((@Conteo_marcajes = 0) AND (@w = 0))
	BEGIN
		SELECT @asunto = descripcion, @body = referencia_06 FROM @parametro_tabla WHERE parametro = 'ER_Marcaje';
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, @Aux_fecha_hora,9) );
	END 
	ELSE IF ((@Conteo_marcajes > 0) AND (@w = 0))
	BEGIN
		SELECT @asunto = descripcion, @body = referencia_06 FROM @parametro_tabla WHERE parametro = 'ER_Marcaje';
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, @Aux_fecha_hora,9) );
	END

	INSERT INTO Avisos.cantidad_marcajes (fecha, hora, total_marcaje)
	SELECT @fecha, CONVERT(VARCHAR(30), CONVERT(TIME, @Aux_fecha_hora)), @w;
	
	-- INSERT notificación consolidada
	INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
	VALUES ('A', 'Marcajes', 'pa_existemarcaje', @asunto, @body, @Conteo_marcajes, @Dirigido, @copia);
	EXEC msdb.dbo.Sp_send_dbmail
	@profile_name = 'Informacion_Nomina',
	@Subject = @asunto,
	@recipients = @Dirigido,
 	@body_format= 'html',
	@body = @body; --,
	--@copy_recipients = @copia;
END



