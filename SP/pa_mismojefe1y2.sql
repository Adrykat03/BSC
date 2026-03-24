----Avisos el mismo jefe en jefe 1 y 2

CREATE procedure [Avisos].[pa_mismojefe1y2]
AS
declare 
@tableHTML2 nvarchar(max),
@tableHTML nvarchar(max),
@tableHTML4 nvarchar(max),
@tableHTML3 nvarchar(max),
@tableHTML5 nvarchar(max),
@nombre varchar(100),
@query1 varchar(6000),
@cuerpo NVARCHAR(MAX),
@Dirigido varchar(300),
@copia varchar(100),
@w int=0,
@i int=0 

set nocount on
Begin


 declare @tablaCuerpo as table (cuerpo text)

    --select @copia = 'sabrina.chinchin@kfc.com.ec'
   select @Dirigido  = valor from Configuracion.parametros
   where parametro = 'Avisos_MisJef'

   select @copia  = valor from Configuracion.parametros
   where parametro = 'Avisos_MisJefC'
    

   set @nombre = 'Analista de Nómina'
   
   select @w = 0
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------
   ---Valide de la tabla de agrupaciones principales (CCO), filtre el jefe 1 o jefe 2 no sea el mismo colaborador. Es decir Sabri no sea el mismo jefe 1 y jefe 2
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------
    
	  declare @tableJefe1Jefe2 as table (cco varchar(15), descripcion varchar(200), jefe1 varchar(20), jefe2 varchar(20))
	  

	    insert into @tableJefe1Jefe2
	   select cco, descripcion , jefe1, jefe2 from Catalogos.centro_costos C
       where jefe2  = jefe1
       and esLocal  = 'S' and estatus = 1
	    
		delete dbo.mensajeCorreo1
	   insert into dbo.mensajeCorreo1(cco  , descripcion , jefe1 , jefe2 , tipo)

	   select *, 'J1J2' from @tableJefe1Jefe2
	    where jefe1 = jefe2


	  select  @w = count(*) from @tableJefe1Jefe2
  
	 --select @query1  = ' Select cco  , descripcion  , jefe1 , jefe2, (Select top 1 nombre from DB_NOMKFC.RRHH.vw_datosTrabajadores W where W.codigo = H.jefe1) as NombreJefe  from DB_NOMKFC.dbo.mensajeCorreo1 H '
	  
	 if @w >0
	 begin
	  SET @tableHTML = N'
<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400;">
    <h4>Listado de CCO que tienen asignados como Jefe 1 y jefe 2 a la misma persona.</h4>
</p>
<br/>
<table id="box-table">
    <tr align="left">
        <th align="center">CCO</th>
        <th align="left">Descripción</th>
        <th align="left">Jefe</th>
        <th align="left">Nombre Jefe 2</th>
    </tr>' +
    CAST(
        (SELECT
            td = cco, '',
            td = descripcion, '',
            td = jefe1, '',
            td = (SELECT TOP 1 nombre FROM RRHH.vw_datosTrabajadores W WHERE W.codigo = T.jefe1), ''
         FROM @tableJefe1Jefe2 T
         WHERE jefe1 = jefe2
         ORDER BY cco
         FOR XML PATH('tr'), TYPE
        ) AS NVARCHAR(MAX)) +
    N'</table>
<br/>';
	 end
	 else
	 begin
	  select @tableHTML =' '+
	    N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4>Listado de CCO que tienen asignados como Jefe 1 a un colaborador que pertenece a ese CCO</h4> </p> '+
        N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No Existen CCO con jefe 1 y jefe 2 igual  </p>' + 
	    N' <hr/>'
	 end
     
	  
	Set @tableHTML= Replace(@tableHTML, '<td>', '<td><small>') 
    Set @tableHTML = Replace(@tableHTML, '</td>', '</small></td>') 
   
    
    SET @cuerpo = N'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte</title>
    <style type="text/css">
        #box-table {
            font-family: "Calibri", sans-serif;
            font-size: 14px;
            text-align: center;
            border-collapse: collapse;
            border: 1px solid black;
        }
        #box-table th {
            font-size: 10px;
            font-weight: bold;
            background: black;
            color: white;
            border: 1px solid black;
        }
        #box-table td {
            border: 1px solid gray;
            color: black;
        }
        tr:nth-child(odd) {
            background-color: #eee;
        }
        tr:nth-child(even) {
            background-color: #fff;
        }
        th, td {
            padding: 4px;
            text-align: left;
        }
    </style>
</head>
<body>
    <p style="font-family: Calibri; color: black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400;">
        Estimado(a), ' + @nombre + N'
    </p>
    <hr/>
    ' + ISNULL(@tableHTML, 'No hay datos por reportar') + N'
    <br/><br/>
    <p>Atentamente,</p>
    <p>Por favor no responder a este correo, en caso de que requiera información adicional, comuníquese con el Área de Nómina.</p>
    <div>
        <p>
            <a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=14" target="_blank" style="color: blue; text-decoration: underline;">Ver Informe</a>
        </p>
        <p>Atentamente,</p>
        <p><strong>Departamento de Nómina</strong></p>
    </div>
</body>
</html>';
	 
	 
  -- INSERT notificación consolidada
  INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
  VALUES ('A', 'Jerarquías', 'pa_mismojefe1y2', 'Listado de CCO que tienen asignado jefe 1 o jefe 2 al mismo colaborador Tienda', @cuerpo, @w, @dirigido, @copia);
  exec msdb.dbo.Sp_send_dbmail
     @profile_name = 'Informacion_Nomina',  
     @Subject = 'Listado de CCO que tienen asignado jefe 1 o jefe 2 al mismo colaborador Tienda',
     @recipients = @dirigido, 
     @body_format= 'html',
	 @copy_recipients = @copia,
     @body = @cuerpo 
	  
	--drop table dbo.mensajeCorreo1
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------
   ---Valide de la tabla de agrupaciones principales (CCO), filtre el jefe 1 o jefe 2 no sea el mismo colaborador. Es decir Sabri no sea el mismo jefe 1 y jefe 2 CAR
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------
    
	  declare @tableJefe1Jefe2CAR as table (trabajador varchar(25), nombre varchar(200), jefe1 varchar(20),nombreJefe1 varchar(250), jefe2 varchar(20), nombreJefe2 varchar(250))
	   
	  -- create table  dbo.mensajeCorreo (trabajador varchar(25), nombre varchar(200), jefe1 varchar(20),nombreJefe1 varchar(250), jefe2 varchar(20), nombreJefe2 varchar(250))
	  Delete dbo.mensajeCorreo

	 insert into @tableJefe1Jefe2CAR
	 select trabajador, nombre,jefe1 , (Select top 1 nombre from RRHH.vw_datosTrabajadores W where W.codigo = t.jefe1) as nombreJefe1,
      jefe2 ,  (Select top 1 nombre from RRHH.vw_datosTrabajadores Z where Z.codigo = t.jefe2) as nombreJefe2
	 from RRHH.vw_datosTrabajadores t
	 where situacion  = 'Activo'
	 and car like '%CAR%'
	 and jefe1 = jefe2

	   insert into dbo.mensajeCorreo
	   select *  from @tableJefe1Jefe2CAR
	    where jefe1 = jefe2
		 

	  --select @query1  = ' Select trabajador , nombre , jefe1 ,nombreJefe1 , jefe2 , nombreJefe2  from DB_NOMKFC.dbo.mensajeCorreo '

	   set @w = 0
	  select  @w = count(*) from @tableJefe1Jefe2CAR
  
	 
	 if @w >0
	 begin
	  select @tableHTML= ''+
		N' <h4>Listado de trabajadores del CAR que tienen asignados como Jefe 1 y Jefe a la misma persona</h4> '+
		N' <br/>'+
		N'<table id="box-table" >' +
		N'  <tr>
      <th align="center">Cédula</th>
      <th align="left">Nombre</th>
      <th align="left">Jefe 1</th>
      <th align="left">Nombre Jefe 1</th>
      <th align="left">Jefe 2</th>
      <th align="left">Nombre Jefe 2</th>
    </tr>'+ 
	  cast(  (	SELECT  
	   td = trabajador, '', 
	   td = nombre, '',
	   td = jefe1, '' ,
	   td = isnull(nombreJefe1,''), '' ,
	   td = jefe2, '' ,
	   td = isnull(nombreJefe2,''),''
	  from @tableJefe1Jefe2CAR
	   order by trabajador
	  FOR XML PATH('tr'), TYPE 
		) AS varchar(max)) +
		N'</table>' +
		N' <br/>' 
	 end
	 else
	 begin
	  select @tableHTML =' '+
	    N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; ">  <h4>Listado de trabajadores del CAR que tienen asignados como Jefe 1 y Jefe a la misma persona</h4> </p> '+
        N' <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400; "> No Existen trabajadores del CAR con jefe 1 y jefe 2 igual  </p>' + 
	    N' <hr/>'
	 end
     
	  
	Set @tableHTML= Replace(@tableHTML, '<td>', '<td><small>') 
    Set @tableHTML = Replace(@tableHTML, '</td>', '</small></td>') 
   
    select @cuerpo ='<head>  <meta charset="UTF-8"> <title> </title>'+
	N'<style type="text/css">
  #box-table {
    font-family: "Calibri";
    font-size: 14px;
    text-align: center;
    border-collapse: collapse;
    border: 1px solid black; /* Simplificado */
  }
  #box-table th {
    font-size: 10px;
    font-weight: bold;
    background: black;
    color: white;
    border: 1px solid black;
  }
  #box-table td {
    border: 1px solid gray;
    color: black;
  }
  tr:nth-child(odd) {
    background-color: #eee;
  }
  tr:nth-child(even) {
    background-color: #fff;
  }
  th, td {
    padding: 4px;
    text-align: left;
  }
</style> '+
	N' </head>'+
    N' <body>'+'<br />'+  
	N'  <br /> 
        <p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal; font-weight: 400;">
        Estimado(a), '+ @nombre+'
      </p>  
   '+ 
    N' <hr/>' +isnull(@tableHTML ,'No hay datos por reportar')+' '+ N'<br/>' +
	N' 
  <p style="font-family: Calibri;">Atentamente,</p>
  <p>Por favor no responder a este correo, en caso de que requiera información adicional, comuníquese con el Área de Nómina.</p>
  <div>
    <p><a href="https://nomina.kfc.com.ec/KFCReporteador/vacaciones/AvisosVacaciones.aspx?A1=15" target="_blank">Ver Informe</a></p>
    <p>Atentamente,</p>
    <p><strong>Departamento de Nómina</strong></p>
  </div>
</body>
</html>'  ;
	 
	  
  -- INSERT notificación consolidada
  INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, cantidadRegistros, destinatarios, destinatariosCc)
  VALUES ('A', 'Jerarquías', 'pa_mismojefe1y2', 'Listado de personas que tienen asignado jefe 1 o jefe 2 al mismo colaborador CAR', @cuerpo, @w, @dirigido, @copia);
  exec msdb.dbo.Sp_send_dbmail
     @profile_name = 'Informacion_Nomina',  
     @Subject = 'Listado de personas que tienen asignado jefe 1 o jefe 2 al mismo colaborador CAR',
     @recipients = @dirigido, 
     @body_format= 'html',
	 @copy_recipients = @copia,
     @body = @cuerpo 

	-- drop table  dbo.mensajeCorreo 
 End