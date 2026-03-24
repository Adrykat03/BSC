CREATE PROCEDURE [Avisos].[pa_validarJerarquiasLocales]
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
    DECLARE @tablaCuerpo AS TABLE (cuerpo TEXT)

    DELETE dbo.avisosTemporal

    SELECT @copia = valor
    FROM Configuracion.parametros
    WHERE parametro = 'Avisos_JQLC'

    SELECT @Dirigido = valor
    FROM Configuracion.parametros
    WHERE parametro = 'Avisos_JQL'

    SET @nombre = 'Analista de Nómina'

    SELECT @w = 0

    SET @tableHTML5 = ''

    --------------------------------------------------------------------------------------------------------
    ----Listado de CCO locales con J1 o J2 menores a 050
    --------------------------------------------------------------------------------------------------------
    SELECT @w = 0

    SET @tableHTML5 = ''

    DECLARE @tabla12 AS TABLE (
        cco VARCHAR(15)
        , descCCO VARCHAR(250)
        , codigo VARCHAR(20)
        , nombre VARCHAR(200)
        , cargoHomologado SMALLINT
        )

    --create table dbo.avisosTemporal (cco varchar(15), descCCO varchar(250),codigo varchar(20), nombre varchar(200), cargoHomologado smallint, tipo char(2) )
    INSERT INTO @tabla12
    SELECT cco
        , descripcion
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
    FROM Catalogos.centro_costos C
    WHERE esLocal = 'S'
        AND estatus = 1
        AND (
            SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe1
            ) > 50
        AND jefe1 IS NOT NULL

    INSERT INTO dbo.avisosTemporal (
        cco
        , descCCO
        , codigo
        , nombre
        , cargoHomologado
        , tipo
        )
    SELECT *
        , 'A1'
    FROM @tabla12
    WHERE cargoHomologado > 50

    SELECT @w = count(*)
    FROM @tabla12
    WHERE cargoHomologado > 50

    IF @w > 0
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO locales con J1  menores a 050 (Locales) </h4> </p> ' + N' <hr/>' + N'<table id="box-table" >' + N' <tr align="left">' + N' <th align="left"> Codigo </th>' + N' <th align="left"> Nombre </th>' + N' <th align="left"> Cargo Homologado  </th>' + cast((
                    SELECT DISTINCT td = codigo
                        , ''
                        , td = nombre
                        , ''
                        , td = cargoHomologado
                        , ''
                    FROM @tabla12 T
                    WHERE cargoHomologado > 50
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</table>' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de CCO con jefe 1 con  menor a 050 es de : ' + convert(VARCHAR(5), @w) + '  </p>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO locales con J1 menores a 050 (Locales)</h4> </p> ' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen  CCO con jefe 1 con cargo menor a 050  </p>' + N' <hr/>'
    END

    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> ' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + isnull(@tableHTML5, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=21" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de Nómina</strong></label></div> <p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p></body>';

    -- select @query1  = 'select cco , descCCO ,codigo  , nombre , cargoHomologado  from  DB_NOMKFC.dbo.avisosTemporal'
    -- INSERT notificación consolidada
    INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
    VALUES ('A', 'Jerarquías', 'pa_validarJerarquiasLocales', 'Listado de CCO locales con J1 menores a 050 (Locales)', @cuerpo, @w, @dirigido, @copia);
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
        , @Subject = 'Listado de CCO locales con J1 menores a 050 (Locales)'
        , @recipients = @dirigido
        ,
        -- @attach_query_result_as_file = 1,
        --@query = @query1 ,
        --@query_result_header = 1,
        --   @query_result_separator =  ';',
        --   @query_result_no_padding = 1,
        --@query_result_width = 32767,
        --@query_attachment_filename = 'Listado de personas.csv',
        @body_format = 'html'
        , @copy_recipients = @copia
        , @body = @cuerpo

    --------------------------------------------------------------------------------------------------------
    ----Listado de CCO locales con J1 o J2 menores a 050
    --------------------------------------------------------------------------------------------------------
    SELECT @w = 0

    SET @tableHTML5 = ''

    DECLARE @tabla12A AS TABLE (
        cco VARCHAR(15)
        , descCCO VARCHAR(250)
        , codigo VARCHAR(20)
        , nombre VARCHAR(200)
        , cargoHomologado SMALLINT
        )

    INSERT INTO @tabla12A
    SELECT cco
        , descripcion
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
    FROM Catalogos.centro_costos C
    WHERE esLocal = 'S'
        AND estatus = 1
        AND (
            SELECT cod_cargo_homologado
            FROM RRHH.vw_datosTrabajadores
            WHERE codigo = C.jefe2
            ) > 50
        AND jefe2 IS NOT NULL

    INSERT INTO dbo.avisosTemporal (
        cco
        , descCCO
        , codigo
        , nombre
        , cargoHomologado
        , tipo
        )
    SELECT *
        , 'A2'
    FROM @tabla12A
    WHERE cargoHomologado > 50

    SELECT @w = count(*)
    FROM @tabla12A
    WHERE cargoHomologado > 50

    IF @w > 0
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO locales con J2 menores a 050 (Locales) </h4> </p> ' + N' <hr/>' + N'<table id="box-table" >' + N' <tr align="left">' + N' <th align="left"> Codigo </th>' + N' <th align="left"> Nombre </th>' + N' <th align="left"> Cargo Homologado  </th>' + cast((
                    SELECT DISTINCT td = codigo
                        , ''
                        , td = nombre
                        , ''
                        , td = cargoHomologado
                        , ''
                    FROM @tabla12A T
                    WHERE cargoHomologado > 50
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</table>' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de CCO con jefe 2 con cargo  menor a 050 es de : ' + convert(VARCHAR(5), @w) + '  </p>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO locales con J2 menores a 050 (Locales)</h4> </p> ' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen  CCO con jefe 2 con cargo menor a 050  </p>' + N' <hr/>'
    END

    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> ' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + isnull(@tableHTML5, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=20" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de Nómina</strong></label></div> <p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p></body>';

    -- select @query1  = 'select cco , descCCO ,codigo  , nombre , cargoHomologado  from  DB_NOMKFC.dbo.avisosTemporal'
    -- INSERT notificación consolidada
    INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
    VALUES ('A', 'Jerarquías', 'pa_validarJerarquiasLocales', 'Listado de CCO locales con J2 menores a 050 (Locales)', @cuerpo, @w, @dirigido, @copia);
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
        , @Subject = 'Listado de CCO locales con J2 menores a 050 (Locales)'
        , @recipients = @dirigido
        , @body_format = 'html'
        , @copy_recipients = @copia
        ,
        --@attach_query_result_as_file = 1,
        --@query = @query1 ,
        --@query_result_header = 1,
        --   @query_result_separator =  ';',
        --   @query_result_no_padding = 1,
        --@query_result_width = 32767,
        --@query_attachment_filename = 'Listado de personas.csv',
        @body = @cuerpo
        --drop table  dbo.avisosTemporal
END
