-- =============================================
-- Author:		Jimmy Cazaro
-- Create date: 08/02/2025
-- Description:	Pedido de Data de Nomina, personal actualizado en nomina
--				NA, Nomina Activo
-- =============================================
CREATE PROCEDURE [Avisos].[pa_PersonalActualizadoNA]
AS
BEGIN
	SET NOCOUNT ON;
		--DECLARE @fi date, @ff date

	IF OBJECT_ID(N'tempdb..#tmp_BDD_NA_PersonalActivo', N'U') IS NOT NULL 
		DROP TABLE #tmp_BDD_NA_PersonalActivo
	CREATE TABLE #tmp_BDD_NA_PersonalActivo 
	(
		[Codigo]				[varchar](30) NULL, 
		[Trabajador]			[varchar](10) NULL, 
		[Nombre]				[varchar](200) NULL, 
		[Cargo]					[varchar](100) NULL, 
		[Compania_Desc]			[varchar](150) NULL, 
		[Desc_Clase_Nomina]		[varchar](150) NULL, 
		[CCO]					[varchar](20) NULL,
		[Desc_CCO]				[varchar](200) NULL, 
		[Fecha_Ingreso]			[date] NULL, 
		[Jefe1]					[varchar](30) NULL,
		[Tipo]					[varchar](8) NULL,
		[CAR]					[varchar](60) NULL
	)

	INSERT #tmp_BDD_NA_PersonalActivo (Codigo, Trabajador, Nombre, Cargo, Compania_Desc, Desc_Clase_Nomina, CCO, Desc_CCO, Fecha_Ingreso, Jefe1, Tipo, CAR) 
	--*/
	SELECT v.Codigo, v.Trabajador, v.Nombre, v.Cargo, v.Compania_Desc, v.Desc_Clase_Nomina, v.CCO, v.Desc_CCO, v.Fecha_Ingreso, v.Jefe1, centro.tipo, LTRIM(RTRIM(v.CAR)) AS CAR
	FROM RRHH.vw_datosTrabajadores AS v
	INNER JOIN Catalogos.VW_CCO AS centro ON v.CCO = centro.cco
	WHERE v.Situacion = 'Activo';
	
	/*
	SELECT --pa.Codigo, 
	pa.Trabajador, 
	pa.Nombre, 
	pa.Cargo, 
	pa.Fecha_Ingreso, 
	pa.Compania_Desc AS Empresa, 
	pa.Desc_Clase_Nomina AS Cadena, 
	--pa.CCO, 
	pa.Desc_CCO AS CentroCosto, 
	--pa.Jefe1, 
	JefeUno = (SELECT Nombre FROM #tmp_BDD_NA_PersonalActivo WHERE Codigo = pa.Codigo)--, 
	--pa.Tipo, pa.CAR 
	FROM #tmp_BDD_NA_PersonalActivo AS pa
	WHERE pa.CAR = 'CAR ADMINISTRATIVO'
	ORDER BY pa.Trabajador
	*/

	IF (SELECT COUNT(1) FROM #tmp_BDD_NA_PersonalActivo) > 0
	BEGIN 
		DECLARE @HTML varchar(MAX), @destinatarios varchar(MAX),@asunto VARCHAR(75), @fecha varchar(25) = convert(varchar(25),DATEADD(DAY, -1, GETDATE()),103)
		SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_PerNomActAct'
		SELECT @HTML = N'<style type="text/css">
							#box-table
							{
								font-family: "Calibri";
								font-size: 10px;
								text-align: center;
								border-collapse: collapse;
								border-top: 7px solid #9baff1;
								border-bottom: 7px solid #9baff1;
							}
							#box-table th
							{
								font-size: 11px;
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
						  </style>'+	
							N'<H4><font color="SteelBlue">Información de Personal que se encuentra en Nómina ' + @fecha +
							' </H4>' +
							N'<table id="box-table" >' +
							N'<tr><font color="Green">
							<th>CÉDULA</th>
							<th>NOMBRE</th>
							<th>CARGO</th>
							<th>FECHA INGRESO</th>
							<th>EMPRESA</th>
							<th>CADENA</th>
							<th>CENTRO COSTO</th>
							<th>JEFE</th>
							</tr>' +
							CAST(
								(	SELECT --pa.Codigo, 
									td = pa.Trabajador,' ', 
									td = pa.Nombre,' ',  
									td = pa.Cargo,' ',  
									td = CONVERT(VARCHAR(12), pa.Fecha_Ingreso, 103),' ',  
									td = pa.Compania_Desc,' ', 
									td = pa.Desc_Clase_Nomina,' ',  
									--pa.CCO, 
									td = pa.Desc_CCO,' ',  
									--pa.Jefe1, 
									td = ISNULL((SELECT Nombre FROM #tmp_BDD_NA_PersonalActivo WHERE Codigo = pa.Jefe1), '')  
									--pa.Tipo, pa.CAR 
									FROM #tmp_BDD_NA_PersonalActivo AS pa
									WHERE pa.CAR = 'CAR ADMINISTRATIVO'
									ORDER BY pa.Compania_Desc, pa.Desc_Clase_Nomina, pa.Desc_CCO, pa.Nombre
									FOR XML PATH('tr'), TYPE) AS varchar(max)) +
							N'</table>' +
							N'<br/><br/>' +
							N'</body>' 

		SELECT @asunto = REPLACE(@asunto, '@fecha', @fecha)

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Trabajadores', 'pa_PersonalActualizadoNA', @asunto, @HTML, @destinatarios, @fi, @ff);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML	
	END

	IF OBJECT_ID(N'tempdb..#tmp_BDD_NA_PersonalActivo', N'U') IS NOT NULL 
		DROP TABLE #tmp_BDD_NA_PersonalActivo
	SET NOCOUNT OFF;
END

