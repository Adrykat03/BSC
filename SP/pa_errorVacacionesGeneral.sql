
-- =============================================
-- Create:		Mateo Alvear
-- Create date:	12-09-2022
-- Description: Se comprueba que las solicitudes de vacación
--				estén correctas en las 4 tablas de vacación
-- =============================================

-- =============================================
-- Edit:		Mateo Alvear
-- Create date:	10-11-2022
-- Description: Se corrige un error que hacia que salten fechas
--				faltantes si el id de la solicitud era diferente
--				a alguna fecha en preprogramacion, se agrega una consulta
--				para revisar si la preprogramacion tiene id diferente de la solicitud
-- =============================================

CREATE PROCEDURE [Avisos].[pa_errorVacacionesGeneral]
AS
DECLARE
@fi DATE,
@ff DATE

BEGIN 
SET NOCOUNT ON;

set language 'spanish' 
SET DATEFORMAT dmy;


	SELECT @fi = '2022-01-01', @ff = GETDATE()

	IF OBJECT_ID(N'tempdb..#vacaciones_svp', N'U') IS NOT NULL
		DROP TABLE #vacaciones_svp
	IF OBJECT_ID(N'tempdb..#vacaciones_pv', N'U') IS NOT NULL
		DROP TABLE #vacaciones_pv
	IF OBJECT_ID(N'tempdb..#tmpv1', N'U') IS NOT NULL
		DROP TABLE #tmpv1
	IF OBJECT_ID(N'tempdb..#tmpv3', N'U') IS NOT NULL
		DROP TABLE #tmpv3
	IF OBJECT_ID(N'tempdb..#tmpvs1', N'U') IS NOT NULL
		DROP TABLE #tmpvs1
	IF OBJECT_ID(N'tempdb..#tmp_errores_saldos', N'U') IS NOT NULL
		DROP TABLE #tmp_errores_saldos
	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
		DROP TABLE #tmp_errores
	IF OBJECT_ID(N'tempdb..#tmp_errores2', N'U') IS NOT NULL
		DROP TABLE #tmp_errores2
	IF OBJECT_ID(N'tempdb..#tmp_datos', N'U') IS NOT NULL
		DROP TABLE #tmp_datos
	IF OBJECT_ID(N'tempdb..#saldos', N'U') IS NOT NULL
		DROP TABLE #saldos
	IF OBJECT_ID(N'tempdb..#saldos_s', N'U') IS NOT NULL
		DROP TABLE #saldos_s
	IF OBJECT_ID(N'tempdb..#error_hueco', N'U') IS NOT NULL
		DROP TABLE #error_hueco
	IF OBJECT_ID(N'tempdb..#error_massaldos', N'U') IS NOT NULL
		DROP TABLE #error_massaldos
	IF OBJECT_ID(N'tempdb..#error_masPorCiclo', N'U') IS NOT NULL
		DROP TABLE #error_masPorCiclo

	----------------------------------------------------------------------------------------------- TABLAS TEMPORALES

	SELECT sv.codigo, CONVERT(VARCHAR(20),sv.fecha_inicio,105)fecha_inicio,CONVERT(VARCHAR(20),sv.fecha_fin,105)fecha_fin,sv.dias,sv.estado,
	svp.trabajador SVPTrabajador, svp.ciclo_laboral SVPCiclo, svp.tiempo_prog_vac SVPTiempo, svp.fecha_ini_per_vac SVPIni, 
	svp.fecha_fin_per_vac SVPFin, svp.situacion_programa SVPEstado, dt.Compania
	INTO #vacaciones_svp FROM Vacacion.Solicitud_vacaciones sv WITH(NOLOCK)
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = sv.codigo AND dt.Situacion = 'Activo'
	INNER JOIN Vacacion.Solicitud_Vacaciones_Preprogramacion svp WITH(NOLOCK) ON LEFT(sv.codigo,10) = svp.trabajador AND svp.fecha_ini_per_vac BETWEEN sv.fecha_inicio AND sv.fecha_fin AND dt.Compania = svp.compania
	WHERE sv.fecha_inicio BETWEEN @fi and @ff

	SELECT sv.codigo, CONVERT(VARCHAR(20),sv.fecha_inicio,105)fecha_inicio,CONVERT(VARCHAR(20),sv.fecha_fin,105)fecha_fin,sv.dias,sv.estado,
	pv.trabajador PVTrabajador, pv.ciclo_laboral PVCiclo, pv.tiempo_prog_vac PVTiempo, pv.fecha_ini_per_vac PVIni, pv.fecha_fin_per_vac PVFin,
	pv.situacion_programa PVEstado, dt.Compania
	INTO #vacaciones_pv FROM Vacacion.Solicitud_vacaciones sv WITH(NOLOCK)
	INNER JOIN RRHH.vw_datosTrabajadores dt WITH(NOLOCK) ON dt.Codigo = sv.codigo AND dt.Situacion = 'Activo'
	INNER JOIN Adam.dbo.programacion_vacaciones pv WITH(NOLOCK) ON pv.trabajador = LEFT(sv.codigo,10) AND pv.fecha_ini_per_vac BETWEEN sv.fecha_inicio AND sv.fecha_fin AND dt.Compania = pv.compania
	WHERE sv.fecha_inicio BETWEEN @fi and @ff

	SELECT codigo, ciclo_laboral, SUM(pv2.tiempo_prog_vac) Suma, pv.Compania INTO #tmpv3 FROM #vacaciones_pv pv
	INNER JOIN Adam.dbo.programacion_vacaciones pv2 WITH(NOLOCK) ON pv2.trabajador = pv.PVTrabajador AND pv2.ciclo_laboral = pv.PVCiclo AND pv2.situacion_programa = PVEstado AND pv2.compania = pv.Compania
	WHERE pv2.situacion_programa = 3 GROUP BY codigo, fecha_inicio, pv2.ciclo_laboral, pv.Compania ORDER BY codigo

	SELECT codigo, ciclo_laboral, SUM(pv2.tiempo_prog_vac) Suma, pv.Compania INTO #tmpv1 FROM #vacaciones_pv pv
	INNER JOIN Adam.dbo.programacion_vacaciones pv2 WITH(NOLOCK) ON pv2.trabajador = pv.PVTrabajador AND pv2.ciclo_laboral = pv.PVCiclo AND pv2.situacion_programa = PVEstado AND pv2.compania = pv.Compania
	WHERE pv2.situacion_programa = 1 GROUP BY codigo, fecha_inicio, pv2.ciclo_laboral, pv.Compania ORDER BY codigo

	SELECT codigo, ciclo_laboral, SUM(pv2.tiempo_prog_vac) Suma, pv.Compania INTO #tmpvs1 FROM #vacaciones_svp pv
	INNER JOIN  Vacacion.Solicitud_Vacaciones_Preprogramacion pv2 WITH(NOLOCK) ON pv2.trabajador = pv.SVPTrabajador AND pv2.ciclo_laboral = pv.SVPCiclo AND pv2.situacion_programa = SVPEstado AND pv2.compania = pv.Compania
	WHERE pv2.situacion_programa = 1 GROUP BY codigo, fecha_inicio, pv2.ciclo_laboral, pv.Compania ORDER BY codigo

	-------------------------------------------------------------- ERRORES SOLICITUD Y PROGRAMACION

	SELECT DISTINCT CONVERT(VARCHAR(50),'PROGRAMACION - SOLICITUD') Error, pv.codigo, pv.Compania, pv.fecha_inicio, pv.fecha_fin, pv.dias, pv.estado, pv.PVCiclo Ciclo
	INTO #tmp_errores FROM #vacaciones_pv pv
	WHERE pv.dias <> (SELECT SUM(pv2.PVTiempo) FROM #vacaciones_pv pv2 WHERE pv2.codigo = pv.codigo AND pv.fecha_inicio = pv2.fecha_inicio)
	INSERT INTO #tmp_errores
	SELECT DISTINCT 'PREPROGRAMACIÓN - SOLICITUD' Error, svp.codigo, svp.Compania, svp.fecha_inicio, svp.fecha_fin, svp.dias, svp.estado, svp.SVPCiclo Ciclo FROM #vacaciones_svp svp
	WHERE svp.dias <> (SELECT SUM(svp2.SVPTiempo) FROM #vacaciones_svp svp2 WHERE svp2.codigo = svp.codigo AND svp.fecha_inicio = svp2.fecha_inicio)
	
	SELECT DISTINCT CONVERT(VARCHAR(50),'SOLICITUD SIN PROGRAMACION') Error, pv.* INTO #tmp_errores2 FROM Vacacion.Solicitud_vacaciones pv
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = pv.codigo AND dt.Fecha_bajaIndice IS NULL AND dt.Fecha_baja IS NULL
	WHERE pv.fecha_inicio >= @fi AND pv.estado <> 0
	AND ((SELECT COUNT(1) FROM Adam.dbo.programacion_vacaciones svp 
	WHERE svp.trabajador = LEFT(pv.codigo, 10)  AND svp.compania = RIGHT(pv.codigo,2) AND svp.fecha_ini_per_vac BETWEEN pv.fecha_inicio and pv.fecha_fin) = 0)
	UNION
	SELECT DISTINCT 'SOLICITUD SIN PREPROGRAMACION' Error, pv.* FROM Vacacion.Solicitud_vacaciones pv
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = pv.codigo AND dt.Fecha_bajaIndice IS NULL AND dt.Fecha_baja IS NULL
	WHERE pv.fecha_inicio >= @fi AND pv.estado <> 0
	AND ((SELECT COUNT(1) FROM Vacacion.solicitud_vacaciones_preprogramacion svp3 
	WHERE svp3.trabajador = LEFT(pv.codigo,10) AND svp3.compania = RIGHT(pv.codigo,2) AND svp3.fecha_ini_per_vac BETWEEN pv.fecha_inicio AND pv.fecha_fin) = 0)
	
	INSERT INTO #tmp_errores
	SELECT DISTINCT 'PREPROGRAMACIÓN - PROGRAMACIÓN F' Error, pv.codigo, pv.Compania, pv.fecha_inicio, pv.fecha_fin, pv.dias, pv.estado, pv.SVPCiclo FROM #vacaciones_svp pv
	WHERE(SELECT COUNT(1) FROM #vacaciones_pv svp WHERE svp.codigo = pv.codigo AND svp.PVIni = pv.SVPIni) = 0
	INSERT INTO #tmp_errores
	SELECT DISTINCT 'PREPROGRAMACIÓN - PROGRAMACIÓN F' Error, pv.codigo, pv.Compania, pv.fecha_inicio, pv.fecha_fin, pv.dias, pv.estado, pv.PVCiclo FROM #vacaciones_pv pv
	WHERE (SELECT COUNT(1) FROM #vacaciones_svp svp WHERE svp.codigo = pv.codigo AND svp.SVPIni = pv.PVIni) = 0
	INSERT INTO #tmp_errores
	SELECT DISTINCT 'PREPROGRAMACIÓN - PROGRAMACIÓN E' Error, pv.codigo, pv.Compania, pv.fecha_inicio, pv.fecha_fin, pv.dias, pv.estado, pv.SVPCiclo FROM #vacaciones_svp pv
	WHERE (SELECT COUNT(1) FROM #vacaciones_pv svp WHERE svp.codigo = pv.codigo AND svp.PVIni = pv.SVPIni AND svp.PVEstado <> pv.SVPEstado) > 0

	INSERT INTO #tmp_errores
	SELECT 'NO TIENE SOLICITUD' Error, dt.Codigo, dt.Compania,
	ISNULL(CONVERT(VARCHAR(20),sv.fecha_inicio,105),'-'),
	ISNULL(CONVERT(VARCHAR(20),sv.fecha_fin,105),'-'),
	ISNULL(sv.dias,'0'),
	ISNULL(sv.estado,'0'),
	svp.ciclo_laboral
	FROM Vacacion.Solicitud_Vacaciones_Preprogramacion svp 
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Trabajador = svp.trabajador AND dt.Compania = svp.compania 
	LEFT JOIN Vacacion.Solicitud_vacaciones sv ON svp.id = sv.id 
	WHERE sv.id IS NULL

	INSERT INTO #tmp_errores
	SELECT 'SOLICITUD - PREPROGRAMACION E' Error, sv.codigo, svp.Compania, sv.fecha_inicio, sv.fecha_fin, sv.dias, sv.estado, svp.ciclo_laboral
	FROM Vacacion.Solicitud_vacaciones sv INNER JOIN Vacacion.Solicitud_Vacaciones_Preprogramacion svp ON sv.id = svp.id
	WHERE estado <> svp.situacion_programa
	
	INSERT INTO #tmp_errores
	SELECT 'SOLICITUD - PROGRAMACION E' Error, sv.codigo, pv.Compania, sv.fecha_inicio, sv.fecha_fin, sv.dias, sv.estado, pv.ciclo_laboral
	FROM Vacacion.Solicitud_vacaciones sv INNER JOIN Adam.dbo.programacion_vacaciones pv
	ON LEFT(sv.codigo, 10) = pv.trabajador AND RIGHT(sv.codigo,2) = pv.compania AND pv.fecha_ini_per_vac BETWEEN sv.fecha_inicio AND sv.fecha_fin
	WHERE sv.estado <> pv.situacion_programa

	INSERT INTO #tmp_errores 
	SELECT 'SOLICITUD - PREPROGRAMACION ID' Error, sv.codigo, pv.Compania, sv.fecha_inicio, sv.fecha_fin, sv.dias, sv.estado, pv.ciclo_laboral
	FROM Vacacion.Solicitud_vacaciones sv INNER JOIN Vacacion.Solicitud_Vacaciones_Preprogramacion pv
	ON LEFT(sv.codigo, 10) = pv.trabajador AND RIGHT(sv.codigo,2) = pv.compania AND pv.fecha_ini_per_vac BETWEEN sv.fecha_inicio AND sv.fecha_fin
	WHERE sv.id <> pv.id

	------------------------------------------------------------- ERRORES SALDOS

	SELECT DISTINCT CONVERT(VARCHAR(50),'SALDOS - PROGRAMACION 3') Error, tv.codigo, tv.ciclo_laboral, tv.suma, tv.Compania, pv2.vac_disfrutadas, pv2.vac_programadas
	INTO #tmp_errores_saldos FROM #tmpv3 tv INNER JOIN Adam.dbo.saldos_vacaciones pv2 with (nolock) ON pv2.trabajador = LEFT(tv.codigo, 10) AND pv2.ciclo_laboral = tv.ciclo_laboral AND tv.compania = pv2.compania
	WHERE (pv2.vac_disfrutadas NOT IN (Suma/2, Suma/3, Suma)) ORDER BY tv.codigo
	INSERT INTO #tmp_errores_saldos
	SELECT DISTINCT 'SALDOS - PROGRAMACIÓN 1' Error, tv.codigo, tv.ciclo_laboral, tv.suma, tv.Compania, pv2.vac_disfrutadas, pv2.vac_programadas 
	FROM #tmpv1 tv INNER JOIN Adam.dbo.saldos_vacaciones pv2 with (nolock) ON pv2.trabajador = LEFT(tv.codigo, 10) AND pv2.ciclo_laboral = tv.ciclo_laboral AND tv.compania = pv2.compania
	WHERE (pv2.vac_programadas NOT IN (Suma/2, Suma/3, Suma)) ORDER BY tv.codigo 
	INSERT INTO #tmp_errores_saldos
	SELECT 'SALDOS - PREPROGRAMACIÓN 1' Error, tv.codigo, tv.ciclo_laboral, tv.suma, tv.Compania, pv2.vac_disfrutadas, pv2.vac_programadas 
	FROM #tmpvs1 tv INNER JOIN Adam.dbo.saldos_vacaciones pv2 with (nolock) ON pv2.trabajador = LEFT(tv.codigo, 10) AND pv2.ciclo_laboral = tv.ciclo_laboral AND tv.compania = pv2.compania
	WHERE (pv2.vac_programadas NOT IN (Suma/2, Suma/3, Suma)) ORDER BY tv.codigo 

	-------------------------------------------------------------- VACACIONES CON HUECOS EN CICLOS

	SELECT * INTO #tmp_datos FROM RRHH.vw_datosTrabajadores WHERE Situacion = 'Activo'

	SELECT sv.*, dt.Nombre, dt.CCO, dt.Desc_CCO INTO #saldos 
	FROM Adam.dbo.saldos_vacaciones sv INNER JOIN #tmp_datos dt ON dt.Trabajador = sv.trabajador AND dt.Compania = sv.compania

	SELECT * INTO #saldos_s FROM #saldos
	WHERE vac_por_ciclo <> (vac_disfrutadas + vac_programadas)

	SELECT s.trabajador, s.Nombre, s.CCO, s.Desc_CCO, ss.ciclo_laboral Hueco INTO #error_hueco FROM #saldos s INNER JOIN #saldos_s ss ON ss.trabajador = s.trabajador
	WHERE ((s.ciclo_laboral > ss.ciclo_laboral) AND (s.vac_disfrutadas <> 0 OR s.vac_programadas <> 0))
	-------------------------------------------------------------- VACACIONES CON MAS DIAS QUE LO PERMITIDO POR CICLO

	SELECT s.trabajador, s.Nombre, s.CCO, s.Desc_CCO, s.ciclo_laboral, s.vac_por_ciclo, s.vac_disfrutadas, s.vac_programadas INTO #error_masPorCiclo FROM #saldos s WHERE (vac_disfrutadas + vac_programadas) > vac_por_ciclo

	-------------------------------------------------------------- VACACIONES CON MAS DIAS REGISTRADOS EN SALDOS QUE EN PROGRAMACION

	SELECT sv.trabajador, sv.compania, sv.ciclo_laboral, sv.vac_por_ciclo, sv.vac_disfrutadas, sv.vac_programadas, dt.Nombre, dt.CCO, dt.Desc_CCO, SUM(pv.tiempo_prog_vac) TiempoProgramado, pv.situacion_programa
	INTO #error_massaldos
	FROM Adam.dbo.saldos_vacaciones sv
	INNER JOIN Adam.dbo.programacion_vacaciones pv ON sv.trabajador = pv.trabajador AND pv.compania = sv.compania AND sv.ciclo_laboral = pv.ciclo_laboral
	INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Trabajador = sv.trabajador AND dt.Compania = sv.compania AND dt.Situacion = 'Activo'
	WHERE sv.vac_disfrutadas <>
	(SELECT SUM(pv2.tiempo_prog_vac) FROM Adam.dbo.programacion_vacaciones pv2
	WHERE pv2.trabajador = sv.trabajador AND pv2.compania = sv.compania AND sv.ciclo_laboral = pv2.ciclo_laboral AND pv2.situacion_programa = 3)
	OR
	sv.vac_programadas <>
	(SELECT SUM(pv2.tiempo_prog_vac) FROM Adam.dbo.programacion_vacaciones pv2
	WHERE pv2.trabajador = sv.trabajador AND pv2.compania = sv.compania AND sv.ciclo_laboral = pv2.ciclo_laboral AND pv2.situacion_programa = 1)
	GROUP BY pv.trabajador, pv.ciclo_laboral, pv.situacion_programa, sv.trabajador, sv.compania, sv.ciclo_laboral, sv.vac_por_ciclo, sv.vac_disfrutadas, sv.vac_programadas, dt.Nombre, dt.CCO, dt.Desc_CCO
	ORDER BY trabajador, sv.ciclo_laboral

	DELETE FROM #error_massaldos WHERE vac_por_ciclo = vac_disfrutadas 
	OR 
	trabajador in 
	(SELECT trabajador FROM #tmp_errores_saldos es INNER JOIN #error_massaldos ems ON LEFT(es.codigo,10) = ems.trabajador AND RIGHT(es.codigo, 2) = ems.compania AND es.ciclo_laboral = ems.ciclo_laboral)


	---------------------------------------------------------------- CORREO

	DECLARE @HTML varchar(MAX)
	DECLARE @destinatarios varchar(max), @asunto varchar(300)
	SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_Vac_Gral'
	IF ((SELECT COUNT(1) FROM #tmp_errores) > 0 OR (SELECT COUNT(1) FROM #tmp_errores_saldos) > 0
	OR (SELECT COUNT(1) FROM #error_hueco) > 0  OR (SELECT COUNT(1) FROM #tmp_errores2) > 0 OR (SELECT COUNT(1) FROM #error_masPorCiclo) > 0
	OR (SELECT COUNT(1) FROM #error_massaldos) > 0)
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
					N'<H4><font color="SteelBlue">Trabajadores con error en las vacaciones.</H4>'+
					N'<table id="box-table" >' +
					N'<tr><font color="Green">'+
					N'<th>ERROR</th>'+
					N'<th>DESCRIPCIÓN</th>'+
					N'</tr>' +
					N'<tr><td>PROGRAMACIÓN - SOLICITUD</td><td>Error en la tabla Adam.dbo.programacion_vacaciones no coinciden las fechas con la cantidad de días de la solicitud</td></tr>'+
					N'<tr><td>PREPROGRAMACIÓN - SOLICITUD</td><td>Error en la tabla Vacacion.Solicitud_Vacaciones_Preprogramacion no coinciden las fechas con la cantidad de días de la solicitud</td></tr>'+
					N'<tr><td>PREPROGRAMACIÓN - PROGRAMACIÓN F</td><td>Error en la tabla Adam.dbo.programacion_vacaciones no coinciden las fechas con la tabla Vacacion.Solicitud_Vacaciones_Preprogramacion</td></tr>'+
					N'<tr><td>PREPROGRAMACIÓN - PROGRAMACIÓN E</td><td>Error en la tabla Adam.dbo.programacion_vacaciones no coinciden los estados de las fechas con la tabla Vacacion.Solicitud_Vacaciones_Preprogramacion</td></tr>'+
					N'<tr><td>SALDOS - PROGRAMACION 3</td><td>Error en la tabla Adam.dbo.saldos_vacaciones los dias disfrutados no coinciden con los dias de las fechas en la tabla Adam.dbo.programacion_vacaciones en el ciclo</td></tr>'+
					N'<tr><td>SALDOS - PROGRAMACIÓN 1</td><td>Error en la tabla Adam.dbo.saldos_vacaciones los dias programados no coinciden con los dias de las fechas en la tabla Adam.dbo.programacion_vacaciones en el ciclo</td></tr>'+
					N'<tr><td>SALDOS - PREPROGRAMACIÓN 1</td><td>Error en la tabla Adam.dbo.saldos_vacaciones los dias programados no coinciden con los dias de las fechas en la tabla Vacacion.Solicitud_Vacacion_Preprogramacion en el ciclo</td></tr>'+
					N'</table>'+
					N'<p font color="red">Si se tiene el error PREPROGRAMACIÓN - PROGRAMACIÓN F en un trabajador pero no se tiene el error PROGRAMACIÓN - SOLICITUD no existen fechas creadas en la tabla Adam.dbo.programacion_vacaciones para esa solicitud del trabajador</p>'+
					N'<br/><br/>'
					IF (SELECT COUNT(1) FROM #tmp_errores) > 0
					BEGIN
						SELECT @html = CONCAT(@html, N'<table id="box-table">'+
						N'<th>CÓDIGO</th>'+
						N'<th>NOMBRE</th>'+
						N'<th>COMPAÑIA</th>'+
						N'<th>FECHA INICIO</th>'+
						N'<th>FECHA FIN</th>'+
						N'<th>DIAS VACACIÓN</th>'+
						N'<th>ESTADO</th>'+
						N'<th>CICLO</th>'+
						N'<th>ERROR</th>'+
						N'</tr>'+
						CAST(
							(SELECT 
								td = e.codigo, '',
								td = dt.Nombre, '',
								td = e.Compania, '',
								td = CONVERT(VARCHAR, e.fecha_inicio, 105), '',
								td = CONVERT(VARCHAR, e.fecha_fin, 105), '',
								td = e.dias, '',
								td = e.estado, '',
								td = e.Ciclo, '',
								td = e.Error, ''
							FROM #tmp_errores e INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo ORDER BY e.codigo
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>' +
						N'<br/><br />')
					END
					IF (SELECT COUNT(1) FROM #tmp_errores2) > 0
					BEGIN
						SELECT @html = CONCAT(@html, N'<table id="box-table">'+
						N'<th>CÓDIGO</th>'+
						N'<th>NOMBRE</th>'+
						N'<th>COMPAÑIA</th>'+
						N'<th>FECHA INICIO</th>'+
						N'<th>FECHA FIN</th>'+
						N'<th>DIAS VACACIÓN</th>'+
						N'<th>ESTADO</th>'+
						N'<th>ERROR</th>'+
						N'</tr>'+
						CAST(
							(SELECT 
								td = e.codigo, '',
								td = dt.Nombre, '',
								td = dt.Compania, '',
								td = CONVERT(VARCHAR, e.fecha_inicio, 105), '',
								td = CONVERT(VARCHAR, e.fecha_fin, 105), '',
								td = e.dias, '',
								td = e.estado, '',
								td = e.Error, ''
							FROM #tmp_errores2 e INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo ORDER BY e.codigo
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>' +
						N'<br/><br />')
					END
					IF (SELECT COUNT(1) FROM #tmp_errores_saldos) > 0 
					BEGIN
						SELECT @html = CONCAT(@html ,N'<H4><font color="SteelBlue">Trabajadores con error en las vacaciones.</H4>'+
						N'<table id="box-table" >' +
						N'<tr><font color="Green">
						<th>CÓDIGO</th>
						<th>NOMBRE</th>
						<th>COMPAÑIA</th>
						<th>CICLO</th>
						<th>DÍAS VACACIÓN</th>
						<th>VACACIONES ASENTADAS</th>
						<th>VACACIONES PROGRAMADAS</th>
						<th>ERROR</th>
						</tr>' +
						CAST(
							(SELECT 
								td = e.codigo, '',
								td = dt.Nombre, '',
								td = e.Compania, '',
								td = e.ciclo_laboral, '',
								td = e.Suma, '',
								td = e.vac_disfrutadas, '',
								td = e.vac_programadas, '',
								td = e.Error, ''
							FROM #tmp_errores_saldos e INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo ORDER BY e.codigo
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>'+
						N'<br/><br />')
					END
					IF (SELECT COUNT(1) FROM #error_hueco) > 0 
					BEGIN
						SELECT @html = CONCAT(@html ,N'<H4><font color="SteelBlue">Trabajadores con ciclos laborales en vacaciones incompletos.</H4>'+
						N'<table id="box-table" >' +
						N'<tr><font color="Green">
						<th>TRABAJADOR</th>
						<th>NOMBRE</th>
						<th>CCO</th>
						<th>DESCRIPCIÓN CCO</th>
						<th>CICLO CON ERROR</th>
						</tr>' +
						CAST(
							(SELECT 
								td = e.trabajador, '',
								td = e.Nombre, '',
								td = e.CCO, '',
								td = e.Desc_CCO, '',
								td = e.Hueco, ''
							FROM #error_hueco e 
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>'+
						N'<br/><br />')
					END
					IF (SELECT COUNT(1) FROM #error_masPorCiclo) > 0 
					BEGIN
						SELECT @html = CONCAT(@html ,N'<H4><font color="SteelBlue">Trabajadores con más dias de vacación que lo que deberían tener por ciclo.</H4>'+
						N'<table id="box-table" >' +
						N'<tr><font color="Green">
						<th>TRABAJADOR</th>
						<th>NOMBRE</th>
						<th>CCO</th>
						<th>DESCRIPCIÓN CCO</th>
						<th>VAC POR CICLO</th>
						<th>VAC DISFRUTADAS</th>
						<th>VAC PENDIENTES</th>
						</tr>' +
						CAST(
							(SELECT 
								td = e.trabajador, '',
								td = e.Nombre, '',
								td = e.CCO, '',
								td = e.Desc_CCO, '',
								td = e.vac_por_ciclo, '',
								td = e.vac_disfrutadas, '',
								td = e.vac_programadas, ''
							FROM #error_masPorCiclo e 
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>'+
						N'<br/><br />')
					END
					IF (SELECT COUNT(1) FROM #error_massaldos) > 0 
					BEGIN
						SELECT @html = CONCAT(@html ,N'<H4><font color="SteelBlue">Trabajadores con total dias disfrutados o programados distintos a los registrados.</H4>'+
						N'<table id="box-table" >' +
						N'<tr><font color="Green">
						<th>TRABAJADOR</th>
						<th>NOMBRE</th>
						<th>CCO</th>
						<th>DESCRIPCIÓN CCO</th>
						<th>VAC DISFRUTADAS</th>
						<th>VAC PROGRAMADAS</th>
						<th>DIAS VACACION</th>
						<th>ESTADO</th>
						</tr>' +
						CAST(
							(SELECT 
								td = e.trabajador, '',
								td = e.Nombre, '',
								td = e.CCO, '',
								td = e.Desc_CCO, '',
								td = e.vac_disfrutadas, '',
								td = e.vac_programadas, '',
								td = e.TiempoProgramado, '',
								td = e.situacion_programa, ''
							FROM #error_massaldos e 
							FOR XML PATH('tr'), TYPE) AS varchar(max)) +
						N'</table>'+
						N'<br/><br />')
					END
					SELECT @HTML = CONCAT(@html, N' </body>')
					 
			BEGIN TRY
				-- INSERT notificación consolidada
				INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
				VALUES ('A', 'Vacaciones', 'pa_errorVacacionesGeneral', @asunto, @HTML, @destinatarios, @fi, @ff);
				EXEC msdb.dbo.Sp_send_dbmail

				@profile_name = 'Informacion_Nomina',
				@Subject = @asunto,
				 @recipients = @destinatarios,
			 	@body_format= 'html',
				@body = @HTML
			END TRY
			BEGIN CATCH
				INSERT INTO Logs.log_usuarios 
				(id_usuario, fecha, descripcion, notas, operacion, ip, referencia_01, referencia_02, referencia_03, referencia_04, referencia_05, referencia_06)
				select 'Adam', getdate(), @html, '',1,'','', 'pa_errorVacacionesGeneral',0,0,getdate(), '';
			END CATCH
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
					N'<H4><font color="SteelBlue">No se encontraron trabajadores con error en las vacaciones.</H4>'+
					N'<br/><br/>'
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Vacaciones', 'pa_errorVacacionesGeneral', @asunto, @HTML, @destinatarios, @fi, @ff);
			EXEC msdb.dbo.Sp_send_dbmail

			@profile_name = 'Informacion_Nomina',
			@Subject = @asunto,
			@recipients = @destinatarios,
			@body_format= 'html',
			@body = @HTML
	END


	IF OBJECT_ID(N'tempdb..#vacaciones_svp', N'U') IS NOT NULL
		DROP TABLE #vacaciones_svp
	IF OBJECT_ID(N'tempdb..#vacaciones_pv', N'U') IS NOT NULL
		DROP TABLE #vacaciones_pv
	IF OBJECT_ID(N'tempdb..#tmpv1', N'U') IS NOT NULL
		DROP TABLE #tmpv1
	IF OBJECT_ID(N'tempdb..#tmpv3', N'U') IS NOT NULL
		DROP TABLE #tmpv3
	IF OBJECT_ID(N'tempdb..#tmpvs1', N'U') IS NOT NULL
		DROP TABLE #tmpvs1
	IF OBJECT_ID(N'tempdb..#tmp_errores_saldos', N'U') IS NOT NULL
		DROP TABLE #tmp_errores_saldos
	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
		DROP TABLE #tmp_errores
	IF OBJECT_ID(N'tempdb..#tmp_errores2', N'U') IS NOT NULL
		DROP TABLE #tmp_errores2
	IF OBJECT_ID(N'tempdb..#tmp_datos', N'U') IS NOT NULL
		DROP TABLE #tmp_datos
	IF OBJECT_ID(N'tempdb..#saldos', N'U') IS NOT NULL
		DROP TABLE #saldos
	IF OBJECT_ID(N'tempdb..#saldos_s', N'U') IS NOT NULL
		DROP TABLE #saldos_s
	IF OBJECT_ID(N'tempdb..#error_hueco', N'U') IS NOT NULL
		DROP TABLE #error_hueco
	IF OBJECT_ID(N'tempdb..#error_massaldos', N'U') IS NOT NULL
		DROP TABLE #error_massaldos
	IF OBJECT_ID(N'tempdb..#error_masPorCiclo', N'U') IS NOT NULL
		DROP TABLE #error_masPorCiclo
	IF OBJECT_ID(N'tempdb..#tmp_errores_sin', N'U') IS NOT NULL
		DROP TABLE #tmp_errores_sin
END