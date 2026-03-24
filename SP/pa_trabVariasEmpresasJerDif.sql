
CREATE procedure [Avisos].[pa_trabVariasEmpresasJerDif]
AS
declare 
@tableHTML2 varchar(8000),
@tableHTML varchar(8000),
@tableHTML4 varchar(8000),
@tableHTML3 varchar(8000),
@tableHTML5 varchar(8000),
@nombre varchar(100),
@query1 varchar(6000),
@cuerpo NVARCHAR(MAX),
@Dirigido varchar(300),
@copia varchar(100),
@w int=0,
@i int=0 
BEGIN

 declare @tablaCuerpo as table (cuerpo text)
    
   select @copia  = valor from Configuracion.parametros
     where parametro = 'Avisos_TMEMJC'

     select @Dirigido  = valor from Configuracion.parametros
     where parametro = 'Avisos_TMEMJ'
	  

   set @nombre = 'Analista de Nómina'

 select @w = 0
    set @tableHTML5 = ''

	 declare @tablaTrab1 as table(trabajador char(10), d int)

	  insert into @tablaTrab1
	  select trabajador, count(distinct Jefe2  ) from  rrhh.vw_datosTrabajadores
	  where trabajador in ( select trabajador from adam.dbo.VW_TrabActivosmasUnaEmpresa) and Situacion = 'Activo'
	  group by  Trabajador
	  having count(distinct Jefe2 )>1


	  declare @tabla6 as table (compania char(4), trabajador char(10), nombre varchar(200), jefe2 varchar(80), jefe2Ant varchar(80))

	  insert into @tabla6
	  select  distinct '',  trabajador, nombre, Jefe2 ,''
	  from  rrhh.vw_datosTrabajadores
	  where trabajador in ( select trabajador from @tablaTrab1)
	  and Situacion = 'Activo'
	  
      select @w = count(*)  from @tabla6
 
	 
	 
	 if @w >0
	 begin
	   select @tableHTML5=' '+
		 N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de trabajadores en varias empresas con jefe 2 diferente </h4> </p> '+
         N' <hr/>'+
		 N'<table id="box-table" >' +
		 N' <tr align="left">'+    
		 N' <th align="left"> Trabajador </th>'+
		 N' <th align="left"> Nombre </th>'+
		 N' <th align="left"> Jefe 2 </th>'+  
		  N' <th align="left"> Nombre Jefe 2 </th>'+  
      cast( (select   distinct 
			td= trabajador,'',
			td= nombre,'',
			td= jefe2,'' ,
			 td = (Select top 1 nombre from RRHH.vw_datosTrabajadores W where W.codigo = T.jefe2),''
      from @tabla6 T 
      where jefe2Ant<> jefe2
    FOR XML PATH('tr'),TYPE ) as varchar(max))+
		N'</table>'+ 
		N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de trabajadores en varias empresas con jefe 2 diferente es de : ' + convert(varchar(5),@w) +'  </p>'  
		 
	 end
	 else
	 begin
	  select @tableHTML5=' '+
	   N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de trabajadores en varias empresas con jefe 2 diferente  </h4> </p> '+
       N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen trabajadores en varias empresas con jefe 2 diferente  </p>'+
	   N' <hr/>'  
	  
	 end

	  
   select @cuerpo ='<head> <title> </title>'+
	N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> '+
	N' </head>'+
    N' <body>'+'<br />'+  
	N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> '+
	N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,'+ @nombre+'</p>'+
     N' <hr/>' +isnull(@tableHTML5,'')+' '+ N'<br/>' +
	N'<p style="font-family:Calibri">Atentamente,</p> ' +
    N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' +
    N'<p style="font-family:Calibri"><strong>Soporte NOMINA</strong></p></body>' ;
	 
   -- INSERT notificación consolidada
   INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
   VALUES ('A', 'Trabajadores', 'pa_trabVariasEmpresasJerDif', 'Avisos trabajadores en varias empresas con jefe 2 diferente', @cuerpo, @w, @dirigido, @copia);
   exec msdb.dbo.Sp_send_dbmail
     @profile_name = 'Informacion_Nomina',  
     @Subject = 'Avisos trabajadores en varias empresas con jefe 2 diferente',
     @recipients = @dirigido,
     @body_format= 'html',
	 @copy_recipients = @copia,
     @body = @cuerpo 



	 --------------------------------------------------------------------------------------------------------
   ----Valide que los colaboradores que tengamos contratado más de una empresa tenga la misma jerarquía 1.
   --------------------------------------------------------------------------------------------------------
    select @w = 0
    set @tableHTML5 = ''

	  declare @tablaTrab as table(trabajador char(10), d int)

	  insert into @tablaTrab
	  select trabajador, count(distinct Jefe1  ) from  rrhh.vw_datosTrabajadores
	  where trabajador in ( select trabajador from adam.dbo.VW_TrabActivosmasUnaEmpresa) and Situacion = 'Activo'
	  group by  Trabajador
	  having count(distinct Jefe1  )>1


	  declare @tabla5 as table (compania char(4), trabajador char(10), nombre varchar(200), jefe1 varchar(80), jefe1Ant varchar(80))

	 

	insert into @tabla5
	select  distinct '',  trabajador, nombre, Jefe1 ,''
	from  rrhh.vw_datosTrabajadores
	where trabajador in ( select trabajador from @tablaTrab)
	and Situacion = 'Activo'
	 
  
      select @w = count(*)  from @tabla5
	  --where jefe1Ant<> jefe1
	 
	 
	 if @w >0
	 begin
	   select @tableHTML5=' '+
		 N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de trabajadores en varias empresas con jefe 1 diferente </h4> </p> '+
         N' <hr/>'+
		 N'<table id="box-table" >' +
		 N' <tr align="left">'+    
		 N' <th align="left"> Trabajador </th>'+
		 N' <th align="left"> Nombre </th>'+
		 N' <th align="left"> Jefe 1 </th>'+ 
		  N' <th align="left"> Nombre Jefe 1 </th>'+ 
      cast( (select   distinct  
			td= trabajador,'',
			td= nombre,'',
			td= jefe1,'' ,
			td = (Select top 1 nombre from RRHH.vw_datosTrabajadores W where W.codigo = C.jefe1),''
      from @tabla5 C 
      --where jefe1Ant<> jefe1
    FOR XML PATH('tr'),TYPE ) as varchar(max))+
		N'</table>'+ 
		N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de trabajadores en varias empresas con jefe 1 diferente es de : ' + convert(varchar(5),@w) +'  </p>'  
		 
	 end
	 else
	 begin
	  select @tableHTML5=' '+
	   N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de trabajadores en varias empresas con jefe 1 diferente  </h4> </p> '+
       N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen trabajadores en varias empresas con jefe 1 diferente  </p>'+
	   N' <hr/>'  
	  
	 end

	  
   select @cuerpo ='<head> <title> </title>'+
	N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> '+
	N' </head>'+
    N' <body>'+'<br />'+  
	N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> '+
	N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,'+ @nombre+'</p>'+
     N' <hr/>' +isnull(@tableHTML5,'')+' '+ N'<br/>' +
	N'<p style="font-family:Calibri">Atentamente,</p> ' +
    N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' +
    N'<p style="font-family:Calibri"><strong>Soporte NOMINA</strong></p></body>' ;
	
   

   -- INSERT notificación consolidada
   INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
   VALUES ('A', 'Trabajadores', 'pa_trabVariasEmpresasJerDif', 'Avisos trabajadores en varias empresas con jefe 1 diferente', @cuerpo, @w, @dirigido, @copia);
   exec msdb.dbo.Sp_send_dbmail
     @profile_name = 'Informacion_Nomina',  
     @Subject = 'Avisos trabajadores en varias empresas con jefe 1 diferente',
     @recipients = @dirigido,
     @body_format= 'html',
	 @copy_recipients = @copia,
     @body = @cuerpo 


 End  