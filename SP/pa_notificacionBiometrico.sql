
/*

=============================================
  
Author:			Jimmy Cazaro
Create date:	17-07-2024
Description:	Notifica la desconexion del dispositivo biometrico del Sistema Consola DIEL
				- Proceso con servidor vinculado

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_notificacionBiometrico]
@aux_opcion TINYINT,
@aux_cco VARCHAR(15),
@aux_fecha VARCHAR(15),
@aux_hora VARCHAR(15)
AS
DECLARE
@var_correo_query1 varchar(6000),
@var_correo_cuerpo NVARCHAR(MAX),
@var_correo_Dirigido varchar(300),
@var_correo_asunto varchar(300),
@var_correo_copia_oculta varchar(500),
@var_correo_body varchar(MAX),
@var_correo_w int = 0
BEGIN
	SET LANGUAGE 'Spanish';
	SET DATEFORMAT ymd;
	SET DATEFIRST 1;
	DECLARE @aux_fecha_hora DATETIME = GETDATE();
	--SELECT @aux_fecha_hora
	/* 2024-07-17 11:16:43.340 */
	DECLARE @ad_cor_analista VARCHAR(250) = '', @ad_cor_cco VARCHAR(15) = '', @ad_cor_descripcioncco VARCHAR(250) = '', @aux_modulo VARCHAR(2000), @aux_referencia_06 VARCHAR(MAX) = '';

 
	IF (@aux_opcion = 1)
	BEGIN
		SELECT @aux_modulo = 'Correos Biometricos Apagados, Notificación biométrico (Sistema Consola DIEL)';
	 	SELECT @var_correo_copia_oculta = 'sabrina.chinchin@kfc.com.ec;patricia.flores@kfc.com.ec;pamela.naranjo@kfc.com.ec';

		/* Correos Biometricos Apagados */
		SELECT @var_correo_asunto = descripcion, /*valor,*/ @var_correo_body = referencia_06 FROM Configuracion.parametros WITH (NOLOCK) WHERE parametro = 'MAilBIOAP      '; -- referencia_06 LIKE '%NOTIFICACION ESTADO EQUIPO BIOMETRICO%'

		IF OBJECT_ID(N'tempdb..#tmp_AnalistaCCO', N'U') IS NOT NULL
			DROP TABLE #tmp_AnalistaCCO

		SELECT LTRIM(RTRIM(Configuracion.fn_correosVariosRemitentesContactoTiendas(v.clase_nomina))) AS analista
		, LTRIM(RTRIM(v.cco)) AS cco
		, LTRIM(RTRIM(v.descripcion)) AS descripcion
		INTO #tmp_AnalistaCCO
		FROM Catalogos.VW_CCO AS v
		WHERE v.cco = @aux_cco ; --COLLATE SQL_Latin1_General_CP1_CI_AS;

		SELECT @ad_cor_analista = analista, @ad_cor_cco = cco, @ad_cor_descripcioncco = descripcion FROM #tmp_AnalistaCCO;
		
		--IF (SELECT COUNT(cco) AS Existe FROM #tmp_AnalistaCCO) > 0
		IF (SELECT COUNT(cco) FROM #tmp_AnalistaCCO) > 0
		BEGIN
			BEGIN TRY

				SELECT @var_correo_body = REPLACE (@var_correo_body, '@CCO', @ad_cor_descripcioncco); 		
				SELECT @var_correo_body = REPLACE (@var_correo_body, '@fecha', @aux_fecha);
				SELECT @var_correo_body = REPLACE (@var_correo_body, '@hora', @aux_hora);
				print 'envia correo';
				--IF @ad_cor_descripcioncco IS NOT NULL AND @ad_cor_analista IS NOT NULL 
				IF (ISNULL(@ad_cor_descripcioncco, '') <> '' AND ISNULL(@ad_cor_analista, '') <> '')
				--SELECT @HTML = @htmlE + ' ' +@htmlGeneral 
				BEGIN
					-- INSERT notificación consolidada
					INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, destinatariosCc)
					VALUES ('A', 'Biométricos', 'pa_notificacionBiometrico', @var_correo_asunto, @var_correo_body, @ad_cor_analista, @var_correo_copia_oculta);
					EXEC msdb.dbo.sp_send_dbmail 
						@profile_name ='Informacion_Nomina',
					 	@recipients = @ad_cor_analista, 
						@blind_copy_recipients = @var_correo_copia_oculta,
						@importance = 'High',
						@subject = @var_correo_asunto,
						@body = @var_correo_body,
						@body_format = 'HTML' ;  

				 	END
			END TRY 
			BEGIN CATCH
				 
				SELECT	@aux_fecha_hora = GETDATE(), 
						@aux_referencia_06 = 'ErrorNumber: ' + CONVERT(VARCHAR(16), ERROR_NUMBER()) +
											', ErrorSate: ' + CONVERT(VARCHAR(16), ERROR_STATE()) + 
											', ErrorSeverity: ' + CONVERT(VARCHAR(16), ERROR_SEVERITY()) + 
											', ErrorProcedure: ' + ISNULL(ERROR_PROCEDURE(), '') + 
											', ErrorLine: ' + CONVERT(VARCHAR(16), ERROR_LINE()) +
											', ErrorMessage: ' + ISNULL(ERROR_MESSAGE(), '');

				--SELECT @aux_fecha_hora = GETDATE();
				--select * from Logs.log_envio_correo

				/* insercion de log cuando existe error */
				INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02, referencia_06) VALUES (@aux_fecha_hora, @ad_cor_analista, @var_correo_copia_oculta, @var_correo_body, @aux_modulo, (@aux_cco + ' -- ' + @ad_cor_descripcioncco), @aux_referencia_06);
			END CATCH
		END


		IF OBJECT_ID(N'tempdb..#tmp_AnalistaCCO', N'U') IS NOT NULL
			DROP TABLE #tmp_AnalistaCCO
	END
END



