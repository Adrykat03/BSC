-- =============================================
-- Author:		Andrés Gómez
-- Create date: 15/06/2022
-- Description:	
-- =============================================
-- =============================================
-- Edit:		Mateo Alvear
-- Create date: 11/10/2022
-- Description:	Se envía la tabla como archivo adjunto para mejorar rendimiento.
-- =============================================

CREATE PROCEDURE [Avisos].[pa_calculosHorarios]

AS 
DECLARE

@nombre varchar(100),
@query1 varchar(6000),
@cuerpo NVARCHAR(MAX),
@Dirigido varchar(300),
@asunto varchar(300),
@copia varchar(100),
@body varchar(5000),
@HTML varchar(MAX),
@VARIABLE VARCHAR(50),
@w int=0,
@fecha_ini DATE ,
@fecha_fin DATE  

BEGIN
	
--***************************************************************--
-- Tabla temporal para las fechas del corte de nómina--

	DECLARE @tabla_fechas_corte AS TABLE(fecha_ini DATE, fecha_fin DATE)
	INSERT INTO @tabla_fechas_corte(fecha_ini, fecha_fin)
	SELECT FechaInicioNomina, GETDATE() FROM [Utilidades].[fn_fechasperiodonomina](GETDATE())
	SELECT @fecha_ini = fecha_ini, @fecha_fin = GETDATE() FROM @tabla_fechas_corte

	DECLARE @valida INT =0, @q varchar(max), @tab char(1) = CHAR(9);
-- Fin de la tabla temporal de las fechas del corte de nómina--    

	DECLARE @c1 INT
	SET @c1 = (select COUNT (1) from Asistencia.calculosHorarios WITH (NOLOCK) where fecha BETWEEN @fecha_ini AND @fecha_fin )

	DECLARE @c2 INT
	SET @c2 = (SELECT COUNT (1) from Asistencia.rel_trab_horarios WITH (NOLOCK) where fecha BETWEEN @fecha_ini AND @fecha_fin)

	IF OBJECT_ID(N'tempdb..##tmp_errores', N'U') IS NOT NULL
		DROP TABLE ##tmp_errores

	IF @c1 <> @c2
	BEGIN 

		; WITH CTE_tabla_cco (cco, descripcion, cadena)
		AS (
			SELECT COO
			, CCO_DESCRIPCION
			, DESCRIPCION_CLASE
			FROM Adam.[dbo].[FPV_AGR_COM_CLASE] WITH (NOLOCK)
			WHERE REFERENCIA_20 = 'SI'
				AND [STATUS] = 'ABIERTO' AND referencia_09 in ('DP02','DP01')
		),

		CTE_tablafecha (descripcion, cco, fecha)
		AS (
			SELECT E.cco, F.descripcion, e.fecha
			FROM Asistencia.rel_trab_horarios E WITH (NOLOCK) 
			INNER JOIN Catalogos.VW_CCO F ON E.cco = F.cco 
			INNER JOIN CTE_tabla_cco B on B.cco = E.cco
			INNER JOIN RRHH.trabajadoresDatosDiario DD WITH (NOLOCK) ON DD.codigo = E.codigo AND DD.fecha = E.fecha AND DD.cco = E.cco
			where not exists (select codigo from Asistencia.calculosHorarios WITH (NOLOCK) where codigo = E.codigo AND fecha = E.fecha AND cco = E.cco) 
			and ((SELECT COUNT(codigo) FROM Asistencia.calculosHorarios WITH (NOLOCK) WHERE cco = E.cco AND (fecha BETWEEN @fecha_ini AND @fecha_fin))
			<> (SELECT COUNT(codigo) FROM Asistencia.rel_trab_horarios WITH (NOLOCK) WHERE cco = E.cco AND (fecha BETWEEN @fecha_ini AND @fecha_fin)))
			and e.fecha BETWEEN @fecha_ini AND @fecha_fin
		),

		CTE_fecha (semana, fecha_ini, fecha_fin)
		AS (
			SELECT op.semana, op.fecha_ini, op.fecha_fin
			FROM Asistencia.periodos_operacionalesDet AS op WITH (NOLOCK)
			WHERE ((SELECT fecha_ini FROM @tabla_fechas_corte) BETWEEN op.fecha_ini AND op.fecha_fin
			OR (SELECT fecha_fin FROM @tabla_fechas_corte) BETWEEN op.fecha_ini AND op.fecha_fin)
			OR (op.fecha_ini >= (SELECT fecha_ini FROM @tabla_fechas_corte)
			AND op.fecha_fin <= (SELECT fecha_fin FROM @tabla_fechas_corte))
		)
		SELECT DISTINCT
						A.descripcion CCO,
						A.cco [CENTRO DE COSTOS],
						B.semana SEMANA,
						(SELECT 'Del ' + CONVERT(VARCHAR(10), fecha_ini, 105) + ' al ' + CONVERT(VARCHAR(10), fecha_fin, 105) FROM CTE_fecha WHERE semana = B.semana) [DIAS DE LA SEMANA]
						INTO ##tmp_errores FROM CTE_tablafecha A
						INNER JOIN CTE_fecha B ON A.fecha BETWEEN B.fecha_ini AND B.fecha_fin
						WHERE A.fecha BETWEEN @fecha_ini AND @fecha_fin
						ORDER BY  A.cco, B.semana 

		SELECT @Dirigido = valor, @asunto = descripcion, @HTML = referencia_06 FROM Configuracion.parametros WHERE parametro = 'AL_Calculo_Hor'
		
		IF (SELECT COUNT(1) FROM ##tmp_errores) > 0 
		BEGIN
			SELECT @q = 'SELECT '''''''' + CONVERT(varchar(20),e.CCO), e.[CENTRO DE COSTOS], e.[DIAS DE LA SEMANA] FROM ##tmp_errores e'
			BEGIN TRY
				select @HTML = REPLACE(@HTML, '@fecha', convert(varchar(12),GETDATE(),103)) 
				-- INSERT notificación consolidada
				INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
				VALUES ('A', 'Horarios', 'pa_calculosHorarios', @asunto, @HTML, @c2, @Dirigido, @fecha_ini, @fecha_fin);
				EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina',
				@recipients= @Dirigido, 
				--@recipients= 'pasante.nominadosec@kfc.com.ec',
				@subject = @asunto,
				@body_format= 'html',
				@execute_query_database = 'DB_NOMKFC',
				--@query=@q,
				--@attach_query_result_as_file = 1,
				--@query_attachment_filename = 'CCO CON ERRORES EN EL CALCULO DEL COSTO HORARIO POR SEMANA.csv',
				--@query_result_separator=@tab,
				--@query_result_no_padding=1,
				@body = @HTML
			END TRY
			BEGIN CATCH
				INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), @dirigido, NULL, @html, 'Calculo Costo Horario', 'Error al envíar correo')
			END CATCH
		END

		IF OBJECT_ID(N'tempdb..##tmp_errores', N'U') IS NOT NULL
			DROP TABLE ##tmp_errores
	END
END

