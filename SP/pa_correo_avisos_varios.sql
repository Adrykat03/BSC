CREATE  procedure [Avisos].[pa_correo_avisos_varios]
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
@i int=0,
@espacioTotal varchar(15) 
 
 Begin
 /****** Object:  Table [ANS].[estructuraSalarial]    Script Date: 20/09/2022 15:03:26 ******/
   -- IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'mensajeCorreo1') AND type in (N'U'))
   -- begin
   -- DROP TABLE dbo.mensajeCorreo1
   --End
  --- create table  dbo.mensajeCorreo1 (cco varchar(15), descripcion varchar(200), jefe1 varchar(20), jefe2 varchar(20),tipo varchar(10) )
     
 --     delete dbo.mensajeCorreo1
 --  --------------------------------------------------------------------------------------------------------
 --  ---Avisos el mismo jefe en jefe 1 y 2.
 --  --------------------------------------------------------------------------------------------------------
  
	--exec avisos.pa_mismojefe1y2
	  
 --  --------------------------------------------------------------------------------------------------------
 --  ----Valide que los colaboradores que esten en  contratado más de una empresa tenga el mismo cargo.
 --  --------------------------------------------------------------------------------------------------------
    ---no esta
  --exec avisos.pa_trabajadoresVariasEmpresasDifCargo 

   
 --  --------------------------------------------------------------------------------------------------------
 --  ----Valide que contengan la misma dirección de correo en todas las empresas.
 --  --------------------------------------------------------------------------------------------------------
 --no esta
  --exec avisos.pa_trabVarEmpCorreosDif

 --  --------------------------------------------------------------------------------------------------------
 --  ----Notifique los cargos que únicamente tiene dos o menos beneficios asignados.
 --  --------------------------------------------------------------------------------------------------------
    --No esta
	exec avisos.pa_trabMenos2Benf 

 --  --------------------------------------------------------------------------------------------------------
 --  ----Valide que los colaboradores que tengamos contratado más de una empresa tenga la misma jerarquía 1 y 2.
 --  --------------------------------------------------------------------------------------------------------
    
	--exec avisos.pa_trabVariasEmpresasJerDif

 --  --------------------------------------------------------------------------------------------------------
 --  ----Listado de CCO no locales con J1 o J2 menores a 070 que no pertenecen a la clase de nómina 27 (Embutser), 11 (Planta)
 --  --------------------------------------------------------------------------------------------------------
    
	-- exec avisos.pa_validarJerarquiasCarPlanta

 --  --------------------------------------------------------------------------------------------------------
 --  ----Listado de CCO locales con J1 o J2 menores a 060  pertenecen a la clase de nómina 27 (Embutser), 11 (Planta)
 --  --------------------------------------------------------------------------------------------------------
 --   exec avisos.pa_validarJerarquiasCarNoPlanta

 --  --------------------------------------------------------------------------------------------------------
 --  ----Listado de CCO locales con J1 o J2 menores a 050 que son tienda
 --  --------------------------------------------------------------------------------------------------------
 --   exec avisos.pa_validarJerarquiasLocales

	-- --------------------------------------------------------------------------------------------------------
 --  ----Listado de CCO con jefe 1 que no pertence al cargo debido.
 --  --------------------------------------------------------------------------------------------------------
   
	-- exec  avisos.pa_cargosgtesjefoprTiendasMal
 --   ---------------------------------------------------------------------------------------------
 --   ----Fin de los procesos
 --   ---------------------------------------------------------------------------------------------



end

 