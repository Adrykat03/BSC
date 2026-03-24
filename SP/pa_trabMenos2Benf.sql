
CREATE procedure Avisos.pa_trabMenos2Benf
As
declare 
@tableHTML2 nvarchar(max),
@tableHTML nvarchar(max),
@tableHTML4 nvarchar(max),
@tableHTML3 nvarchar(max),
@tableHTML5 nvarchar(max),
@nombre varchar(100),
@query1 varchar(max),
@cuerpo NVARCHAR(MAX),
@Dirigido nvarchar(300),
@copia nvarchar(100),
@w int=0,
@i int=0 
Begin

     select @w = 0
      declare @tablaCuerpo as table (cuerpo text)
     
     
     --select @copia  = valor from Configuracion.parametros
     -- where parametro = 'Avisos_MDBFC'

     --select @Dirigido  = valor from Configuracion.parametros
     --where parametro = 'Avisos_MDBF'


    set @nombre = 'Analista de Nómina'

	 select @tableHTML5=' '
	 
	 declare @table7 as table(cadena varchar(250),cargo varchar(20), puesto varchar(250), cant smallint)
  
	  insert into @table7
	 select  CC.Descripcion as Cadena, A.id_cargo, C.descripcion,  count(id_parametroBeneficio) 
	from Cargos.rel_cargos_beneficios A inner join cargos.cargos C
    on A.id_cargo = C.id_cargo
	inner join catalogos.clases_de_nomina  cc
	on cc.id_clasenomina = a.id_clase_nomina
    group by  A.id_clase_nomina, CC.Descripcion, A.id_cargo, C.descripcion
    having count(id_parametroBeneficio) <3
  
     select @w = count(*)  from @table7 
	 
	  select  cadena,  cargo,   puesto, cant 
      from @table7 

	 --if @w >0
	 --begin
	 --  select @tableHTML5=' '+
		-- N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de cargos que tienen menos de dos beneficios asignados</h4> </p> '+
  --       N' <hr/>'+
		-- N'<table id="box-table" >' +
		-- N' <tr align="left">'+   
		-- N' <th align="left"> Cadena </th>'+
		-- N' <th align="left"> Cargo </th>'+ 
		-- N' <th align="left"> Puesto </th>'+
		-- N' <th align="left"> Cantidad </th>'+ 
  --    cast( (select   distinct td= cadena,'',
	 --       td= cargo,'', 
		--	td= puesto,'', 
		--	td= cant,''  
  --    from @table7 
  --  FOR XML PATH('tr'),TYPE ) as varchar(max))+
		--N'</table>'+ 
		--N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de cargos con dos o menos beneficios es de: ' + convert(varchar(5),@w) +'  </p>'  
		 
	 --end
	 --else
	 --begin
	 -- select @tableHTML5=' '+
	 --  N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de cargos que tienen menos de dos beneficios asignados </h4> </p> '+
  --     N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen cargos con dos o menos beneficios  </p>'+
	 --  N' <hr/>'  
	  
	 --end

	  
  -- select @cuerpo ='<head> <title> </title>'+
	 --N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> '+
	 --N' </head>'+
  --   N' <body>'+'<br />'+  
	 --N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> '+
	 --N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,'+ @nombre+'</p>'+
  --   N' <hr/>' +isnull(@tableHTML5,'')+' '+ N'<br/>' +
	 --N'<p style="font-family:Calibri">Atentamente,</p> ' +
  --   N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' +
  --   N'<p style="font-family:Calibri"><strong>Soporte NOMINA</strong></p></body>' ;
	 

  -- exec msdb.dbo.Sp_send_dbmail
  --   @profile_name = 'Informacion_Nomina',  
  --   @Subject = 'Avisos cargos con 2 beneficios (o menos)',
  --   @recipients = @dirigido,
  --   @body_format= 'html',
	 ----@copy_recipients = @copia,
  --   @body = @cuerpo 


	 -- exec msdb.dbo.Sp_send_dbmail
  --   @profile_name = 'Informacion_Nomina',  
  --   @Subject = 'Avisos cargos con 2 beneficios (o menos)',
  --   @recipients = 'dennis.suarez@gmail.com',
  --   @body_format= 'html',
	 ----@copy_recipients = @copia,
  --   @body = @cuerpo 
 End


  
	 