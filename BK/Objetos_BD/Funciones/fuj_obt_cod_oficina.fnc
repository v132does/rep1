create or replace function it.fuj_obt_cod_oficina(p_nro_caja in number)
return number is
v_cod_oficina number(5);
begin
   select cod_oficina
     into v_cod_oficina
     from cj_cajas
    where nro_caja = p_nro_caja;
   return v_cod_oficina;
exception
   when others then
       return null;
end;
/

