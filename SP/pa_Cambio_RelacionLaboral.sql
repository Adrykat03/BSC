
-- =============================================
-- Create:		Andrés Gómez
-- Create date:	16-06-2022
-- Description: Se envía un correo con la información 
--				del empleado cambiado de relación laboral
-- =============================================
-- =============================================
-- Edit:		Mateo Alvear
-- Create date:	16/09/2022
-- Description: Limpieza de codigo
-- =============================================

CREATE   procedure [Avisos].[pa_Cambio_RelacionLaboral]
@codigo VARCHAR(20),
@fecha_ini DATE,
@fecha_fin DATE,
@cont_ant varchar(3),
@cont_actual varchar(3)
AS
DECLARE
@body varchar(MAX),	
@Dirigido varchar(300),
@asunto varchar(300),
@nombre varchar (200),
@cco varchar (15),
@desc_cco varchar (250),
@contrato_actual_desc VARCHAR(100),
@contrato_anterior_desc VARCHAR(100),
@fecha_antiguedad date,
@genero varchar(10),
@saludo varchar(30),
@fecha_baja date
BEGIN				
	SELECT @Dirigido = valor, @asunto = descripcion, @body = referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_Cam_rel_lab';

	IF OBJECT_ID(N'tempdb..#temp_contratos', N'U') IS NOT NULL
				DROP TABLE #temp_contratos

	SELECT Tipo_Contrato, Desc_Tipo_Contrato INTO #temp_contratos FROM RRHH.vw_datosTrabajadores v GROUP BY v.Desc_Tipo_Contrato, v.Tipo_Contrato

	SELECT @nombre = nombre, @cco = CCO, @desc_cco = Desc_CCO, @fecha_antiguedad = fecha_antiguedad, @genero = Genero, @fecha_baja = COALESCE(Fecha_baja, Fecha_bajaIndice)
	FROM RRHH.vw_datosTrabajadores WHERE Codigo = @codigo

	IF @cont_ant IS NOT NULL
	BEGIN
		SELECT @contrato_actual_desc = Desc_Tipo_Contrato FROM #temp_contratos WHERE Tipo_Contrato = @cont_actual
		SELECT @contrato_anterior_desc = Desc_Tipo_Contrato FROM #temp_contratos WHERE Tipo_Contrato = @cont_ant
		IF @genero = 'Femenino'
		BEGIN
			SELECT @saludo = 'La asociada'
		END
		ELSE
		BEGIN
			SELECT @saludo = 'El asociado'
		END
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, GETDATE(),9) ) ;
		SELECT @body = REPLACE (@body, '@genero', ISNULL(@saludo,''))
		SELECT @body = REPLACE (@body, '@trabajador', ISNULL(@nombre,''))
		SELECT @body = REPLACE (@body, '@cedula', ISNULL(LEFT(@codigo,10),''))
		SELECT @body = REPLACE (@body, '@cco', ISNULL(@cco,''))
		SELECT @body = REPLACE (@body, '@desc_cco', ISNULL(@desc_cco,''))
		SELECT @body = REPLACE (@body, '@fecha_ant', CONVERT(VARCHAR(10), ISNULL(@fecha_antiguedad, '-'), 105))
		SELECT @body = REPLACE (@body, '@contrato_ant', ISNULL(@contrato_anterior_desc,''))
		SELECT @body = REPLACE (@body, '@contrato_actual', ISNULL(@contrato_actual_desc,''))
		SELECT @body = REPLACE (@body, '@fbaja', ISNULL(CONVERT(varchar(22), @fecha_baja, 105),'No tiene fecha de baja'))
		BEGIN TRY
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Cambios', 'pa_Cambio_RelacionLaboral', @asunto, @body, @Dirigido, @fecha_ini, @fecha_fin);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = @asunto,
			@recipients = @Dirigido,
			@body_format= 'html',
			@body = @body;
		END TRY
		BEGIN CATCH
			INSERT INTO db_nomkfc.logs.log_usuarios (id_usuario, fecha, descripcion, notas, operacion, ip, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06)
			select 'Adam', getdate(),'Error al enviar el correo de notificación del cambio de relación laboral del trabajador ' 
					+ LEFT(@codigo, 10) + ' con cco ' + @cco + ' _ ' + @desc_cco + ' y fecha de baja: ' + ISNULL(CONVERT(varchar(20), @fecha_baja, 105),'No tiene fecha de baja'),'',1,'','', 'pa_Cambio_RelacionLaboral',0,0,getdate(), '';
		END CATCH
	END
	IF OBJECT_ID(N'tempdb..#temp_contratos', N'U') IS NOT NULL
				DROP TABLE #temp_contratos
END
