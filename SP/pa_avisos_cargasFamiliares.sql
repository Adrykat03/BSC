  
 create procedure avisos.pa_avisos_cargasFamiliares
 (
  @tipo smallint 
 )
 AS
 Begin

 if @tipo = 1
 begin
  --Si el trabajador ingreso anterior a la fecha de nacimiento del hijo debe tener una maternidad 

 select  t.Compania_Desc,t.Desc_Clase_Nomina, t.cco as CCO, t.Desc_CCO Trabajador, nombreTrab as Nombre,t.Fecha_Ingreso, Fecha_Antiguedad,T.genero,
 tipoCarga as Tipo_Cargo, f.nombre as Nombre_Carga, f.Fecha_Nacimiento, tipoDiscapacidad as Discapacitado
 from Cargas.vw_cargasPersonal f inner join RRHH.vw_datosTrabajadores t
 on f.codigo =t.codigo
 where f.codigo not in (select codigo from  ausencias.accidentes  where id_tipoAusencia  in ( '01'))
 and tipoCarga = 'HIJO / A'  and t.situacion = 'Activo'
 and  f.fecha_nacimiento>='20230101'
 and Genero <> 'Masculino'
 and Fecha_Ingreso>f.fecha_nacimiento
 end
  else if @tipo = 2
 begin
  --Si el trabajador ingreso anterior a la fecha de nacimiento del hijo debe tener una paternidad

 select  t.Compania_Desc,t.Desc_Clase_Nomina, t.cco as CCO, t.Desc_CCO Trabajador, nombreTrab as Nombre,t.Fecha_Ingreso, Fecha_Antiguedad,T.genero,
 tipoCarga as Tipo_Cargo, f.nombre as Nombre_Carga, f.Fecha_Nacimiento, tipoDiscapacidad as Discapacitado
 from Cargas.vw_cargasPersonal f inner join RRHH.vw_datosTrabajadores t
 on f.codigo =t.codigo
 where f.codigo not in (select codigo from  ausencias.accidentes  where id_tipoAusencia  in ( '04'))
 and tipoCarga = 'HIJO / A'  and t.situacion = 'Activo'
 and  f.fecha_nacimiento>='20230101'
 and Genero = 'Masculino'
 and Fecha_Ingreso>f.fecha_nacimiento
 end
 

 End
 