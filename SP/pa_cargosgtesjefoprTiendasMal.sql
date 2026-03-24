CREATE PROCEDURE [Avisos].[pa_cargosgtesjefoprTiendasMal]
AS
DECLARE @tableHTML2 NVARCHAR(MAX)
    , @tableHTML NVARCHAR(MAX)
    , @tableHTML4 NVARCHAR(MAX)
    , @tableHTML3 NVARCHAR(MAX)
    , @tableHTML5 NVARCHAR(MAX)
    , @nombre VARCHAR(100)
    , @query1 VARCHAR(6000)
    , @cuerpo NVARCHAR(MAX)
    , @Dirigido VARCHAR(1000)
    , @copia VARCHAR(100)
    , @w INT = 0
    , @i INT = 0

BEGIN
    DECLARE @tablaCuerpo AS TABLE (cuerpo TEXT)

    SELECT @copia = valor
    FROM Configuracion.parametros
    WHERE parametro = 'Avisos_VariosC'

    SELECT @Dirigido = valor
    FROM Configuracion.parametros
    WHERE parametro = 'Avisos_Varios'

    SET @nombre = 'Analista de Nómina'

    SELECT @w = 0

    --------------------------------------------------------------------------------------------------------
    ----Listado de CCO con jefe 1 que no pertence al cargo debido.
    --------------------------------------------------------------------------------------------------------
    SELECT @w = 0

    SET @tableHTML5 = ''

    DECLARE @tableCCOCargos AS TABLE (
        cco VARCHAR(15)
        , descripcion VARCHAR(250)
        , cargo VARCHAR(20)
        )

    INSERT INTO @tableCCOCargos
    SELECT cco
        , descripcion
        , (
            SELECT puesto
            FROM rrhh.vw_datosTrabajadores T
            WHERE T.codigo = C.jefe1
			--and Puesto in ('0134', '0100', '0083', '0493', '0691')
            )
    FROM catalogos.centro_costos C
    WHERE esLocal = 'S'
        AND estatus = 1

    SELECT @w = count(*)
    FROM @tableCCOCargos
    WHERE cargo NOT IN (
            SELECT valor
            FROM configuracion.parametros
            WHERE parametro = 'cargo_gteTienda'
            )

    IF @w > 0
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO con jefe 1 cuyo cargo es diferente al parámetro cargo_gteTienda </h4> </p> ' + N' <hr/>' + N'<table id="box-table" >' + N' <tr align="left">' + N' <th align="left"> CCO </th>' + N' <th align="left"> Descripción </th>' + N' <th align="left"> Cod Cargo </th>' + N' <th align="left"> Cargo </th>' + cast((
                    SELECT DISTINCT td = cco
                        , ''
                        , td = descripcion
                        , ''
                        , td = cargo
                        , ''
                        , td = (
                            SELECT descripcion
                            FROM Cargos.cargos C
                            WHERE c.cod_cargo = T.cargo
                            )
                        , ''
                    FROM @tableCCOCargos T
                    WHERE cargo NOT IN (
                            SELECT valor
                            FROM configuracion.parametros
                            WHERE parametro = 'cargo_gteTienda'
                            )
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</table>' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de CCO con jefe 1 que no pertence al cargo debido es de : ' + convert(VARCHAR(5), @w) + '  </p>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO con jefe 1 cuyo cargo es diferente al parámetro cargo_gteTienda </h4> </p> ' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen CCO con jefe 1 que no pertence al cargo debido  </p>' + N' <hr/>'
    END

    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> ' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + isnull(@tableHTML5, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=23" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de Nómina</strong></label></div> <p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p></body>';

    --select @query1  = 'select cco, descripcion, (select cargo from DB_NOMKFC.rrhh.vw_datosTrabajadores T where T.codigo  = C.jefe1), (select puesto from DB_NOMKFC.rrhh.vw_datosTrabajadores T where T.codigo  = C.jefe1), C.jefe1
    --                     from DB_NOMKFC.catalogos.centro_costos C where esLocal = ''S'' and
    --                      (select puesto from DB_NOMKFC.rrhh.vw_datosTrabajadores T where T.codigo  = C.jefe1) not in  (select valor from DB_NOMKFC.configuracion.parametros where parametro  = ''cargo_gteTienda'')
    --                      and estatus = 1'
    -- INSERT notificación consolidada
    INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
    VALUES ('A', 'Jerarquías', 'pa_cargosgtesjefoprTiendasMal', 'Listado de CCO con jefe 1 cuyo cargo es diferente al parámetro “cargo_gteTienda”) ', @cuerpo, @w, @dirigido, @copia);
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
        , @Subject = 'Listado de CCO con jefe 1 cuyo cargo es diferente al parámetro “cargo_gteTienda”) '
        , @recipients = @dirigido
        , @body_format = 'html'
        , @copy_recipients = @copia
        , @body = @cuerpo

    --------------------------------------------------------------------------------------------------------
    ----Listado de CCO con jefe 2 que no pertence al cargo debido.
    --------------------------------------------------------------------------------------------------------
    SELECT @w = 0

    SET @tableHTML5 = ''

    DECLARE @tableCCOCargos2 AS TABLE (
        cco VARCHAR(15)
        , descripcion VARCHAR(250)
        , cargo VARCHAR(20)
        )

    INSERT INTO @tableCCOCargos2
    SELECT cco
        , descripcion
        , (
            SELECT puesto
            FROM rrhh.vw_datosTrabajadores T
            WHERE T.codigo = C.jefe2 ---and Puesto in ('0134', '0100', '0083', '0493', '0691')
            )
    FROM catalogos.centro_costos C
    WHERE esLocal = 'S'
        AND estatus = 1

 


    SELECT @w = count(*)
    FROM @tableCCOCargos2
    WHERE cargo NOT IN (
            SELECT valor
            FROM configuracion.parametros
            WHERE parametro = 'cargo_gteTienda'
            )

    IF @w > 0
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO con jefe 2 cuyo cargo es diferente al parámetro cargo_gteTienda </h4> </p> ' + N' <hr/>' + N'<table id="box-table" >' + N' <tr align="left">' + N' <th align="left"> CCO </th>' + N' <th align="left"> Descripción </th>' + N' <th align="left"> Cod Cargo </th>' + N' <th align="left"> Cargo </th>' + cast((
                    SELECT DISTINCT td = cco
                        , ''
                        , td = descripcion
                        , ''
                        , td = cargo
                        , ''
                        , td = (
                            SELECT descripcion
                            FROM Cargos.cargos C
                            WHERE c.cod_cargo = T.cargo
                            )
                        , ''
                    FROM @tableCCOCargos2 T
                    WHERE cargo NOT IN (
                            SELECT valor
                            FROM configuracion.parametros
                            WHERE parametro = 'cargo_gteTienda'
                            )
                    FOR XML PATH('tr')
                        , TYPE
                    ) AS VARCHAR(max)) + N'</table>' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de CCO con jefe 2 que no pertence al cargo debido es de : ' + convert(VARCHAR(5), @w) + '  </p>'
    END
    ELSE
    BEGIN
        SELECT @tableHTML5 = ' ' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4> Listado de CCO con jefe 2 cuyo cargo es diferente al parámetro cargo_gteTienda</h4> </p> ' + N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen CCO con jefe 2 que no pertence al cargo debido  </p>' + N' <hr/>'
    END
 
    SELECT @cuerpo = '<head> <title> </title>' + N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> ' + N' </head>' + N' <body>' + '<br />' + N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> ' + 
        N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,' + @nombre + '</p>' + N' <hr/>' + isnull(@tableHTML5, '') + ' ' + N'<br/>' + N'<p style="font-family:Calibri">Atentamente,</p> ' + N'<div><p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=24" target="_blank">Ver Informe</a></p><br><label>Atentamente,</label><br><br><label><strong>Departamento de Nómina</strong></label></div> <p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p></body>';

    --select @query1  = 'select cco, descripcion, (select puesto from DB_NOMKFC.rrhh.vw_datosTrabajadores T where T.codigo  = C.jefe2),  (select cargo from DB_NOMKFC.rrhh.vw_datosTrabajadores T where T.codigo  = C.jefe2), C.jefe2
    --                    from DB_NOMKFC.catalogos.centro_costos C where esLocal = ''S'' and
    --                     (select puesto from DB_NOMKFC.rrhh.vw_datosTrabajadores T where T.codigo  = C.jefe2) not in  (select valor from DB_NOMKFC.configuracion.parametros where parametro  = ''cargo_gteTienda'')
    --                     and estatus = 1'
    -- INSERT notificación consolidada
    INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
    VALUES ('A', 'Jerarquías', 'pa_cargosgtesjefoprTiendasMal', 'Listado de CCO con jefe 2 cuyo cargo es diferente al parámetro “cargo_gteTienda”) ', @cuerpo, @w, @dirigido, @copia);
    EXEC msdb.dbo.Sp_send_dbmail @profile_name = 'Informacion_Nomina'
        , @Subject = 'Listado de CCO con jefe 2 cuyo cargo es diferente al parámetro “cargo_gteTienda”) '
        , @recipients = @dirigido
        , @body_format = 'html'  
        , @copy_recipients = @copia
        , @body = @cuerpo
END
