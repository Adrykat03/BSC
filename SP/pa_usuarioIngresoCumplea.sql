-- =============================================
-- Author:		<Pamela Pupiales>
-- Create date: <18-04-2023>
-- Description:	<Aviso sobre que usuario modifico el dia de cumpleaños de un trabajador>
-- =============================================
-- =============================================
-- Author:		<Steven Quispe>
-- Create date: <06-03-2024>
-- Description:	<Se agrega el campo "Fecha de antiguedad">
-- =============================================
CREATE PROCEDURE [Avisos].[pa_usuarioIngresoCumplea]
	AS
	BEGIN
	DECLARE @fecha date = DATEADD(DAY, 0, CONVERT(date, GETDATE()))
	IF OBJECT_ID(N'tempdb..#InfoUser', N'U') IS NOT NULL
		DROP TABLE #InfoUser
	IF OBJECT_ID(N'tempdb..#HistCumple', N'U') IS NOT NULL
		DROP TABLE #HistCumple
	IF OBJECT_ID(N'tempdb..#LogUser', N'U') IS NOT NULL
		DROP TABLE #LogUser
	IF OBJECT_ID(N'tempdb..#DetalleCumple', N'U') IS NOT NULL
		DROP TABLE #DetalleCumple
	IF OBJECT_ID(N'tempdb..#Cumpleanos', N'U') IS NOT NULL
		DROP TABLE #Cumpleanos

	SELECT Nombre, Codigo, Compania ,Compania_Desc, Clase_Nomina, Desc_Clase_Nomina, CCO, Desc_CCO, Fecha_Antiguedad
	INTO #InfoUser FROM [Adam_consolidados].[dbo].[TB_Trabajadores_Mes]

	SELECT cco, usuario ,codigo,fecha,referencia_05 as fechaCumple, fechaCambio 
	INTO #HistCumple FROM [DB_NOMKFC].[Asistencia].[histCumple] 

	SELECT fecha,id_usuario,descripcion 
	INTO #LogUser FROM [DB_NOMKFC].[Logs].[log_usuarios]

	SELECT A.cco, A.usuario, A.codigo, A.fecha, A.fechaCumple, A.fechaCambio, B.descripcion  
	INTO #DetalleCumple FROM #HistCumple A 
	LEFT JOIN #LogUser B
	ON A.fecha= B.fecha 
	WHERE A.usuario= B.id_usuario

	SELECT distinct C.Codigo, C.Nombre, C.Compania , C.Compania_Desc, C.Clase_Nomina, C.Desc_Clase_Nomina, C.CCO, C.Desc_CCO, CONVERT(varchar(10), D.fechaCumple, 120) AS fechaCumple, 
	D.fechaCambio as FechaCnuevo, CONVERT(varchar(10), D.fecha, 120) as fechaModificacionU, UPPER(D.usuario) as usuario, CONVERT(varchar(10), C.Fecha_Antiguedad, 120) AS Fecha_Antiguedad
	INTO #Cumpleanos FROM #InfoUser C
	JOIN #DetalleCumple D
	ON C.CCO= D.cco
	where C.Codigo= D.codigo

	DECLARE @tiene1 int = 0
		DECLARE @htmlE varchar(max)='', @html1 varchar(max)='', @asunto varchar (400), @saludos varchar(500)='', @destinatarios varchar(max); 
		declare @fecha2 date = DATEADD(DAY, 0, CONVERT(date, GETDATE()))
		SELECT @destinatarios= valor, @asunto=descripcion FROM [DB_NOMKFC].[Configuracion].[parametros] WHERE parametro = 'CambioCumple'

		SELECT DISTINCT @tiene1 = COUNT(1) FROM  #Cumpleanos where FORMAT(DATEADD(day, +1, fechaModificacionU), 'yyyy-MM-dd') = FORMAT(@fecha, 'yyyy-MM-dd')

		IF (@tiene1 <> 0)
		BEGIN
			SELECT @htmlE=N' <style type="text/css">
											.box-table { font-family: "Calibri"; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
											.box-table th { text-align: center; padding: 5px; height: 24px;  font-size: 12px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
											.box-table td { text-align: left; padding: 5px; height: 22px; font-size: 10px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } 
											</style>'
			IF (@tiene1 <> 0)
				BEGIN
				select @html1=
								N'<body>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> 
									Mediante la presente ponemos en su conocimiento, el día ' +CONVERT(VARCHAR, @fecha, 103)+ ',
									el listado de los cambios de fechas de cumpleaños realizados el día '+ CONVERT(VARCHAR, DATEADD(day, -1, @fecha), 103) + ' por un usuario específico.'+
									N' <br>'+
									N' <table class="box-table" >' +
								
									N' <tr>'+
									N' <th style="text-align:center"> Código Colaborador</th>'+
									N' <th style="text-align:center"> Nombre Colaborador</th>'+
									N' <th style="text-align:center"> Código Empresa</th>'+
									N' <th style="text-align:center"> Nombre Empresa</th>'+
									N' <th style="text-align:center"> Clase Nómina</th>'+
									N' <th style="text-align:center"> Nombre Clase Nómina</th>'+	
									N' <th style="text-align:center"> CCO</th>'+
									N' <th style="text-align:center"> Descripción CCO</th>'+
									N' <th style="text-align:center"> Fecha Original Cumpleaños</th>'+
									N' <th style="text-align:center"> Fecha Cambio Cumpleaños</th>'+
									N' <th style="text-align:center"> Fecha Modificación</th></th>'+
  									N' <th style="text-align:center"> Fecha Antiguedad</th>' + 
									N' <th style="text-align:center"> Usuario</th>'+
							
									cast( (select 
								
												td = ISNULL(e.Codigo,'N/A'),'',
												td = ISNULL(e.Nombre,'N/A'),'',
												td = ISNULL(e.Compania,'N/A'),'',
												td = ISNULL(e.Compania_Desc,'N/A'),'',
												td = ISNULL(e.Clase_Nomina,'N/A'),'',
												td = ISNULL(e.Desc_Clase_Nomina,'N/A'),'',
												td = ISNULL(e.CCO,'N/A'),'',
												td = ISNULL(e.Desc_CCO,'N/A'),'',
												td = CAST(e.fechaCumple AS varchar),'',
												td = CAST(e.FechaCnuevo AS varchar),'',
												td = CAST(e.fechaModificacionU AS varchar),'',
												td = CAST(e.Fecha_Antiguedad AS varchar),'',
												td = ISNULL(e.usuario,'N/A'),''

												FROM #Cumpleanos e where FORMAT(DATEADD(day, +1, fechaModificacionU), 'yyyy-MM-dd') = FORMAT(@fecha, 'yyyy-MM-dd') order by fechaModificacionU desc
								
									FOR XML PATH('tr'),TYPE
									) as varchar(max))+
										N'</table>'+
										N'<br>'+
										N' <br/></body>' 
				END
		
				if @html1 is not null 
					declare @html varchar(max)= @htmlE + ' ' +@html1 
					begin
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
							VALUES ('A', 'Aniversarios', 'pa_usuarioIngresoCumplea', @asunto, @html, @tiene1, @destinatarios);
							exec msdb.dbo.Sp_send_dbmail
							@profile_name = 'Informacion_Nomina',  
							@Subject = @asunto,
							@recipients = @destinatarios,
							-- @recipients = 'pasante.nominadosec@kfc.com.ec;',
							@body_format= 'html',
							@body = @html
					end
	END
		ELSE
			BEGIN
						select @html1=N'<body>'+
							N' <h2 style="font-family: "Calibri"; text-align:center">Notificación de modificación Cumpleaños</h2>'+ 
							N' <br/>'+
							N' <p style="border: 2px solid #d8d8d8; background: #white; font-weight:normal; padding: 100px; border-left: solid rgb(0, 103, 198);  font-family: "Calibri";"> 
							Mediante el presente ponemos en su conocimiento, el día '+CONVERT(VARCHAR, @fecha, 103)+' <br/>
							No se encontraron modificaciones de fechas de Cumpleaños del día '+ CONVERT(VARCHAR, DATEADD(day, -1, @fecha), 103) +'</h3></br>'+
							N' <br/><br/><br/><br/>  </body>';

						if @html1 is not null 
						begin
						-- INSERT notificación consolidada
						INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
						VALUES ('A', 'Aniversarios', 'pa_usuarioIngresoCumplea', @asunto, @html1, @tiene1, @destinatarios);
						exec msdb.dbo.Sp_send_dbmail
							@profile_name = 'Informacion_Nomina', 
							@Subject = @asunto,
							@recipients = @destinatarios,
							-- @recipients = 'pasante.nominadosec@kfc.com.ec;',
							@body_format= 'html',
							@body = @html1
						end
			END
END