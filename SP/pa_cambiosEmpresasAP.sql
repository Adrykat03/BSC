 CREATE  procedure [Avisos].[pa_cambiosEmpresasAP]    
 AS    
Declare     
 @html varchar(max)='',    
 @asunto varchar (400),    
 @saludos varchar(500)='',    
 @msg varchar (5000)='',    
 @correo varchar(max),    
 @fecha date    
    
Begin    
Declare @mesNombre varchar(20)    
     
  select @asunto=descripcion , @saludos=valor, @msg=referencia_06 from configuracion.parametros where parametro='Mail_APCE'    
    
      
  Select @mesNombre = Configuracion.fn_Nombre_Mes(datepart(month, GETDATE()))    
  select @fecha =  dateadd(month, -1,DATEADD(month,DATEDIFF(month,0,GETDATE()),0))     
     
  set @msg= replace(@msg,'@fecha',@mesNombre)     
      select @correo= Configuracion.fn_correosVariosRemitentes ('RecibNotPrebaja')    
              
  --select @correo =  valor  from configuracion.parametros where parametro='AVI_CAMEMP_AP'    
   set @correo=replace(@correo,'ñ','n')    
         
       
   Select @html='<head> <title></title>'+    
   N' <style type="text/css"> #box-table { font-family: "Calibri"; font-size: 12px; text-align: center; border-collapse: collapse; border-top: 0px solid black; border-bottom: 0px solid black; }   
   #box-table th { font-size: 12px; font-weight: normal; font-style: bold; background: black; border-right: 0px solid black; border-left: 0px solid black; border-bottom: 0px solid black; color: white; }  
    #box-table td { border-right: 0px solid gray; border-left: 0px solid gray; border-bottom: 0px solid gray; color: black; } tr:nth-child(odd)   
   { background-color:#eee; } tr:nth-child(even)  { background-color:#fff; } th, td { padding: 4px; text-align: left;}</style> '+    
   N' </head>'+    
   N' <body>'+    
   N' <p style="font-family: Calibri; color:black;font-size:15px;line-height:auto;">'+@saludos+'</p>'+    
    
  @msg +    
        N' <br/>'+    
        N'<table id="box-table" border=0 cellspacing=0 cellpadding=0;  >' +    
        N'<tr border-bottom: 1px align="center">'+    
        N'<th style=" text-align: center;background-color:gray; color:white;" colspan="3" align="left"><strong>Datos Trabajador</strong></th>'+    
        N'<th style=" text-align: center;background-color:DarkSlateGray; color:white;" colspan="3" align="left"><strong>Datos Empresa Ant</strong></th>'+    
        N'<th style=" text-align: center;background-color:DarkCyan; color:white;" colspan="3" align="left"><strong>Datos Empresa Nueva</strong></th>'+    
        N'<th style=" text-align: center;background-color:SteelBlue; color:white;" colspan="1" align="left"><strong>Fechas</strong></th>'+    
        N'</tr>'+    
        N' <tr style="text-align: center;">'+    
        N' <th style="text-align: center;"> <strong>Cédula</strong></th>'+    
        N' <th style="text-align: center;"> <strong>Nombre</strong></th>'+    
        N' <th style="text-align: center;"> <strong>Cargo</strong></th>'+     
        N' <th style="text-align: center;"> <strong>Compañía ANT</strong></th>'+    
  N' <th style="text-align: center;"> <strong>Cadena ANT</strong></th>'+    
  N' <th style="text-align: center;"> <strong>CCO ANT</strong></th>'+     
  N' <th style="text-align: center;"> <strong>Compañía</strong></th>'+    
  N' <th style="text-align: center;"> <strong>Cadena</strong></th>'+    
     N' <th style="text-align: center;"> <strong>CCO</strong></th>'+     
        --N' <th style="text-align: center;"> <strong>Fecha Creación</strong></th>'+    
        N' <th style="text-align: center;"> <strong>Fecha Efectiva</strong></th>'+    
            
    cast( (select distinct td= left(a.codigo,10), '',    
            td= Nombre,'',    
   td= t.Cargo,'' ,    
   td= Compania_Desc,'',    
   td= t.Desc_Clase_Nomina,'',    
   td= Desc_CCO,'',    
   td= (select x.nombre_cia from Catalogos.VW_CCO x where x.cco = a.cco ),'',    
   td= (select cadena from Catalogos.VW_CCO x where x.cco = a.cco ),'',    
   td= (select descripcion from Catalogos.VW_CCO x where x.cco = a.cco ) ,'',    
   --td= convert(nvarchar,fecha_creacion,103), '',     
   td= convert(nvarchar,fecha_efectiva,103), ''      
     from AP.AccionesPersonal a inner join RRHH.vw_datosTrabajadores t on a.codigo = t.Codigo    
  where fecha_creacion>= @fecha     
  and accionCCO = 1     
  and ccoICE = 1     
  and estado in (7,5)    
  and datepart(month,fecha_efectiva) <> datepart(month,fecha_creacion)      
  FOR XML PATH('tr'),TYPE ) as varchar(max))+    
      N'</table>'+    
   N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal;"> Atentamente </p>'+    
      N'<p style="font-family: Calibri; color:black; font-size: 14px; font-style: normal; font-variant: normal;">NÓMINA</p>'+    
      N' <br/><br /><br/><br/>  </body>'  ;    
    
    --print @html    
  declare @correoSoporte varchar(80)    
  select @correoSoporte =Configuracion.fn_soportemail()    
     
   --EXEC dbo.pa_enviar_correo_general  
   -- @Modulo   = 'AP-CE',  
   -- @To       = @correo,  
   -- @Cc       = NULL,  
   -- @Bcc      =@correoSoporte,  
   -- @Asunto   = @asunto,  
   -- @Mensaje  = @html;  
  
  
 -- INSERT notificación consolidada
 INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios, destinatariosCc)
 VALUES ('A', 'Cambios', 'pa_cambiosEmpresasAP', @asunto, @html, @correo, @correoSoporte);
 exec msdb.dbo.Sp_send_dbmail    
     @profile_name = 'Informacion_Nomina',      
     @Subject = @asunto,    
     @recipients =   @correo,    
     @blind_copy_recipients =@correoSoporte,    
     @body_format= 'html',    
     @body = @html       
    
  -- INSERT notificación consolidada
  INSERT INTO Avisos.notificacionesConsolidadas (estado, origen, spOrigen, asunto, descripcionHtml, destinatarios)
  VALUES ('A', 'Cambios', 'pa_cambiosEmpresasAP', @asunto, @html, @correoSoporte);
  exec msdb.dbo.Sp_send_dbmail    
     @profile_name = 'Informacion_Nomina',      
     @Subject = @asunto,    
     @recipients =   @correoSoporte,     
     @body_format= 'html',    
     @body = @html      
     
  End    
         