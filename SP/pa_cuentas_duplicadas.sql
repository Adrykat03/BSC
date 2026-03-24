-- =============================================
-- Author:		<Pamela Pupiales>
-- Create date: <21/03/2023>
-- Description:	<Avisos de cuentas bancarias duplicadas>
-- =============================================
CREATE PROCEDURE [Avisos].[pa_cuentas_duplicadas]
AS
BEGIN

	DECLARE @fecha date = DATEADD(DAY, 0, CONVERT(date, GETDATE()))
	
	IF OBJECT_ID(N'tempdb..#EspecialC', N'U') IS NOT NULL
		DROP TABLE #EspecialC
	IF OBJECT_ID(N'tempdb..#VTrabajadores', N'U') IS NOT NULL
		DROP TABLE #VTrabajadores
	IF OBJECT_ID(N'tempdb..#CuentasT', N'U') IS NOT NULL
		DROP TABLE #CuentasT
	IF OBJECT_ID(N'tempdb..#ObservacionCuentas', N'U') IS NOT NULL
		DROP TABLE #ObservacionCuentas
	
	CREATE TABLE #EspecialC(
			ID int IDENTITY(1,1) PRIMARY KEY,
			Compania VARCHAR(50),
			Compania_Desc varchar(200),
			Nombre varchar(100),
			Trabajador VARCHAR(50),
			Cuenta VARCHAR(50),
			banco VARCHAR(60),
			formaDesc varchar(100),
			n INT
		)

		CREATE TABLE #ObservacionCuentas(
			ID int IDENTITY(1,1) PRIMARY KEY,
			Compania VARCHAR(50),
			Compania_Desc varchar(200),
			codigo varchar(100),
			Nombre varchar(100),
			cuenta varchar(40),
			banco VARCHAR(60),
			formaDesc varchar(100),
			Observaciones VARCHAR(100)
		)
		
		--Tabla Casos especiales #VTrabajadores, se filtra informacion de solo colaboradores activos
		select Codigo,Compania,Compania_Desc,Nombre,Trabajador,Cuenta,Banco,Forma_Pago,Forma_PagoDesc,Fecha_Ingreso, Situacion 
		INTO #VTrabajadores 
		FROM RRHH.vw_datosTrabajadores WHERE Situacion = 'Activo' 

		--Tabla Casos especiales #VTrabajadores, se filtra informacion de solo colaboradores activos
		SELECT ct.codigo,ct.Cuenta,ct.TipoCuentaID,ct.id_bancos,ct.FormaPagoID,ct.EsPrincipal 
		INTO #CuentasT FROM RRHH.Cuentas_Trab AS ct WITH (NOLOCK)
		WHERE ct.codigo IN (SELECT codigo FROM #VTrabajadores )

		--Tabla Casos especiales #EspecialC
		INSERT INTO #EspecialC(Compania,Compania_Desc,Nombre,Trabajador,Cuenta,banco,formaDesc,n)
			SELECT v.Compania,v.Compania_Desc,v.Nombre, v.Trabajador, v.Cuenta, v.Banco,v.Forma_PagoDesc, c.cantidad
			 FROM (
				SELECT DISTINCT c.id_bancos, c.TipoCuentaID, c.FormaPagoID, COUNT(c.Cuenta) AS cantidad, c.codigo, c.EsPrincipal
				FROM #CuentasT AS c 
				GROUP BY c.id_bancos, c.TipoCuentaID, c.FormaPagoID, c.codigo, c.EsPrincipal
				HAVING COUNT(c.Cuenta) > 1	
			) AS c INNER JOIN #VTrabajadores AS v ON c.codigo = v.codigo 

		--Tabla Casos especiales #ObservacionCuentas solo disponible en la vista no en otras tablas
		INSERT INTO #ObservacionCuentas(Compania,Compania_Desc,codigo,Nombre,cuenta,banco, formaDesc, Observaciones)
		SELECT DISTINCT v.Compania, v.Compania_Desc, v.codigo, v.Nombre, v.cuenta, v.banco, v.Forma_PagoDesc, '1' AS Observacion
		FROM #VTrabajadores AS v
		LEFT JOIN #CuentasT AS c ON v.codigo = c.codigo AND c.EsPrincipal = 1
		WHERE c.codigo IS NOT NULL AND LTRIM(RTRIM(v.cuenta)) <> LTRIM(RTRIM(c.cuenta))
		UNION
		SELECT v.Compania, v.Compania_Desc, v.codigo, v.Nombre, v.cuenta, v.banco, v.Forma_PagoDesc, '2' AS Observacion
		FROM #VTrabajadores AS v
		LEFT JOIN #CuentasT AS c ON v.codigo = c.codigo AND c.EsPrincipal = 1
		WHERE ISNULL(c.codigo, '') = '' AND ISNULL(v.cuenta, '') <> '' AND v.Forma_Pago <> 2 AND v.Forma_PagoDesc <> 'Cheque'
		ORDER BY Observacion, Compania, Nombre ASC

	DECLARE @tiene1 int = 0
	DECLARE @tiene2 int = 0
	declare @htmlE varchar(max)=''
	declare @html1 varchar(max)=''
	declare @html2 varchar(max)='',
	
		@asunto varchar (400),
		@saludos varchar(500)='',
		@destinatarios varchar(max) ; 
		SELECT @destinatarios= valor, @asunto=descripcion FROM Configuracion.parametros WHERE parametro = 'AL_DUPCTA'


	SELECT DISTINCT @tiene1 = COUNT(1) FROM #ObservacionCuentas
	SELECT DISTINCT @tiene2 = COUNT(1) FROM #EspecialC

	IF (@tiene1 <> 0 or @tiene2 <> 0)
	BEGIN
		select @htmlE=N' <style type="text/css">
										.box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; }
										.box-table th { padding: 6px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); border-right: 1px solid black; 
											border-left: 1px solid black; border-bottom: 1px solid black; color: white; }
										.box-table td { padding: 6px; height: 24px; font-size: 13px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } </style>'
		IF (@tiene1 <> 0)
			BEGIN
			select @html1=
								N' <body>'+
								N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
								N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> 
								Mediante el presente ponemos en su conocimiento, el día ' +CONVERT(VARCHAR, @fecha, 103)+ ',
								el listado de los casos en los cuales los colaboradores tienen anomalías de cuentas diferentes y cuentas no encontradas.'+
							
								N' <br/>'+
								N' <table class="box-table" >' +
								N' <th style="text-align:center; font-size: 14px;"> # Observación</th>'+
								N' <td style="text-align:left; font-size: 14px; background-color: rgb(0, 103, 198); color: white"> Explicación a detalle del campo Observación del Reporte 1</td>'+
								N' <tr>'+
								N' <th style="text-align:center"> 1</th>'+
								N' <td style="text-align:left"> RRHH.Cuentas_Trab tiene cuenta diferente que la vista RRHH.vw_datosTrabajadores</td>'+
								N' <tr>'+
								N' <th style="text-align:center"> 2</th>'+
								N' <td style="text-align:left"> RRHH.Cuentas_Trab no existe la cuenta en esa tabla, solo disponible en la vista RRHH.vw_datosTrabajadores</td>'+
								N' </table>'+
								N' <br>'+
								N' <h3 style="font-family: "Calibri";">Reporte 1. Casos de cuentas diferentes y cuentas no encontradas</h3>'+
								N' <br>'+
								N' <table class="box-table" >' +
								N' <tr>'+
								N' <th style="text-align:center"> ID</th>'+
								N' <th style="text-align:center"> Compañía</th>'+
								N' <th style="text-align:center"> Descripción Compañía</th>'+
								N' <th style="text-align:center"> Nombre</th>'+
								N' <th style="text-align:center"> Trabajador</th>'+
  								N' <th style="text-align:center"> Cuenta CCO</th>'+
								N' <th style="text-align:center"> Banco</th>'+
								N' <th style="text-align:center"> Forma de Pago</th>'+
								N' <th style="text-align:center"> Observación</th>'+
				
								cast( (select 
											td = ISNULL(e.ID,'N/A'),'',
											td = ISNULL(e.Compania,'N/A'),'',
											td=  ISNULL(e.Compania_Desc,'N/A'),'',
											td=  ISNULL(e.codigo, 'N/A'),'',
											td=  ISNULL(e.Nombre, 'N/A'),'',
											td=  ISNULL(e.cuenta, 'N/A'),'',
											td=  ISNULL(e.banco, 'N/A'),'',
											td=  ISNULL(e.formaDesc, 'N/A'),'',
											td=  ISNULL(e.Observaciones, 'N/A'),''
											FROM #ObservacionCuentas e
								  
								FOR XML PATH('tr'),TYPE
								) as varchar(max))+
									N' </table>'+
									N' <br>'+
									N' <br/></body>' 
			END
		IF (@tiene2 <> 0)
			BEGIN
				select @html2=
							N'<body>'+
								N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;">'+@saludos+'</p>'+
								N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; line-height: auto;"> Mediante el presente ponemos en su conocimiento, el día ' +CONVERT(VARCHAR, @fecha, 103)+ ',
								el listado de los casos en los cuales los colaboradores tienen duplicidad en las cuentas.'+
								N' <h3 style="font-family: "Calibri";">Reporte 2. Casos Especiales</h3>'+
								N' <br>'+
								N' <table class="box-table" >' +
								N' <tr>'+
								N' <th style="text-align:center"> ID</th>'+
								N' <th style="text-align:center"> Compañía</th>'+
								N' <th style="text-align:center"> Descripción Compañía</th>'+
								N' <th style="text-align:center"> Nombre</th>'+
								N' <th style="text-align:center"> Trabajador</th>'+
  								N' <th style="text-align:center"> Cuenta</th>'+
								N' <th style="text-align:center"> Banco</th>'+
								N' <th style="text-align:center"> Forma de Pago</th>'+
								N' <th style="text-align:center"> Cantidad</th>'+
						
								cast( (select 
											td = ISNULL(e.ID,'N/A'),'',
											td = ISNULL(e.Compania,'N/A'),'',
											td=  ISNULL(e.Compania_Desc,'N/A'),'',
											td=  ISNULL(e.Nombre, 'N/A'),'',
											td=  ISNULL(e.Trabajador, 'N/A'),'',
											td=  ISNULL(e.Cuenta, 'N/A'),'',
											td=  ISNULL(e.banco, 'N/A'),'',
											td=  ISNULL(e.formaDesc, 'N/A'),'',
											td=  ISNULL(CONVERT(varchar(50), e.n), 'N/A'),''
											FROM #EspecialC e
								  ORDER BY e.Compania ASC, e.Compania_Desc, e.banco, e.Nombre
							  
								FOR XML PATH('tr'),TYPE
								) as varchar(max))+
									N' </table>'+
									N' <br/></body>'  
			END	
				if @html1 is not null or @html2 is not null 
					declare @html varchar(max)=@htmlE + ' ' +@html1 + ' ' + @html2
					begin
							-- INSERT notificación consolidada
							INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
							VALUES ('A', 'Cuentas Bancarias', 'pa_cuentas_duplicadas', @asunto, @html, @tiene2, @destinatarios);
							exec msdb.dbo.Sp_send_dbmail
							@profile_name = 'Informacion_Nomina',  
							@Subject = @asunto,
							@recipients = @destinatarios,
							--@recipients = 'pasante.nominadosec@kfc.com.ec;',
							@body_format= 'html',
							@body = @html
					end
	END
	ELSE
	BEGIN

		select @html1=N'<body>'+
							N' <h2 style="font-family: "Calibri"; text-align:center">Notificación de Cuentas</h2>'+ 
							N' <br/>'+
							N' <p style="border: 2px solid #d8d8d8; background: #white; font-weight:normal; 
							padding: 100px; border-left: solid rgb(0, 103, 198);  font-family: "Calibri";">
							No se encontraron casos especiales en las cuentas el día hoy ' +CONVERT(VARCHAR, @fecha, 103)+ 
							'</h3></br>'+	
							N' <br/><br/><br/><br/>  </body>';

						if @html1 is not null
						begin
						-- INSERT notificación consolidada
						INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios)
						VALUES ('A', 'Cuentas Bancarias', 'pa_cuentas_duplicadas', @asunto, @html1, @tiene2, @destinatarios);
						exec msdb.dbo.Sp_send_dbmail
							@profile_name = 'Informacion_Nomina', 
							@Subject = @asunto,
							@recipients = @destinatarios,
							--@recipients = 'pasante.nominadosec@kfc.com.ec;',
							@body_format= 'html',
							@body = @html1
						end
	END
END