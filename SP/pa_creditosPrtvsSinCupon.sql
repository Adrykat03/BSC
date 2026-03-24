
CREATE procedure [Avisos].[pa_creditosPrtvsSinCupon]
@cco varchar(15)
AS
--"* Valide que los créditos ingresados en Payroll tienda versus créditos sin cupon cuadren.
--* La información que mostrará es el cuadre de los últimos tres días
--* La tarea estará visible mientras exista descuadre"

declare
@fechaIni date,
@fechaFin date,
@texto varchar(100), 
@fechaIniMal date, 
@fechaFinMal date,
@i smallint = 0

Begin
  declare @tableCreditos as table(cco varchar(15), fecha date,montoReg decimal(12,2), montoWs decimal(12,2) )

   declare @tableCreditosMal as table(cco varchar(15), fecha date , monto decimal(12,2))

  --if (datepart(DAY, getdate()) between 1 and 14)
  --begin
   
  -- select @fechaIni = fecha_ini_tiendas, @fechaFin = fecha_fin_tiendas from nomina.calendario_nominas
  -- where tipo_nomina = 'SQ' and mes_acumular = DATEPART(MONTH, GETDATE())
  -- and anio = DATEPART(YEAR,GETDATE()) and tipo_nomina = 'SQ'
  --end
  --else
  --begin
  --   select @fechaIni = fecha_ini_tiendas, @fechaFin = fecha_fin_tiendas from nomina.calendario_nominas
  -- where tipo_nomina = 'SQ' and mes_acumular = DATEPART(MONTH, dateadd(month,1,GETDATE()))
  -- and anio = DATEPART(YEAR,dateadd(month,1,GETDATE())) and tipo_nomina = 'SQ'
  --end

   insert into @tableCreditos
   Select cco, fecha , sum(monto),0 as monto  
   from CreditosTienda.RegistroCreditos
   where fecha between dateadd(day,-3,getdate()) and getdate() 
   and cco = @cco
   group by cco , fecha 

   insert into @tableCreditos
	Select cco, fechaConsumo , 0,sum(valor) as monto   
	from CreditosTienda.creditos_gte_ws
	where  fechaConsumo  between dateadd(day,-3,getdate()) and getdate() 
	and cco = @cco
	group by cco , fechaConsumo 
	 
   insert into @tableCreditosMal
	 select cco, fecha, sum(montoReg) - sum(montoWs) as diferencia from @tableCreditos
	 where   cco = @cco
	 group by cco, fecha
	 having sum(montoReg) - sum(montoWs) <>0
	 order by cco, fecha
  
  
 select @fechaIniMal =min(fecha) from @tableCreditosMal where  cco = @cco
 select @fechaFinMal = max(fecha) from @tableCreditosMal where cco = @cco

 
 while @fechaIniMal <= @fechaFinMal
 begin
    
   if  isnull(@texto,'') = ''
   begin
   select @texto =  convert(varchar(4),datepart(day,@fechaIniMal))

   end
   else
   begin
    select @texto =  @texto  +', ' + convert(varchar(4),datepart(day,@fechaIniMal))

   end
    
	set @i = @i+1
   set @fechaIniMal = dateadd(day,1,@fechaIniMal)

 end

  if ( @cco in (select cco from CreditosTienda.CCO_danCredito))
  begin
  if @i>0
  begin

     select @cco, 'El crédito de(los) día(s) ('+@texto+') se encuentra descuadrado, favor validar información','Diferencias Creditos',
               'Hay diferencias en los creditos de(los) día(s) ('+@texto+'). Valide por favor para no tener problemas ne la nómina',
			   getdate(),'Valide que los créditos ingresados en Payroll tienda versus créditos sin cupon cuadren. La información que mostrará es el cuadre de los últimos tres días. La tarea estará visible mientras exista descuadre ',1
  end
  end


 End