
CREATE PROCEDURE [Avisos].[pa_Transferencias]
AS
DECLARE
    @HTML        VARCHAR(MAX),
    @fecha_ini   DATE,
    @fecha_fin   DATE = GETDATE(),
    @w           INT
BEGIN
    SET DATEFORMAT dmy;

    /* Limpieza inicial */
    IF OBJECT_ID(N'tempdb..#tmp_errores_tdd', N'U') IS NOT NULL DROP TABLE #tmp_errores_tdd;
    IF OBJECT_ID(N'tempdb..#tmp_errores_rth', N'U') IS NOT NULL DROP TABLE #tmp_errores_rth;
    IF OBJECT_ID(N'tempdb..#tmp_errores_m',   N'U') IS NOT NULL DROP TABLE #tmp_errores_m;
    IF OBJECT_ID(N'tempdb..#tmp_transferencias', N'U') IS NOT NULL DROP TABLE #tmp_transferencias;
    IF OBJECT_ID(N'tempdb..#tmp_t_rth', N'U') IS NOT NULL DROP TABLE #tmp_t_rth;
    IF OBJECT_ID(N'tempdb..#tmp_t_m',   N'U') IS NOT NULL DROP TABLE #tmp_t_m;
    IF OBJECT_ID(N'tempdb..#tmp_t_tdd', N'U') IS NOT NULL DROP TABLE #tmp_t_tdd;
    IF OBJECT_ID(N'tempdb..#tmp_e_m',   N'U') IS NOT NULL DROP TABLE #tmp_e_m;
    IF OBJECT_ID(N'tempdb..#tmp_e_rth', N'U') IS NOT NULL DROP TABLE #tmp_e_rth;
    IF OBJECT_ID(N'tempdb..#tmp_e_tdd', N'U') IS NOT NULL DROP TABLE #tmp_e_tdd;
    IF OBJECT_ID(N'tempdb..#tmp_p_t',   N'U') IS NOT NULL DROP TABLE #tmp_p_t;

    DECLARE @fi DATE, @ff DATE;
    SELECT @fi = FechaInicioNomina, @ff = FechaFinNomina
    FROM Utilidades.fn_fechasperiodonomina(GETDATE());

    /* ---------------------- */
    /* Permiso apertura local */
    SELECT
        pt.codigo,
        pt.cco,
        pt.cco_destino,
        CONVERT(DATE, pt.fecha_ini) AS fecha_ini,
        CONVERT(DATE, pt.fecha_fin) AS fecha_fin,
        pt.tiempo_afectacion
    INTO #tmp_p_t
    FROM Catalogos.Permisos AS p
    INNER JOIN Asistencia.permisos_trabajadores AS pt ON p.idPermiso = pt.idPermiso
    WHERE pt.idPermiso = 7
      AND pt.estado = 1
      AND CONVERT(DATE, pt.fecha_ini) >= @fi;

    /* ---------------------------------------------- */
    /* Transferencias del periodo con CORTE por retorno */
    /* - Retorno aprobado: hist_transferencias.estatus = 8
       - Fecha efectiva fin temporal = MIN(fecha_modificacion estatus 8) - 1 día
       - Siguiente transferencia: se calcula sobre Asistencia.transferencias estatus IN (3,8)
    */
    ;WITH CTE_Retornos AS (
        SELECT
            ht.id_transferencia,
            MIN(CONVERT(DATE, ht.fecha_modificacion)) AS fecha_retorno
        FROM Asistencia.hist_transferencias ht
        WHERE ht.estatus = 8
        GROUP BY ht.id_transferencia
    ),
    CTE_Transferencias AS (
        SELECT
            t.id_transferencia,
            t.tipo_transferencia,
            t.cco_origen,
            t.cco_destino,
            t.estatus,
            t.codigo,
            t.fecha_inicio,
            CONVERT(DATE,
                ISNULL(
                    t.fecha_fin,
                    DATEADD(DAY, -1, ISNULL(
                        (SELECT MIN(t2.fecha_inicio)
                         FROM Asistencia.transferencias t2
                         WHERE t2.codigo = t.codigo
                           AND t2.fecha_inicio > t.fecha_inicio
                           AND t2.estatus IN (3,8)),
                        DATEADD(DAY, 1, GETDATE())
                    ))
                )
            ) AS fecha_fin_calc
        FROM Asistencia.transferencias t
        WHERE t.fecha_inicio BETWEEN @fi AND @ff
          AND t.estatus = 3
    )
    SELECT
        t.tipo_transferencia,
        t.cco_origen,
        t.cco_destino,
        t.estatus,
        t.codigo,
        t.fecha_inicio,
        CASE
            WHEN t.tipo_transferencia = 1
                 AND r.fecha_retorno IS NOT NULL
                 AND DATEADD(DAY, -1, r.fecha_retorno) < t.fecha_fin_calc
                THEN DATEADD(DAY, -1, r.fecha_retorno)
            ELSE t.fecha_fin_calc
        END AS fecha_fin,
        dt.Nombre,
        dt.CCO AS CCOVista
    INTO #tmp_transferencias
    FROM CTE_Transferencias t
    INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = t.codigo
    LEFT JOIN CTE_Retornos r ON r.id_transferencia = t.id_transferencia
    WHERE dt.Situacion = 'Activo';

    /* Cruces */
    SELECT t.*, rth.cco AS CCORTH, rth.fecha
    INTO #tmp_t_rth
    FROM #tmp_transferencias t
    INNER JOIN Asistencia.rel_trab_horarios rth
        ON rth.codigo = t.codigo
       AND rth.fecha > @fi;

    SELECT t.*, m.cco_marcaje, m.cco_trab, m.cco_padre, m.fecha
    INTO #tmp_t_m
    FROM #tmp_transferencias t
    INNER JOIN Asistencia.marcajes m
        ON m.codigo_emp_equipo = t.codigo
       AND m.fecha > @fi;

    /* ------------------------- */
    /* trabajadores datos diario (con override por permiso apertura local) */
    ;WITH CTE_tdd AS (
        SELECT codigo, fecha, cco
        FROM RRHH.trabajadoresDatosDiario
        WHERE codigo IN (SELECT DISTINCT codigo FROM #tmp_transferencias)
          AND fecha >= @fi
    ),
    CTE_validatdd AS (
        SELECT
            r.codigo,
            r.fecha,
            r.cco,
            cco_destino = (
                SELECT DISTINCT cco_destino
                FROM #tmp_p_t
                WHERE codigo = r.codigo
                  AND (r.fecha BETWEEN fecha_ini AND fecha_fin)
                  AND cco = r.cco
            )
        FROM CTE_tdd r
    ),
    CTE_nuevatdd AS (
        SELECT
            codigo,
            fecha,
            CASE WHEN ISNULL(cco_destino,'') = '' THEN cco ELSE cco_destino END AS cco
        FROM CTE_validatdd
    )
    SELECT t.*, tdd.fecha, tdd.cco
    INTO #tmp_t_tdd
    FROM #tmp_transferencias t
    INNER JOIN CTE_nuevatdd tdd
        ON t.codigo = tdd.codigo
       AND tdd.fecha > @fi;

    /* ========================== */
    /* ERRORES RTH */
    /* ========================== */
    SELECT t.*, 'T-RTH-CCO' AS ERROR
    INTO #tmp_errores_rth
    FROM #tmp_t_rth t
    WHERE (
        tipo_transferencia = 1
        AND (
            (
                fecha BETWEEN DATEADD(DAY, 1, fecha_fin)
                AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
                ))
                AND cco_origen <> CCORTH
            )
            OR
            (
                fecha BETWEEN fecha_inicio AND fecha_fin
                AND cco_destino <> CCORTH
            )
        )
    );

    INSERT INTO #tmp_errores_rth
    SELECT t.*, 'D-RTH-CCO' AS ERROR
    FROM #tmp_t_rth t
    WHERE (
        tipo_transferencia = 2
        AND fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
        AND DATEADD(DAY, -1, ISNULL(
            (SELECT MIN(t2.fecha_inicio)
             FROM Asistencia.transferencias t2
             WHERE t2.codigo = t.codigo
               AND t2.fecha_inicio > t.fecha_fin
               AND t2.estatus IN (3,8)),
            DATEADD(DAY, 1, GETDATE())
        ))
        AND cco_destino <> CCORTH
    )
    AND (
        EXISTS(
            SELECT 1
            FROM Asistencia.marcajes m WITH (NOLOCK)
            WHERE m.codigo_emp_equipo = t.codigo
              AND m.estatus IN (3,4)
              AND m.fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
              AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
              ))
        )
        OR NOT EXISTS(
            SELECT 1
            FROM Asistencia.marcajes m WITH (NOLOCK)
            WHERE m.estatus IN (0,1)
              AND m.codigo_emp_equipo = t.codigo
              AND m.fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
              AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
              ))
        )
    );

    /* ========================== */
    /* ERRORES MARCAJES */
    /* ========================== */
    SELECT
        t.*,
        CASE WHEN '' IN (cco_trab, cco_padre, cco_marcaje) THEN 'D-MARCAJE-F' ELSE 'D-MARCAJE-CCO' END AS ERROR
    INTO #tmp_errores_m
    FROM #tmp_t_m t
    WHERE (
        tipo_transferencia = 1
        AND (
            (
                fecha BETWEEN DATEADD(DAY, 1, fecha_fin)
                AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
                ))
                AND cco_origen NOT IN (cco_trab, cco_padre, cco_marcaje)
            )
            OR
            (
                fecha BETWEEN fecha_inicio AND fecha_fin
                AND cco_destino NOT IN (cco_trab, cco_padre, cco_marcaje)
            )
        )
    );

    INSERT INTO #tmp_errores_m
    SELECT
        t.*,
        CASE WHEN '' IN (cco_trab, cco_padre, cco_marcaje) THEN 'D-MARCAJE-F' ELSE 'D-MARCAJE-CCO' END
    FROM #tmp_t_m t
    WHERE (
        tipo_transferencia = 2
        AND fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
        AND DATEADD(DAY, -1, ISNULL(
            (SELECT MIN(t2.fecha_inicio)
             FROM Asistencia.transferencias t2
             WHERE t2.codigo = t.codigo
               AND t2.fecha_inicio > t.fecha_fin
               AND t2.estatus IN (3,8)),
            DATEADD(DAY, 1, GETDATE())
        ))
        AND cco_destino NOT IN (cco_trab, cco_padre, cco_marcaje)
    );

    /* ========================== */
    /* ERRORES TDD */
    /* ========================== */
    SELECT t.*, 'T-TDD-CCO' AS ERROR
    INTO #tmp_errores_tdd
    FROM #tmp_t_tdd t
    WHERE (
        tipo_transferencia = 1
        AND (
            (
                fecha BETWEEN DATEADD(DAY, 1, fecha_fin)
                AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
                ))
                AND cco_origen <> cco
            )
            OR
            (
                fecha BETWEEN fecha_inicio AND fecha_fin
                AND cco <> cco_destino
            )
        )
    );

    INSERT INTO #tmp_errores_tdd
    SELECT t.*, 'D-TDD-CCO' AS ERROR
    FROM #tmp_t_tdd t
    WHERE (
        tipo_transferencia = 2
        AND fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
        AND DATEADD(DAY, -1, ISNULL(
            (SELECT MIN(t2.fecha_inicio)
             FROM Asistencia.transferencias t2
             WHERE t2.codigo = t.codigo
               AND t2.fecha_inicio > t.fecha_fin
               AND t2.estatus IN (3,8)),
            DATEADD(DAY, 1, GETDATE())
        ))
        AND cco_destino <> cco
    )
    AND (
        EXISTS(
            SELECT 1
            FROM Asistencia.marcajes m WITH (NOLOCK)
            WHERE m.codigo_emp_equipo = t.codigo
              AND m.estatus IN (3,4)
              AND m.fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
              AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
              ))
        )
        OR NOT EXISTS(
            SELECT 1
            FROM Asistencia.marcajes m WITH (NOLOCK)
            WHERE m.estatus IN (0,1)
              AND m.codigo_emp_equipo = t.codigo
              AND m.fecha BETWEEN DATEADD(DAY, 1, fecha_inicio)
              AND DATEADD(DAY, -1, ISNULL(
                    (SELECT MIN(t2.fecha_inicio)
                     FROM Asistencia.transferencias t2
                     WHERE t2.codigo = t.codigo
                       AND t2.fecha_inicio > t.fecha_fin
                       AND t2.estatus IN (3,8)),
                    DATEADD(DAY, 1, GETDATE())
              ))
        )
    );

    /* ---------------------- */
    /* DELETE por AccionesPersonal (global) */
    DELETE FROM #tmp_errores_tdd
    WHERE (
        SELECT COUNT(1)
        FROM #tmp_errores_tdd m
        INNER JOIN AP.AccionesPersonal ap ON ap.codigo = m.codigo
        WHERE ap.accionCCO = 1
          AND ap.estado = 7
          AND ap.codigo = m.codigo
          AND ap.ccoAnt IN (m.cco_destino, m.cco_origen)
    ) > 0;

    DELETE FROM #tmp_errores_m
    WHERE (
        SELECT COUNT(1)
        FROM #tmp_errores_m m
        INNER JOIN AP.AccionesPersonal ap ON ap.codigo = m.codigo
        WHERE ap.accionCCO = 1
          AND ap.estado = 7
          AND ap.codigo = m.codigo
          AND ap.ccoAnt IN (m.cco_destino, m.cco_origen)
    ) > 0;

    DELETE FROM #tmp_errores_rth
    WHERE (
        SELECT COUNT(1)
        FROM #tmp_errores_rth m
        INNER JOIN AP.AccionesPersonal ap ON ap.codigo = m.codigo
        WHERE ap.accionCCO = 1
          AND ap.estado = 7
          AND ap.codigo = m.codigo
          AND ap.ccoAnt IN (m.cco_destino, m.cco_origen)
    ) > 0;

    /* ---------------------- */
    /* DELETE por Permiso apertura local */
    DELETE FROM #tmp_errores_tdd
    WHERE (
        SELECT COUNT(1)
        FROM #tmp_errores_tdd tdd
        INNER JOIN #tmp_p_t pt ON tdd.codigo = pt.codigo
        WHERE pt.codigo = tdd.codigo
          AND pt.cco = tdd.cco_origen
          AND pt.cco_destino = tdd.cco
          AND (tdd.fecha BETWEEN pt.fecha_ini AND pt.fecha_fin)
    ) > 0;

    DELETE FROM #tmp_errores_m
    WHERE (
        SELECT COUNT(1)
        FROM #tmp_errores_m m
        INNER JOIN #tmp_p_t pt ON m.codigo = pt.codigo
        WHERE pt.codigo = m.codigo
          AND pt.cco = m.cco_origen
          AND pt.cco_destino = m.cco_marcaje
          AND (m.fecha BETWEEN pt.fecha_ini AND pt.fecha_fin)
    ) > 0;

    DELETE FROM #tmp_errores_rth
    WHERE (
        SELECT COUNT(1)
        FROM #tmp_errores_rth h
        INNER JOIN #tmp_p_t pt ON h.codigo = pt.codigo
        WHERE pt.codigo = h.codigo
          AND pt.cco = h.cco_origen
          AND pt.cco_destino = h.CCORTH
          AND (h.fecha BETWEEN pt.fecha_ini AND pt.fecha_fin)
    ) > 0;

    /* ---------------------- */
    /* Agrupación final */
    SELECT
        e.codigo, e.Nombre, e.fecha_inicio, e.fecha_fin, e.tipo_transferencia,
        e.cco_origen, e.cco_destino, e.cco_marcaje, e.cco_padre, e.cco_trab,
        dt.Clase_Nomina, e.ERROR,
        CONVERT(VARCHAR, MIN(e.fecha), 103) AS Desde,
        CONVERT(VARCHAR, MAX(e.fecha), 103) AS Hasta
    INTO #tmp_e_m
    FROM #tmp_errores_m e
    INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo
    GROUP BY
        e.codigo, e.Nombre, e.fecha_inicio, e.fecha_fin, e.tipo_transferencia,
        e.cco_origen, e.cco_destino, e.cco_marcaje, e.cco_padre, e.cco_trab,
        e.ERROR, dt.Clase_Nomina;

    SELECT
        e.codigo, e.Nombre, e.tipo_transferencia, e.fecha_inicio, e.fecha_fin,
        e.cco_origen, e.cco_destino, e.CCORTH, e.ERROR,
        dt.Clase_Nomina,
        CONVERT(VARCHAR, MIN(e.fecha), 103) AS Desde,
        CONVERT(VARCHAR, MAX(e.fecha), 103) AS Hasta
    INTO #tmp_e_rth
    FROM #tmp_errores_rth e
    INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo
    GROUP BY
        e.codigo, e.Nombre, e.tipo_transferencia, e.fecha_inicio, e.fecha_fin,
        e.cco_origen, e.cco_destino, e.CCORTH, e.ERROR, dt.Clase_Nomina;

    SELECT
        e.codigo, e.Nombre, e.tipo_transferencia, e.fecha_inicio, e.fecha_fin,
        e.cco_origen, e.cco_destino, e.cco, e.ERROR,
        dt.Clase_Nomina,
        CONVERT(VARCHAR, MIN(e.fecha), 103) AS Desde,
        CONVERT(VARCHAR, MAX(e.fecha), 103) AS Hasta
    INTO #tmp_e_tdd
    FROM #tmp_errores_tdd e
    INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Codigo = e.codigo
    GROUP BY
        e.codigo, e.Nombre, e.tipo_transferencia, e.fecha_inicio, e.fecha_fin,
        e.cco_origen, e.cco_destino, e.cco, e.ERROR, dt.Clase_Nomina;

     DECLARE @correo_pruebas VARCHAR(200) = 'smosquera@sipecom.com';
    DECLARE @destinatarios VARCHAR(MAX), @asunto VARCHAR(300);
    SELECT @destinatarios = valor, @asunto = descripcion
    FROM Configuracion.parametros
    WHERE parametro = 'AL_Transf';

    IF ((SELECT COUNT(1) FROM #tmp_e_m) > 0 OR (SELECT COUNT(1) FROM #tmp_e_rth) > 0 OR (SELECT COUNT(1) FROM #tmp_e_tdd) > 0)
    BEGIN
        /* ========================= */
        /* CORREO GENERAL (igual que tu SP) */
        /* ========================= */
        SELECT @HTML = N'<style type="text/css">
                        .box-table
                        {
                            font-family: "Calibri";
                            font-size: 10px;
                            text-align: center;
                            border-collapse: collapse;
                            border-top: 7px solid #9baff1;
                            border-bottom: 7px solid #9baff1;
                        }
                        .box-table th
                        {
                            font-size: 11px;
                            font-weight: normal;
                            background: #b9c9fe;
                            border-right: 2px solid #9baff1;
                            border-left: 2px solid #9baff1;
                            border-bottom: 2px solid #9baff1;
                            color: #039;
                        }
                        .box-table td
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
                        tr:nth-child(odd)    { background-color:#eee; }
                        tr:nth-child(even)   { background-color:#fff; }
                    </style>'
                    +N'<h3><font color="SteelBlue">ERROR EN TRANSFERENCIAS</h3>'
                    +N'<h4><font color="SteelBlue">Fecha: '+CONVERT(VARCHAR(12),GETDATE(),103)+'</h4>'
                    +N'<h4><font color="SteelBlue">Error en las tranferencias con los siguientes trabajadores</h4>';

        IF (SELECT COUNT(1) FROM #tmp_e_m) > 0
        BEGIN
            SELECT @html = CONCAT(@html,
            N'<h3>Trabajadores con error en marcaciones</h3>'
            +N'<p>D-MARCAJE-F -> Marcaje de transferencia definitiva sin cco en las fechas</p>'
            +N'<p>D-MARCAJE-CCO -> Marcaje de transferencia definitiva con cco incorrecto en las fechas</p>'
            +N'<p>T-MARCAJE-F -> Marcaje de transferencia temporal sin cco en las fechas</p>'
            +N'<p>T-MARCAJE-CCO -> Marcaje de transferencia temporal con cco incorrecto en las fechas</p>'
            +N'<table class="box-table" >'
            +N'<th>TIPO</th>'
            +N'<th>FECHA INICIO</th>'
            +N'<th>FECHA FIN</th>'
            +N'<th>CÓDIGO</th>'
            +N'<th>NOMBRE</th>'
            +N'<th>CCO ORIGEN</th>'
            +N'<th>DESCRIPCION CCO ORIGEN</th>'
            +N'<th>CCO DESTINO</th>'
            +N'<th>DESCRIPCION CCO DESTINO</th>'
            +N'<th>CCO MARCAJE</th>'
            +N'<th>CCO PADRE</th>'
            +N'<th>CCO TRAB</th>'
            +N'<th>DESDE</th>'
            +N'<th>HASTA</th>'
            +N'<th>ERROR</th>'
            +N'</tr>' +
                CAST((
                SELECT
                    td = e.tipo_transferencia, '',
                    td = CONVERT(VARCHAR, e.fecha_inicio, 23), '',
                    td = ISNULL(CONVERT(VARCHAR, e.fecha_fin, 23), '--'), '',
                    td = e.Codigo, '',
                    td = e.Nombre, '',
                    td = e.cco_origen, '',
                    td = ccoo.descripcion, '',
                    td = e.cco_destino, '',
                    td = ccod.descripcion, '',
                    td = e.cco_marcaje, '',
                    td = e.cco_padre, '',
                    td = e.cco_trab, '',
                    td = e.Desde, '',
                    td = e.Hasta, '',
                    td = e.ERROR
                FROM #tmp_e_m e
                INNER JOIN Catalogos.VW_CCO ccoo ON ccoo.cco = e.cco_origen
                INNER JOIN Catalogos.VW_CCO ccod ON ccod.cco = e.cco_origen
                ORDER BY e.Codigo, e.ERROR, e.Desde
                FOR XML PATH('tr'), TYPE) AS VARCHAR(MAX)) +
            +N'</table><br/><br/>');
        END

        IF (SELECT COUNT(1) FROM #tmp_e_rth) > 0
        BEGIN
            SELECT @html = CONCAT(@html,
            N'<h3>Trabajadores con error en la tabla RRHH.rel_trab_horarios</h3>'
            +N'<p>D-RTH-CCO -> Horario despues de una transferencia definitiva con error en el cco</p>'
            +N'<p>T-RTH-CCO-> Horario durante o despues de una transferencia temporal con error en el cco</p>'
            +N'<table class="box-table" >'
            +N'<th>TIPO</th>'
            +N'<th>FECHA INICIO</th>'
            +N'<th>FECHA FIN</th>'
            +N'<th>CÓDIGO</th>'
            +N'<th>NOMBRE</th>'
            +N'<th>CCO ORIGEN</th>'
            +N'<th>DESCRIPCION CCO ORIGEN</th>'
            +N'<th>CCO DESTINO</th>'
            +N'<th>DESCRIPCION CCO DESTINO</th>'
            +N'<th>CCO ACTUAL</th>'
            +N'<th>DESCRIPCION CCO ACTUAL</th>'
            +N'<th>DESDE</th>'
            +N'<th>HASTA</th>'
            +N'<th>ERROR</th>'
            +N'</tr>' +
                CAST((
                SELECT
                    td = e.tipo_transferencia, '',
                    td = CONVERT(VARCHAR, e.fecha_inicio, 23), '',
                    td = ISNULL(CONVERT(VARCHAR, e.fecha_fin, 23), '--'), '',
                    td = e.Codigo, '',
                    td = e.Nombre, '',
                    td = e.cco_origen, '',
                    td = ccoo.descripcion, '',
                    td = e.cco_destino, '',
                    td = ccod.descripcion, '',
                    td = e.CCORTH, '',
                    td = ccoa.descripcion, '',
                    td = e.Desde, '',
                    td = e.Hasta, '',
                    td = e.ERROR
                FROM #tmp_e_rth e
                INNER JOIN Catalogos.VW_CCO ccoo ON ccoo.cco = e.cco_origen
                INNER JOIN Catalogos.VW_CCO ccod ON ccod.cco = e.cco_destino
                INNER JOIN Catalogos.VW_CCO ccoa ON ccoa.cco = e.CCORTH
                ORDER BY e.Codigo, e.ERROR, e.Desde
                FOR XML PATH('tr'), TYPE) AS VARCHAR(MAX))
            +N'</table><br/><br/>');
        END

        IF (SELECT COUNT(1) FROM #tmp_e_tdd) > 0
        BEGIN
            SELECT @HTML = CONCAT(@HTML,
            N'<h3>Trabajadores con error en la tabla RRHH.trabajadoresDatosDiario</h3>'
            +N'<p>D-TDD-CCO -> Despues de una transferencia definitiva con error en el cco</p>'
            +N'<p>T-TDD-CCO-> Durante o despues de una transferencia temporal con error en el cco</p>'
            +N'<table class="box-table" >'
            +N'<th>TIPO</th>'
            +N'<th>FECHA INICIO</th>'
            +N'<th>FECHA FIN</th>'
            +N'<th>CÓDIGO</th>'
            +N'<th>NOMBRE</th>'
            +N'<th>CCO ORIGEN</th>'
            +N'<th>DESCRIPCION CCO ORIGEN</th>'
            +N'<th>CCO DESTINO</th>'
            +N'<th>DESCRIPCION CCO DESTINO</th>'
            +N'<th>CCO ACTUAL</th>'
            +N'<th>DESCRIPCION CCO ACTUAL</th>'
            +N'<th>DESDE</th>'
            +N'<th>HASTA</th>'
            +N'<th>ERROR</th>'
            +N'</tr>' +
                CAST((
                SELECT
                    td = e.tipo_transferencia, '',
                    td = CONVERT(VARCHAR, e.fecha_inicio, 23), '',
                    td = ISNULL(CONVERT(VARCHAR, e.fecha_fin, 23), '--'), '',
                    td = e.Codigo, '',
                    td = e.Nombre, '',
                    td = e.cco_origen, '',
                    td = ccoo.descripcion, '',
                    td = e.cco_destino, '',
                    td = ccod.descripcion, '',
                    td = e.cco, '',
                    td = ccoa.descripcion, '',
                    td = e.Desde, '',
                    td = e.Hasta, '',
                    td = e.ERROR
                FROM #tmp_e_tdd e
                INNER JOIN Catalogos.VW_CCO ccoo ON ccoo.cco = e.cco_origen
                INNER JOIN Catalogos.VW_CCO ccod ON ccod.cco = e.cco_destino
                INNER JOIN Catalogos.VW_CCO ccoa ON ccoa.cco = e.cco
                ORDER BY e.Codigo, e.ERROR, e.Desde
                FOR XML PATH('tr'), TYPE) AS VARCHAR(MAX))
            +N'</table><br/><br/>');
        END

        SELECT @HTML = CONCAT(@HTML, N'<br/><br />'+N' </body>');

        -- INSERT notificación consolidada
        INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
        VALUES ('A', 'Transferencias', 'pa_Transferencias', @asunto, @HTML, @destinatarios, @fecha_ini, @fecha_fin);
        EXEC msdb.dbo.Sp_send_dbmail
            @profile_name = 'Informacion_Nomina',
            @Subject      = @asunto,
            @recipients   = @destinatarios,
            @body_format  = 'html',
            @body         = @HTML;

        /* ========================= */
        /* CORREO POR CLASE NÓMINA (mismo código tuyo) */
        /* ========================= */
        DECLARE @Correo_Clase_Nomina AS TABLE (clase_nomina VARCHAR(6), analista VARCHAR(1000));

        INSERT INTO @Correo_Clase_Nomina (clase_nomina, analista)
        SELECT CV.clase_nomina, Configuracion.fn_correosVariosRemitentesContactoTiendas(CV.clase_nomina)
        FROM Asistencia.transferencias t
        INNER JOIN RRHH.vw_datosTrabajadores dt ON t.codigo = dt.Codigo
        INNER JOIN Catalogos.VW_CCO cv ON t.cco_origen = cv.cco AND cv.clase_nomina = dt.Clase_Nomina
        GROUP BY CV.clase_nomina;

        DECLARE @clase_nomina VARCHAR(6), @ANALISTA VARCHAR(1000);
        DECLARE CURSOR4 CURSOR LOCAL FOR
        SELECT clase_nomina, analista FROM @Correo_Clase_Nomina ORDER BY clase_nomina;

        OPEN CURSOR4;
        FETCH CURSOR4 INTO @clase_nomina, @ANALISTA;

        WHILE (@@FETCH_STATUS = 0)
        BEGIN
            /* Nota: Se mantiene tu lógica original de @w */
            SELECT @w = COUNT(1)
            FROM @Correo_Clase_Nomina cn
            INNER JOIN #tmp_e_m   t1 ON cn.clase_nomina = t1.Clase_Nomina
            INNER JOIN #tmp_e_rth t2 ON cn.clase_nomina = t2.Clase_Nomina
            INNER JOIN #tmp_e_tdd t3 ON cn.clase_nomina = t3.Clase_Nomina
            WHERE cn.clase_nomina = @clase_nomina
              AND cn.clase_nomina = t1.clase_nomina;

            IF @w > 0
            BEGIN
                /* Reutiliza el HTML ya armado arriba (mismo que tu SP). */
                -- INSERT notificación consolidada
                INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
                VALUES ('A', 'Transferencias', 'pa_Transferencias', @asunto, @HTML, @w, @destinatarios, @fecha_ini, @fecha_fin);
                EXEC msdb.dbo.Sp_send_dbmail
                    @profile_name = 'Informacion_Nomina',
                    @Subject      = @asunto,
                    @recipients   = @destinatarios,
                    @body_format  = 'html',
                    @body         = @HTML;
            END

            FETCH CURSOR4 INTO @clase_nomina, @ANALISTA;
        END

        CLOSE CURSOR4;
        DEALLOCATE CURSOR4;
    END
    ELSE
    BEGIN
        SELECT @HTML = N' <style type="text/css">
                        .box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
                        .box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
                        .box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }
                    </style>'+
                    N'<body>'+
                    N'<h3><font color="SteelBlue">ERROR EN TRANSFERENCIAS</h3>' +
                    N'<h4><font color="SteelBlue">Fecha: '+CONVERT(VARCHAR(12),GETDATE(),103)+'</h4>'+
                    N'<h4><font color="SteelBlue">No existe error en las transferencias</h4>'+
                    N' <br/><br/></body>';

        IF @html IS NOT NULL
        BEGIN
            -- INSERT notificación consolidada
            INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
            VALUES ('A', 'Transferencias', 'pa_Transferencias', @asunto, @html, @w, @destinatarios, @fecha_ini, @fecha_fin);
            EXEC msdb.dbo.Sp_send_dbmail
                @profile_name = 'Informacion_Nomina',
                @Subject      = @asunto,
                @recipients   = @destinatarios,
                @body_format  = 'html',
                @body         = @html;
        END
    END

    /* Limpieza final */
    IF OBJECT_ID(N'tempdb..#tmp_errores_tdd', N'U') IS NOT NULL DROP TABLE #tmp_errores_tdd;
    IF OBJECT_ID(N'tempdb..#tmp_errores_rth', N'U') IS NOT NULL DROP TABLE #tmp_errores_rth;
    IF OBJECT_ID(N'tempdb..#tmp_errores_m',   N'U') IS NOT NULL DROP TABLE #tmp_errores_m;
    IF OBJECT_ID(N'tempdb..#tmp_transferencias', N'U') IS NOT NULL DROP TABLE #tmp_transferencias;
    IF OBJECT_ID(N'tempdb..#tmp_t_rth', N'U') IS NOT NULL DROP TABLE #tmp_t_rth;
    IF OBJECT_ID(N'tempdb..#tmp_t_m',   N'U') IS NOT NULL DROP TABLE #tmp_t_m;
    IF OBJECT_ID(N'tempdb..#tmp_t_tdd', N'U') IS NOT NULL DROP TABLE #tmp_t_tdd;
    IF OBJECT_ID(N'tempdb..#tmp_e_m',   N'U') IS NOT NULL DROP TABLE #tmp_e_m;
    IF OBJECT_ID(N'tempdb..#tmp_e_rth', N'U') IS NOT NULL DROP TABLE #tmp_e_rth;
    IF OBJECT_ID(N'tempdb..#tmp_e_tdd', N'U') IS NOT NULL DROP TABLE #tmp_e_tdd;
    IF OBJECT_ID(N'tempdb..#tmp_p_t',   N'U') IS NOT NULL DROP TABLE #tmp_p_t;
END
