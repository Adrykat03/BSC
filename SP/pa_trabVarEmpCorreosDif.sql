
CREATE procedure [Avisos].[pa_trabVarEmpCorreosDif]
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

Begin

 select @w = 0
    
	 declare @tablaCuerpo as table (cuerpo text)
    
     --select @copia  = valor from Configuracion.parametros
     --where parametro = 'Avisos_MCDEC'

     --select @Dirigido  = valor from Configuracion.parametros
     --where parametro = 'Avisos_MCDE'

   set @nombre = 'Analista de Nómina'

	declare @tabla2 as table (compania char(4), trabajador char(10), nombre varchar(200), correo varchar(80), correoAnt varchar(80))

	 insert into @tabla2
	select Compania, trabajador, nombre, correoEmpresa,case when LAG (correoEmpresa, 1, 0) OVER (PARTITION BY trabajador ORDER BY correoEmpresa DESC) = '0' then correoEmpresa else
	LAG (correoEmpresa, 1, 0) OVER (PARTITION BY trabajador ORDER BY correoEmpresa DESC)  end 
	from  rrhh.vw_datosTrabajadores
	where trabajador in ( select trabajador from adam.dbo.VW_TrabActivosMasUnaEmpresa)
	and Situacion = 'Activo'
  
	select @w = count(*) from @tabla2 where correo <> correoAnt

	 --if @w >0
	 --begin


	 select   distinct 
			 compania, 
			 trabajador, 
			 nombre, 
		     correo, 
			  correoAnt 
     from  @tabla2  
	 where correo <> correoAnt
	 order by trabajador


	 --  select @tableHTML4=' '+
		-- N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de los colaboradores que no tienen la misma dirección de correo en todas las empresas </h4> </p> '+
  --       N' <br/>'+
		-- N'<table id="box-table" >' +
		-- N' <tr align="left">'+   
		-- N' <th align="left"> Compania </th>'+
		-- N' <th align="left"> Trabajador </th>'+
		-- N' <th align="left"> Nombre </th>'+
		-- N' <th align="left"> correo Empresa </th>'+
		-- N' <th align="left"> correo Dif Empresa </th>'+ 
  --    cast( (select   distinct 
		--	td= compania,'',
		--	td= trabajador,'',
		--	td= nombre,'',
		--	td= correo,'',
		--	td= correoAnt,''  
  --   from  @tabla2  
	 --where correo <> correoAnt
	 --order by trabajador
  --  FOR XML PATH('tr'),TYPE ) as varchar(max))+
		--N'</table>'+ 
		--N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de trabajadores en varias empresas que tienen correos diferentes es de: ' + convert(varchar(5),@w) +'  </p>'  
		 
	 --end
	 --else
	 --begin
	 -- select @tableHTML4=' '+
	 --  N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> <h4>Listado de los colaboradores que no tienen la misma dirección de correo en todas las empresas </h4> </p> '+
  --     N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen trabajadores en varias empresas que tengan correos diferentes </p>' +
	 --  N' <hr/>' 
	  
	 --end
	  
	 --  select @cuerpo ='<head> <title> Listado de Alertas</title>'+
	 --N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> '+
	 --N' </head>'+
  --   N' <body>'+'<br />'+  
	 --N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> Listado de Alertas</h4> </p> '+
	 --N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,'+ @nombre+'</p>'+
  --   N' <hr/>' +isnull(@tableHTML4,'')+' '+ N'<br/>' +
	 --N'<p style="font-family:Calibri">Atentamente,</p> ' +
  --   N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' +
  --   N'<p style="font-family:Calibri"><strong>Soporte NOMINA</strong></p></body>' ;
	
   

  --exec msdb.dbo.Sp_send_dbmail
  --   @profile_name = 'Informacion_Nomina',  
  --   @Subject = 'Avisos de trabajadores en varias empresas que tengan correos diferentes',
  --   @recipients = @dirigido,
  --   @body_format= 'html',
	 --@copy_recipients = @copia,
  --   @body = @cuerpo
	 
 End