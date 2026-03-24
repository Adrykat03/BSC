
-- ======================================================
-- Create:		Andrés Gómez							
-- Create date:	16-06-2022								
-- Description: Se envía un correo con la información
--				del cco que creo mal la jornada			
-- ======================================================
-- ======================================================
-- Edit:		Andrés Gómez
-- Edit date:	05-07-2022
-- Description: Se añade el trabajador y se imprimen 
--				solo los horarios que se estan usando 
--				actualmente y son erróneos
-- ======================================================
CREATE   PROCEDURE [Avisos].[pa_JornadaMalCreada]

AS
declare
@fi DATE = GETDATE(), 
@ff DATE = GETDATE(),
@fecha_ini DATE,
@fecha_fin DATE = GETDATE(),
@Dirigido varchar(300),
@asunto varchar(300),
@HTML varchar(MAX),
@body varchar(MAX),
@CONT INT = 0
BEGIN 
		SET LANGUAGE 'Spanish';
		SET DATEFORMAT ymd;
		DECLARE @Aux_fecha_hora DATETIME = GETDATE();

			SELECT @Dirigido = valor FROM Configuracion.parametros WHERE parametro = 'AL_Jornadas';
			SELECT @asunto = descripcion FROM Configuracion.parametros WHERE parametro = 'AL_Jornadas';

				-- Tabla temporal para las fechas del corte de nómina--

					DECLARE @tabla_fechas_corte AS TABLE(fecha_ini DATE, fecha_fin DATE)
						INSERT INTO @tabla_fechas_corte(fecha_ini, fecha_fin)
						select FechaInicioNomina, GETDATE() from  [Utilidades].[fn_fechasperiodonomina](GETDATE())
						select @fecha_ini = fecha_ini, @fecha_fin = GETDATE() from @tabla_fechas_corte

					-- Fin de la tabla temporal de las fechas del corte de nómina--  
/*
IF OBJECT_ID(N'tempdb..#tmp_jornada_erronea',N'U') is not null
	drop table #tmp_jornada_erronea

			SELECT  distinct jd.cco, A.descripcion, jd.id_jornada_definicion, SUBSTRING(jd.descripcion, 12, 30) AS jornada,
			 CASE 
				WHEN (CONVERT(TIME, jd.horadesde) <= CONVERT(TIME, jd.horahasta)) THEN
				   
					convert (varchar,(convert (int, DATEDIFF(MINUTE,CONVERT(DATETIME, CONVERT(VARCHAR(10), @fi, 121) + ' ' + jd.horadesde),CONVERT(DATETIME, CONVERT(VARCHAR(10), @ff, 121) + ' ' + jd.horahasta)) - 
					DATEdiff(MINUTE,convert(time ,replace(jd.horadesdedescanso,'0000','00:00')) , convert(time ,  replace(jd.horadeshadescanso,'0000','00:00'))))/60)) + ':' 
					+ case 
					when 
					len(convert(varchar,convert ( int ,datediff (MINUTE,CONVERT(DATETIME, CONVERT(VARCHAR(10), @fi, 121) + ' '+ jd.horadesde), CONVERT(DATETIME, CONVERT(VARCHAR(10),@ff, 121)+ ' ' + jd.horahasta)) -
					(DATEdiff(MINUTE,convert(time ,replace(horadesdedescanso,'0000','00:00')) , convert(time ,  replace(jd.horadeshadescanso ,'0000','00:00'))))) - (convert ( int ,datediff (MINUTE, horadesde,horahasta)-(DATEdiff(MINUTE,convert(time ,replace(horadesdedescanso,'0000','00:00')) , convert(time ,  replace(horadeshadescanso,'0000','00:00')))))/60)*60))=1 
					then '0' else '' end + 
					convert(varchar,convert ( int ,datediff (MINUTE, horadesde,horahasta)-(DATEdiff(MINUTE,convert(time ,replace(horadesdedescanso,'0000','00:00')) , convert(time ,  replace(horadeshadescanso,'0000','00:00'))))) - 
					convert(varchar ,(convert ( int ,datediff (MINUTE, CONVERT(DATETIME, CONVERT(VARCHAR(10), @fi, 121) + ' ' + jd.horadesde),CONVERT (DATETIME, CONVERT(VARCHAR(10), @ff, 121)+ ' ' + jd.horahasta))-
					DATEdiff(MINUTE,convert(time ,replace(jd.horadesdedescanso,'0000','00:00')) , convert(time ,  replace(jd.horadeshadescanso,'0000','00:00')))))/60)*60)
			ELSE 
					convert (varchar, (convert(int, DATEDIFF(MINUTE,CONVERT(DATETIME, CONVERT(VARCHAR(10), @fi, 121) + ' ' + jd.horadesde),CONVERT(DATETIME, CONVERT(VARCHAR(10), DATEADD(day, 1, @ff), 121) + ' ' + jd.horahasta))-
					DATEdiff(MINUTE,convert(time ,replace(jd.horadesdedescanso,'0000','00:00')) , convert(time ,  replace(jd.horadeshadescanso,'0000','00:00'))))/60)) + ':' 
					+ 
					convert(varchar,convert ( int ,datediff (MINUTE, jd.horahasta,jd.horadesde)-(DATEdiff(MINUTE,convert(time ,replace(horadeshadescanso,'0000','00:00')) , convert(time ,  replace(horadesdedescanso,'0000','00:00'))))) - 
					(convert ( int ,datediff (MINUTE, horahasta,horadesde)-(DATEdiff(MINUTE,convert(time ,replace(horadeshadescanso,'0000','00:00')) , 
					convert(time ,  replace(horadesdedescanso,'0000','00:00')))))/60)*60)
			END AS 'HORAS TRABAJADAS',
				jd.id_tipoJornada, tj.descripcion AS DescripcionTipoJornadas,
				[Asistencia].[fn_validarJornadasDefn](jd.horadesde,jd.horahasta,jd.horadesdedescanso, jd.horadeshadescanso, jd.id_tipoJornada, td.minutos) as validarMensaje
				into #tmp_jornada_erronea
		FROM Asistencia.jornadas_definicion jd 
			INNER JOIN Asistencia.tiempos_Descanso td ON jd.id_descanso = td.id_descanso 
			INNER JOIN Asistencia.tipos_jornadas tj ON jd.id_tipoJornada = tj.id_tipoJornada
			INNER JOIN Catalogos.VW_CCO A ON A.cco = jd.cco
				and JD.cco<>'0'
				and [Asistencia].[fn_validarJornadasDefn](jd.horadesde,jd.horahasta,jd.horadesdedescanso, jd.horadeshadescanso, jd.id_tipoJornada, td.minutos) <> 'OK'


				DECLARE @Jorn_error_usadas AS TABLE(cco varchar(10), descripcion VARCHAR(500), cedula varchar(20), nombre VARCHAR(100), fecha date, semana VARCHAR(5), jornada VARCHAR(100), desc_jornada VARCHAR(100), horas_trab VARCHAR(10), mensaje VARCHAR(100))
				INSERT INTO @Jorn_error_usadas (cco, descripcion, cedula, nombre, fecha, semana, jornada, desc_jornada, horas_trab, mensaje)
					select 
						v.cco, v.descripcion
						, w.Trabajador, w.Nombre
						, h.fecha as fecha, h.semana
						, t.jornada, t.DescripcionTipoJornadas, t.[HORAS TRABAJADAS],t.validarMensaje
					from Asistencia.rel_trab_horarios as h
						INNER JOIN Catalogos.VW_CCO AS v ON h.cco = v.cco
						INNER JOIN RRHH.vw_datosTrabajadores AS w ON h.codigo = w.Codigo
						INNER JOIN #tmp_jornada_erronea AS t ON h.cco = t.cco AND h.id_jornada_definicion = t.id_jornada_definicion
					where h.fecha BETWEEN @fecha_ini and @fecha_fin
					ORDER BY v.descripcion, h.fecha
*/

			DECLARE @Jorn_error_usadas AS TABLE(
				id_jornada_definicion		bigint,
				Cadena						varchar(250),
				Nombre_cco					varchar(200),
				cco							varchar(10),
				Jornada						varchar(35),
				DescripcionTiempoDescanso	varchar(80),
				--minutos						int,
				--DescripcionTipoJornadas		varchar(80),
				validarMensaje				varchar(200)
			)
			

			--IF OBJECT_ID(N'tempdb..#tmp_JornadaValida', N'U') IS NOT NULL 
			--	DROP TABLE #tmp_JornadaValida

			; WITH CTE_Jornadas (id_jornada_definicion, descripcion, id_tipoJornada, horahasta, cco, horadesde, id_descanso, horadesdedescanso, horadesdehadescanso, idintegracion
				, intdescripcion, estatus, lastUpdate, lastUser, DescripcionTiempoDescanso, minutos, DescripcionTipoJornadas, CantHorasTipoJornada, TieneDescanso, Cantidad
				, Cantidad2, validarMensaje, valida)
			AS
			(
				SELECT jd.id_jornada_definicion, jd.descripcion, jd.id_tipoJornada, jd.horahasta, jd.cco, 
				jd.horadesde, jd.id_descanso, jd.horadesdedescanso, jd.horadeshadescanso, 
				jd.idintengracion, jd.intdescripcion, jd.estatus, jd.lastUpdate, jd.lastUser, 
				td.descripcion AS DescripcionTiempoDescanso, td.minutos, tj.descripcion AS DescripcionTipoJornadas, isnull((select count(codigo) from Asistencia.rel_trab_horarios HH where HH.id_jornada_definicion = jd.id_jornada_definicion ),0) CantHorasTipoJornada, 
				tj.descanso TieneDescanso,	isnull((select count(codigo) from Asistencia.rel_trab_horarios HH where HH.id_jornada_definicion = jd.id_jornada_definicion ),0) as Cantidad, [Asistencia].[fn_cantRelJoradasRoles]( jd.cco ,jd.id_jornada_definicion) as Cantidad2,
				[Asistencia].[fn_validarJornadasDefn](jd.horadesde,jd.horahasta,jd.horadesdedescanso, jd.horadeshadescanso,  jd.id_tipoJornada,  td.minutos) as validarMensaje,
				case when [Asistencia].[fn_validarJornadasDefn](jd.horadesde,jd.horahasta,jd.horadesdedescanso, jd.horadeshadescanso,  jd.id_tipoJornada,  td.minutos) <> 'OK' then 'MAL' else 'CORRECTO' end  as valida
				FROM Asistencia.jornadas_definicion jd INNER JOIN
				Asistencia.tiempos_Descanso td ON jd.id_descanso = td.id_descanso INNER JOIN
				Asistencia.tipos_jornadas tj ON jd.id_tipoJornada = tj.id_tipoJornada
				and cco<>'0' and jd.estatus =1
				and jd.referencia_03 = 0
			)

			INSERT INTO @Jorn_error_usadas (id_jornada_definicion, Cadena, Nombre_cco, cco, Jornada
				, DescripcionTiempoDescanso
				--, minutos, DescripcionTipoJornadas
				, validarMensaje )

			SELECT c.id_jornada_definicion
			, v.Cadena
			, v.descripcion AS Nombre_cco
			, c.cco
			--, SUBSTRING(c.descripcion, 1, 10) AS Jornada
			----, c.descripcion
			, SUBSTRING(c.descripcion, 12, LEN(c.descripcion) - 10) AS Jornada
			--, c.DescripcionTiempoDescanso
			--, c.minutos
			--, c.DescripcionTipoJornadas
		----INTO #tmp_JornadaValida
			, c.DescripcionTiempoDescanso
			--, c.minutos
			--, c.DescripcionTipoJornadas
			, c.validarMensaje
			FROM CTE_Jornadas AS c
			INNER JOIN Catalogos.vw_cco AS v ON c.cco = v.cco
			WHERE c.valida = 'MAL'
			--ORDER BY 2, 4
			;

	--SELECT * FROM #tmp_JornadaValida ORDER BY 2, 3, 4;
				

SELECT @CONT = COUNT(1) FROM @Jorn_error_usadas

	IF @CONT > 0
		BEGIN
			select @HTML = N'<style type="text/css">
						#box-table
						{
						font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
						font-size: 9px;
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
						padding: 3px;
						border-right: 1px solid #aabcfe;
						border-left: 1px solid #aabcfe;
						border-bottom: 1px solid #aabcfe;
						color: #669;
						}
						tr:nth-child(odd)	{ background-color:#eee; }
						tr:nth-child(even)	{ background-color:#fff; }	
						</style>'+	
						N'<H3><font color="SteelBlue">ERRORES EN LA JORNADA</H3>' +
						N'<H3><font color="SteelBlue">Fecha: '+convert(varchar(12),GETDATE(),103)+'</H3>'+
						--N'<H3><font color="SteelBlue">Se ha generado un error en las jornadas con los siguientes trabajadores y centros de costo </H3>'+
						N'<H3><font color="SteelBlue">Error en las siguientes jornadas </H3>'+
						N'<table id="box-table" >' +
						N'<tr><font color="Green">
						<!--
						<th>CCO</th>
						<th>CCO DESCRIPCION</th>
						<th>CEDULA</th>
						<th>NOMBRE</th>
						<th>FECHA</th>
						<th>SEMANA</th>
						<th>JORNADA</th>
						<th>DESC_JORNADA</th>
						<th>HORAS_TRABAJADAS</th>
						<th>MENSAJE</th>
						-->

						<th>ID JORNADA DEFINICION</th>
						<th>CADENA</th>
						<th>LOCAL</th>
						<th>CCO</th>
						<th>JORNADA</th>
						<th>TIEMPO DESCANSO</th>
						<th>MENSAJE</th>

						</tr>' +
							CAST(( SELECT
									/*
									td =  cco, '', 
									td = descripcion, '', 
									td = cedula, '',
									td = nombre, '',
									td = fecha, '', 
									td = semana, '', 
									td = jornada, '',
									td = desc_jornada, '',
									td = horas_trab, '',
									td = mensaje, ''
									*/
--id_jornada_definicion, Cadena, Nombre_cco, cco, Jornada
									td =  id_jornada_definicion, '', 
									td = Cadena, '', 
									td = Nombre_cco, '',
									td = cco, '',
									td = Jornada, '',
									td = DescripcionTiempoDescanso, '',
									td = validarMensaje, ''
									FROM @Jorn_error_usadas
									ORDER BY 2, 3, 4
											  FOR XML PATH('tr'), TYPE 
									) AS varchar(max)) +
						N'</table>' +
						N'<br/><br />'+
						N' </body>'  
		

												-- INSERT notificación consolidada
												INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
												VALUES ('A', 'Horarios', 'pa_JornadaMalCreada', @asunto, @HTML, @CONT, @Dirigido, @fecha_ini, @fecha_fin);
												EXEC msdb.dbo.Sp_send_dbmail
												@profile_name = 'Informacion_Nomina',
												@Subject = @asunto,
												@recipients = @Dirigido,
												 @body_format= 'html',
												@body = @HTML; 
		END

		ELSE IF @CONT = 0
		BEGIN 
		select @body = referencia_06  FROM Configuracion.parametros WHERE parametro = 'AL_Jornadas';
		SELECT @body = REPLACE (@body, '@fecha_hora', CONVERT(varchar, @Aux_fecha_hora,9) ) 

										-- INSERT notificación consolidada
										INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, periodoInicio, periodoFin)
										VALUES ('A', 'Horarios', 'pa_JornadaMalCreada', @asunto, @body, @CONT, @Dirigido, @fecha_ini, @fecha_fin);
										EXEC msdb.dbo.Sp_send_dbmail
										@profile_name = 'Informacion_Nomina',
										@Subject = @asunto,
										@recipients = @Dirigido,
										 @body_format= 'html',
										@body = @body; 
		END
	
			--IF OBJECT_ID(N'tempdb..#tmp_jornada_erronea',N'U') is not null
			--	drop table #tmp_jornada_erronea


	END
