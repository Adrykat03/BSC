
-- =============================================
-- Create:		Andrés Gómez
-- Create date:	17-06-2022
-- Description: Se envía un correo con la información 
--				del empleado que no tiene horarios en 
--				las ausencias y vacaciones
-- =============================================

-- =============================================
-- Edit:		Mateo Alvear
-- Create date:	12-09-2022
-- Description: Se filtran los horarios y marcajes mas a fondo
-- =============================================

CREATE PROCEDURE [Avisos].[pa_errorAusencia]

AS
declare

@HTML varchar(MAX),
@cont_ausencias INT = 0,
@cont_vacaciones INT = 0,
@fecha_ini DATE,
@fecha_fin DATE

BEGIN 

set language 'spanish' 
SET DATEFORMAT dmy;

	-- Tabla temporal para las fechas del corte de nómina--


	SELECT @fecha_ini = FechaInicioNomina, @fecha_fin = FechaFinNomina FROM  [Utilidades].[fn_fechasperiodonomina](GETDATE())

					-- Fin de la tabla temporal de las fechas del corte de nómina--  
					
	DECLARE @CTE_tabla_cco AS TABLE(cco VARCHAR(30), descripcion VARCHAR (100), cadena VARCHAR(50))

	INSERT INTO @CTE_tabla_cco (cco, descripcion, cadena)
		SELECT COO
		, CCO_DESCRIPCION
		, DESCRIPCION_CLASE
		FROM Adam.[dbo].[FPV_AGR_COM_CLASE]
		WHERE REFERENCIA_20 = 'SI'
			AND [STATUS] = 'ABIERTO' AND referencia_09 in ('DP02','DP01')
			
							----------------************AUSENCIAS***********------------
-------------------------------------- AUSENCIAS ------------------------------------------------------


IF OBJECT_ID(N'tempdb..#AUSENCIAS_TEMP', N'U') IS NOT NULL
	DROP TABLE #AUSENCIAS_TEMP

SELECT DISTINCT
	a.codigo,
	dt.Nombre,
	dt.CCO,
	dt.Desc_CCO,
	dt.Situacion,
	ta.descripcion,
	a.Fecha_Ini_Incapacidad, 
	a.Fecha_Fin_Incapacidad,
	a.fecha_fallecimientoCFoTR,
	a.Total_Dias_Perdidos,
	fpm.id_TipoCarga
	INTO #AUSENCIAS_TEMP
FROM ((Ausencias.Accidentes a
LEFT JOIN Ausencias.tipos_ausencias ta ON a.id_tipoAusencia = ta.id_tipoAusencia)
INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = a.Codigo)
INNER JOIN @CTE_tabla_cco cc ON cc.cco = dt.cco
LEFT JOIN Cargas.familiares_personas AS fpm ON a.Codigo = fpm.codigo AND fpm.id_TipoCarga = 1
WHERE 
	(a.Fecha_Ini_Incapacidad between @fecha_ini and @fecha_fin
    OR (a.Fecha_Ini_Incapacidad < @fecha_ini and a.Fecha_Fin_Incapacidad between @fecha_ini and @fecha_fin)
    OR (a.Fecha_Ini_Incapacidad < @fecha_ini and a.Fecha_Fin_Incapacidad > @fecha_fin))
	AND dt.Situacion = 'Activo'


DECLARE @ausencias AS TABLE 
(codigo varchar(50), 
nombre varchar(100), 
cco varchar(100),
desc_cco varchar(500), 
situacion varchar(100), 
descripcion varchar(100), 
fecha_ini date,
fecha_fin date,
fecha_f date,
dias VARCHAR(10),
observacion varchar(100))

IF OBJECT_ID(N'tempdb..#HORARIOS_TEMP', N'U') IS NOT NULL
		DROP TABLE #HORARIOS_TEMP
IF OBJECT_ID(N'tempdb..#MARCAJES_TEMP', N'U') IS NOT NULL
		DROP TABLE #MARCAJES_TEMP

DECLARE @fmin date, @fmax date
SELECT @fmin = MIN(a.Fecha_Ini_Incapacidad), @fmax = MAX(a.Fecha_Fin_Incapacidad) FROM #AUSENCIAS_TEMP a

SELECT rth.codigo, rth.fecha, rth.Observaciones, rth.notas, rth.id_motivos INTO #HORARIOS_TEMP
FROM Asistencia.rel_trab_horarios rth INNER JOIN #AUSENCIAS_TEMP a ON a.Codigo = rth.codigo
WHERE rth.fecha between @fmin and @fmax AND (rth.Observaciones in ('MATERNIDAD', 'PATERNIDAD','ENFERMEDAD GENERAL') OR rth.notas like 'AUSENCIA-%')


SELECT m.codigo_emp_equipo, m.fecha, m.referencia_06, m.id_motivos_ausencias, m.comentario INTO #MARCAJES_TEMP
FROM Asistencia.marcajes m INNER JOIN #AUSENCIAS_TEMP a ON a.Codigo = m.codigo_emp_equipo
WHERE m.fecha between @fmin and @fmax AND (m.referencia_06  in ('MATERNIDAD', 'PATERNIDAD','ENFERMEDAD GENERAL') OR m.id_motivos_ausencias = 'MO001A')

---------------- AUSENCIA HORARIOS - MATERNIDAD

INSERT INTO @ausencias
SELECT a.codigo, a.nombre, a.cco, a.Desc_CCO, a.situacion, a.descripcion, 
	   a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.fecha_fallecimientoCFoTR, a.Total_Dias_Perdidos, 'AUSENCIA MATERNIDAD - HORARIOS' 
		FROM #AUSENCIAS_TEMP a WHERE a.descripcion = 'MATERNIDAD'
			AND NOT EXISTS(SELECT 1 FROM #HORARIOS_TEMP rth WHERE rth.codigo = a.Codigo
							AND rth.fecha between a.Fecha_Ini_Incapacidad and a.Fecha_Fin_Incapacidad
							AND (rth.Observaciones = a.descripcion OR rth.notas = 'AUSENCIA-01')) ORDER BY Fecha_Ini_Incapacidad

---------------- AUSENCIA HORARIOS - PATERNIDAD

INSERT INTO @ausencias
SELECT a.codigo, a.nombre, a.cco,a.Desc_CCO, a.situacion, a.descripcion,
	   a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.fecha_fallecimientoCFoTR, a.Total_Dias_Perdidos, 'AUSENCIA PATERNIDAD - HORARIOS'
		FROM #AUSENCIAS_TEMP a WHERE a.descripcion = 'PATERNIDAD'
			AND NOT EXISTS(SELECT 1 FROM #HORARIOS_TEMP rth WHERE rth.codigo = a.codigo
							AND rth.fecha between a.Fecha_Ini_Incapacidad and a.Fecha_Fin_Incapacidad 
							AND (rth.Observaciones = a.descripcion or rth.notas = 'AUSENCIA-04')) ORDER BY Fecha_Ini_Incapacidad

---------------- AUSENCIA HORARIOS - ENFERMEDAD GENERAL

INSERT INTO @ausencias
SELECT a.codigo, a.nombre, a.cco,a.Desc_CCO, a.situacion, a.descripcion,
	   a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.fecha_fallecimientoCFoTR, a.Total_Dias_Perdidos, 'AUSENCIA ENFERMEDAD GENERAL - HORARIOS'
		FROM #AUSENCIAS_TEMP a WHERE a.descripcion = 'ENFERMEDAD GENERAL' 
			AND NOT EXISTS(SELECT 1 FROM #HORARIOS_TEMP rth WHERE rth.codigo = a.codigo
							AND rth.fecha between a.Fecha_Ini_Incapacidad and a.Fecha_Fin_Incapacidad
							AND(rth.Observaciones = a.descripcion or rth.notas = 'AUSENCIA-02')) ORDER BY Fecha_Ini_Incapacidad

---------------- AUSENCIA MARCAJE - MATERNIDAD

INSERT INTO @ausencias
SELECT a.codigo, a.nombre, a.cco, a.Desc_CCO, a.situacion, a.descripcion, 
	   a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.fecha_fallecimientoCFoTR, a.Total_Dias_Perdidos, 'AUSENCIA MATERNIDAD - MARCAJE' 
		FROM #AUSENCIAS_TEMP A WHERE a.descripcion = 'MATERNIDAD' 
			AND NOT EXISTS(SELECT 1 FROM #MARCAJES_TEMP m WHERE m.codigo_emp_equipo = a.Codigo
							AND m.fecha between a.Fecha_Ini_Incapacidad and a.Fecha_Fin_Incapacidad
							and (m.referencia_06 = 'MATERNIDAD' or (m.id_motivos_ausencias = 'MO001A' and a.descripcion = 'MATERNIDAD'))) 
		ORDER BY a.Fecha_Ini_Incapacidad

---------------- AUSENCIA MARCAJE - PATERNIDAD

INSERT INTO @ausencias
SELECT a.codigo, a.nombre, a.cco, a.Desc_CCO, a.situacion, a.descripcion, 
	   a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.fecha_fallecimientoCFoTR, a.Total_Dias_Perdidos, 'AUSENCIA PATERNIDAD - MARCAJE'
		FROM #AUSENCIAS_TEMP A WHERE a.descripcion = 'PATERNIDAD'
			AND NOT EXISTS(SELECT 1 FROM #MARCAJES_TEMP m WHERE m.codigo_emp_equipo = a.Codigo
							AND m.fecha between a.Fecha_Ini_Incapacidad and a.Fecha_Fin_Incapacidad
							AND(m.referencia_06 = 'PATERNIDAD' or (m.id_motivos_ausencias = 'MO001A' and a.descripcion = 'PATERNIDAD')))
		ORDER BY a.Fecha_Ini_Incapacidad

---------------- AUSENCIA MARCAJE - ENFERMEDAD GENERAL

INSERT INTO @ausencias
SELECT a.codigo, a.nombre, a.cco, a.Desc_CCO, a.situacion, a.descripcion, 
	   a.Fecha_Ini_Incapacidad, a.Fecha_Fin_Incapacidad, a.fecha_fallecimientoCFoTR, a.Total_Dias_Perdidos, 'AUSENCIA ENFERMEDAD GENERAL - MARCAJE'
		FROM #AUSENCIAS_TEMP A WHERE a.descripcion = 'ENFERMEDAD GENERAL' 
			AND NOT EXISTS(SELECT 1 FROM #MARCAJES_TEMP m WHERE m.codigo_emp_equipo = a.Codigo 
							AND m.fecha between a.Fecha_Ini_Incapacidad and a.Fecha_Fin_Incapacidad
							AND(m.referencia_06 = 'ENFERMEDAD GENERAL' or (m.id_motivos_ausencias = 'MO001A' and a.descripcion = 'ENFERMEDAD GENERAL')))
		ORDER BY a.Fecha_Ini_Incapacidad

----------------------------------------- CORREOS --------------------------------------------------------

DELETE FROM @ausencias WHERE fecha_f IS NOT NULL

DECLARE @destinatarios varchar(MAX) = (SELECT valor FROM Configuracion.parametros WHERE parametro = 'AL_Ausencia')

SELECT @cont_ausencias = COUNT(1) FROM @ausencias

	IF @cont_ausencias > 0
	BEGIN 
	SELECT @HTML = N'<style type="text/css">
						#box-table
						{
							font-family: "Calibri";
							font-size: 10px;
							text-align: center;
							border-collapse: collapse;
							border-top: 7px solid #9baff1;
							border-bottom: 7px solid #9baff1;
						}
						#box-table th
						{
							font-size: 11px;
							font-weight: normal;
							background: #b9c9fe;
							border-right: 2px solid #9baff1;
							border-left: 2px solid #9baff1;
							border-bottom: 2px solid #9baff1;
							color: #039;
						}
						#box-table td
						{
							border-right: 1px solid #aabcfe;
							border-left: 1px solid #aabcfe;
							border-bottom: 1px solid #aabcfe;
										  padding-top: 2px;
										  padding-bottom: 2px;
										  padding-left: 4px;
										  padding-right: 4px;
							color: #669;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
					  </style>'+	
						N'<H4><font color="SteelBlue">ERROR EN AUSENCIAS</H4>' +
						N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
						N'<H4><font color="SteelBlue">Trabajadores con error en las ausencias.</H4>'+
						N'<table id="box-table" >' +
						N'<tr><font color="Green">
						<th>CÉDULA</th>
						<th>NOMBRE</th>
						<th>CCO</th>
						<th>DESC CCO</th>
						<th>FECHA INICIO</th>
						<th>FECHA FIN</th>
						<th>TOTAL DIAS</th>
						<th>DESCRIPCION</th>
						<th>OBSERVACIÓN</th>
						</tr>' +
						CAST(
							(SELECT
									td = SUBSTRING (a.codigo,1,10),'', 
									td = a.Nombre,'',
									td = a.cco,'', 
									td = a.Desc_CCO,'',
									td = CONVERT(VARCHAR(12),a.fecha_ini, 103),'', 
									td = CONVERT(VARCHAR(12),a.fecha_fin,103),'',
									td = a.dias,'',
									td = a.descripcion,'',
									td = a.observacion
								FROM @ausencias a ORDER BY a.desc_cco, a.fecha_ini, a.nombre, a.observacion
								FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>' +
						N'<br/><br/>' +
						N'</body>' 

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Ausencias', 'pa_errorAusencia', 'ERROR EN AUSENCIAS', @HTML, @cont_ausencias, @destinatarios, @fecha_ini, @fecha_fin);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = 'ERROR EN AUSENCIAS',
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML	

	END
	ELSE
	BEGIN 
	SELECT @HTML = N'<style type="text/css">
						#box-table
						{
							font-family: "Calibri";
							font-size: 10px;
							text-align: center;
							border-collapse: collapse;
							border-top: 7px solid #9baff1;
							border-bottom: 7px solid #9baff1;
						}
						#box-table th
						{
							font-size: 11px;
							font-weight: normal;
							background: #b9c9fe;
							border-right: 2px solid #9baff1;
							border-left: 2px solid #9baff1;
							border-bottom: 2px solid #9baff1;
							color: #039;
						}
						#box-table td
						{
							border-right: 1px solid #aabcfe;
							border-left: 1px solid #aabcfe;
							border-bottom: 1px solid #aabcfe;
										  padding-top: 2px;
										  padding-bottom: 2px;
										  padding-left: 4px;
										  padding-right: 4px;
							color: #669;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
					  </style>'+	
						N'<H4><font color="SteelBlue">ERROR EN AUSENCIAS</H4>' +
						N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
						N'<H4><font color="SteelBlue">No se encontraron trabajadores con error en las ausencias.</H4>'
						
		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Ausencias', 'pa_errorAusencia', 'ERROR EN AUSENCIAS', @HTML, @cont_ausencias, @destinatarios, @fecha_ini, @fecha_fin);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = 'ERROR EN AUSENCIAS',
		@recipients = @destinatarios,
	   @body_format= 'html',
		@body = @HTML	

	END

	 
	----------------************VACACIONES***********------------
	IF OBJECT_ID(N'tempdb..#VACACIONES_TEMP', N'U') IS NOT NULL
		DROP TABLE #VACACIONES_TEMP

	SELECT DISTINCT
		A.codigo, 
		dt.Nombre,
		dt.Situacion,
		dt.CCO,
		dt.Desc_CCO,
		a.fecha_inicio, 
		a.fecha_fin, 
		a.dias 
		INTO #VACACIONES_TEMP
			FROM Vacacion.Solicitud_vacaciones a
			inner join RRHH.vw_datosTrabajadores dt on dt.Codigo = a.codigo
			inner join @CTE_tabla_cco c on c.cco = dt.CCO
			WHERE 
				(a.fecha_inicio between @fecha_ini and @fecha_fin
				OR (a.fecha_inicio < @fecha_ini and a.fecha_fin between @fecha_ini and @fecha_fin)
				OR (a.fecha_inicio < @fecha_ini and a.fecha_fin > @fecha_fin))
				AND dt.Situacion = 'Activo' AND a.estado IN (3,1)


	-------------------------------------------	VACACIONES -------------------------------------------------------------


	DECLARE @vacaciones AS TABLE(
	codigo varchar(50), 
	nombre varchar(200),
	cco varchar(200),
	desc_cco varchar(500),
	fecha_ini VARCHAR(50), 
	fecha_fin VARCHAR(50), 
	dias VARCHAR(10), 
	tipo varchar(30))

	SET @destinatarios = (SELECT valor FROM Configuracion.parametros WHERE parametro = 'AL_Vacacion')

	SELECT @fmin = MIN(v.fecha_inicio), @fmax = MAX(v.fecha_fin) FROM #VACACIONES_TEMP v

	INSERT INTO #HORARIOS_TEMP SELECT rth.codigo, rth.fecha, rth.Observaciones, rth.notas, rth.id_motivos 
	FROM Asistencia.rel_trab_horarios rth INNER JOIN #VACACIONES_TEMP v ON v.codigo = rth.codigo 
	WHERE rth.fecha between @fmin and @fmax and rth.notas in ('Vacaciones', 'Vacaciones Reprogramadas') and rth.id_motivos IN ('MO000', 'VACRE')
	INSERT INTO #MARCAJES_TEMP SELECT m.codigo_emp_equipo, m.fecha, m.referencia_06, m.id_motivos_ausencias, m.comentario
	FROM Asistencia.marcajes m INNER JOIN #VACACIONES_TEMP v ON v.codigo = m.codigo_emp_equipo 
	WHERE m.fecha between @fmin and @fmax and m.comentario in ('Vacaciones', 'Vacaciones Reprogramadas') and m.id_motivos_ausencias = 'MO000'

	---------------- VACACIONES - HORARIOS

	INSERT INTO @vacaciones
	SELECT a.codigo, a.Nombre, a.cco, a.Desc_CCO, a.fecha_inicio, a.fecha_fin, a.dias, 'VACACIONES - HORARIOS'
			FROM #VACACIONES_TEMP a
				WHERE NOT EXISTS(SELECT 1 FROM #HORARIOS_TEMP rth WHERE rth.codigo = a.Codigo 
								AND rth.fecha between a.fecha_inicio and a.fecha_fin
								and rth.notas in ('Vacaciones', 'Vacaciones Reprogramadas') AND rth.id_motivos IN ('MO000', 'VACRE'))

	---------------- VACACIONES - MARCAJES

	INSERT INTO @vacaciones
	SELECT a.codigo, a.Nombre, a.cco, a.Desc_CCO, a.fecha_inicio, a.fecha_fin, a.dias, 'VACACIONES - MARCAJES' 
			FROM #VACACIONES_TEMP a 
				WHERE NOT EXISTS(SELECT 1 FROM #MARCAJES_TEMP m WHERE m.codigo_emp_equipo = a.Codigo 
								AND m.fecha between a.fecha_inicio and a.fecha_fin
								and m.comentario in ('Vacaciones', 'Vacaciones Reprogramadas') and m.id_motivos_ausencias = 'MO000')
					  AND NOT EXISTS(SELECT 1 FROM #AUSENCIAS_TEMP a2 WHERE a.Codigo = a2.Codigo AND a2.Fecha_Ini_Incapacidad BETWEEN a.fecha_inicio AND a.fecha_fin)

	DECLARE @haspv int = 0
	SELECT @cont_vacaciones = COUNT(1) FROM @vacaciones
	IF @cont_vacaciones > 0
	BEGIN
		SELECT @haspv = COUNT(1) FROM @vacaciones WHERE tipo = 'VACACIONES - PROGRAMACIÓN'
		SELECT @HTML = N'<style type="text/css">
						#box-table
						{
							font-family: "Calibri";
							font-size: 11px;
							text-align: center;
							border-collapse: collapse;
							border-top: 7px solid #9baff1;
							border-bottom: 7px solid #9baff1;
						}
						#box-table th
						{
							font-size: 10px;
							font-weight: normal;
							background: #b9c9fe;
							border-right: 2px solid #9baff1;
							border-left: 2px solid #9baff1;
							border-bottom: 2px solid #9baff1;
							color: #039;
						}
						#box-table td
						{
							border-right: 1px solid #aabcfe;
							border-left: 1px solid #aabcfe;
							border-bottom: 1px solid #aabcfe;
										  padding-top: 2px;
										  padding-bottom: 2px;
										  padding-left: 4px;
										  padding-right: 4px;
							color: #669;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
					</style>'
					+	
					N'<H4><font color="SteelBlue">ERROR EN VACACIONES</H4>' +
					N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
					N'<H4><font color="SteelBlue">Trabajadores con error en las vacaciones.</H4>'+
					CASE WHEN @haspv <> 0 THEN N'<H5><font color="SteelBlue">VACACIONES - PROGRAMACIÓN => Faltan fechas en programación de vacaciones</H5>' ELSE '' END+
					N'<table id="box-table" >' +
					N'<tr><font color="Green">
					<th>CÉDULA</th>
					<th>NOMBRE</th>
					<th>CCO</th>
					<th>DESC CENTRO DE COSTO</th>
					<th>FECHA INICIO</th>
					<th>FECHA FIN</th>
					<th>TOTAL DIAS</th>
					<th>OBSERVACIÓN</th>
					</tr>' +
					CAST(
						(SELECT
							td = SUBSTRING (v.codigo,1,10),'', 
							td = v.Nombre,'',
							td = v.CCO,'', 
							td = v.Desc_CCO,'',
							td = CONVERT(VARCHAR(12),v.fecha_ini, 103),'', 
							td = CONVERT(VARCHAR(12),v.fecha_fin ,103),'',
							td = v.dias,'',
							td = v.tipo
						FROM @vacaciones v ORDER BY v.desc_cco, v.fecha_ini, v.nombre, v.tipo
						FOR XML PATH('tr'), TYPE) AS varchar(max)) +
					N'</table>' +
					N'<br/><br />'+
					N' </body>' 

			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Ausencias', 'pa_errorAusencia', 'ERROR EN VACACIONES', @HTML, @haspv, @destinatarios, @fecha_ini, @fecha_fin);
			EXEC msdb.dbo.Sp_send_dbmail

			@profile_name = 'Informacion_Nomina',
			@Subject = 'ERROR EN VACACIONES',
			@recipients = @destinatarios,
			@body_format= 'html',
			@body = @HTML
	END
	ELSE
	BEGIN
		SELECT @HTML = N'<style type="text/css">
						#box-table
						{
							font-family: "Calibri";
							font-size: 11px;
							text-align: center;
							border-collapse: collapse;
							border-top: 7px solid #9baff1;
							border-bottom: 7px solid #9baff1;
						}
						#box-table th
						{
							font-size: 10px;
							font-weight: normal;
							background: #b9c9fe;
							border-right: 2px solid #9baff1;
							border-left: 2px solid #9baff1;
							border-bottom: 2px solid #9baff1;
							color: #039;
						}
						#box-table td
						{
							border-right: 1px solid #aabcfe;
							border-left: 1px solid #aabcfe;
							border-bottom: 1px solid #aabcfe;
										  padding-top: 2px;
										  padding-bottom: 2px;
										  padding-left: 4px;
										  padding-right: 4px;
							color: #669;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
					</style>'
					+	
					N'<H4><font color="SteelBlue">ERROR EN VACACIONES</H4>' +
					N'<H4><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H4>'+
					N'<H4><font color="SteelBlue">No se encontraron trabajadores con error en las vacaciones.</H4>'

			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Ausencias', 'pa_errorAusencia', 'ERROR EN VACACIONES', @HTML, @haspv, @destinatarios, @fecha_ini, @fecha_fin);
			EXEC msdb.dbo.Sp_send_dbmail
			@profile_name = 'Informacion_Nomina',
			@Subject = 'ERROR EN VACACIONES',
			@recipients = @destinatarios,
			@body_format= 'html',
			@body = @HTML
	END
	 
	IF OBJECT_ID(N'tempdb..#AUSENCIAS_TEMP', N'U') IS NOT NULL
		DROP TABLE #AUSENCIAS_TEMP
	IF OBJECT_ID(N'tempdb..#VACACIONES_TEMP', N'U') IS NOT NULL
		DROP TABLE #VACACIONES_TEMP
	IF OBJECT_ID(N'tempdb..#HORARIOS_TEMP', N'U') IS NOT NULL
		DROP TABLE #HORARIOS_TEMP
	IF OBJECT_ID(N'tempdb..#MARCAJES_TEMP', N'U') IS NOT NULL
		DROP TABLE #MARCAJES_TEMP
END


