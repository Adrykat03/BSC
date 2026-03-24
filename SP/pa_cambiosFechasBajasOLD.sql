
CREATE PROCEDURE [Avisos].[pa_cambiosFechasBajasOLD] 
      @codigo VARCHAR(20)
    , @fechaAnt DATE
    , @fechaNew DATE
AS
 DECLARE @tableHTML2 VARCHAR(8000)
    , @tableHTML VARCHAR(8000)
    , @tableHTML4 VARCHAR(8000)
    , @tableHTML3 VARCHAR(8000)
    , @tableHTML5 VARCHAR(8000)
    , @nombre VARCHAR(100)
    , @query1 VARCHAR(6000)
    , @cuerpo NVARCHAR(MAX)
    , @Dirigido VARCHAR(300)
    , @copia VARCHAR(100)
    , @w INT = 0
    , @i INT = 0

BEGIN
    DECLARE @fechaIni DATE
        , @fechaFin DATE
        , @estado SMALLINT = 0

    IF OBJECT_ID(N'tempdb..#tabla', N'U') IS NOT NULL
        DROP TABLE #tabla

    DECLARE @tablaCuerpo AS TABLE (cuerpo TEXT)

    SELECT @copia = valor
    FROM Configuracion.parametros
    WHERE parametro = 'MAILAVICFCB' ---'sabrina.chinchin@kfc.com.ec;dennis.suarez@gmail.com'

    SELECT @Dirigido = valor
        , @nombre = referencia_06
    FROM Configuracion.parametros
    WHERE parametro = 'MAILAVICFB' --'mariajose.pulla@kfc.com.ec'
        --SET @nombre = 'Silvana Varela'

    SELECT @w = 0

    SELECT dt.compania
        , dt.cco
        , dt.Desc_CCO
        , dt.Trabajador
        , dt.Nombre
        , dt.Fecha_Antiguedad
        , dt.Cargo
    INTO #tabla
    FROM RRHH.Prebajas_PRT b
    INNER JOIN rrhh.vw_datosTrabajadores dt
        ON dt.codigo = b.codigo
    WHERE b.codigo = @codigo

    --and accion = 'Se Actualizo Prebaja PRT'  and Referencia_06 = 'Cambios de fecha baja'
    --and  convert(DATE,referencia_05) = convert(DATE,getdate()) 
    SELECT @w = count(1)
    FROM #tabla

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
        SELECT @tableHTML2 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> 
		                              <h4>Listado de los colaboradores que se les realizó un cambio de fecha de baja en PRT por el área de RRHH </h4> </p> ' + N' <br/>' + 
									  N'<TABLE id="box-TABLE" >' + N' <tr align="left">' + N' <th align="left"> Empresa</th>' + N' <th align="left"> CCO </th>' + 
									  N' <th align="left"> Descripción CCO </th>' + N' <th align="left"> Trabajador </th>' + 
									  N' <th align="left"> Nombre </th>' + N' <th align="left"> Fecha Antigüedad </th>' + 
									  N' <th align="left"> Fecha Nueva </th>' + N' <th align="left"> Fecha Antigüedad </th>' + 
									  N' <th align="left"> Cargo </th>' + N' <th align="left"> Estado Marcajes </th>' + 
									  N' <th align="left"> Fecha Cambio </th>' + CAST((
                    SELECT DISTINCT td = compania
                        , ''
                        , td = cco
                        , ''
                        , td = Desc_CCO
                        , ''
                        , td = trabajador
                        , ''
                        , td = nombre
                        , ''
                        , td = CONVERT(VARCHAR, @fechaAnt, 103)
                        , ''
                        , td = CONVERT(VARCHAR, @fechaNew, 103)
                        , ''
                        , td = CONVERT(VARCHAR, Fecha_Antiguedad, 103)
                        , ''
                        , td = Cargo
                        , ''
                        , td = CASE 
                            WHEN @estado IN (0, 1, 2)
                                THEN 'Pendiente'
                            WHEN @estado = 3
                                THEN 'Asentado'
                            WHEN @estado = 4
                                THEN 'Legalidazo'
                            END
                        , ''
                        , td = CONVERT(VARCHAR, getdate(), 103)
                    FROM #tabla
                    ORDER BY trabajador
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</TABLE>' + N'<hr/>'
    
	   Select * from asistencia.marcajes
	   where codigo_emp_equipo = @codigo
	   and fecha between @fechaIni and @fechaFin

	    Select * from asistencia.marcajes
	   where codigo_emp_equipo = @codigo
	   and fecha between @fechaIni and @fechaFin
	
	END
    ELSE
    BEGIN
        SELECT @tableHTML2 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> No existe colaboradores con cambios en fecha de baja el día de hoy. </h4> </p> ' + N' <hr/>'

        SET @i = 1
    END

    SET @tableHTML2 = Replace(@tableHTML2, '<td>', '<td><small>')
    SET @tableHTML2 = Replace(@tableHTML2, '</td>', '</small></td>')

    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-TABLE { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-TABLE th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-TABLE td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style>' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + ISNULL(@tableHTML2, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' + N'<p style="font-family:Calibri"><strong>Soporte NOMINA</strong></p></body>';

    IF @i <> 1
    BEGIN
        -- INSERT notificación consolidada
        INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc, periodoInicio, periodoFin)
        VALUES ('A', 'Bajas', 'pa_cambiosFechasBajasOLD', 'Avisos de cambios de Fecha Bajas', @cuerpo, @w, @dirigido, @copia, @fechaIni, @fechaFin);
        EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
            , @Subject = 'Avisos de cambios de Fecha Bajas'
            , @recipients = @dirigido
            , @body_format = 'html'
            , @copy_recipients = @copia
            , @body = @cuerpo
     END
END
