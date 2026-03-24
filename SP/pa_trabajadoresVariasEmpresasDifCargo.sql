CREATE procedure [Avisos].[pa_trabajadoresVariasEmpresasDifCargo]
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
   where parametro = 'Avisos_VTVEMPC'


   select @Dirigido  = valor from Configuracion.parametros
   where parametro = 'Avisos_TVEMP'

   set @nombre = 'Analista de Nómina'
   
   select @w = 0

 --------------------------------------------------------------------------------------------------------
   ----Valide que los colaboradores que esten en  contratado más de una empresa tenga el mismo cargo.
   --------------------------------------------------------------------------------------------------------
    
   declare @tabla as table (codigo char(20),trabajador char(10), nombre varchar(200), cargoHomologado varchar(150), cargoHomologaAnt varchar(150))

	insert into @tabla
	select codigo, trabajador, nombre, Cargo,case when LAG (Cargo, 1, 0) OVER (PARTITION BY trabajador ORDER BY Cargo DESC) = '0' then Cargo else
	LAG (Cargo, 1, 0) OVER (PARTITION BY trabajador ORDER BY Cargo DESC)  end 
	from  rrhh.vw_datosTrabajadores
	where trabajador in ( select trabajador from adam.dbo.VW_TrabActivosMasUnaEmpresa)
	and Situacion = 'Activo'

   select @w =count(*) from @tabla
    where cargoHomologaAnt <> cargoHomologado
	 
	-- if @w >0
	-- begin
	--   select @tableHTML2=' '+
	--     N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4>Listado de los colaboradores que están contratados en más de una empresa con cargo diferente </h4> </p> '+
 --        N' <br/>'+ 
	--	 N'<table id="box-table" >' +
	--	 N' <tr align="left">'+   
	--	 N' <th align="left"> Trabajador </th>'+
	--	 N' <th align="left"> Nombre </th>'+
	--	 N' <th align="left"> Jerarquía </th>'+ 
 --     cast( (select   distinct 
	--		td= trabajador,'',
	--		td= nombre,'',
	--		td= cargoHomologado,''  
 --    from  @tabla    where cargoHomologaAnt <> cargoHomologado 
	-- order by trabajador
 --    FOR XML PATH('tr'),TYPE ) as varchar(max))+
	--	 N'</table>'+
	--	 N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> La cantidad de trabajadores en varias empresas con cargos diferentes: ' + convert(varchar(5),@w) +'  </p>'  +
	--     N'<hr/>'
	-- end
	-- else
	-- begin
	--  select @tableHTML2=' '+
	--   N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4>Listado de los colaboradores que están contratados en más de una empresa con cargo diferente </h4> </p> '+
 --      N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No existen trabajadores en varias empresas con cargos diferentes </p>' + 
	--   N' <hr/>'
	-- end
   
	--Set @tableHTML2= Replace(@tableHTML2, '<td>', '<td><small>') 
 --   Set @tableHTML2 = Replace(@tableHTML2, '</td>', '</small></td>') 
 
 --	 select @cuerpo ='<head> <title> </title>'+
	--N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 10px; text-align: center; border-collapse: collapse; border-top: 1px solid black; border-bottom: 1px solid black; } #box-table th { font-size: 10px; font-weight: normal; font-style: bold; background: black; border-right: 1px solid black; border-left: 1px solid black; border-bottom: 1px solid black; color: white; } #box-table td { border-right: 1px solid gray; border-left: 1px solid gray; border-bottom: 1px solid gray; color: black; } tr:nth-child(odd)   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style>'+
	--N' </head>'+
 --   N' <body>'+'<br />'+  
	--N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4> </h4> </p> '+
	--N' <p  style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> Estimado(a) ,'+ @nombre+'</p>'+
 --    N' <hr/>' +isnull(@tableHTML2,'')+' '+ N'<br/>' +
	--N'<p style="font-family:Calibri">Atentamente,</p> ' +
 --   N'<p>Por favor no responder a este correo, en caso de que requiera informaci&oacute;n adicional, comun&iacute;quese con el &Aacute;rea de N&oacute;mina.</p> ' +
 --   N'<p style="font-family:Calibri"><strong>Soporte NOMINA</strong></p></body>' ;
 
		Select codigo,trabajador , nombre , cargoHomologado  , cargoHomologaAnt from @tabla
		  where cargoHomologaAnt <> cargoHomologado
		order by trabajador
  --exec msdb.dbo.Sp_send_dbmail
  --   @profile_name = 'Informacion_Nomina',  
  --   @Subject = 'Avisos de trabajadores en varias empresas con cargos diferentes',
  --   @recipients = @dirigido,
  --   @body_format= 'html',
	 --@copy_recipients = @copia,
  --   @body = @cuerpo 

 END
  