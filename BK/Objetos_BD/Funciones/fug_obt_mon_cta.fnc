create or replace function it.fug_obt_mon_cta -- Funcion de busqueda de la moneda en una cuenta
   (p_nro_cuenta in varchar2) -- Recibe el nro de cuenta 
    return varchar2 is        -- Devuelve el nro de cuenta
    Result varchar2(3); 
begin
  -- Busca la cuenta para detectar la moneda
  select a.cod_moneda
    into result
    from ge_cuentas a
   where a.nro_cuenta = p_nro_cuenta;
  return(Result);
exception
  when no_data_found then
     raise_application_error(-20000,'Error en traer la moneda de la cuenta : '||p_nro_cuenta||'-'||sqlerrm);  
  when others then 
     raise_application_error(-20000,'Error en fug_obt_mon_cta : '||p_nro_cuenta||'-'||sqlerrm);  
end fug_obt_mon_cta;
/

