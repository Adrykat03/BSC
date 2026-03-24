-- =============================================
-- Author:		<Pamela Pupiales>
-- Create date: <30/03/2023>
-- Description:	<Alerta para informar el conteo de los campos nulos en la información de los colaboradores y montos P&G>
-- =============================================
-- =============================================
-- Edit:		<Steven Quispe>
-- Edition date: <02/04/2024>
-- Description:	<Se aumenta la comprobación de la existencia de datos en Adam Consolidados, y se toma el año de ejecución automaticamente>
-- =============================================

CREATE PROCEDURE [Avisos].[pa_TrabajadoresValidacion]
AS
BEGIN
-- Comprobacion de existencia de datos en la base Adam Consolidados
IF( SELECT COUNT(Codigo) FROM [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes]  WHERE CONVERT(INT,Anio) >= YEAR(CONVERT(date, GETDATE())) and CONVERT(INT,Mes)= MONTH(DATEADD(DAY, 0, CONVERT(date, GETDATE()))) ) > 0
	BEGIN
		DECLARE @fecha date = DATEADD(DAY, 0, CONVERT(date, GETDATE()))
		DECLARE @NumTrabajadores int = 0
	
		IF OBJECT_ID(N'tempdb..#Trabajadores', N'U') IS NOT NULL
			DROP TABLE #Trabajadores
		IF OBJECT_ID(N'tempdb..#TrabajadoresMes', N'U') IS NOT NULL
			DROP TABLE #TrabajadoresMes
		IF OBJECT_ID(N'tempdb..#NumTrabajadoresMes', N'U') IS NOT NULL
			DROP TABLE #NumTrabajadoresMes
		IF OBJECT_ID(N'tempdb..#MontosPG', N'U') IS NOT NULL
			DROP TABLE #MontosPG

		--Tabla de trabajadores, CASO 1: Trabajadores con registros NULL 
		SELECT Codigo,Trabajador,Nombre,Compania,Compania_Desc,Clase_Nomina,Desc_Clase_Nomina,Desc_Tipo_Contrato,Fecha_Antiguedad,Fecha_Ingreso,Cargo,Sueldo,CCO,Desc_CCO,Region,Discapacitado,Genero,Sectorial 
		INTO #Trabajadores FROM [Adam_Consolidados].[dbo].[TB_Trabajadores] WITH (NOLOCK)
		WHERE Situacion='Activo' and  
			(
				ISNULL(Codigo, '') = '' 
				or ISNULL(Trabajador, '') = '' 
				or ISNULL(Nombre, '') = '' 
				or ISNULL(Compania, '') = '' 
				or ISNULL(Compania_Desc, '') = '' 
				or ISNULL(Desc_Clase_Nomina, '') = '' 
				or ISNULL(Clase_Nomina, '') = '' 
				or ISNULL(Desc_Tipo_Contrato, '') = '' 
				or  ISNULL(Fecha_Antiguedad, '') = '' 
				or ISNULL(Fecha_Ingreso, '') = '' 
				or ISNULL(Cargo, '') = '' 
				or ISNULL(Sueldo, 0) = 0 
				or ISNULL(CCO, '') = '' 
				or ISNULL(Desc_CCO, '') = '' 
				or ISNULL(Region, '') = '' 
				or ISNULL(Discapacitado, '') = '' 
				or ISNULL(Genero, '') = '' 
				or ISNULL(Sectorial, '') = '' 
			)

		-- Trabajadores sin registro de horas semanales
		SELECT Codigo, Trabajador, Nombre, Compania, Compania_Desc, Anio, Mes, HRS_TRAB_Semana,Clase_Nomina, Desc_Clase_Nomina, Desc_Tipo_Contrato, Fecha_Antiguedad, Fecha_Ingreso,Cargo,Sueldo,CCO,Desc_CCO,Region,Discapacitado,Genero,Sectorial 
		INTO #TrabajadoresMes FROM [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes] WITH (NOLOCK)
		WHERE CONVERT(INT,Anio) >= YEAR(CONVERT(date, GETDATE())) and CONVERT(INT,Mes)= MONTH(DATEADD(DAY, 0, CONVERT(date, GETDATE()))) and (ISNULL(Mes, '') = '' or ISNULL(Codigo, '') = '' or ISNULL(Trabajador, '') = '' or ISNULL(Nombre, '') = '' or ISNULL(Compania, '') = '' or ISNULL(Compania_Desc, '') = '' or 
		ISNULL(Desc_Clase_Nomina, '') = '' or ISNULL(Clase_Nomina, '') = '' or ISNULL(Desc_Tipo_Contrato, '') = '' or  ISNULL(Fecha_Antiguedad, '') = '' or ISNULL(Fecha_Ingreso, '') = '' or
		ISNULL(Cargo, '') = '' or ISNULL(Sueldo, 0) = 0 or ISNULL(CCO, '') = '' or ISNULL(Desc_CCO, '') = '' or ISNULL(Region, '') = '' or ISNULL(Discapacitado, '') = '' or ISNULL(Genero, '') = '' or 
		ISNULL(Sectorial, '') = '' or ISNULL(HRS_TRAB_Semana, '') = '')

		--Conteo de trabajadores por empresa en el presente mes
		SELECT DISTINCT Compania,Compania_Desc, COUNT(Trabajador) AS Trabajadores 
		INTO #NumTrabajadoresMes FROM [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes] 
		WHERE CONVERT(INT,Anio) >= YEAR(CONVERT(date, GETDATE())) and CONVERT(INT,Mes)= MONTH(DATEADD(DAY, 0, CONVERT(date, GETDATE()))) and Situacion='Activo' 
		GROUP BY Compania, Compania_Desc
	
		--Tabla Montos P&G, CASO 3

		SELECT Agrupacion, Compania, Concepto,Mes,  COUNT( distinct Trabajador) as Num_Trabajadores,  FORMAT(SUM(Monto_PyG), '#,##0.00') as Monto_PyG_Compania
		into #MontosPG FROM [Adam_Consolidados].[dbo].[TB_Montos_PyG]
		WHERE CONVERT(INT,Anio) >= YEAR(CONVERT(date, GETDATE())) and CONVERT(INT,Mes)= MONTH(DATEADD(DAY, 0, CONVERT(date, GETDATE()))) AND Agrupacion='CONCEPTOS KFC' AND Concepto IN (9885,9890)
		GROUP BY Agrupacion, Compania, Concepto,Mes
		order by Compania,Concepto, Mes
	
		DECLARE @tiene1 int = 0, @tiene2 int = 0, @tiene3 int = 0, @tiene4 int = 0
		DECLARE @htmlE varchar(max)='', @html1 varchar(max)='', @html2 varchar(max)='', @html3 varchar(max)='',@html4 varchar(max)='', @asunto varchar (400), @saludos varchar(500)='', @destinatarios varchar(max); 
	
		SELECT @destinatarios= valor, @asunto=descripcion FROM [DB_NOMKFC].[Configuracion].[parametros] WHERE parametro = 'AvisosTrabMonto'
		SELECT DISTINCT @tiene1 = COUNT(1) FROM  #Trabajadores --0
		SELECT DISTINCT @tiene2 = COUNT(1) FROM  #TrabajadoresMes -- 0
		SELECT DISTINCT @tiene3 = COUNT(1) FROM  #NumTrabajadoresMes --1
		SELECT DISTINCT @tiene4 = COUNT(1) FROM  #MontosPG --1
		
		IF (@tiene1 = 0 or @tiene2 = 0 or @tiene3 <> 0 or @tiene4 <> 0)
		BEGIN
			SELECT @htmlE=
						N' <style type="text/css">
					.box-table { font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
					.box-table th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
					border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
					.box-table td { text-align: center; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }
					.box{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
					.box th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
					border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
					.box td { text-align: right; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }

					.box2{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
					.box2 th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
					border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
					.box2 td { text-align: left; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }

					.aviso{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
					.aviso th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); 
					border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
					.aviso td { text-align: left; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; }

				</style>'+
			N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> 
									Mediante el presente ponemos en su conocimiento, el día ' +CONVERT(VARCHAR, @fecha, 103)+ ', los siguientes reportes del presente mes.'
	
			IF (@tiene1 <> 0)
				BEGIN
				select @html1= 	
								N'<body>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
								
									N' <br/>'+
									N' <h4 style="font-family: Calibri;">Trabajadores con registros NULL importantes </h4>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> 
									Listado de trabajadores que tienen registros NULL de la base [Adam_Consolidados].[dbo].[TB_Trabajadores]'+
									N' <br>'+
									N' <table class="box-table" >' +
									N' <tr>'+
									N' <th style="text-align:center"> Código</th>'+
									N' <th style="text-align:center"> Trabajador</th>'+
									N' <th style="text-align:center"> Nombre</th>'+
									N' <th style="text-align:center"> Compañía</th>'+
									N' <th style="text-align:center"> Descripción Compañía</th>'+
									N' <th style="text-align:center"> Clase Nómina</th>'+
  									N' <th style="text-align:center"> Descripción Clase Nómina</th>'+
									N' <th style="text-align:center"> Descripción tipo Contrato</th>'+
									N' <th style="text-align:center"> Fecha Antiguedad</th>'+
									N' <th style="text-align:center"> Fecha Ingreso</th>'+
									N' <th style="text-align:center"> Cargo</th>'+
									N' <th style="text-align:center"> Sueldo</th>'+
									N' <th style="text-align:center"> CCO</th>'+
									N' <th style="text-align:center"> Descripción CCO</th>'+
									N' <th style="text-align:center"> Región</th>'+
									N' <th style="text-align:center"> Discapacitado</th>'+
									N' <th style="text-align:center"> Género</th>'+
									N' <th style="text-align:center"> Sectorial</th>'+
	
									cast( (select 
												td = ISNULL(e.Codigo,'N/A'),'',
												td = ISNULL(e.Trabajador,'N/A'),'',
												td = ISNULL(e.Nombre,'N/A'),'',
												td = ISNULL(e.Compania,'N/A'),'',
												td=  ISNULL(e.Compania_Desc,'N/A'),'',
												td=  ISNULL(e.Clase_Nomina, 'N/A'),'',
												td=  ISNULL(e.Desc_Clase_Nomina, 'N/A'),'',
												td=  ISNULL(e.Desc_Tipo_Contrato, 'N/A'),'',
												td=	 CAST(e.Fecha_Antiguedad AS varchar),'',
												td=  CAST(e.Fecha_Ingreso AS varchar),'',
												td=  ISNULL(e.Cargo, 'N/A'),'',
												td=  CAST(e.Sueldo AS varchar),'',
												td=  ISNULL(e.CCO, 'N/A'),'',
												td=  ISNULL(e.Desc_CCO, 'N/A'),'',
												td=  ISNULL(e.Region, 'N/A'),'',
												td=  ISNULL(e.Discapacitado, 'N/A'),'',
												td=  ISNULL(e.Genero, 'N/A'),'',
												td=  ISNULL(e.Sectorial, 'N/A'),''
										
												FROM #Trabajadores e
								
									FOR XML PATH('tr'),TYPE
									) as varchar(max))+
										N'</table>'+
										N'<br>'+
										N' <br/></body>' 
				END
				else
				BEGIN
				select @html1=N'<body>'+
						
						N' <table class="box-table">' +N' <tr>' +
								N' <th style="text-align:center" > Notificación</th>'+
							N' </tr>'+
							N' <tr>'+
								N' <td >
								No se encontraron trabajadores con registros NULL en la base [Adam_Consolidados].[dbo].[TB_Trabajadores].</td>'+N' </tr>'+
						N'</table>'+
										N' <br/> <br/></body>';
						
				END
			IF (@tiene2 <> 0)
				BEGIN
					select @html2= 	
								N'<body>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> 
								
									Listado de trabajadores sin registro de horas semanales de la base [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes]'+
									N' <br/>'+
									N' <h3 style="font-family: Calibri;">Trabajadores sin registro de horas semanales </h3>'+
									N' <br>'+
									N' <table class="box-table" >' +
									N' <tr>'+
									N' <th style="text-align:center"> Código</th>'+
									N' <th style="text-align:center"> Trabajador</th>'+
									N' <th style="text-align:center"> Nombre</th>'+
									N' <th style="text-align:center"> Compañía</th>'+
									N' <th style="text-align:center"> Descripción Compañía</th>'+
									N' <th style="text-align:center"> Año</th>'+
									N' <th style="text-align:center"> Mes</th>'+
									N' <th style="text-align:center"> Horas Semanales</th>'+
									N' <th style="text-align:center"> Clase Nómina</th>'+
  									N' <th style="text-align:center"> Descripción Clase Nómina</th>'+
									N' <th style="text-align:center"> Descripción tipo Contrato</th>'+
									N' <th style="text-align:center"> Fecha Antiguedad</th>'+
									N' <th style="text-align:center"> Fecha Ingreso</th>'+
									N' <th style="text-align:center"> Cargo</th>'+
									N' <th style="text-align:center"> Sueldo</th>'+
									N' <th style="text-align:center"> CCO</th>'+
									N' <th style="text-align:center"> Descripción CCO</th>'+
									N' <th style="text-align:center"> Región</th>'+
									N' <th style="text-align:center"> Discapacitado</th>'+
									N' <th style="text-align:center"> Genero</th>'+
									N' <th style="text-align:center"> Sectorial</th>'+
	 
									cast( (select 
												td = ISNULL(e.Codigo,'N/A'),'', 
												td = ISNULL(e.Trabajador,'N/A'),'',
												td = ISNULL(e.Nombre,'N/A'),'',
												td = ISNULL(e.Compania,'N/A'),'',
												td=  ISNULL(e.Compania_Desc,'N/A'),'',
												td = ISNULL(e.Anio,'N/A'),'',
												td = ISNULL(e.Mes,'N/A'),'',
												td=  ISNULL(e.HRS_TRAB_Semana,'N/A'),'',
												td=  ISNULL(e.Clase_Nomina, 'N/A'),'',
												td=  ISNULL(e.Desc_Clase_Nomina, 'N/A'),'',
												td=  ISNULL(e.Desc_Tipo_Contrato, 'N/A'),'',
												td=  CAST(e.Fecha_Antiguedad AS varchar),'',
												td=  CAST(e.Fecha_Ingreso AS varchar),'',
												td=  ISNULL(e.Cargo, 'N/A'),'',
												td=  CAST(e.Sueldo AS varchar),'',
												td=  ISNULL(e.CCO, 'N/A'),'',
												td=  ISNULL(e.Desc_CCO, 'N/A'),'',
												td=  ISNULL(e.Region, 'N/A'),'',
												td=  ISNULL(e.Discapacitado, 'N/A'),'',
												td=  ISNULL(e.Genero, 'N/A'),'',
												td=  ISNULL(e.Sectorial, 'N/A'),''
												FROM #TrabajadoresMes e
								 
									FOR XML PATH('tr'),TYPE
									) as varchar(max))+
										N' </table>'+
										N' <br>'+
										N' <br/></body>' 
									
				END

			

				 else 
				BEGIN
				select @html2=N'<body>'+
								N' <table class="box-table">' +
								N' <tr>'+
								N' <th style="text-align:center"> Notificación</th>'+N' </tr>'+N' <tr>'+
								N' <td >
								No se encontraron trabajadores sin registro de horas semanales en la base [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes].  </td>'+N' </tr>'+
						N'</table>'+
										N' </body>';
							
				END

				IF (@tiene3 <> 0)
				BEGIN
					select @html3= 	
	N'<body>'+
		N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+        
		N' <br/>'+
		N' <h4 style="font-family: Calibri;">Número de trabajadores mes por empresa</h4>'+
		N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">  
		Listado de cuantos trabajadores existen por cada Compañía de la base [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes] '+
		N' <br>'+
		N' <table class="table1" >'+ 
		N' <th style="font-weight: normal;   ">'+
		N' <table class="box-table" >' +
		N' <th style="text-align:center"> Compañía</th>'+
   
   
		cast( (select 
				td = ISNULL(d.Compania,'N/A') ,''
					FROM #NumTrabajadoresMes d
			order by d.Compania
		FOR XML PATH('tr'),TYPE
		) as varchar(max))+N'</table>'+

		N' </th>'+

		N' <th style="font-weight: normal;   ">'+
		N' <table class="box2" >' +
   
		N' <th style="text-align:center"> Descripción Compañía</th>'+
   
		cast( (select 
          
				td = ISNULL(d.Compania_Desc,'N/A'),''
					FROM #NumTrabajadoresMes d
			order by d.Compania
		FOR XML PATH('tr'),TYPE
		) as varchar(max))+N'</table>'+

		N' </th>'+
		N' <th style="font-weight: normal; border: none;">'+
		N' <table class="box" >' + 
		N' <tr>'+
		N' <th style="text-align:center"> Trabajadores</th>'+
		 cast( (select 
				   td = CAST(d.Trabajadores AS varchar),''
                
					FROM #NumTrabajadoresMes d
			order by d.Compania
		FOR XML PATH('tr'),TYPE) as varchar(max))+N'</table>'+
		N' </th>'+
		N'</table>'+

		N' </body>'  

				END

			
				IF (@tiene4 <> 0)
				BEGIN
				select @html4=
									N' <body>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
								
									N' <br/>'+
									N' <h4 style="font-family: Calibri;">Montos P&G</h4>'+
									N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> 
								
									Detalle de Montos P&G, número de trabajadores por companía y concepto de la agrupación CONCEPTOS KFC.'+
									N' <br>'+
									N' <table class="table1" >'+ 
									N' <th style="font-weight: normal;   ">'+
									N' <table class="box-table" >' +
									N' <tr>'+
									N' <th style="text-align:center"> Agrupación</th>'+
									N' <th style="text-align:center"> Compañía</th>'+
									N' <th style="text-align:center"> Concepto</th>'+
									N' <th style="text-align:center"> Mes</th>'+
								

									cast( (select 
												td = ISNULL(e.Agrupacion,'N/A'),'',
												td = ISNULL(e.Compania,'N/A'),'',
												td = CAST(e.Concepto AS varchar),'',
												td = CAST(e.Mes AS varchar),''
										
												FROM #MontosPG e
											ORDER BY e.Compania, e.Concepto, e.Mes
									FOR XML PATH('tr'),TYPE
									) as varchar(max))+
										N' </table>'+
										N' </th>'+
		N' <th style="font-weight: normal; ">'+
		N' <table class="box" >' + 
		N' <tr>'+
								
									N' <th style="text-align:center"> #Trabajadores</th>'+
									N' <th style="text-align:center"> Monto P&G </th>'+

									cast( (select 
										
												td = CAST(e.Num_Trabajadores AS varchar),'',
												td = CAST(e.Monto_PyG_Compania AS varchar),''
												FROM #MontosPG e
											ORDER BY e.Compania, e.Concepto, e.Mes
									FOR XML PATH('tr'),TYPE
									) as varchar(max))+
										N' </table>'+
										N' </th>'+
									
										N'</body>' 
				END

					if @html1 is not null or @html2 is not null or @html3 is not null or @html4 is not null
						declare @html varchar(max)= @htmlE + ' ' +@html1 + ' ' + @html2 + ' ' + @html3 + ' ' + @html4
						begin
								-- INSERT notificación consolidada
								INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
								VALUES ('A', 'Trabajadores', 'pa_TrabajadoresValidacion', @asunto, @html, @tiene4, @destinatarios);
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
								N' <h4 style="font-family: Calibri; text-align:center">Notificación de Información de Trabajadores</h4>'+ 
							
								N' <p style="border: 2px solid #d8d8d8; background: #white; font-weight:normal; padding: 100px; 
								border-left: solid rgb(0, 103, 198);  font-family: Calibri;">Fecha: '+CONVERT(VARCHAR, @fecha, 103)+' <br/>
								En el presente mes no se encontraron trabajadores con registros NULL en la base [Adam_Consolidados].[dbo].[TB_Trabajadores] ni 
								trabajadores sin registro de horas semanales en la base [Adam_Consolidados].[dbo].[TB_Trabajadores_Mes].</br>'+
								N' <br/></body>';

							if @html1 is not null 
							begin
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
							VALUES ('A', 'Trabajadores', 'pa_TrabajadoresValidacion', @asunto, @html1, @tiene4, @destinatarios);
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
END