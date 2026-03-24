
/*

=============================================
  
Author: Steven Quispe
Create date: 22/02/20224
Description: Alerta para notificar las novedades de cargas familiares que registren conyuge y tengan distinto estado civil a Casado o Union de hecho.

=============================================

*/

CREATE PROCEDURE [Avisos].[pa_cargasFamiliaresEstadoCivilConyugue]
AS 
BEGIN

/*	VARIABLES PARA ENVIO DE CORREO	*/
	DECLARE 
	@Dirigido		varchar(300),
	@asunto			varchar(300),
	@body			varchar(5000),
	@HTML			Nvarchar(MAX),
	@tab			char(1) = char(9),
	@error			varchar(10),
	@destinatarios	varchar(max),
	@fi date,	@ff date;

	-- Configuración parámetros del correo
	SELECT @destinatarios = valor, @asunto = descripcion 
	FROM Configuracion.parametros 
	WHERE parametro = 'Mail_CFCEDACOUH'

	/*		VARIABLES PARA CREACION EL CSV (ADJUNTO DEL CORREO)		*/
/*	DECLARE @consulta varchar(MAX), @archivo varchar(MAX) */

	/*		CREACION DE TABLAS TEMPORALES AUXILIARES				*/
	IF Object_id(N'tempdb..##tmp_Alerta_CargaFamiliarEstadoCivilMal', N'U') IS NOT NULL
		DROP TABLE ##tmp_Alerta_CargaFamiliarEstadoCivilMal

	CREATE TABLE ##tmp_Alerta_CargaFamiliarEstadoCivilMal
		(
			cedula				char(10),
			Nombre				varchar(150),
			id_TipoCarga		smallint,
			TipoCarga			varchar(50),
			id_estadoCivil		smallint,
			estadoCivil			varchar(50),
			cedula_carga		char(10),
			nombre_carga		varchar(150),
			apellido_carga		varchar(150),
			fecha_nacimiento	smalldatetime,
			fecha_matrimonio	smalldatetime,
			fecha_fallecimiento	smalldatetime,
			fecha_separacion	smalldatetime,
			id_genero			smallint,
			genero				varchar(50),
			posee_discapacidad	char(2),
			estado				smallint,
			estado_descripcion	varchar(50)		
		)

	/*		OBTENCION DE DATOS PARA LA ALERTA				*/
	INSERT INTO ##tmp_Alerta_CargaFamiliarEstadoCivilMal
		SELECT DISTINCT cf.cedula, v.Nombre,
	
		cf.id_TipoCarga,
		CASE WHEN cf.id_TipoCarga = 1 THEN 'HIJO / A' ELSE 'CONYUGE' END AS TipoCarga,
	
		cf.id_estadoCivil,
		CASE WHEN cf.id_estadoCivil = 1 THEN 'SOLTERO' WHEN cf.id_estadoCivil = 2 THEN 'CASADO'
		WHEN cf.id_estadoCivil = 3 THEN 'DIVORCIADO' WHEN cf.id_estadoCivil = 4 THEN 'VIUDO' 
		WHEN cf.id_estadoCivil = 5 THEN 'UNION DE HECHO' ELSE '' END AS estadoCivil, 

		--cf.id_tipoDocumento,
		cf.cedula_carga, cf.nombre AS nombre_carga, cf.apellido AS apellido_carga,
		--(@aux_Anio - YEAR(cf.fecha_nacimiento)) AS edad,
		CONVERT(DATE, cf.fecha_nacimiento) AS fecha_nacimiento,
		CONVERT(DATE, cf.fecha_matrimonio) AS fecha_matrimonio,
		CONVERT(DATE, cf.fecha_fallecimiento) AS fecha_fallecimiento,
		CONVERT(DATE, cf.fecha_separacion) AS fecha_separacion,
		cf.id_genero,
		CASE WHEN cf.id_genero = 1 THEN 'MASCULINO' WHEN cf.id_genero = 2 THEN 'FEMENINO' ELSE '' END AS genero,

		cf.posee_discapacidad,
		cf.estado,
		CASE WHEN cf.estado = 0 THEN 'Por Aprobar' WHEN cf.estado = 2 THEN 'Legalizado' 
		WHEN cf.estado = 4 THEN 'Creado' WHEN cf.estado = 5 THEN 'Inactivo' ELSE '' END AS estado_descripcion

	FROM [Cargas].[familiares_personas] AS cf
	INNER JOIN RRHH.vw_datosTrabajadores AS v ON cf.cedula = v.Trabajador AND v.Situacion = 'Activo'	
	WHERE cf.id_TipoCarga = 2 -- Carga familiar reportada como conyuge
	AND cf.id_estadoCivil NOT IN (5, 2) -- Estado civil de la carga diferente a Casado o Unión de hecho 
	AND estado != 5 -- Excluye los inactivos

	/*		ENVIO DE DATOS POR CORREO		*/
	-- Comprobación de datos
	IF ((SELECT COUNT(cedula) FROM ##tmp_Alerta_CargaFamiliarEstadoCivilMal) > 0)
			-- Si existen novedades:
		BEGIN TRY 
			SELECT @HTML = N'<style type="text/css">'
							+N' .box-table { font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } '
							+N' .box-table th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); '
							+N' border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } '
							+N' .box-table td { text-align: center; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } '
							+N' .box{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } '
							+N' .box th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); '
							+N' border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } '
							+N' .box td { text-align: right; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } '

							+N' .box2{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } '
							+N' .box2 th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); '
							+N' border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } '
							+N' .box2 td { text-align: left; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } '

							+N' .aviso{ font-family: Calibri; font-size: 10px;  border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } '
							+N' .aviso th { text-align: center; padding: 5px; height: 24px;  font-size: 13px; font-weight: normal; font-style: bold; background-color: rgb(0, 103, 198); '
							+N' border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } '
							+N' .aviso td { text-align: left; padding: 5px; height: 22px; font-size: 12px; border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } '

							+N'</style>'
							+N'<body><h3 style="font-family: "Cambria"; color:black; text-align:center">ALERTA CARGAS FAMILIARES</h3>'
							+N'<h4 style="font-family: "Tahoma"; color:black;">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<p style="font-family: "Tahoma"; color:black;">Se adjunta el reporte de novedades de cargas familiares que registren cónyuge y tengan distinto estado civil a Casado o Unión de hecho.</p>'
							--+N'<br/>'
							+N' </body>' 
/* '''''''' */
			/*SET @consulta =*/ +N'<body>'+
									N' <br>'+
									N' <table class="box-table" >' +
										N' <tr>'+
										N' <th style="text-align:center"> Cédula Colaborador</th>'+
										N' <th style="text-align:center"> Nombre Colaborador</th>'+
										N' <th style="text-align:center"> Tipo Carga</th>'+
										N' <th style="text-align:center"> Estado Civil Carga</th>'+
										N' <th style="text-align:center"> Cédula Carga</th>'+
										N' <th style="text-align:center"> Nombre Carga</th>'+
										N' <th style="text-align:center"> Apellido Carga</th>'+
										N' <th style="text-align:center"> Fecha Nacimiento Carga</th>'+
										N' <th style="text-align:center"> Fecha Matrimonio</th>'+
										N' <th style="text-align:center"> Fecha Separación</th>'+
										N' <th style="text-align:center"> Genero Carga</th>'+
										N' <th style="text-align:center"> Posee Discapacidad Carga</th>'+
										N' <th style="text-align:center"> Estado Descripcion</th>'+
										
								CAST( (SELECT 
											td = ISNULL(CONVERT(varchar(11), cedula), ''), '', 
											td = ISNULL(Nombre, ''), '',
											td = ISNULL(TipoCarga, ''), '', 
											td = ISNULL(estadoCivil, ''), '',  
											td = ISNULL(CONVERT(varchar(11), cedula_carga), ''), '', 
											td = ISNULL(nombre_carga, ''), '', 
											td = ISNULL(apellido_carga, ''), '',
											td = ISNULL(CONVERT(varchar(12), fecha_nacimiento, 103), ''), '',
											td = ISNULL(CONVERT(varchar(12), fecha_matrimonio, 103), ''), '',
											td = ISNULL(CONVERT(varchar(12), fecha_separacion, 103), ''), '', 
											td = ISNULL(genero, ''), '',  
											td = ISNULL(posee_discapacidad, ''), '', 
											td = ISNULL(estado_descripcion, ''), ''
										  FROM ##tmp_Alerta_CargaFamiliarEstadoCivilMal
										  ORDER BY Nombre
										  FOR XML PATH('tr'), TYPE
										  ) AS varchar(max))+
										  N'</table>'+
										  N'</br>'+
										  N'</body>'

/*			SET @archivo = N''+ convert(varchar(12),GETDATE(), 105) + ' - CargasFamiliaresEstadoCivilMal.csv'; */
						-- SET @archivo = N'CargasFamiliaresEstadoCivilMal.csv';

			/*		ENVIO DE CORREO			*/
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Cargas Familiares', 'pa_cargasFamiliaresEstadoCivilConyugue', @asunto, @HTML, @destinatarios, @fi, @ff);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina',
				@recipients= @destinatarios, 
			 	@subject = @asunto,
				@body = @HTML, 
				@body_format = 'HTML' ; 

		END TRY
		BEGIN CATCH
				INSERT INTO Logs.log_envio_correo(fecha, correo, correocc, html, modulo, referencia_02) VALUES (GETDATE(), 'pasante.nominadosec@kfc.com.ec' , NULL, @html, @asunto, 'Error al envíar correo')
		END CATCH
	ELSE
		-- Si no existen novedades:
		BEGIN 
						SELECT @HTML = N'<body><h3 style="font-family: "Tahoma"; color:black; text-align:center">ALERTA CARGAS FAMILIARES</h3>'
							+N'<h4 style="font-family: "Tahoma"; color:black;">Fecha: '+convert(varchar(12),GETDATE(), 103)+'</h4>'
							+N'<h5 style="font-family: "Tahoma"; color:black;">No existen novedades de cargas familiares que registren cónyuge y tengan estado civil distinto a Casado o Unión de hecho.</h5>'
							+N'<br/><br />'
							+N' </body>' 


			/*		ENVIO DE CORREO			*/
			-- INSERT notificación consolidada
			INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, periodoInicio, periodoFin)
			VALUES ('A', 'Cargas Familiares', 'pa_cargasFamiliaresEstadoCivilConyugue', @asunto, @HTML, @destinatarios, @fi, @ff);
			EXEC msdb.dbo.sp_send_dbmail 
				@profile_name='Informacion_Nomina',
				@recipients= @destinatarios, 		
			 	@subject = @asunto,
				@body = @HTML,
				@body_format = 'HTML' ;
		
		END

	/*		ELIMINACION  DE TABLAS TEMPORALES AUXILIARES				*/
	IF Object_id(N'tempdb..##tmp_Alerta_CargaFamiliarEstadoCivilMal', N'U') IS NOT NULL
		DROP TABLE ##tmp_Alerta_CargaFamiliarEstadoCivilMal
END