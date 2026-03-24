CREATE PROCEDURE [Avisos].[pa_validarJerarquiasCarNoPlanta]
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
    --------------------------------------------------------------------------------------------------------
    ----Valide es local "NO" el cargo Homologado de la jerarquia debe ser > 060 no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta) jefe 1
    --------------------------------------------------------------------------------------------------------
    DECLARE @tablaCuerpo AS TABLE (cuerpo TEXT)

    SELECT @copia = valor
    FROM Configuracion.parametros
    WHERE parametro = 'Avisos_LTJMNC'

    SELECT @Dirigido = valor
    FROM Configuracion.parametros
    WHERE parametro = 'Avisos_LTJN2'

    SET @nombre = 'Analista de Nómina'

    SELECT @w = 0

    SET @tableHTML5 = ''

    DECLARE @tabla AS TABLE (
        trabajador CHAR(10)
        , nombreTrab VARCHAR(250)
        , cco VARCHAR(15)
        , descCCO VARCHAR(250)
        , codigo VARCHAR(20)
        , nombre VARCHAR(200)
        , cargoHomologado SMALLINT
        , car VARCHAR(150)
        )

    INSERT INTO @tabla
    SELECT trabajador
        , nombre
        , cco
        , Desc_CCO
        , jefe1
        , (
            SELECT Nombre
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1
            ) AS nombre
        , (
            SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1
            ) AS cod_homologado
        , CAR
    FROM RRHH.vw_datosTrabajadores C
    WHERE Situacion = 'Activo'
        AND car <> 'LOCALES'
        AND eslocal = 'NO'
        AND jefe1 IS NOT NULL
        AND clase_nomina NOT IN ('11', '27')
        AND (
            SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1
            ) > 60 ---and cco in (select cco from Catalogos.VW_CCO where Estado = 'Abierto' and esLocal = 'S')   

    SELECT @w = count(*)
    FROM @tabla
    WHERE cargoHomologado > 60

    --select @query1  = ';with myCTE as (  select trabajador, nombre as nombreTrab, cco, Desc_CCO , jefe1 , (select Nombre from DB_nomkfc.RRHH.vw_datosTrabajadores where codigo = C.jefe1) as nombre,
    --                     (select cod_cargo_homologado from DB_nomkfc.RRHH.vw_datosTrabajadores where codigo = C.jefe1)  as cod_homologado, CAR
    --                      from DB_nomkfc.RRHH.vw_datosTrabajadores C  where   Situacion = ''Activo'' and eslocal = ''NO'' and car <> ''LOCALES'' and jefe1 is not null and clase_nomina not in (11,27)    
    --                     )SELECT * FROM myCTE where cod_homologado > 60'
    IF @w > 0
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de personas (CAR) con J1 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))  </h4> </p> ' + N' <hr/>' + N'<table id="box-table" >' + N' <tr align="left">' + N' <th align="left"> Codigo </th>' + N' <th align="left"> Nombre </th>' + N' <th align="left"> Cargo Homologado  </th>' + cast((
                    SELECT DISTINCT td = codigo
                        , ''
                        , td = nombre
                        , ''
                        , td = cargoHomologado
                        , ''
                    FROM @tabla T
                    WHERE cargoHomologado > 60
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</table>' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de personas (CAR) con J1 menores a 060 es de : ' + convert(VARCHAR(5), @w) + '  </p>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de personas (CAR) con J1 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))</h4> </p> ' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen de personas (CAR) con J1 menores a 060  </p>' + N' <hr/>'
    END

    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> ' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + isnull(@tableHTML5, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' + N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=18" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de Nómina</strong></label></div> <p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p></body>';

    -- INSERT notificación consolidada
    INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
    VALUES ('A', 'Jerarquías', 'pa_validarJerarquiasCarNoPlanta', 'Listado de personas (CAR) con J1 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))', @cuerpo, @w, @Dirigido, @copia);
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
        , @Subject = 'Listado de personas (CAR) con J1 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))'
        , @recipients = @Dirigido
        , @body_format = 'html'
        ,
        --@attach_query_result_as_file = 1,
        --@query = @query1 ,
        --@query_result_header = 1,
        --   @query_result_separator =  ';',
        --   @query_result_no_padding = 1,
        --@query_result_width = 32767,
        -- @query_attachment_filename = 'Listado de personas.csv',
        @copy_recipients = @copia
        , @body = @cuerpo

    --------------------------------------------------------------------------------------------------------
    ----Valide es local "NO" el cargo Homologado de la jerarquia debe ser > 060 que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta) jefe 2
    --------------------------------------------------------------------------------------------------------
    DELETE @tablaCuerpo

    SELECT @w = 0

    SET @tableHTML5 = ''

    DELETE @tabla

    INSERT INTO @tabla
    SELECT trabajador
        , nombre
        , cco
        , Desc_CCO
        , jefe2
        , (
            SELECT Nombre
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2
            ) AS nombre
        , (
            SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2
            ) AS cod_homologado
        , CAR
    FROM RRHH.vw_datosTrabajadores C
    WHERE Situacion = 'Activo'
        AND car <> 'LOCALES'
        AND Jefe2 IS NOT NULL
        AND clase_nomina NOT IN ('11', '27')
        AND (
            SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2
            ) > 60
        AND eslocal = 'NO'

    ---and cco in (select cco from Catalogos.VW_CCO where Estado = 'Abierto' and esLocal = 'S') 
    SELECT @w = count(*)
    FROM @tabla
    WHERE cargoHomologado > 60

    --select @query1  = ';with myCTE as (  select trabajador, nombre as nombreTrab, cco, Desc_CCO , jefe2 , (select Nombre from DB_nomkfc.RRHH.vw_datosTrabajadores where codigo = C.jefe2) as nombre,
    --                     (select cod_cargo_homologado from DB_nomkfc.RRHH.vw_datosTrabajadores where codigo = C.jefe2)  as cod_homologado, CAR
    --                      from DB_nomkfc.RRHH.vw_datosTrabajadores C  where   Situacion = ''Activo'' and car <> ''LOCALES'' and eslocal = ''NO'' and jefe2 is not null and clase_nomina not in (11,27)  
    --                     )SELECT * FROM myCTE where cod_homologado > 60'
    IF @w > 0
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de personas (CAR) con J2 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))  </h4> </p> ' + N' <hr/>' + N'<table id="box-table" >' + N' <tr align="left">' + N' <th align="left"> Codigo </th>' + N' <th align="left"> Nombre </th>' + N' <th align="left"> Cargo Homologado  </th>' + cast((
                    SELECT DISTINCT td = codigo
                        , ''
                        , td = nombre
                        , ''
                        , td = cargoHomologado
                        , ''
                    FROM @tabla T
                    WHERE cargoHomologado > 60
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</table>' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de personas (CAR) con J2 menores a 060 es de : ' + convert(VARCHAR(5), @w) + '  </p>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de personas (CAR) con J2 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))</h4> </p> ' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen de personas (CAR) con J2 menores a 060  </p>' + N' <hr/>'
    END

    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> ' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + isnull(@tableHTML5, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' + N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=19" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de Nómina</strong></label></div> <p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p></body>';

    -- INSERT notificación consolidada
    INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
    VALUES ('A', 'Jerarquías', 'pa_validarJerarquiasCarNoPlanta', 'Listado de personas (CAR) con J2 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))', @cuerpo, @w, @Dirigido, @copia);
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
        , @Subject = 'Listado de personas (CAR) con J2 menores a 060 (que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta))'
        , @recipients = @Dirigido
        , @body_format = 'html'
        ,
        --@attach_query_result_as_file = 1,
        --@query = @query1 ,
        --@query_result_header = 1,
        --   @query_result_separator =  ';',
        --   @query_result_no_padding = 1,
        --@query_result_width = 32767,
        --@query_attachment_filename = 'Listado de personas.csv',
        @copy_recipients = @copia
        , @body = @cuerpo
END
