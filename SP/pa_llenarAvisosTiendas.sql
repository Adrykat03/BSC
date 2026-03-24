
CREATE procedure [Avisos].[pa_llenarAvisosTiendas]
AS
Declare
 @id numeric(28, 0),
 @cco  varchar(15),
 @trabajador char(10),
 @codigo varchar(20),
 @nombreCarga varchar(300),
 @nombre varchar(300),
 @mensajeCorto varchar(200),
 @asunto varchar(100),
 @tipoCarga varchar(25),
 @mensajeLargo varchar(max),
 @fecha_aviso smalldatetime,
 @fecha_aviso2 smalldatetime,
 @estado dbo.estatus,
 @regla_tarea varchar(max),
 @tipo smallint 

 Begin
     declare @tablaCargas as table(asunto varchar(50), regla varchar(max), cco varchar(15), 
                             mensajeCorte varchar(200), mensajeLargo varchar(2000), 
							 fechaAviso smalldatetime, tipoAviso smallint)

----Aviso cargas por aprobar
	Declare C_cargarsApro Cursor local For                          
	  Select C.cedula,T.Nombre, (select Descripcion from Cargas.Tipo_CargasFamiliares CA where CA.id_TipoCarga = C.id_TipoCarga) as tipo_carga ,
	  C.nombre +' '+ c.apellido as nombreCarga, CCO
	  from Cargas.familiares_personas C inner join adam.dbo.vw_datos_trabajador T
	  on C.cedula = T.Trabajador 
	  where estado = 0 and Situacion = 'Activo' and Fecha_bajaIndice is null

Open C_cargarsApro                          
                          
 While @@Fetch_Status < 1                          
  Begin                          
     Fetch C_cargarsApro Into @trabajador,@nombre,@tipoCarga,@nombreCarga,@cco                   
                          
     If @@Fetch_Status <> 0                           
        Begin                          
           Break                          
        End                          
      
	  set @regla_tarea = 'Dar lectura del módulo de cargas familiares con estado "Por aprobar". Esta alerta debe generarse todos los días lunes. La tarea desaparece cuando el estado de CF cambie a legalizado. (Nombre/tipo de carga/nombre carga)'
	  set @asunto = 'Cargas pendientes por aprobar'
	  set @mensajeCorto = 'Trabajador:' +@nombre +' Carga: ' +@nombreCarga  + ' Tipo Carga: ' + @tipoCarga

	  set @mensajeLargo = 'El trabajador '+@nombre +' con cédula: ' + @trabajador + ' tiene una carga pendiete por aprobar, con nombre ' + @nombreCarga + '('+@tipoCarga+').' + 
	                       ' Por favor entrar al módulo de Cargas Familiares o comunicarse con el departamento de Nómina.'
	  
	  
	  
	  insert into @tablaCargas (cco, mensajeCorte, asunto,mensajeLargo, fechaAviso, regla, tipoAviso )
	  select @cco, @mensajeCorto, @asunto,@mensajeLargo,getdate(),  @regla_tarea,1

                       
end                          
  Close      C_cargarsApro                          
  Deallocate C_cargarsApro



  INSERT INTO Avisos.avisosTiendas (cco,nombre,mensajeCorto,asunto,mensajeLargo,fecha_aviso,fecha_aviso2,estado,regla_tarea,tipo)
  Select cco, 'Aviso Cargas',mensajeCorte,asunto,mensajeLargo, fechaAviso, getdate(),1,regla, tipoAviso
  from  @tablaCargas
    
 End
