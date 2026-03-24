
-- =============================================
-- Edit:		Vinicio Muela 
-- Edit date:	21-06-2023
-- Description: Alerta de correo para informar la 
--              fecha de aniversario mendiante un
--              mensaje de felicitacion con una imagen   
-- =============================================

CREATE PROCEDURE [Avisos].[pa_aniversario] 
AS
BEGIN
	SET NOCOUNT ON;
	SET LANGUAGE 'Spanish';
	SET DATEFORMAT ymd;
	DECLARE  
	@body varchar(MAX),	
	 
	@C_Dirigido varchar(300)= 'sabrina.chinchin@kfc.com.ec',
	@Dirigido varchar(300) = 'pasante.nominadosec@kfc.com.ec',
	@asunto varchar(300) = 'Aniversario',
	@Aux_fecha_hora DATETIME, 
	@aux_fecha DATE = '20230722';  
	


	IF OBJECT_ID(N'tempdb..#tmp_aviso_aniversario', N'U') IS NOT NULL 
		DROP TABLE #tmp_aviso_aniversario

	; WITH CTE_aniversario (Comparar, Aniversario, Fecha_Antiguedad, Nombre, mail_Trabajador, correoJefe1)
	AS (
		SELECT DISTINCT CONVERT(VARCHAR(4), YEAR(GETDATE())) 
		+ CASE WHEN LEN(CONVERT(VARCHAR(10), CONVERT(VARCHAR(2), MONTH(v.Fecha_Antiguedad)))) = 1 THEN '0'+CONVERT(VARCHAR(10), CONVERT(VARCHAR(2), MONTH(v.Fecha_Antiguedad))) ELSE CONVERT(VARCHAR(10), CONVERT(VARCHAR(2), MONTH(v.Fecha_Antiguedad))) END
		+ CASE WHEN LEN(CONVERT(VARCHAR(10), CONVERT(VARCHAR(2), DAY(v.Fecha_Antiguedad)))) = 1 THEN '0'+CONVERT(VARCHAR(10), CONVERT(VARCHAR(2), DAY(v.Fecha_Antiguedad))) ELSE CONVERT(VARCHAR(10), CONVERT(VARCHAR(2), DAY(v.Fecha_Antiguedad))) END AS Comparar
		, DATEDIFF(YEAR, v.Fecha_Antiguedad, CONVERT(DATE, GETDATE())) AS Aniversario
		, CONVERT(VARCHAR(10), CONVERT(DATE, v.Fecha_Antiguedad)) AS Fecha_Antiguedad/*, v.Fecha_Antiguedad, v.Fecha_Ingreso, v.Codigo, v.Trabajador*/, v.Nombre, v.mail_Trabajador/*, v.Jefe1*/
		, (SELECT correoEmpresa FROM RRHH.vw_datosTrabajadores WHERE Codigo = v.Jefe1) AS correoJefe1
		FROM RRHH.vw_datosTrabajadores AS v
		WHERE v.Situacion = 'Activo'
			--AND v.CAR IN ('CAR ADMINISTRATIVO                                                                                  ')
			AND ISNULL(v.mail_Trabajador, '') != ''
	)

	SELECT t.Comparar, t.Aniversario, t.Fecha_Antiguedad, t.Nombre, t.mail_Trabajador, t.correoJefe1
	, an.ruta_imagen
	, CASE 
	WHEN t.Aniversario = 1 THEN '1 año'
	WHEN t.Aniversario = 2 THEN '2 años'
	WHEN t.Aniversario = 3 THEN '3 años'
	WHEN t.Aniversario = 4 THEN '4 años'
	WHEN t.Aniversario = 5 THEN '5 años'
	WHEN t.Aniversario = 6 THEN '6 años'
	WHEN t.Aniversario = 7 THEN '7 años'
	WHEN t.Aniversario = 8 THEN '8 años'
	WHEN t.Aniversario = 9 THEN '9 años'
	WHEN t.Aniversario = 10 THEN '10 años'
	WHEN t.Aniversario = 11 THEN '11 años'
	WHEN t.Aniversario = 12 THEN '12 años'
	WHEN t.Aniversario = 13 THEN '13 años'
	WHEN t.Aniversario = 14 THEN '14 años'
	WHEN t.Aniversario = 15 THEN '15 años'
	WHEN t.Aniversario = 16 THEN '16 años'
	WHEN t.Aniversario = 17 THEN '17 años'
	WHEN t.Aniversario = 18 THEN '18 años'
	WHEN t.Aniversario = 19 THEN '19 años'
	WHEN t.Aniversario = 20 THEN '20 años'
	WHEN t.Aniversario = 21 THEN '21 años'
	WHEN t.Aniversario = 22 THEN '22 años'
	WHEN t.Aniversario = 23 THEN '23 años'
	WHEN t.Aniversario = 24 THEN '24 años'
	WHEN t.Aniversario = 25 THEN '25 años'
	WHEN t.Aniversario = 26 THEN '26 años'
	WHEN t.Aniversario = 27 THEN '27 años'
	WHEN t.Aniversario = 28 THEN '28 años'
	WHEN t.Aniversario = 29 THEN '29 años'
	WHEN t.Aniversario = 30 THEN '30 años'
	WHEN t.Aniversario = 31 THEN '31 años'
	WHEN t.Aniversario = 32 THEN '32 años'
	WHEN t.Aniversario = 33 THEN '33 años'
	WHEN t.Aniversario = 34 THEN '34 años'
	WHEN t.Aniversario = 35 THEN '35 años'
	WHEN t.Aniversario = 36 THEN '36 años'
	END AS Aniversario_texto
	INTO #tmp_aviso_aniversario
	FROM CTE_aniversario AS t
	LEFT JOIN Asistencia.aniversario AS an ON t.Aniversario = an.anio AND an.estado = 1
	WHERE an.ruta_imagen IS NOT NULL
		--AND ISNULL(t.correoEmpresa, '') != ''
		AND CONVERT(DATE, t.Comparar) = @aux_fecha
		AND t.Aniversario BETWEEN 1 AND 36;

	DECLARE	@aux_Aniversario TINYINT, @aux_Nombre VARCHAR(200), @aux_correoPersonal VARCHAR(200), @aux_correoJefe1 VARCHAR(200), @aux_rutaImagen VARCHAR(200), @aux_Aniversario_texto VARCHAR(200);

	DECLARE cursor_Aniversario CURSOR LOCAL FOR
		SELECT Aniversario, Nombre, mail_Trabajador, ISNULL(correoJefe1, '') AS correoJefe1, ruta_imagen, Aniversario_texto
		FROM #tmp_aviso_aniversario
		ORDER BY Nombre
	OPEN cursor_Aniversario
	FETCH NEXT FROM cursor_Aniversario INTO @aux_Aniversario, @aux_Nombre, @aux_correoPersonal, @aux_correoJefe1, @aux_rutaImagen, @aux_Aniversario_texto
	WHILE @@FETCH_STATUS = 0
	BEGIN

		SELECT @body = ' <p>
  <center>
    <font face="Lucida Calligraphy">
		<em>
			<p style="font-size: 17px"> Estimado/a
		</em> 
				<font face="Bahnschrift">@nombre_asociado</font>
		<em>
				¡Hoy cumplimos @Aniversario_texto de trabajo junto a ti! </p>
		</em>
    </font>
</p>
<img src="@ruta_imagen" width="750" height="550">'+ ' <center>'+ ' </>
	<font face="Lucida Calligraphy">
		<em>
			<p style="font-size: 20px">¡¡¡Gracias por ser parte de esta gran familia
		</em><font face="Bahnschrift">GRUPO KFC</font><em>!!!</p>
		</em> 
	</font>';

		SELECT @Aux_fecha_hora = GETDATE();
		--SELECT @Dirigido = '@aux_correoPersonal';
		--SELECT @C_Dirigido = '@aux_correoJefe1';
		SELECT @body = REPLACE (@body, '@nombre_asociado', @aux_Nombre) 
		SELECT @body = REPLACE (@body, '@aniversario_texto', @aux_Aniversario_texto)
		SELECT @body = REPLACE (@body, '@ruta_imagen', @aux_rutaImagen)
		--SELECT @body = REPLACE (@body, '@aux_profiler', @aux_descripcion)
		
		
		----SELECT @asunto = descripcion, @Dirigido = valor, @body = referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_Cambio';
		--SELECT * FROM Configuracion.parametros WHERE parametro = 'AL_Cambio';

		SELECT @asunto = 'Feliz Aniversario!!! ' + @aux_Nombre +'';

		DECLARE @TransactionName VARCHAR(30), @errorMensaje VARCHAR(1000); 
		SELECT @TransactionName = 'ValidaMail';  
		BEGIN TRAN @TransactionName;  
		BEGIN TRY
		IF @aux_correoPersonal != '' AND @aux_correoJefe1 != ''
		BEGIN
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
			VALUES ('A', 'Aniversarios', 'pa_aniversario', @asunto, @body, @Dirigido);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @asunto,
			@recipients = @Dirigido,
		 	@body_format= 'html',
			@body = @body;
		END
		ELSE
		BEGIN
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
			VALUES ('A', 'Aniversarios', 'pa_aniversario', @asunto, @body, @Dirigido);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @asunto,
			@recipients = @Dirigido,
			@body_format= 'html',
			@body = @body;
			COMMIT TRANSACTION  @TransactionName;
		END
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION @TransactionName;

			SELECT @errorMensaje = SUBSTRING(ERROR_PROCEDURE() + ' - ' + ERROR_MESSAGE() + ' - del correo: ' + @aux_correoPersonal + ' - nombre: ' + @aux_Nombre + ', ' + @aux_Aniversario_texto + ', ' + @aux_rutaImagen, 0, 999);

			INSERT DB_NOMKFC.Logs.log_envio_correo (fecha, correo, html, modulo, referencia_02, referencia_06)
			SELECT GETDATE(), @Dirigido, @body, 'Correo de notificación por Aniversario', SYSTEM_USER, @errorMensaje; 
			
			--COMMIT TRANSACTION  @TransactionName;
		END CATCH	

		FETCH NEXT FROM cursor_Aniversario INTO @aux_Aniversario, @aux_Nombre, @aux_correoPersonal, @aux_correoJefe1, @aux_rutaImagen, @aux_Aniversario_texto
	END
	CLOSE cursor_Aniversario
	DEALLOCATE cursor_Aniversario

	IF OBJECT_ID(N'tempdb..#tmp_aviso_aniversario', N'U') IS NOT NULL 
		DROP TABLE #tmp_aviso_aniversario

	SET NOCOUNT OFF;
END
