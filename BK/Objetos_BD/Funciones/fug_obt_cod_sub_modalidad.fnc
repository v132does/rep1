create or replace function it.fug_obt_cod_sub_modalidad(p_nro_cuenta in varchar2)
return number is
v_cod_sub_modalidad number(5) := null;
begin
   select cod_sub_modalidad
   into v_cod_sub_modalidad
   from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
   return v_cod_sub_modalidad;
exception
 when others then
     return null;
end;
/

