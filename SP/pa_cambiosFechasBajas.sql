
CREATE PROCEDURE [Avisos].[pa_cambiosFechasBajas] @codigo VARCHAR(20)
    , @fechaAnt DATE
    , @fechaNew DATE
AS
DECLARE @tableHTML2 VARCHAR(8000)
    , @tableHTML NVARCHAR(MAX)
    , @tableHTML4  NVARCHAR(MAX)
    , @tableHTML3  NVARCHAR(MAX)
    , @tableHTML5  NVARCHAR(MAX)
    , @nombre VARCHAR(100)
    , @query1  NVARCHAR(MAX)
    , @cuerpo NVARCHAR(MAX)
    , @Dirigido VARCHAR(300)
    , @copia VARCHAR(100)
    , @w INT = 0
    , @i INT = 0
    , @marcajes VARCHAR(500) = ''
    , @Resultmarcajes  NVARCHAR(MAX) = ''
    , @horarios VARCHAR(500) = ''
    , @Resulthorarios  NVARCHAR(MAX) = ''
    , @resultadoTrab  NVARCHAR(MAX)

BEGIN
    DECLARE @fechaIni DATE
        , @fechaFin DATE
        , @estado SMALLINT = 0 
    DECLARE @tablaCuerpo AS TABLE (cuerpo TEXT)

    SELECT @copia = valor
    FROM Configuracion.parametros
    WHERE parametro = 'MAILAVICFCB'  

    SELECT @Dirigido = valor
        , @nombre = referencia_06
    FROM Configuracion.parametros
    WHERE parametro = 'MAILAVICFB' 

    SELECT @w = 0
	 
    SELECT @w = count(*)
    FROM RRHH.Prebajas_PRT b
    INNER JOIN rrhh.vw_datosTrabajadores dt
        ON dt.codigo = b.codigo
    WHERE b.codigo = @codigo

    SELECT @fechaIni = fecha_ini_tiendas
        , @fechaFin = fecha_fin_tiendas
    FROM nomina.calendario_nominas
    WHERE tipo_nomina = 'SQ'
        AND @fechaAnt BETWEEN fecha_ini_tiendas AND fecha_fin_tiendas

    SELECT TOP 1 @estado = estatus
    FROM Asistencia.marcajes
    WHERE codigo_emp_equipo = @codigo
        AND fecha BETWEEN @fechaIni AND @fechaFin

    IF ISNULL(@w, 0) > 0
    BEGIN
        SELECT @resultadoTrab = '<tr><td style="width:30px;text-align: center;">' + dt.compania + '</td>' + '<td style="width:30px;text-align:center;">' + dt.cco + '</td>' + '<td style="width:200px;text-align:center;">' + dt.Desc_CCO + '</td>' + '<td style="width:30px;text-align:center;">' + dt.Trabajador + '</td>' + '<td style="width:200px;text-align:center;">' + dt.Nombre + '</td>' + '<td style="width:30px;text-align:center;">' + convert(VARCHAR(12), dt.Fecha_Antiguedad, 103) + '</td>' + '<td style="width:200px;text-align:center;">' + dt.Cargo + '</td>' + '<td style="width:30px;text-align:center;">' + convert(VARCHAR(12), @fechaAnt, 103) + '</td>' + '<td style="width:30px;text-align:center;">' + convert(VARCHAR(12), @fechaNew, 103) + '</td>' + '<td style="width:30px;text-align:center;">' + CASE 
                WHEN @estado IN (0, 1, 2)
                    THEN 'Pendiente'
                WHEN @estado = 3
                    THEN 'Asentado'
                WHEN @estado = 4
                    THEN 'Legalidazo'
                END + '</td>' + '<td style="width:30px;text-align:center;">' + convert(VARCHAR(12), getdate(), 103) + '</td>'
        FROM RRHH.Prebajas_PRT b
        INNER JOIN rrhh.vw_datosTrabajadores dt
            ON dt.codigo = b.codigo
        WHERE b.codigo = @codigo

        --------------------------------------------------------------------------------------------------------------------------------
        ----Marcajes
        --------------------------------------------------------------------------------------------------------------------------------
        DECLARE CMarcajesBaja CURSOR LOCAL
        FOR
        SELECT '<tr><td style="text-align: center;">' + convert(VARCHAR(12), fecha, 103) + '</td>' + '<td style="text-align: center;">' + isnull(comentario, '') + '</td>' + '<td align="center"style="text-align: center;">' + isnull(hora1, '') + '</td>' + '<td style="text-align: center;">' + isnull(hora2, '') + '</td>' + '<td style="text-align: center;">' + isnull(hora3, '') + '</td>' + '<td style="text-align: center;">' + isnull(hora4, '') + '</td>' + '<td style="text-align: center;">' + isnull(CASE 
                    WHEN estatus = 3
                        THEN 'Asentado'
                    WHEN estatus IN (2, 1)
                        THEN 'Pendiente'
                    WHEN estatus = 4
                        THEN 'Legalizado'
                    END, '') + '</td>' + '<td style="text-align: center;">' + Isnull((
                    SELECT [Utilidades].[fn_minutos_horas](he25a)
                    ), '0') + '</td>' + '<td style="text-align: center;">' + isnull((
                    SELECT [Utilidades].[fn_minutos_horas](he50a)
                    ), '0') + '</td>' + '<td style="text-align: center;">' + isnull((
                    SELECT [Utilidades].[fn_minutos_horas](he100a)
                    ), '0') + '</td>' + '<td style="text-align: center;">' + isnull((
                    SELECT [Utilidades].[fn_minutos_horas](hefa)
                    ), '0') + '</td></tr>'
        FROM asistencia.marcajes
        WHERE codigo_emp_equipo = @codigo
            AND fecha BETWEEN @fechaIni AND @fechaFin
            AND estatus <> 0

        OPEN CMarcajesBaja

        WHILE @@Fetch_Status < 1
        BEGIN
            FETCH CMarcajesBaja
            INTO @marcajes

            IF @@Fetch_Status <> 0
            BEGIN
                BREAK
            END

            SELECT @Resultmarcajes = @Resultmarcajes + @marcajes
                --print @Resultmarcajes
        END

        CLOSE CMarcajesBaja

        DEALLOCATE CMarcajesBaja

        --------------------------------------------------------------------------------------------------------------------------------
        ----Horarios
        --------------------------------------------------------------------------------------------------------------------------------
        DECLARE CHorariossBaja CURSOR LOCAL
        FOR
        SELECT '<tr><td style="text-align: center;">' + convert(VARCHAR(12), fecha, 103) + '</td>' + '<td style="text-align: center;">' + CASE 
                WHEN id_motivos = 'MO000'
                    THEN 'VACACIONES'
                WHEN id_motivos = 'MO001A'
                    THEN notas
                WHEN h.id_jornada_definicion = 9
                    THEN 'LIBRE'
                WHEN id_descanso = 3
                    THEN j.horadesde + '-' + j.horahasta
                ELSE j.horadesde + '-' + j.horadesdedescanso
                END + '</td>' + '<td style="text-align: center;">' + CASE 
                WHEN id_motivos = 'MO000'
                    THEN 'VACACIONES'
                WHEN id_motivos = 'MO001A'
                    THEN notas
                WHEN h.id_jornada_definicion = 9
                    THEN 'LIBRE'
                WHEN id_descanso = 3
                    THEN ''
                ELSE j.horadeshadescanso + '-' + j.horahasta
                END + '</td></tr>'
        FROM Asistencia.rel_trab_horarios h
        INNER JOIN Asistencia.jornadas_definicion j
            ON h.id_jornada_definicion = j.id_jornada_definicion
        WHERE codigo = @codigo
            AND fecha BETWEEN @fechaIni AND @fechaFin

        OPEN CHorariossBaja

        WHILE @@Fetch_Status < 1
        BEGIN
            FETCH CHorariossBaja
            INTO @horarios

            IF @@Fetch_Status <> 0
            BEGIN
                BREAK
            END

            SELECT @Resulthorarios = @Resulthorarios + @horarios
        END

        CLOSE CHorariossBaja

        DEALLOCATE CHorariossBaja

        SET @cuerpo = '<!DOCTYPE html><html><head><title>Baja con cambios
	     Editor</title><meta name="viewport"content="width=device-width, initial-scale=1"> 
	     <style> .centrado { text-align: center;}table {border-collapse: collapse; width: 100%; font-size: smaller; font-family: calibri;}th,td {text-align: left; border-bottom: 1px solid #ddd;
        padding: 8px;}tr:hover {background-color: coral;}tr:nth-child(even) {background-color: #f2f2f2;}      
        </style></head><body style="font-family: calibri;"><div ><br/><h4 class="centrado">Avisos de cambios de Fecha Bajas</h4>
	    <br/><p>Estimado(a),<strong>' + @Dirigido + 
            '</strong></p><hr/><p>Listado de los colaboradores que se les realizó un cambio de fecha de baja en PRT por el área de RRHH</p>
	    <div style="font-family: calibri;font-size: smaller;"><div><table style="font-size: smaller;"><thead><tr><th style="width: 30px;text-align: center;">Empresa</th>
	    <th style="width: 30px;text-align: center;">CCO</th><th style="width: 200px;text-align: center;">Descripción</th><th style="width: 30px;text-align: center;">Cédula</th><th style="width: 200px;text-align: center;">Nombre</th><th style="width: 30px;text-align: center;">Fecha Antigüedad</th><th style="width:200px;text-align:center;">Cargo</th><th style="width: 30px;text-align: center;">Fecha Baja Anterior</th><th style="width: 30px;text-align: center;">Fecha Baja Nueva</th><th style="width: 30px;text-align: center;">Estado Marcajes</th><th style="width: 30px;text-align: center;">Fecha Cambio</th>
	    </tr></thead><tbody>' + @resultadoTrab + 
            '</tbody></table></div></div><p style="text-align: left;"><span style="text-decoration: underline;">Marcaciones registradas del corte de n&oacute;mina</span></p>
	    <div style="font-family: calibri;font-size: smaller;"><div>
	    <table style="font-size: smaller;"><thead>
	    <tr><th style="text-align: center;">Fecha</th><th style="text-align: center;">Notas</th><th style="text-align: center;">Hora Entrada</th><th style="text-align: center;">Hora Salida Descanso</th><th style="text-align: center;">Hora Entrada Descanso</th><th style="text-align: center;">Hora Salida</th><th style="text-align: center;">Estado</th><th style="text-align: center;">Horas 25</th><th>Horas 50</th><th style="text-align: center;">Horas 100</th><th style="text-align: center;">Horas Feriados</th></tr>
	    </thead><tbody>' + @Resultmarcajes + 
            '</tbody></table></div></div><p><span style="text-decoration: underline;">Horarios registradas del corte de n&oacute;mina</span></p><div style="font-family: calibri;font-size: smaller;"><div class="col"><table style="font-size: smaller;width: 400px;" class="table table-striped table-bordered table-hover"><thead><tr><th style="text-align: center;">Fecha</th><th style="text-align: center;">Jornada 1</th><th style="text-align: center;">Jornada 2</th></tr></thead><tbody>' + @Resulthorarios + '</tbody></Table></div></div></div><br/><br/><br/></body></html>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML2 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> No existe colaboradores con cambios en fecha de baja el día de hoy. </h4> </p> ' + N' <hr/>'

        SET @i = 1
    END

    IF @i <> 1
    BEGIN
        -- INSERT notificación consolidada
        INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc, periodoInicio, periodoFin)
        VALUES ('A', 'Bajas', 'pa_cambiosFechasBajas', 'Avisos de cambios de Fecha Bajas', @cuerpo, @w, @dirigido, @copia, @fechaIni, @fechaFin);
        EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
            , @Subject = 'Avisos de cambios de Fecha Bajas'
            , @recipients = @dirigido
            , @body_format = 'html'
            , @copy_recipients = @copia
            , @body = @cuerpo
    END
END
