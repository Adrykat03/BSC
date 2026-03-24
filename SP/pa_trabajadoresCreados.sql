-- =============================================
-- Author:		Mateo Alvear
-- Create date: 17/11/2022
-- Description:	Se envía un correo notificando los trabajadores
--				que se crearon en PRT el día anterior
-- =============================================
CREATE PROCEDURE [Avisos].[pa_trabajadoresCreados]
AS
BEGIN
	SET NOCOUNT ON;
		DECLARE @fi date, @ff date

	IF OBJECT_ID(N'tempdb..#tmp_errores', N'U') IS NOT NULL
			DROP TABLE #tmp_errores

	SELECT * INTO #tmp_errores FROM RRHH.Personas WHERE fecha_creacion >= DATEADD(DAY, -1, GETDATE())

	IF (SELECT COUNT(1) FROM #tmp_errores) > 0
	BEGIN 
		DECLARE @HTML varchar(MAX), @destinatarios varchar(MAX),@asunto VARCHAR(75), @fecha varchar(25) = convert(varchar(25),DATEADD(DAY, -1, GETDATE()),103)
		SELECT @destinatarios = valor, @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_Trab_Creado'
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
							N'<H4><font color="SteelBlue">Trabajadores que fueron ingresados en el sistema Payroll ' + @fecha +
							' (fecha en la que se crean los trabajadores en el sistema)</H4>' +
							N'<table id="box-table" >' +
							N'<tr><font color="Green">
							<th>CÉDULA</th>
							<th>NOMBRE</th>
							<th>CCO</th>
							<th>DESC CCO</th>
							<th>CONTRATO</th>
							<th>FECHA INGRESO</th>
							</tr>' +
							CAST(
								(SELECT
										td = a.cedula_dni,'', 
										td = dt.Nombre,'',
										td = dt.cco,'', 
										td = dt.Desc_CCO,'',
										td = dt.Desc_Tipo_Contrato,'',
										td = CONVERT(VARCHAR(12),dt.Fecha_Ingreso, 103)
									FROM #tmp_errores a 
									INNER JOIN RRHH.vw_datosTrabajadores dt ON dt.Trabajador = a.cedula_dni
									and dt.situacion = 'Activo'
									ORDER BY dt.desc_cco, dt.Nombre
									FOR XML PATH('tr'), TYPE) AS varchar(max)) +
							N'</table>' +
							N'<br/><br/>' +
							N'</body>' 

		SELECT @asunto = REPLACE(@asunto, '@fecha', @fecha)

		-- INSERT notificación consolidada
		INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
		VALUES ('A', 'Trabajadores', 'pa_trabajadoresCreados', @asunto, @HTML, @destinatarios, @fi, @ff);
		EXEC msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',
		@Subject = @asunto,
		@recipients = @destinatarios,
		@body_format= 'html',
		@body = @HTML	
	END
END
