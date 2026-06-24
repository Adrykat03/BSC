

-- 1. El dia anterior a que se ejecutan las AP,  valide si alguna de las personas tienen 
-- fecha de prebaja y genere notificación inmediatamente después del correo “Información AP” ver imagen en anexo 6
--2. Enviar a  Paola, Sabri y Tatiana
 declare
 	@asunto varchar(250),
	@html varchar(6500),
	@saludos varchar(100),
	@correo varchar(1000),
	@correoCC varchar(1000),
	@p smallint = 0 ,
	@desc varchar(150),
	@x smallint=0,
	@fechaEfectiva date,
	@mes char(2),
	@anio char(4),
	@dia smallint =  datepart(day,getdate())
   
	  select @p = count(*) from rrhh.preBajas_PRT where situacion in (0,2,1)
	  and codigo in (select codigo from AP.AccionesPersonal AP where estado in (5,7) and AP.Fecha_creacion  between  DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH( getdate() ,0))
	  and Fecha_Baja between DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and EOMONTH( getdate() ,0)
	       
	  select @correo = valor from Configuracion.parametros where parametro = 'MailAvisoAPBaja'
	   if  @dia in (28,29,30,31 )
	   begin
	     select @fechaEfectiva = AP.fecha_efectiva from AP.AccionesPersonal AP
	     where estado in (5,7) 
	     and AP.Fecha_creacion  
	     between  DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH(Getdate() ,0) 
	  
	   end
	   else if @dia in (1,2,3 )
	   begin

	      select @fechaEfectiva = AP.fecha_efectiva from AP.AccionesPersonal AP
	      where estado in (5,7) 
	      and AP.Fecha_efectiva  
	      between  DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH(Getdate() ,0) 
	  
	   end
	 
	  set @mes = convert(varchar(2), DATEPART(MONTH,@fechaEfectiva))
	  set @anio= convert(varchar(4), DATEPART(YEAR,@fechaEfectiva))
	  
	 if (@p= 0 and @dia in (28,29,30,31 ))
	 Begin
	    set @html = 	N'<p>Estimados<br/><strong>AREA DE NOMINA</strong> </p> <p>Ponemos en su conocimiento que no tenemos bajas en el proceso de AP con fecha efectiva en el <strong> Mes:'+@mes+' y Año:'+@anio+' </strong>.</p>' 
	    set @html = @html + 	N' <br/> <p>Este es un mensaje automático, por favor no conteste este correo.</p>' 
	   
	   exec msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',  
		@Subject = 'No hay personas de Pre-Baja con AP',
		@recipients = @correo,
		@body_format= 'html',
		@body = @html  ,  
		@copy_recipients ='sabrina.chinchin@kfc.com.ec;dennis.suarez@gmail.com' 
	 end
	 else  if (@p= 0 and @dia in (1,2,3 ))
	 Begin
	   set @html = 	N'<p>Estimados<br/><strong>AREA DE NOMINA</strong> </p>   <p>Ponemos en su conocimiento que se ha corrido el proceso de AP con fecha efectiva en el <strong> Mes:'+@mes+' y Año:'+@anio+'</strong>  y NO existen colaboradores con fecha de pre-baja en el sistema.</p>' 
	   set @html = @html + 	N' <br/> <p>Este es un mensaje automático, por favor no conteste este correo.</p>' 
	   
	   exec msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',  
		@Subject = 'No hay personas de Pre-Baja con AP',
		@recipients = @correo,
		@body_format= 'html',
		@body = @html  ,  
		@copy_recipients ='sabrina.chinchin@kfc.com.ec;dennis.suarez@gmail.com' 
	 end
	 Else  
	 begin

	   if @dia =1
	  begin
	  set @x = 2
	    set @desc = 'PREBAJA DEL DIA DEL PROCESO DE AP'
	  end 
	  Else if @dia =3
	  begin
	  set @x = 2
	    set @desc = 'PREBAJA DOS DIAS DESPUES DEL PROCESO DE AP'
	  end
	  else if @dia in (28,29,30,31)
	  begin
	    set @desc = 'PREBAJA ULTIMOS DIAS DEL MES DEL PROCESO DE AP'
		set @x = 1
	  end
       
	   if  @x =1
	   Begin
	    select @html= '<!DOCTYPE html>
			<html lang="es">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Correo HTML</title>
				<style>
					table {
						width: 100%;
						border-collapse: collapse;
					}
					th, td {
						border: 1px solid #ddd;
						padding: 10px;
						text-align: left;
					}
					th {
						background-color: #000;
						color: #fff;
						text-align: center;
					}
					td {
						background-color: #f9f9f9;
					}
				</style>
			</head>
			<body>'+
		N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4>'+@desc+'</h4> </p> '+
		 
		N' <p>Estimados<br />AREA DE NOMINA<br /><br />Ponemos en su conocimiento que los colaboradores detallados tienen generada una Acci&oacute;n de Personal efectiva en <strong> Mes:'+@mes+' y Año:'+@anio+'</strong>, sin embargo, registran fecha de pre-baja en el sistema, por lo tanto, validar para suspender o rechazar la acci&oacute;n de personal antes
           de su ejecuci&oacute;n el d&iacute;a de ma&ntilde;ana.<br /> '+
		N'<table id="box-table" >' +
		N' <tr align="left">'+   
		N' <th align="center"> CADENA</th>'+
		N' <th align="left"> CEDULA</th>'+
		N' <th align="left"> NOMBRE</th>'+ 
		N' <th align="left"> AP</th>'+ 
		N' <th align="left"> FECHA PRE-BAJA</th>'+ 
	  cast(  (	SELECT  
	   td =T.Desc_Clase_Nomina, '', 
	   td = T.Trabajador, '',
	   td = t.Nombre, '' ,
	   td = (select top 1 id_accionesP from AP.AccionesPersonal A where A.Codigo = B.Codigo and  estado in (5,7) ), '' ,
	   td =  convert(varchar(10),B.Fecha_Baja,121) ,''
	   from  rrhh.preBajas_PRT B inner join RRHH.vw_datosTrabajadores T on B.Codigo = T.Codigo
	    where B.situacion in (0,1,2) 
		and B.Codigo in (select codigo from AP.AccionesPersonal AP where AP.estado in (5,7) and  AP.codigo = B.Codigo
	    and  AP.Fecha_creacion  between  DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH( getdate() ,0))
	    and  B.Fecha_Baja between  DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH( getdate() ,0)
	   ORDER BY  B.Trabajador
	   FOR XML PATH('tr'), TYPE 
		) AS varchar(max)) +
		N'</table>' +
		N' <br/> <br />Este es un mensaje autom&aacute;tico, por favor no conteste este correo.</p></body> </html>' 
	 
		  
		exec msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',  
		@Subject = @desc,
		@recipients = @correo,
		@body_format= 'html',
		@body = @html  ,  
		@copy_recipients ='sabrina.chinchin@kfc.com.ec;dennis.suarez@gmail.com' 

	   end
	   else if  @x in (3,2)
	   Begin

	     select @html= '<!DOCTYPE html>
			<html lang="es">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1.0">
				<title>Correo HTML</title>
				<style>
					table {
						width: 100%;
						border-collapse: collapse;
					}
					th, td {
						border: 1px solid #ddd;
						padding: 10px;
						text-align: left;
					}
					th {
						background-color: #000;
						color: #fff;
						text-align: center;
					}
					td {
						background-color: #f9f9f9;
					}
				</style>
			</head>
			<body>'+
		N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4>'+@desc+'</h4> </p> '+ 
		N'  <p>Estimados<br />AREA DE NOMINA<br /><br />Ponemos en su conocimiento que los colaboradores detallados tienen generada una Acci&oacute;n de Personal efectiva en <strong> Mes:'+@mes+' y Año:'+@anio+'</strong>, sin embargo, registran fecha de pre-baja en el sistema. <br /> '+
		N'<table id="box-table" >' +
		N' <tr align="left">'+   
		N' <th align="center"> CADENA</th>'+
		N' <th align="left"> CEDULA</th>'+
		N' <th align="left"> NOMBRE</th>'+ 
		N' <th align="left"> AP</th>'+ 
		N' <th align="left"> FECHA PRE-BAJA</th>'+ 
	  cast(  (	SELECT  
	   td =T.Desc_Clase_Nomina, '', 
	   td = T.Trabajador, '',
	   td = t.Nombre, '' ,
	   td = (select top 1 id_accionesP from AP.AccionesPersonal A where A.Codigo = B.Codigo and  estado= 5 ), '' ,
	   td =  convert(varchar(10),B.Fecha_Baja,121) ,''
	   from  rrhh.preBajas_PRT B inner join RRHH.vw_datosTrabajadores T on B.Codigo = T.Codigo
	    where B.situacion in (0,1,2) 
		and B.Codigo in (select codigo from AP.AccionesPersonal AP where AP.estado  in (7,5) and  AP.codigo = B.Codigo
	    and  AP.Fecha_creacion  between   DATEADD(mm,-1,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH( getdate() ,-1))
	    and  B.Fecha_Baja between  DATEADD(mm,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)) and  EOMONTH( getdate() ,0)
	   ORDER BY  B.Trabajador
	   FOR XML PATH('tr'), TYPE 
		) AS varchar(max)) +
		N'</table>' +
		N' <br/> <br />Este es un mensaje autom&aacute;tico, por favor no conteste este correo.</p></body> </html>' 
	 
		exec msdb.dbo.Sp_send_dbmail
		@profile_name = 'Informacion_Nomina',  
		@Subject = @desc,
		@recipients = @correo,
		@body_format= 'html',
		@body = @html  ,  
		@copy_recipients ='sabrina.chinchin@kfc.com.ec;dennis.suarez@gmail.com' 
	   end
	   
	 end

